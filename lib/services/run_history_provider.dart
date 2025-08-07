import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import '../models/run.dart';
import 'dart:developer' as dev;
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:road_quality_tracker/services/device_meta_service.dart';

class RunHistoryProvider with ChangeNotifier {
  final Box<Run> _runBox = Hive.box<Run>('runs');
  final storage = FlutterSecureStorage();
  bool _writingRun = false;

  List<Run> get completedRuns => _runBox.values.toList();

  Run? getRunById(String runId) {
    try {
      return _runBox.values.cast<Run?>().firstWhere(
        (run) => run?.id == runId,
        orElse: () => null,
      );
    } catch (e) {
      dev.log(
        "Error retrieving run with ID $runId: $e",
        name: 'RunHistoryProvider',
      );
      return null;
    }
  }

  Run? getMostRecentRun() {
    final runs = _runBox.values.toList();
    if (runs.isEmpty) return null;
    return runs.reduce((a, b) => a.startTime.isAfter(b.startTime) ? a : b);
  }

  void addRun(Run run) {
    dev.log("Persisting run: ${run.name}", name: 'RunHistoryProvider');
    _runBox.add(run);
    dev.log("Run box: ${_runBox.length}", name: 'RunHistoryProvider');
    notifyListeners();
  }

  Future<void> _saveRunThrottled(int index, Run updatedRun) async {
    if (_writingRun) {
      dev.log(
        "Skipping write operation as other run update is still processing!",
        name: 'RunHistoryProvider',
      );
      return;
    }

    _writingRun = true;
    try {
      await _saveRun(index, updatedRun);
    } finally {
      _writingRun = false;
    }
  }

  Future<void> _saveRun(int index, Run updatedRun) async {
    if (index >= 0 && index < _runBox.length) {
      await _runBox.putAt(index, updatedRun);
      notifyListeners();
    } else {
      await _runBox.add(updatedRun);
      notifyListeners();
      dev.log(
        'Run index out of bounds!! Added new run!',
        name: "RunHistoryProvider",
      );
    }
  }

  void updateLatestRun(Run run) {
    final index = _runBox.length - 1;
    _saveRunThrottled(index, run.copy());
  }

  void updateRun(Run run) {
    final index = _runBox.values.toList().indexWhere((r) => r.id == run.id);
    if (index != -1) {
      _saveRunThrottled(index, run.copy());
    } else {
      dev.log(
        "Run not found in box! Saving a new one.",
        name: "RunHistoryProvider",
      );
      addRun(run);
    }
  }

  void deleteRun(int index) {
    _runBox.deleteAt(index);
    notifyListeners();
  }

  void clearAllRuns() {
    _runBox.clear();
    notifyListeners();
  }

