import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/run_history_provider.dart';
import '../models/run.dart';

class HistoryPage extends StatefulWidget {
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          run.isSynced ? Icons.cloud_done : Icons.cloud_upload,
                          color: run.isSynced ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
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
                label: Text("Upload Unsynced"),
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
  // placeholder
  print("Renaming run ${run.name}");
}

void _deleteRun(Run run) {
  // placeholder
  print("Deleting run ${run.name}");
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