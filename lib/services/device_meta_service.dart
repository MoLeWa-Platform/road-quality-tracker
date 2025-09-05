import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:developer' as dev;

class DeviceMetaService {
  static final _storage = FlutterSecureStorage();

  static Future<String> generateDeviceHash() async {
    final deviceInfo = DeviceInfoPlugin();
    String raw;

    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      final randInt = Random().nextInt(1000000);
      raw = '$randInt-{info.id}-${info.manufacturer}-${info.model}-${info.version.sdkInt}';
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      raw = '${info.identifierForVendor}-${info.name}-${info.systemVersion}-${info.model}';
    } else {
      raw = 'unknown-device';
    }

    return sha256.convert(utf8.encode(raw)).toString();
  }

  static Future<Map<String, dynamic>> getMetaData() async {
    final sendHash = (await _storage.read(key: 'sendDeviceHash')) == 'true';
    final sendInfo = (await _storage.read(key: 'sendDeviceInfo')) == 'true';

    String? deviceHash = await _storage.read(key: 'deviceHash');
    String? alreadyUpdatedStr = await _storage.read(key: 'deviceHashVersion2');
    bool alreadyUpdated = alreadyUpdatedStr == 'true';

    if ((deviceHash == null || !alreadyUpdated) && sendHash) {
      deviceHash = await generateDeviceHash();
      await _storage.write(key: 'deviceHash', value: deviceHash);
      await _storage.write(key: 'deviceHashVersion2', value: 'true');
    }

    String? model;
    String? manufacturer;
    String? osVersion;

    if (sendInfo) {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        model = info.model;
        manufacturer = info.manufacturer;
        osVersion = 'Android ${info.version.release}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        model = info.model;
        manufacturer = 'Apple';
        osVersion = '${info.systemName} ${info.systemVersion}';
      }
    }

    final deviceData = {
      'sendHash': sendHash,
      'sendInfo': sendInfo,
      'deviceHash': sendHash ? deviceHash : null,
      'model': sendInfo ? model : null,
      'manufacturer': sendInfo ? manufacturer : null,
      'osVersion': sendInfo ? osVersion : null,
    };
    dev.log("deviceData: ${deviceData.toString()}", name: "DeviceMetaService");
    return deviceData;
  }
}