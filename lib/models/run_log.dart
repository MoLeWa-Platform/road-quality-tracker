import 'package:hive/hive.dart';

part 'run_log.g.dart';

extension RunLogFormatting on RunLog {
  String toFormattedString({String? title}) {
    String header = 'R U N  I D: $runId';
    if (title!=null){
      header = title;
    }

    final warningText = warnings.isNotEmpty
        ? warnings.map((w) => '• $w').join('\n')
        : 'No warnings logged.';

    final fullLogText = fullLog.isNotEmpty
        ? fullLog.join('\n')
        : '(No full log entries)';

    return '''
$header

W A R N I N G S:

$warningText

–––––––––––––––––––––––––––––––

F U L L  L O G:

$fullLogText
''';
  }
}

@HiveType(typeId: 10)
class RunLog extends HiveObject {
  @HiveField(0)
  late String runId;

  @HiveField(1)
  late DateTime startTime;

  @HiveField(2)
  DateTime? endTime;

  @HiveField(3)
  late List<DateTime> recentPoints = [];

  @HiveField(4)
  late List<String> warnings = [];

  @HiveField(5)
  late List<String> fullLog = [];

  @HiveField(6)
  bool reviewed;

  RunLog({
    required this.runId,
    required this.startTime,
    this.reviewed = false,
  });

  getRecentPointsAsString(){
    return recentPoints.map((e) => e.toIso8601String()).toList();
  }

  @override
  String toString() {
    return 'RunLog('
        '\nrunId: $runId, '
        '\nstartTime: ${startTime.toIso8601String()}, '
        '\nendTime: ${endTime?.toIso8601String() ?? "null"}, '
        '\nrecentPoints: [${recentPoints.map((e) => e.toIso8601String()).join(", ")}], '
        '\nwarnings: [${warnings.length} entries], '
        '\nfullLog: [${fullLog.length} entries], '
        '\nfullLog: [${fullLog.join("\n")}], '
        '\nreviewed: $reviewed'
        ')';
  }

  
}