  void uploadSelectedRuns(context, Set<String> selectedRunIds) async {
    final runsToUpload =
        completedRuns.where((r) => selectedRunIds.contains(r.id)).toList();
    final meta = await DeviceMetaService.getMetaData();

    final jsonString = buildJson(
      runsToUpload,
      deviceHash: meta['deviceHash'],
      sendHash: meta['sendHash'],
      sendInfo: meta['sendInfo'],
      model: meta['model'],
      manufacturer: meta['manufacturer'],
      osVersion: meta['osVersion'],
    );

    final resultCode = await makeUploadApiCall(jsonString);

    if (resultCode < 1) {
      dev.log('ERROR occured when uploading Runs!', name: 'RunHistoryProvider');
      updateSyncStatus(false, runsToUpload);
      final text =
          resultCode == -1
              ? 'Please provide your credentials in the settings!'
              : 'Upload failed! Have you checked your connection in the Settings?';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text, textAlign: TextAlign.center),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.fixed,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      dev.log(
        'Uploaded ${runsToUpload.length} Runs.',
        name: 'RunHistoryProvider',
      );
      updateSyncStatus(true, runsToUpload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload successful!'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.fixed,
          backgroundColor: Colors.green[800],
        ),
      );
    }
    notifyListeners();
  }

  void updateSyncStatus(bool uploaded, List<Run> runs) {
    for (var run in runs) {
      if (uploaded) {
        run.isSynced = true;
        run.save();
      }
    }
    notifyListeners();
  }

  Future<int> makeUploadApiCall(String runsJson) async {
    final urlString = await storage.read(key: 'serverUrl');
    final username = await storage.read(key: 'username');
    final password = await storage.read(key: 'password');

    if (urlString == null ||
        username == null ||
        password == null ||
        urlString == '' ||
        username == '' ||
        password == '') {
      dev.log('Missing credentials or server URL', name: 'RunHistoryProvider');
      return -1; // Treat as error
    }

    try {
      final url = Uri.parse(urlString);
      final request = await HttpClient().postUrl(url);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      );
      request.add(utf8.encode(runsJson));

      final response = await request.close();
      dev.log(
        'Upload status: ${response.statusCode}',
        name: 'RunHistoryProvider',
      );

      return response.statusCode >= 200 && response.statusCode < 300 ? 1 : 0;
    } catch (e) {
      dev.log('Upload error: $e', name: 'RunHistoryProvider');
      return 0;
    }
  }

  void downloadSelectedRuns(
    BuildContext context,
    Set<String> selectedRunIds,
  ) async {
    final downloadRuns =
        completedRuns.where((r) => selectedRunIds.contains(r.id)).toList();
    final permissionStatus = await Permission.manageExternalStorage.status;
    if (!permissionStatus.isGranted) {
      if (!context.mounted) return;

      final retry = await showDialog<bool>(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text("Storage Permission Required"),
              content: Text(
                "To save your runs, we need access to your storage.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text("Retry Permission"),
                ),
              ],
            ),
      );

      if (retry == true) {
        final result = await Permission.manageExternalStorage.request();
        if (!result.isGranted) {
          final fallback = await Permission.storage.request();
          if (!fallback.isGranted) {
            dev.log(
              "User denied storage permission",
              name: "RunHistoryProvider",
            );
            return;
          }
        }
      } else {
        return;
      }
    }

    try {
      final meta = await DeviceMetaService.getMetaData();

      final jsonString = buildJson(
        downloadRuns,
        deviceHash: meta['deviceHash'],
        sendHash: meta['sendHash'],
        sendInfo: meta['sendInfo'],
        model: meta['model'],
        manufacturer: meta['manufacturer'],
        osVersion: meta['osVersion'],
      );

      if (!context.mounted) return;

      final fileNameController = TextEditingController(
        text: 'runs_export.json',
      );
      final fileName = await showDialog<String>(
        context: context,
        builder:
            (_) => AlertDialog(
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
                  onPressed:
                      () => Navigator.pop(context, fileNameController.text),
                  child: Text("Save"),
                ),
              ],
            ),
      );

      if (fileName == null || fileName.isEmpty || !context.mounted) return;

      final directory = await FilePicker.platform.getDirectoryPath();
      if (directory == null) {
        dev.log("File picker was cancelled", name: "RunHistoryProvider");
        return;
      }

      final file = File('$directory/$fileName');
      await file.create(recursive: true);
      await file.writeAsString(jsonString);

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
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
    } catch (e) {
      dev.log("Error saving file: $e", name: "RunHistoryProvider");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving file. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String buildJson(
    List<Run> downloadRuns, {
    String? deviceHash,
    bool sendHash = false,
    bool sendInfo = false,
    String? model,
    String? manufacturer,
    String? osVersion,
  }) {
    final jsonList = downloadRuns.map((run) => run.toJson()).toList();

    final payload = <String, dynamic>{'runs': jsonList};

    if (sendHash || sendInfo) {
      final deviceInfo = {};
      if (sendHash && deviceHash != null) {
        deviceInfo['deviceHash'] = deviceHash;
      }
      if (sendInfo) {
        deviceInfo['model'] = model;
        deviceInfo['manufacturer'] = manufacturer;
        deviceInfo['os'] = osVersion;
      }

      payload['deviceInfo'] = deviceInfo;
    }

    final encoder = JsonEncoder.withIndent('  ');
    dev.log(encoder.convert(payload), name: 'RunHistoryProvider');

    return jsonEncode(payload);
  }
}
