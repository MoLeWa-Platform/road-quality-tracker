import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:road_quality_tracker/models/run.dart';
import 'package:road_quality_tracker/models/run_log.dart';
import 'package:road_quality_tracker/services/run_history_provider.dart';
import 'package:road_quality_tracker/services/run_tracker.dart';

class RunLogger {
  static const _hiveBoxNameCurrent = 'runLoggerCurrent';
  static const _hiveBoxNameBugs = 'runLoggerBugReports';

  Box _liveBox;
  RunHistoryProvider? runHistory;

  DateTime? _lastPointTime;
  String? _runId;
  Queue<DateTime> _recentPoints = Queue();
  final List<String> _recentLogs = [];
  final List<String> _recentWarnings = [];

  Timer? _saveTimer;
  final int _saveIntervalSeconds = 17;
  final int _maxBufferedPoints = 15;

  Timer? _inactivityTimer;
  final Duration _inactivityCheckInterval = Duration(seconds: 10);

  String? _lastEventMessage;
  int _lastEventCount = 1;
  String? _lastEventTimestamp;

  String? _lastWarningMessage;
  int _lastWarningCount = 1;
  String? _lastWarningTimestamp;

  bool _hasShownBugPopupThisSession = false;

  bool get hasShownBugPopup => _hasShownBugPopupThisSession;

  void markBugPopupShown() {
    _hasShownBugPopupThisSession = true;
  }

  RunLogger._(this._liveBox, [this.runHistory]);

  static Future<RunLogger> create(RunHistoryProvider runHistory) async {
    final liveBox = await Hive.openBox(_hiveBoxNameCurrent);
    dev.log("Opened logging boxes", name: "RunLogger");
    final runLogger = RunLogger._(liveBox, runHistory);
    runLogger.checkForSuddenShutdown();
    return runLogger;
  }

  bool get runIsActive => _lastPointTime != null;

  static String getTs({DateTime? now}) {
    now ??= DateTime.now();
    return DateFormat('yyyy-MM-dd – kk:mm:ss').format(now);
  }

  Future<void> startRunLog(String runId) async {
    await reloadLiveBox();
    dev.log("Starting Runlog", name: "RunLogger");
    if (_liveBox.get('lastRunLog') != null) {
      checkForSuddenShutdown();
    } else {
      dev.log(
        "LastRunLog is empty, not checking for sudden shutdown.",
        name: "RunLogger",
      );
    }

    await saveInitialRunLog(runId);

    dev.log("Creating inactivityTimer @ ${DateTime.now()}", name: "RunLogger");
    _saveTimer = Timer.periodic(Duration(seconds: _saveIntervalSeconds), (_) {
      dev.log("Calling save procedure", name: "RunLogger");
      if (_recentPoints.isNotEmpty) {
        _saveRunLog();
      }
    });
    _inactivityTimer = Timer.periodic(_inactivityCheckInterval, (_) {
      dev.log("Calling inactivity check", name: "RunLogger");
      checkForInactivity();
    });
  }

  Future<void> saveInitialRunLog(String runId) async {
    await reloadLiveBox();
    await cleanState();
    dev.log("Starting saveInitialRunLog", name: "RunLogger");
    _runId = runId;
    await _liveBox.put('runId', runId);
    dev.log("Runid put into box.", name: "RunLogger");
    _lastPointTime = DateTime.now();
    await _liveBox.put('lastHeartbeat', _lastPointTime);
    _recentPoints.clear();
    _recentPoints.add(_lastPointTime!);

    RunLog currentRunLog = RunLog(runId: runId, startTime: _lastPointTime!);
    currentRunLog.fullLog.add("[${getTs()}] - [LOG] Run started ID: $runId \n");
    currentRunLog.recentPoints = (_recentPoints.toList());
    dev.log("Created RunLog \n ${currentRunLog.toString()}", name: "RunLogger");
    await _liveBox.put("lastRunLog", currentRunLog);
    dev.log(
      "logged: [${getTs()}] - [Run Started] ID: $runId",
      name: "RunLogger",
    );
    _recentLogs.clear();
    _recentWarnings.clear();
  }

