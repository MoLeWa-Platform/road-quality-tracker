import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/run_history_provider.dart';
import '../models/run.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int? expandedIndex;

  void _showDownloadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Download Runs"),
        content: Text("Select runs to download (not implemented yet)."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text("OK"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final RunHistoryProvider runHistoryProvider = context.watch<RunHistoryProvider>();
    final List<Run> completedRuns = runHistoryProvider.completedRuns.reversed.toList();
    final hasUnsyncedRuns = completedRuns.any((run) => !run.isSynced);

    return Scaffold(
      appBar: AppBar(title: Text("Run History")),
      body: Stack(
        children: [
          ListView.builder(
            itemCount: completedRuns.length,
            itemBuilder: (context, index) {
              final run = completedRuns[index];
              final isExpanded = expandedIndex == index;
          
              return Column(
                children: [
                  ListTile(
                    title: Text(run.name),
                    subtitle: Text("Run on ${run.startTime}"),
                    trailing: Row(
                        // mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              run.isSynced ? Icons.cloud_done : Icons.cloud_upload,
                              color: run.isSynced ? Colors.green : Colors.grey,
                              size: 20,
                            ),
                            tooltip: "Sync status",
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints.tightFor(width: 32, height: 32), // 🔧 uniform sizing
                            onPressed: null, // or show info if you want
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
                            Text("Duration: ${run.endTime?.difference(run.startTime) ?? Duration.zero}"),
                            Text("Points: ${run.runPoints.length}"),
                            Text("Additional details coming soon...", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  Divider(),
                ],
              );
            },
          ),
          Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showDownloadDialog(context),
                icon: Icon(Icons.download),
                label: Text("Download Runs"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 3,
                ),
              ),
              ElevatedButton.icon(
                onPressed: hasUnsyncedRuns ? runHistoryProvider.uploadPendingRuns: null,
                icon: Icon(Icons.upload),
                label: Text("Upload All Unsynced"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 3,
                ),
              ),
            ],
          ),
        ),
        ],
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
              run.save(); // ✅ persists change if Run extends HiveObject
              Navigator.pop(context);
              setState(() {}); // Refresh the UI
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
            await run.delete(); // 🧨 from Hive
            Navigator.pop(context);
            setState(() {}); // 🔁 refresh list
          },
        ),
      ],
    ),
  );
}

void _uploadRun(Run run) {
  // placeholder
  print("Uploading run ${run.name}");
}

void _downloadRun(Run run) {
  // placeholder
  print("Downloading run ${run.name}");
}

}