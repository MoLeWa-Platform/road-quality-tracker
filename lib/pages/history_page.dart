import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:road_quality_tracker/pages/log_page.dart';
import 'package:road_quality_tracker/services/run_logger.dart';
import 'package:road_quality_tracker/services/run_tracker.dart';
import '../services/run_history_provider.dart';
import '../models/run.dart';

enum SelectionType { none, upload, download }

class HistoryPage extends StatefulWidget {
  final RunLogger logger;
  const HistoryPage({super.key, required this.logger});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late RunLogger logger;
  RunHistoryProvider? runHistoryProvider;
  List<Run>? completedRuns;
  bool? hasUnsyncedRuns;

  int? expandedIndex;

  SelectionType selectionType = SelectionType.none;
  Set<String> selectedRunIds = {};

  @override
  void initState() {
    super.initState();
    logger = widget.logger;
  }

  void _uploadRuns() {
    logger.log('[HISTORY PAGE] Uploading Runs.');
    setState(() {
      if (selectionType != SelectionType.upload) {
        selectionType = SelectionType.upload;
        selectedRunIds =
            completedRuns!.where((r) => !r.isSynced).map((r) => r.id).toSet();
      } else {
        selectionType = SelectionType.none;
        selectedRunIds.clear();
      }
    });
  }

  void _downloadRuns() {
    logger.log('[HISTORY PAGE] Downloading Runs.');
    setState(() {
      if (selectionType != SelectionType.download) {
        selectionType = SelectionType.download;
        selectedRunIds =
            completedRuns!.map((r) => r.id).toSet(); // select all by default
      } else {
        selectionType = SelectionType.none;
        selectedRunIds.clear();
      }
    });
  }