  Future<void> endRun() async {
    await reloadLiveBox();
    RunLog log = _liveBox.get("lastRunLog");
    final endTime = DateTime.now();
    final duration = endTime.difference(log.startTime);
    logEvent("[${getTs()}] - [Run Ended] ID: $_runId | Duration: $duration");
    dev.log(
      'logged: [${getTs()}] - [Run Ended] ID: $_runId | Duration: $duration',
      name: "RunLogger",
    );
    await _saveRunLog(endTime: endTime);
    await finishUpRun();
  }

  Future<void> finishUpRun() async {
    await reloadLiveBox();
    final bugReportBox = await Hive.openBox(_hiveBoxNameBugs);
    RunLog log = _liveBox.get("lastRunLog");
    if (log.warnings.isNotEmpty) {
      await _liveBox.put('lastRunLog', null);
      await bugReportBox.add(log);
      dev.log("Added log to Bugs.", name: "RunLogger");
    } else {
      await _liveBox.put('lastRunLog', null);
      await _liveBox.put('lastNormalRunLog', log);
      dev.log("Added log as lastNormalRunLog.", name: "RunLogger");
    }
    await bugReportBox.close();
    cleanState();
  }

  Future<void> cleanState() async {
    await reloadLiveBox();
    _saveTimer?.cancel();
    _saveTimer = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;

    await _liveBox.delete('lastHeartbeat');

    _recentPoints.clear();
    _recentLogs.clear();
    _recentWarnings.clear();
    _runId = null;
    _lastPointTime = null;

    _lastEventMessage = null;
    _lastEventCount = 1;
    _lastEventTimestamp = null;

    _lastWarningMessage = null;
    _lastWarningCount = 1;
    _lastWarningTimestamp = null;

    await _liveBox.put('lastRunLog', null);
    await _liveBox.put('lastPointTime', null);
    await _liveBox.put('runId', null);
    await _liveBox.compact();
    await reloadLiveBox();
  }

  Future<void> checkForSuddenShutdown({Run? run}) async {
    await reloadLiveBox();
    dev.log("Checking for sudden shutdown, ", name: "RunLogger");
    final lastLog = _liveBox.get('lastRunLog');
    if (lastLog != null && lastLog.endTime == null) {
      // wasn't able to finish the run properly
      _loadOldRun(lastLog);
      final endTime =
          (lastLog.recentPoints.isNotEmpty)
              ? lastLog.recentPoints.last
              : lastLog.startTime;
      final Duration duration = endTime.difference(lastLog.startTime);
      run?.endTime = endTime;
      final ts = getTs();
      Run? measuredRun = run;
      if (runHistory != null) {
        // dont run from the background isolate
        measuredRun = runHistory?.getRunById(_runId!);
        measuredRun?.endTime = endTime;
      }
      if (measuredRun != null) await checkPointDensity(measuredRun);
      logWarning(
        "[SUDDEN SHUTDOWN] ID: $_runId | Duration: ${duration.inMinutes}min",
      );
      logEvent("[RECENT POINTS] ${_formatRecentPoints()}");
      dev.log(
        "logged WARNING: [$ts] - [SUDDEN SHUTDOWN] ID: $_runId | Duration: ${duration.inMinutes}min",
        name: "RunLogger",
      );
      dev.log(
        "logged [$ts] - [RECENT POINTS] ${_formatRecentPoints()}",
        name: "RunLogger",
      );
      await _saveRunLog(endTime: endTime);
      await finishUpRun();
    } else {
      dev.log("No sudden Shutdown detected", name: "RunLogger");
    }
  }

