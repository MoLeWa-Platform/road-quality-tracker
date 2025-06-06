import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/run.dart';
import 'dart:developer' as dev;

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

  void uploadPendingRuns() {
    final unsynced = completedRuns.where((r) => !r.isSynced).toList();

    for (var run in unsynced) {
      // Placeholder for actual upload logic
      print("Uploading run: ${run.name}");
      run.isSynced = true; // ✅ Mark as synced
    }
    notifyListeners(); // Refresh UI
  }
}