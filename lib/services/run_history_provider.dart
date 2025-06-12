import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/run.dart';
import 'dart:developer' as dev;
import 'dart:convert'; 
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class RunHistoryProvider with ChangeNotifier {
  final Box<Run> _runBox = Hive.box<Run>('runs');

  List<Run> get completedRuns => _runBox.values.toList();

  void addRun(Run run) {
    dev.log("Persisting run: ${run.name}", name: 'RunHistoryProvider');
    _runBox.add(run); 
    dev.log("run box: ${_runBox.length}",  name: 'RunHistoryProvider');
    notifyListeners();
  }

  void updateRun(int index, Run updatedRun) {
    _runBox.putAt(index, updatedRun);
    notifyListeners();
  }

  void deleteRun(int index) {
    _runBox.deleteAt(index);
    notifyListeners();
  }

  void clearAllRuns() {
    _runBox.clear();
    notifyListeners();
  }

  void uploadSelectedRuns(context, Set<String> selectedRunIds) {
    bool gotError = false;
    for (var run in completedRuns) {
          if (selectedRunIds.contains(run.id)) {
            // make api call here
            bool returnVal = true;
            if (returnVal) {
              run.isSynced = true;
              run.save();
            } else {
              run.isSynced = false; 
              run.save();
              gotError = true;
            }
          }
        }
      if (gotError){
        dev.log('ERROR occured when uploading Runs!', name: 'RunHistoryProvider');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed!"),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.fixed,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        dev.log('Uploaded ${selectedRunIds.length} Runs.', name: 'RunHistoryProvider');
      }
    notifyListeners();
  }
  
  void downloadSelectedRuns(BuildContext context, Set<String> selectedRunIds) async {
    final downloadRuns = completedRuns.where((r) => selectedRunIds.contains(r.id)).toList();
    final jsonString = buildJsonDownload(downloadRuns);

    final dir = await getExternalStorageDirectory();
    
    if (context.mounted) {
      final fileNameController = TextEditingController(text: 'runs_export.json');
      final fileName = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Save As"),
          content: TextField(
            controller: fileNameController,
            decoration: InputDecoration(hintText: "Filename"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, fileNameController.text),
              child: Text("Save"),
            ),
          ],
        ),
      );

      if (fileName == null || fileName.isEmpty || !context.mounted) return;

      final file = File('${dir!.path}/$fileName');
      await file.writeAsString(jsonString);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Download complete"),
          content: Text("Saved to:\n${file.path}"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        ),
      );
  }
  }

  String buildJsonDownload(List<Run> downloadRuns) {
    final jsonList = downloadRuns.map((run) => run.toJson()).toList();
    return jsonEncode({'runs': jsonList});
  }
}