  bool _areAllSelected() {
    final allIds = completedRuns!.map((r) => r.id).toSet();
    return selectedRunIds.containsAll(allIds) && allIds.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    runHistoryProvider = context.watch<RunHistoryProvider>();
    completedRuns = runHistoryProvider!.completedRuns.reversed.toList();
    hasUnsyncedRuns = completedRuns!.any((run) => !run.isSynced);

    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surfaceBright,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 17),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectionType == SelectionType.none
                        ? "Run History"
                        : selectionType == SelectionType.upload
                        ? "Upload Runs"
                        : "Download Runs",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      SizedBox(
                        height: 42,
                        width: 42,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LogPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(
                              0,
                            ), // icon is already centered
                            elevation: 1,
                          ),
                          child: const Icon(Icons.bug_report, size: 22),
                        ),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: hasUnreviewedLogsNotifier,
                        builder: (context, hasUnreviewed, _) {
                          if (!hasUnreviewed) return const SizedBox.shrink();
                          return Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.red, width: 1),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Divider(
                thickness: 1.3,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1,
              ),
            ],
          ),
          toolbarHeight: 70,
        ),
        body: Column(
          children: [
            const SizedBox(height: 15),
            if (selectionType != SelectionType.none)
              Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            selectionType == SelectionType.upload
                                ? Icons.cloud_upload
                                : Icons.download,
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            selectionType == SelectionType.upload
                                ? "Select runs to upload."
                                : "Select runs to download.",
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            "Select all",
                            style: TextStyle(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                          Checkbox(
                            value: _areAllSelected(),
                            onChanged: (checked) {
                              logger.log(
                                '[HISTORY PAGE] Tapped select-all checkbox, with checked=$checked.',
                              );
                              setState(() {
                                if (checked == true) {
                                  selectedRunIds =
                                      completedRuns!.map((r) => r.id).toSet();
                                } else {
                                  selectedRunIds.clear();
                                }
                              });
                            },
                          ),
                          SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: ValueListenableBuilder<String?>(
                valueListenable: RunTracker.activeRunId,
                builder: (context, activeRunId, _) {
                  return ListView.builder(
                    itemCount: completedRuns!.length,
                    itemBuilder: (context, index) {
                      final run = completedRuns![index];
                      final isExpanded = expandedIndex == index;
                      final isRunning = run.id == activeRunId;

                      return HistoryEntryCard(
                        onTap: () {
                          logger.log(
                            '[HISTORY PAGE] Tapped run to see more details.',
                          );
                          setState(() {
                            expandedIndex = isExpanded ? null : index;
                          });
                        },
                        isExpanded: isExpanded,
                        header: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          title: Text(run.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.secondary)),
                          subtitle: Text("Run on ${run.startTime.toLocal().toString().split('.').first.substring(0, 16)}"),
                          trailing:
                              selectionType != SelectionType.none
                                  ? _buildSelectionControls(run)
                                  : isRunning
                                  ? Padding(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: Text(
                                      "Currently Running ..",
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.green[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  )
                                  : _buildActionButtons(run),
                        ),
                        expandedContent: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Number of Points: ${run.runPoints.length}"),
                            SizedBox(height: 2),
                            Text("Vehicle Type: ${run.vehicleType}"),
                            SizedBox(height: 2),
                            Text("Duration: ${run.getFormattedDuration()}"),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child:
                  selectionType == SelectionType.none
                      ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed:
                                completedRuns!.isNotEmpty
                                    ? _downloadRuns
                                    : null,
                            icon: Icon(Icons.download),
                            label: Text("Download Runs"),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              elevation: 3,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed:
                                completedRuns!.isNotEmpty
                                    ? _uploadRuns
                                    : null, //hasUnsyncedRuns! ? _uploadRuns: null,
                            icon: Icon(Icons.upload),
                            label: Text("Upload Unsynced"),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              elevation: 3,
                            ),
                          ),
                        ],
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                selectionType = SelectionType.none;
                                selectedRunIds.clear();
                              });
                            },
                            icon: Icon(Icons.close),
                            label: Text("Cancel"),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (selectionType == SelectionType.upload) {
                                logger.log('[HISTORY PAGE] Uploading runs.');
                                context
                                    .read<RunHistoryProvider>()
                                    .uploadSelectedRuns(
                                      context,
                                      selectedRunIds,
                                    );
                              } else if (selectionType ==
                                  SelectionType.download) {
                                logger.log('[HISTORY PAGE] Downloading runs.');
                                context
                                    .read<RunHistoryProvider>()
                                    .downloadSelectedRuns(
                                      context,
                                      selectedRunIds,
                                    );
                              }
                              setState(() {
                                selectionType = SelectionType.none;
                                selectedRunIds.clear();
                              });
                            },
                            icon: Icon(
                              selectionType == SelectionType.upload
                                  ? Icons.upload
                                  : Icons.download,
                            ),
                            label: Text(
                              selectionType == SelectionType.upload
                                  ? "Submit Upload"
                                  : "Download Runs",
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSecondary,
                            ),
                          ),
                        ],
                      ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionControls(Run run) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            run.isSynced ? Icons.cloud_done : Icons.cloud_upload,
            color: run.isSynced ? Colors.green[800] : Colors.grey,
            size: 20,
          ),
          tooltip: "Sync status",
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: null, // or show info
        ),
        Checkbox(
          value: selectedRunIds.contains(run.id),
          onChanged: (checked) {
            setState(() {
              if (checked == true) {
                selectedRunIds.add(run.id);
              } else {
                selectedRunIds.remove(run.id);
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildActionButtons(Run run) {
    return Row(
      // mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            run.isSynced ? Icons.cloud_done : Icons.cloud_upload,
            color: run.isSynced ? Colors.green[800] : Colors.grey,
            size: 20,
          ),
          tooltip: "Sync status",
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: null, // or show info
        ),
        IconButton(
          icon: Icon(Icons.delete, size: 20),
          tooltip: "Rename run",
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: () => _deleteRun(context, run),
        ),
        IconButton(
          icon: Icon(Icons.edit, size: 20),
          tooltip: "Rename run",
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tightFor(width: 32, height: 32),
          onPressed: () => _renameRun(context, run),
        ),
      ],
    );
  }

  void _renameRun(BuildContext context, Run run) {
    logger.log('[HISTORY PAGE] Opening Rename Run Dialog.');
    final controller = TextEditingController(text: run.name);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Rename Run"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: "Enter new name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                logger.log('[HISTORY PAGE] Canceled Rename Run Dialog.');
                Navigator.pop(context);
              },
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                logger.log(
                  '[HISTORY PAGE] Save new run name for run with Id ${run.id}.',
                );
                run.name = controller.text;
                run.save();
                Navigator.pop(context);
                setState(() {});
              },
              child: Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _deleteRun(BuildContext context, Run run) {
    logger.log('[HISTORY PAGE] Opening Delete Run Dialog.');
    ColorScheme appColorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text("Delete Run"),
            content: Text(
              "Are you sure you want to delete:\n\n > ${run.name} ? \n\nThis cannot be undone!",
            ),
            actions: [
              TextButton(
                child: Text("Cancel"),
                onPressed: () {
                  logger.log('[HISTORY PAGE] Canceled Delete Run Dialog.');
                  Navigator.pop(context);
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColorScheme.secondary,
                  foregroundColor: appColorScheme.onSecondary,
                ),
                child: Text("Delete"),
                onPressed: () async {
                  logger.log('[HISTORY PAGE] Deleting run with id ${run.id}.');
                  await run.delete();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            ],
          ),
    );
  }
}

class HistoryEntryCard extends StatelessWidget {
  final Widget header;
  final Widget? expandedContent;
  final bool isExpanded;
  final VoidCallback onTap;

  const HistoryEntryCard({
    super.key,
    required this.header,
    required this.onTap,
    this.expandedContent,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      child: Card(
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 1.0,
                  vertical: 3.0,
                ),
                child: header,
              ),
              if (isExpanded && expandedContent != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 0, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(),
                      const SizedBox(height: 4),
                      ... expandedContent is Column
                          ? (expandedContent as Column).children
                          : [expandedContent!],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
