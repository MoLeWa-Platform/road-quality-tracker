import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:road_quality_tracker/models/run.dart';
import 'package:road_quality_tracker/models/run_log.dart';
import 'package:road_quality_tracker/services/run_history_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

final ValueNotifier<bool> hasUnreviewedLogsNotifier = ValueNotifier(false);

Future<void> updateUnreviewedLogState() async {
  final bugBox =
      Hive.isBoxOpen('runLoggerBugReports')
          ? Hive.box('runLoggerBugReports')
          : await Hive.openBox('runLoggerBugReports');

  final hasUnreviewed = bugBox.values.cast<RunLog>().any(
    (log) => !log.reviewed,
  );
  //dev.log("Updating unreviewed logs: $hasUnreviewed");
  hasUnreviewedLogsNotifier.value = hasUnreviewed;
}

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  late List<RunLog> logs = [];
  late List<Run?> runs = [];

  RunLog? lastNormalLog;
  Run? lastNormalRun;

  @override
  void initState() {
    super.initState();
    setupLogs();
  }

  Future<void> setupLogs() async {
    final runHistory = Provider.of<RunHistoryProvider>(context, listen: false);
    final bugBox =
        Hive.isBoxOpen('runLoggerBugReports')
            ? Hive.box('runLoggerBugReports')
            : await Hive.openBox('runLoggerBugReports');
    logs = bugBox.values.cast<RunLog>().toList().reversed.toList();

    runs = logs.map((log) => runHistory.getRunById(log.runId)).toList();

    final liveBox =
        Hive.isBoxOpen('runLoggerCurrent')
            ? Hive.box('runLoggerCurrent')
            : await Hive.openBox('runLoggerCurrent');

    lastNormalLog = liveBox.get('lastNormalRunLog');
    if (lastNormalLog != null) {
      lastNormalRun = runHistory.getRunById(lastNormalLog!.runId);
    }

    if (mounted) setState(() {});
  }

  Future<void> _confirmDeleteLog(BuildContext context, int index) async {
    final log = logs[index];
    final run = runs[index];
    String title = run != null ? run.name : '';
    if (run == null) {
      final shortId = log.runId.substring(0, 5);
      final dateStr = DateFormat('yyyy-MM-dd – kk:mm').format(log.startTime);
      title = "Log $shortId – $dateStr";
    }

    ColorScheme scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Delete Log"),
            content: Text(
              "Are you sure you want to delete the log:\n\n\t\t $title ?\n\nThis cannot be undone!",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.secondary,
                  foregroundColor: scheme.onSecondary,
                ),
                onPressed: () async {
                  Navigator.pop(context); // close confirmation dialog
                  await deleteLog(index);
                },
                child: const Text("Delete"),
              ),
            ],
          ),
    );
  }

  Future<void> _confirmClearLogs(BuildContext context) async {
    ColorScheme scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Clear all Logs"),
            content: Text(
              "\nAre you sure you want to delete ALL logs?\n\nThis cannot be undone!",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.secondary,
                  foregroundColor: scheme.onSecondary,
                ),
                onPressed: () async {
                  Navigator.pop(context); // close confirmation dialog
                  await clearAllLogs();
                },
                child: const Text("Delete"),
              ),
            ],
          ),
    );
  }

  Future<void> deleteLog(int index) async {
    final bugBox = Hive.box('runLoggerBugReports');
    final key = bugBox.keyAt(index);
    await bugBox.delete(key);
    updateUnreviewedLogState();
    
    setState(() {
      logs.removeAt(index);
      runs.removeAt(index);
    });
  }

  Future<void> clearAllLogs() async {
    final bugBox = Hive.box('runLoggerBugReports');
    await bugBox.clear();
    updateUnreviewedLogState();
    setState(() {
      logs.clear();
      runs.clear();
    });
  }

  String buildCombinedExport(RunLog log, Run? run, {String? title}) {
    final logText = log.toFormattedString();
    final runJson =
        run != null
            ? const JsonEncoder.withIndent('  ').convert(run.toJson())
            : '⚠️ Matching run not found.\n';

    return '''
----------- LOG -----------

$logText

----- RUN DATA (JSON) -----

$runJson
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Run Logs', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              thickness: 1.3,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1,
            ),
            const SizedBox(height: 16),
          ],
        ),
        toolbarHeight: 100,
      ),
      body:
          logs.isEmpty && lastNormalLog == null
              ? const Center(child: Text("No logs found."))
              : ListView(
                children: [
                  if (lastNormalLog != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        "Last Normal Run",
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    buildLastNormalRunCard(),
                    SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Divider(
                        thickness: 1.2,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withAlpha(85),
                      ),
                    ),
                    SizedBox(height: 5),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      "Bug Reports",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                  if (logs.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          SizedBox(height: 40),
                          Text(
                            "No bug reports saved at the moment.",
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...List.generate(
                      logs.length,
                      (index) => buildBugLogTile(index),
                    ),
                ],
              ),
      bottomNavigationBar:
          logs.isEmpty
              ? null
              : Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 50),
                child: ElevatedButton.icon(
                  onPressed: () => _confirmClearLogs(context),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Clear All Logs'),
                ),
              ),
    );
  }

  Widget buildBugLogTile(int index) {
    final log = logs[index];
    final run = runs[index];
    final title = (run?.name.isNotEmpty ?? false) ? run!.name : log.runId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
      child: Card(
        elevation: 1.5,
        child: ListTile(
          title: Row(
            children: [
              if (!log.reviewed)
                const Padding(
                  padding: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 20.0),
                  child: Icon(Icons.circle, size: 6, color: Colors.red),
                ),
              Expanded(child: Text(title)),
            ],
          ),
          subtitle: Text('${log.warnings.length} warning(s)'),
          trailing: IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              final exportText = buildCombinedExport(log, run);
              Share.share(exportText, subject: 'Run log for: $title');
            },
          ),
          onTap: () async {
            await showDialog(
              context: context,
              builder:
                  (_) => AlertDialog(
                    title: Text("Run log for: \n$title"),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: SingleChildScrollView(
                        child: Text(
                          '${log.toFormattedString()}\n\n'
                          '–––––––––––––––––––––––––––––––\n\n'
                          'R U N  D A T A \n\n'
                          '${run != null ? const JsonEncoder.withIndent('  ').convert(run.toJson()) : "⚠️ Run not found. Was probably deleted."}',
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Close"),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete),
                        label: const Text("Delete"),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _confirmDeleteLog(context, index);
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text("Share"),
                        onPressed: () {
                          final exportText = buildCombinedExport(log, run);
                          Share.share(
                            exportText,
                            subject: 'Run log for: $title',
                          );
                        },
                      ),
                    ],
                  ),
            );

            if (!log.reviewed) {
              log.reviewed = true;
              await log.save();
              await updateUnreviewedLogState();
              setState(() {});
            }
          },
        ),
      ),
    );
  }

  Widget buildLastNormalRunCard() {
    if (lastNormalLog == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final exportText = buildCombinedExport(lastNormalLog!, lastNormalRun);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Card(
        elevation: 1.5,
        color: theme.colorScheme.surfaceBright,
        child: ListTile(
          title: Text(
            lastNormalRun != null
                ? lastNormalRun!.name
                : DateFormat(
                  'yyyy-MM-dd – kk:mm',
                ).format(lastNormalLog!.startTime),
          ),
          subtitle: Text('No warning(s)'),
          trailing: IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.share(exportText, subject: 'Last Normal Run Log');
            },
          ),
          onTap: () {
            showDialog(
              context: context,
              builder:
                  (_) => AlertDialog(
                    title: const Text("Last Normal Run Log"),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: SingleChildScrollView(
                        child: Text(
                          '${lastNormalLog!.toFormattedString()}\n\n'
                          '–––––––––––––––––––––––––––––––\n\n'
                          'R U N  D A T A \n\n'
                          '${lastNormalRun != null ? const JsonEncoder.withIndent('  ').convert(lastNormalRun!.toJson()) : "⚠️ Run not found. Was probably deleted."}',
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Close"),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text("Share"),
                        onPressed: () {
                          Share.share(
                            exportText,
                            subject: 'Last Normal Run Log',
                          );
                        },
                      ),
                    ],
                  ),
            );
          },
        ),
      ),
    );
  }
}
