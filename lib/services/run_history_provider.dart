import 'package:flutter/material.dart';
import '/../models/run.dart';

class RunHistoryProvider with ChangeNotifier {
  final List<Run> _completedRuns = [];

  List<Run> get completedRuns => _completedRuns;

  void addRun(Run run) {
    _completedRuns.add(run);
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