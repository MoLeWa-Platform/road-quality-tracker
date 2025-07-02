import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as dev;

import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as app_settings;

class AppUpdater {
  static final updateSupported = _updateSupported();
  static bool notDownloadedYet = true;
  static bool gotError = false;

  static late int currentBuild;
  static late int latestBuild;
  static late int downloadSize;
  static late DateTime updateDate;

  static late String updateUrl;
  static late String localFile;

  static bool? _foundUpdate;
  static DateTime? _foundUpdateAt;

  static cleanup() async {
    if (kIsWeb) return;
    final f = '${(await getApplicationSupportDirectory()).path}/update.apk';
    final file = File(f);
    if (await file.exists()) {
      try {
        await file.delete(recursive: true);
      } catch (e) {
        dev.log("Can't cleanup update file $e", name: 'VersionUpdate');
      }
    }
  }

  static bool _updateSupported() {
    if (!kIsWeb && Platform.isAndroid) {
      return true;
    }
    return false;
  }

  static Future<void> handleApkInstall({
    required String localFilePath,
    required BuildContext context,
  }) async {
    if (!Platform.isAndroid) {
      debugPrint("APK installation is only supported on Android.");
      return;
    }

    if (await Permission.requestInstallPackages.isGranted) {
      OpenFile.open(localFilePath);
      return;
    }

    final status = await Permission.requestInstallPackages.request();
    if (status.isGranted) {
      OpenFile.open(localFilePath);
      return;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final packageName = packageInfo.packageName;
    final intent = AndroidIntent(
      action: 'android.settings.MANAGE_UNKNOWN_APP_SOURCES',
      data: 'package:$packageName',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );

    // Show dialog prompting the user to open settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text("Permission Required"),
              content: const Text(
                "To install this update, you need to allow this app to install unknown APKs. Tap 'Go to Settings' and enable the permission.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    intent.launch();
                  },
                  child: const Text("Go to Settings"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
              ],
            ),
      );
    });
  }

  static Future<bool?> updateAvailable({
    Duration cacheAge = Duration.zero,
  }) async {
    if (!updateSupported) return false;

    if (_foundUpdate != null &&
        _foundUpdateAt != null &&
        _foundUpdateAt!.add(cacheAge).isAfter(DateTime.now())) {
      return _foundUpdate;
    }

    var url = Uri.parse(
      "https://api.github.com/repos/MoLeWa-Platform/road-quality-tracker/releases/latest",
    );
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    Map decoded;
    final response = await HttpClient().getUrl(url).then((request) {
      request.headers.set(
        "User-Agent",
        'MoLeWa-Platform/road-quality-tracker/${packageInfo.version}',
      );
      return request.close();
    });
    dev.log(
      'response: ${response.statusCode} ${response.connectionInfo}',
      name: 'VersionUpdate',
    );
    if (response.statusCode > 400) {
      dev.log("Gihub release request failed ${response.statusCode}");
      return false;
    }

    var resp = await response.transform(utf8.decoder).join();
    decoded = (jsonDecode(resp) ?? {}) as Map<dynamic, dynamic>;
    latestBuild = int.parse((decoded["tag_name"] as String).split("+")[1]);
    currentBuild = int.parse(packageInfo.buildNumber);

    dev.log(
      'Latest App build: $latestBuild vs current: ${packageInfo.version} + ${packageInfo.buildNumber}',
      name: 'VersionUpdate',
    );
    _foundUpdateAt = DateTime.now();

    if (latestBuild > currentBuild) {
      final asset = (decoded["assets"] as List<dynamic>).firstWhere(
        (element) => element["name"] == "app-release.apk",
      );
      updateUrl = asset["browser_download_url"];
      downloadSize = asset["size"];
      updateDate = DateTime.parse(asset["updated_at"]);
      return _foundUpdate = true;
    }
    return _foundUpdate = false;
  }

  static Future<HttpClientResponse?> downloadUpdate() async {
    try {
      var url = Uri.parse(updateUrl);
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      final response = await HttpClient().getUrl(url).then((request) {
        request.headers.set(
          "User-Agent",
          'MoLeWa-Platform/road-quality-tracker/${packageInfo.version}',
        );
        return request.close();
      });
      dev.log(
        'Response: ${response.statusCode} ${response.connectionInfo}',
        name: 'Settingspage',
      );

      if (response.statusCode >= 400) {
        dev.log("GitHub release request failed ${response.statusCode}");
        return null;
      }
      return response;

    } catch (e, stack) {
      dev.log(
        "Update download failed: $e\n$stack",
        level: 1000,
        name: "Settingspage",
      );
      return null;
    }
  }

  static getFilePath() async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/update.apk';
      localFile = filePath;
      return filePath;
    } catch (e, stack) {
      dev.log(
        "File path could not be loaded: $e\n$stack",
        level: 1000,
        name: "Settingspage",
      );
      return null;
    }
  }

  static saveFile(HttpClientResponse response, file) async {
    try {
      dev.log("saving apk to $file", name: "Settingspage");
      await response.pipe(File(file).openWrite());
      dev.log("APK saved successfully to $file", name: "Settingspage");
      return true;
    } catch (e, stack) {
      dev.log(
        "Saving download failed: $e\n$stack",
        level: 1000,
        name: "Settingspage",
      );
      return false;
    }
  }

  static showUpdateDialog(BuildContext context) async {
    final proceed = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Update available!"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Do you want to download it now?",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w400,
                    fontSize: 20,
                  ),
                ),
                SizedBox(height: 12),
                Text("Current Build: $currentBuild"),
                Text("Latest Build: $latestBuild"),
                Text(
                  "Uploaded: ${DateFormat.yMd().add_jms().format(updateDate.toLocal())}",
                ),
                Text(
                  "Download size: ${(downloadSize / 1000000.0).toStringAsFixed(1)} MB",
                ),
              ],
            ),
            actions: [
              TextButton(
                child: Text('Not now'),
                onPressed: () => Navigator.pop(context, false),
              ),
              SizedBox(width: 7,),
              ElevatedButton(
                child: Text('Download'),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
    );

    if (proceed != true) {
      return;
    }

    bool startedDownload = false; //stops endless download by rebuilding
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          bool isDownloading = true;
          bool gotError = false;
          String currentSatus = 'Downloading package..';

          return StatefulBuilder(
            builder: (context, setState) {
              if (!startedDownload) {
                startedDownload = true;
                Future.microtask(() async {
                  try {
                    final response = await downloadUpdate();
                    String? file;
                    bool? savedFile;
                    if (response != null) {
                      file = await getFilePath();
                      setState(() {
                        currentSatus =
                            'Downloading package ✓ \nSaving APK file..';
                      });
                      savedFile = await saveFile(response, file);
                    }
                    final error =
                        (response == null) ||
                        (file == null) ||
                        savedFile == false;
                    setState(() {
                      isDownloading = false;
                      gotError = error;
                    });
                  } catch (_) {
                    setState(() {
                      isDownloading = false;
                      gotError = true;
                    });
                  }
                });
              }

              return AlertDialog(
                title: const Text("App Update"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 20),
                    if (isDownloading) ...[
                      const CircularProgressIndicator(),
                      SizedBox(height: 30),
                      Text(currentSatus),
                    ] else if (gotError)
                      const Text("Download failed. Please try again.")
                    else
                      Text("Download successful."),
                  ],
                ),
                actions: [
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  ElevatedButton(
                    onPressed:
                        isDownloading
                            ? null
                            : () {
                              Navigator.pop(context);
                              if (!gotError) {
                                handleApkInstall(
                                  context: context,
                                  localFilePath: localFile,
                                );
                              }
                            },
                    child: Text(
                      gotError ? 'Close' : 'Install Update',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    });
  }
}
