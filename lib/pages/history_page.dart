import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/run_history_provider.dart';
import '../models/run.dart';

enum SelectionType { none, upload, download }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  RunHistoryProvider? runHistoryProvider;
  List<Run>? completedRuns;
  bool? hasUnsyncedRuns;
  
  int? expandedIndex;
  
  SelectionType selectionType = SelectionType.none;
  Set<String> selectedRunIds = {};

  void _uploadRuns(){
    setState(() {
      if (selectionType != SelectionType.upload) {
        selectionType = SelectionType.upload;
        selectedRunIds = 
          completedRuns!
          .where((r) => !r.isSynced)
          .map((r) => r.id)
          .toSet();
      } else {
        selectionType = SelectionType.none;
        selectedRunIds.clear();
      }
    });
  }

  void _downloadRuns() {
      setState(() {
      if (selectionType != SelectionType.download) {
        selectionType = SelectionType.download;
        selectedRunIds = completedRuns!.map((r) => r.id).toSet(); // select all by default
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
              const SizedBox(height: 25),
              Text(
                selectionType == SelectionType.none
                    ? "Run History"
                    : selectionType == SelectionType.upload
                        ? "Upload Runs"
                        : "Download Runs",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              selectionType == SelectionType.upload
                                  ? Icons.cloud_upload
                                  : Icons.download,
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              selectionType == SelectionType.upload
                                  ? "Select runs to upload."
                                  : "Select runs to download.",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                  ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              "Select all",
                              style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                            ),
                            Checkbox(
                              value: _areAllSelected(),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    selectedRunIds = completedRuns!.map((r) => r.id).toSet();
                                  } else {
                                    selectedRunIds.clear();
                                  }
                                });
                              },
                            ),
                            SizedBox(width: 8),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
            Expanded(
              child: ListView.builder(
                itemCount: completedRuns!.length,
                itemBuilder: (context, index) {
                  final run = completedRuns![index];
                  final isExpanded = expandedIndex == index;
                  return Column(
                    children: [
                      ListTile(
                        title: Text(run.name),
                        subtitle: Text("Run on ${run.startTime}"),
                        trailing: selectionType != SelectionType.none
                        ? Row(
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
                        ) 
                          : Row(
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
                              // Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                            ],
                          ),
                        onTap: () {
                          setState(() {
                            expandedIndex = isExpanded ? null : index;
                          });
                        },
                      ),
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.only(left: 40.0, top: 8.0, bottom: 8.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Number of Points: ${run.runPoints.length}"),
                                Text("Vehicle Type: ${run.vehicleType}"),
                                Text("Duration: ${run.getFormattedDuration()}"),
                              ],
                            ),
                          ),
                        ),
                      Divider(),
                    ],
                  );
                },
              ),
            ),
            SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: selectionType == SelectionType.none
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: completedRuns!.isNotEmpty ? _downloadRuns : null,
                          icon: Icon(Icons.download),
                          label: Text("Download Runs"),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            elevation: 3,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: completedRuns!.isNotEmpty ? _uploadRuns : null, //hasUnsyncedRuns! ? _uploadRuns: null,
                          icon: Icon(Icons.upload),
                          label: Text("Upload Unsynced"),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                              context.read<RunHistoryProvider>().uploadSelectedRuns(context, selectedRunIds);
                            } else if (selectionType == SelectionType.download) {
                              context.read<RunHistoryProvider>().downloadSelectedRuns(context, selectedRunIds);
                            }
                            setState(() {
                              selectionType = SelectionType.none;
                              selectedRunIds.clear();
                            });
                          },
                          icon: Icon(selectionType == SelectionType.upload ? Icons.upload : Icons.download),
                          label: Text(selectionType == SelectionType.upload ? "Submit Upload" : "Download Runs"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.secondary,
                            foregroundColor: Theme.of(context).colorScheme.onSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
          SizedBox(height: 20),
        ])
      ),
    );
  }

void _renameRun(BuildContext context, Run run) {
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              run.name = controller.text;
              run.save(); 
              Navigator.pop(context);
              setState(() {}); 
            },
            child: Text("Save"),
          )
        ],
      );
    },
  );
}

void _deleteRun(BuildContext context, Run run) {
  ColorScheme appColorScheme = Theme.of(context).colorScheme;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Delete Run"),
      content: Text("Are you sure you want to delete:\n\n > ${run.name} ? \n\nThis cannot be undone!"),
      actions: [
        TextButton(
          child: Text("Cancel"),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
                  backgroundColor: appColorScheme.secondary,
                  foregroundColor: appColorScheme.onSecondary),
          child: Text("Delete"),
          onPressed: () async {
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