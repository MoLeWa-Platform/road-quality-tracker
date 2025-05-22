import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:developer';
import '../models/run.dart';
import '../models/run_point.dart';
import '../models/sensor_snapshot.dart';

class RunTracker {
  Run? activeRun;
  bool isReady = false;
  final ValueNotifier<bool> runIsActive = ValueNotifier<bool>(false);
  final ValueNotifier<RunPoint?> lastPoint = ValueNotifier(null);
  
  SensorSnapshot<LocationSpec> _location = SensorSnapshot();
  SensorSnapshot<VibrationSpec> _vibration = SensorSnapshot();
  SensorSnapshot<double> _orientation = SensorSnapshot();
  SensorSnapshot<double> _speed = SensorSnapshot();
  
  final Location _locationService = Location();
  late StreamSubscription<LocationData>? _locationSubscription;

  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  RunTracker._();

  static RunTracker create() {
    final tracker = RunTracker._();
    Future.microtask(()=> 
      tracker._startLocationWatch()
    );
    return tracker;
  }

  void _startLocationWatch() async {
    bool serviceEnabled = await _locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationService.requestService();
      if (!serviceEnabled) {
        throw ('Locationservice couldnt be enabled!');
      }
    }
    log("service enabled: $serviceEnabled", name: 'RunTracker');

    PermissionStatus permissionGranted = await _locationService.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationService.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        throw ('Access rights are missing for the phones location data!');
      }
    }
    log('permission granted: $permissionGranted', name: 'RunTracker');
    _locationService.changeSettings(interval: 2000, accuracy: LocationAccuracy.high);
    
    _locationSubscription = _locationService.onLocationChanged.listen((locationData) {
      Future.microtask(() => onNewLocationPoint(locationData));
    });

    log('subscribed to location Updates', name: 'RunTracker');
    isReady = true;
  }

  void onNewLocationPoint(LocationData locationData){
    log("$locationData", name: 'RunTracker');
    saveNewLocation(locationData);
    if (runIsActive.value) {
      tryToAddNewPoint();
    }
  }

  bool saveNewLocation(LocationData locationData){
      if (locationData.latitude != null && locationData.longitude != null) {
        final loc = LocationSpec(latitude: locationData.latitude!, longitude: locationData.longitude!);
        _location = _location.update(loc);
        log("Current Location updated ${loc.latitude}, ${loc.longitude}", name: 'RunTracker');
        return true;
      }
      return false;
  }

  void tryToAddNewPoint(){
      log('trying to add new point ${_location.value}, ${_location.timestamp}', name: 'RunTracker');
      final now = DateTime.now();
      //final threshold = Duration(milliseconds: 1000);

      VibrationSpec placeholder = VibrationSpec(xCoordinate: 0, yCoordinate: 0, zCoordinate: 0);

      if (_location.value!=null){ //(_vibration.isFresh(threshold, now)){// && _orientation.isFresh(threshold, now) && _speed.isFresh(threshold, now)) {
        final point = RunPoint(
          timestamp: now,
          location: _location.value!,
          vibrationSpec: placeholder, 
          orientation: 0.0,
          speed: 0.0,
        );

        log('added $point', name: 'RunTracker');

        activeRun?.addPoint(point);
        lastPoint.value = point;
        //clearSensorSnapshots();
     // }
    } 
  }

  void subscribeToSensors () {
    if (_accelSubscription != null) {
      log("Already subscribed to accelerometer.", name: 'RunTracker');
      return;
    }
    else{
      _accelSubscription = accelerometerEvents.listen((event) {
        Future.microtask(() => onVibrationEvent(event));
    });
  }
  }

  void onVibrationEvent(event){
    log("Got vibration event: x=${event.x}", name: 'RunTracker');
    _vibration = _vibration.update(VibrationSpec(
      xCoordinate: event.x,
      yCoordinate: event.y,
      zCoordinate: event.z,
    ));
    log('new vibration: ${_vibration.timestamp}, ${_vibration.value}', name: 'RunTracker');
  }

  void clearSensorSnapshots(){
    _vibration = _vibration.clear();
    _orientation = _orientation.clear();
    _speed = _speed.clear();
  }

  void cancelSensorSubscriptions () {
    _accelSubscription?.cancel();
    _accelSubscription = null;
  }

  void startRun() async {
    Future.microtask(() => onStartRun());
  }

  void onStartRun() {
    log("starting run!", name: 'RunTracker');
    //subscribeToSensors();
    activeRun = Run.create(DateTime.now());
    runIsActive.value = true;
    log("in startrun!", name: 'RunTracker');
    tryToAddNewPoint();
  }

  void onEndRun() {
    activeRun?.endRun();

    runIsActive.value = false;
    lastPoint.value = null;
    
    //clearSensorSnapshots();
    //cancelSensorSubscriptions();
  }
  
  void endRun() {
    Future.microtask(() => onEndRun());
  }

  void dispose() {
    _locationSubscription?.cancel();
    cancelSensorSubscriptions();
  }

}