  void checkForInactivity({Duration timeout = const Duration(seconds: 20)}) {
    if (!runIsActive) return;
    dev.log("Checking inactivity", name: "RunLogger");
    final now = DateTime.now();
    final timeDiff = now.difference(_lastPointTime!);
    if (_lastPointTime != null && timeDiff > timeout) {
      final dateForm = DateFormat('yyyy-MM-dd – kk:mm:ss');
      final warning =
          "[NO POINTS RECORDED] since ${dateForm.format(_lastPointTime!)}";
      logWarning(warning);
      logEvent("[RECENT POINTS] ${_formatRecentPoints()}");
      dev.log(
        "logged WARNING: [${getTs(now: now)}] - [WARNING] $warning",
        name: "RunLogger",
      );
      dev.log(
        "logged [${getTs(now: now)}] - [RECENT POINTS] ${_formatRecentPoints()}",
        name: "RunLogger",
      );
      _saveRunLog();
      //FirebaseCrashlytics.instance.log(warning);
    } else {
      dev.log(
        "Inactivity check showed nothing supicious, timediff: $timeDiff",
        name: "RunLogger",
      );
    }
  }

  Future<void> checkPointDensity(Run run) async {
    num supposedTactInMs = RunTracker.tactInMs;
    num margin = 0.20; // 20%

    num pointNumber = run.runPoints.length;
    Duration runTime = run.endTime!.difference(run.startTime);
    if (runTime > Duration(seconds: 20)) {
      // avoid false warnings for very short runs
      num actualTact = runTime.inMilliseconds / pointNumber;
      if (actualTact > (supposedTactInMs * (1 + margin))) {
        // if 20% slower tact the expected
        final warning =
            "[LOW POINT COUNT] Less points measured than supposed to! Pointnumber: $pointNumber, "
            "Runtime: ${runTime.inSeconds}s, supposedTact: min. 1 point every ${supposedTactInMs}ms, actualTact: ${actualTact}ms!";
        logWarning(warning);
        dev.log(
          "logged WARNING: ${getTs()}] - [WARNING] $warning",
          name: "RunLogger",
        );
        _saveRunLog();
      } else {
        final info =
            "[POINT COUNT] Point density looks fine. Pointnumber: $pointNumber, "
            "Runtime: ${runTime.inSeconds}s, supposedTact: ${supposedTactInMs}ms, actualTact ${actualTact}ms.";
        logEvent(info);
        _saveRunLog();
        dev.log("Checked Pointdesity: ok. No Warning added.");
      }
    }
  }

  void logPoint(DateTime timestamp) {
    _lastPointTime = timestamp;
    _recentPoints.add(timestamp);

    if (_recentPoints.length > _maxBufferedPoints) {
      _recentPoints.removeFirst();
    }
    dev.log("Logged point!", name: "RunLogger");
  }

  void logEvent(String message, {DateTime? ts}) {
    if (!runIsActive) return;

    final timestamp = getTs(now: ts ?? DateTime.now());
    if (_lastEventMessage == message) {
      _lastEventCount++;
      _lastEventTimestamp = timestamp;
      return;
    } else {
      // save prior message and start new one
      if (_lastEventMessage != null) {
        final repeatSuffix =
            _lastEventCount > 1 ? " - [${_lastEventCount}x]" : "";
        _recentLogs.add(
          "[$_lastEventTimestamp] - [LOG] $_lastEventMessage$repeatSuffix\n",
        );
      }
      _lastEventMessage = message;
      _lastEventCount = 1;
      _lastEventTimestamp = timestamp;
    }
  }

  void logWarning(String message, {DateTime? ts}) {
    if (!runIsActive) return;

    final timestamp = getTs(now: ts ?? DateTime.now());

    if (_lastWarningMessage == message) {
      _lastWarningCount++;
      _lastWarningTimestamp = timestamp;
      return;
    } else {
      // Save the prior warning and start new one
      if (_lastWarningMessage != null) {
        final repeatSuffix =
            _lastWarningCount > 1 ? " - [${_lastWarningCount}x]" : "";
        _recentWarnings.add(
          "[$_lastWarningTimestamp] - [WARNING] $_lastWarningMessage$repeatSuffix\n",
        );
      }

      logEvent(message, ts: ts);

      _lastWarningMessage = message;
      _lastWarningCount = 1;
      _lastWarningTimestamp = timestamp;
    }
  }

