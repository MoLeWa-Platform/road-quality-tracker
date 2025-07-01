import 'dart:async';
import 'dart:developer' as dev;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const notificationChannelId = 'my_foreground';

Future<FlutterBackgroundService> initService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId, // id
    'MY FOREGROUND SERVICE', // title
    description:
        'This channel is used for important notifications.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
  iosConfiguration: IosConfiguration(
    autoStart: true,
    onForeground: onStart,
    onBackground: onIosBackground,
  ),
  androidConfiguration: AndroidConfiguration(
    onStart: onStart,
    isForegroundMode: false,
    autoStart: true,
    notificationChannelId: notificationChannelId,
    initialNotificationTitle: '',
    initialNotificationContent: '',
    foregroundServiceNotificationId: 888,
  ),);
  return service;
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();
  dev.log('Started Background Service: ${service.hashCode}', name: 'BackgroundService');
  if (service is AndroidServiceInstance){
    service.on('startAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('stopForeground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event){
    service.stopSelf();
  });
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const notificationId = 888;

  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance){
      if (await service.isForegroundService()){
        flutterLocalNotificationsPlugin.show(
          notificationId,
          'Active Road Quality Tracker',
          'Your run is currently being tracked!',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              notificationChannelId,
              'MY FOREGROUND SERVICE',
              icon: 'ic_bg_service_small',
              ongoing: true,
            ),
          ),
        );
      }
    }
  });
  }