  Future<void> _saveRunLog({DateTime? endTime}) async {
    await reloadLiveBox();
    final currentRunLog = _liveBox.get('lastRunLog') as RunLog?;
    if (currentRunLog != null) {
      _flushLastRepeatingLog(currentRunLog);
      _flushLastRepeatingWarning(currentRunLog);

      currentRunLog.fullLog.addAll(_recentLogs);
      currentRunLog.warnings.addAll(_recentWarnings);
      currentRunLog.recentPoints = _recentPoints.toList();

      _recentLogs.clear();
      _recentWarnings.clear();

      if (endTime != null) {
        currentRunLog.endTime = endTime;
      }

      await _liveBox.put('lastRunLog', currentRunLog);
      await _liveBox.put('lastHeartbeat', DateTime.now());
      dev.log(
        "Updated current log in hive. \n ${currentRunLog.toString()}",
        name: "RunLogger",
      );
    }
  }

  void _flushLastRepeatingLog(RunLog log) {
    if (_lastEventMessage == null) return;

    final timestamp = getTs();
    final repeatSuffix = _lastEventCount > 1 ? " - [${_lastEventCount}x]" : "";
    final formattedLog = "[$timestamp] - [LOG] $_lastEventMessage$repeatSuffix";

    if (!_recentLogs.contains(formattedLog)) {
      _recentLogs.add(formattedLog);
    }

    final firstInLine = _recentLogs.first.split(' - ')[1];
    if (log.fullLog.isNotEmpty && log.fullLog.last.contains(firstInLine)) {
      log.fullLog.removeLast();
      dev.log(
        "Removed last with repeating message: $firstInLine",
        name: "RunLogger",
      );
    }
  }

  void _flushLastRepeatingWarning(RunLog log) {
    if (_lastWarningMessage == null) return;

    final timestamp = getTs();
    final repeatSuffix =
        _lastWarningCount > 1 ? " - [${_lastWarningCount}x]" : "";
    final formattedWarning =
        "[$timestamp] - [WARNING] $_lastWarningMessage$repeatSuffix";

    _recentWarnings.add(formattedWarning);

    final firstInLine = _recentWarnings.first.split(' - ')[1];
    if (log.warnings.isNotEmpty && log.warnings.last.contains(firstInLine)) {
      log.warnings.removeLast();
      dev.log(
        "Removed last warning with repeating message: $firstInLine",
        name: "RunLogger",
      );
    }
  }

  String? _formatRecentPoints() {
    final recent =
        _recentPoints.map((s) => DateFormat('kk:mm:ss').format(s)).toList();

    return (recent.isNotEmpty)
        ? "Last ${recent.length} points: ${recent.join(', ')}"
        : null;
  }

  void _loadOldRun(RunLog log) {
    _runId = log.runId;
    _lastPointTime =
        log.recentPoints.isNotEmpty ? log.recentPoints.last : log.startTime;
    _recentPoints = Queue<DateTime>.from(log.recentPoints);
    _recentLogs.clear();
    _recentWarnings.clear();
    dev.log("Loaded old run. ${log.toString()}", name: "RunLogger");
  }

  void dispose() {
    _saveTimer?.cancel();
    _inactivityTimer?.cancel();
  }

  Future<Box> reloadLiveBox() async {
    await _liveBox.close();
    _liveBox = await Hive.openBox(_hiveBoxNameCurrent);
    dev.log('Reloaded LiveBox.', name: "RunLogger");
    return _liveBox;
  }

  void log(String msg, {bool warning = false}) {
    if (runIsActive) {
      if (warning) {
        logWarning(msg);
      } else {
        logEvent(msg);
      }
      final prefix = warning ? '[WARNING] ' : '[LOG] ';
      dev.log("$prefix$msg");
    }
  }

  Future<RunLog?> getMostRecentUnreviewedLog() async {
    final bugBox =
        Hive.isBoxOpen(_hiveBoxNameBugs)
            ? Hive.box(_hiveBoxNameBugs)
            : await Hive.openBox(_hiveBoxNameBugs);

    final log = bugBox.values.cast<RunLog>().lastOrNull;
    if (log != null && !log.reviewed) {
      return log;
    }
    return null;
  }
}
