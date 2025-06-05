import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:developer' as dev;
import '../models/run.dart';
import '../models/run_point.dart';
import '../models/sensor_snapshot.dart';
import 'dart:math';

class RunTracker {
  Run? activeRun;
  bool isReady = false;
  final ValueNotifier<bool> runIsActive = ValueNotifier<bool>(false);
  final ValueNotifier<RunPoint?> lastPoint = ValueNotifier(null);
  
  SensorSnapshot<LocationSpec> _lastLocation = SensorSnapshot();

  SensorSnapshot<LocationSpec> _currentLocation = SensorSnapshot();
  SensorSnapshot<DimensionalSpec> _vibration = SensorSnapshot();
  SensorSnapshot<DimensionalSpec> _rotation = SensorSnapshot();
  SensorSnapshot<DimensionalSpec> _compass = SensorSnapshot();
  SensorSnapshot<double> _speed = SensorSnapshot();
  
  final Location _locationService = Location();
  late StreamSubscription<LocationData>? _locationSubscription;

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
    dev.log("service enabled: $serviceEnabled", name: 'RunTracker');

    PermissionStatus permissionGranted = await _locationService.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationService.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        throw ('Access rights are missing for the phones location data!');
      }
    }
    dev.log('permission granted: $permissionGranted', name: 'RunTracker');
    _locationService.changeSettings(interval: 2000, accuracy: LocationAccuracy.high);
    
    _locationSubscription = _locationService.onLocationChanged.listen((locationData) {
      Future.microtask(() => onNewLocationPoint(locationData));
    });

    dev.log('subscribed to location Updates', name: 'RunTracker');
    isReady = true;
  }

  void onNewLocationPoint(LocationData locationData){
    dev.log("$locationData", name: 'RunTracker');
    saveNewLocation(locationData);
    if (runIsActive.value) {
      addNewPoint();
    }
  }

  bool saveNewLocation(LocationData locationData){
      if (locationData.latitude != null && locationData.longitude != null) {
        final loc = LocationSpec(latitude: locationData.latitude!, longitude: locationData.longitude!);
        if (_currentLocation.value != null) { 
          _lastLocation = _currentLocation;
        }

        _currentLocation = _currentLocation.update(loc);
        if (_lastLocation.value != null && _currentLocation.value != null) {
          updateSpeed();
        }

        dev.log("Current Location updated ${loc.latitude}, ${loc.longitude}", name: 'RunTracker');
        dev.log("Current Location Snapshot ${_currentLocation.timestamp}, ${_currentLocation.value.toString()}", name: 'RunTracker');
        dev.log("Last Location Snapshot ${_lastLocation.timestamp}, ${_lastLocation.value.toString()}", name: 'RunTracker');
        return true;
      }
      return false;
  }

  void addNewPoint(){
    dev.log('trying to add new point ${_currentLocation.value}, ${_currentLocation.timestamp}', name: 'RunTracker');
    final now = DateTime.now();
    final threshold = Duration(milliseconds: 1000);

    if (hasAllMeasurementsNeeded(now, threshold)) {
      final point = RunPoint(
        timestamp: now,
        location: _currentLocation.value!,
        vibrationSpec: _vibration.value!, 
        rotationSpec: _rotation.value!,
        compassSpec: _compass.value!,
        speed: _speed.value!,
      );

      dev.log('added $point', name: 'RunTracker');

      activeRun?.addPoint(point);
      lastPoint.value = point;
      clearSensorSnapshots();
    }
  } 

  bool hasAllMeasurementsNeeded(now, threshold){
    if (_currentLocation.value!=null 
        && _vibration.isFresh(threshold, now)
        && _rotation.isFresh(threshold, now)
        && _compass.isFresh(threshold, now)
        && _speed.isFresh(threshold, now)) 
    {
      return true;
    }
    else {
      return false;
    }
  }

  void onVibrationEvent(event){
    dev.log("Got vibration event: x=${event.x}", name: 'RunTracker');
    _vibration = _vibration.update(DimensionalSpec(
      type: 'Vibration',
      xCoordinate: event.x,
      yCoordinate: event.y,
      zCoordinate: event.z,
    ));
    dev.log('new vibration: ${_vibration.timestamp}, ${_vibration.value}', name: 'RunTracker');
  }

  void onRotationEvent(event){
    dev.log("Got Rotation event: x=${event.x}", name: 'RunTracker');
    _rotation = _rotation.update(DimensionalSpec(
      type: 'Rotation',
      xCoordinate: event.x,
      yCoordinate: event.y,
      zCoordinate: event.z,
    ));
    dev.log('new Rotation: ${_rotation.timestamp}, ${_rotation.value}', name: 'RunTracker');
  }

  void onCompassEvent(event){
    dev.log("Got Compass event: x=${event.x}", name: 'RunTracker');
    _compass = _compass.update(DimensionalSpec(
      type: 'Compass',
      xCoordinate: event.x,
      yCoordinate: event.y,
      zCoordinate: event.z,
    ));
    dev.log('new Compass: ${_compass.timestamp}, ${_compass.value}', name: 'RunTracker');
  }

  void clearSensorSnapshots(){
    _vibration = _vibration.clear();
    _rotation = _rotation.clear();
    _compass = _compass.clear();
    _speed = _speed.clear();
  }

  void startRun() async {
    Future.microtask(() => {
      dev.log("starting run!", name: 'RunTracker'),
      activeRun = Run.create(DateTime.now()),
      runIsActive.value = true,
      dev.log("in startrun!", name: 'RunTracker'),
      addNewPoint(),
    });
  }
  
  Run? endRun() {
    activeRun?.endRun();
    runIsActive.value = false;
    lastPoint.value = null;
    clearSensorSnapshots();
    return activeRun;
}

  void dispose() {
    _locationSubscription?.cancel();
  }


  void updateSpeed() {
    final lastLoc = _lastLocation.value!;
    final currentLoc = _currentLocation.value!;

    final timeDelta = _currentLocation.timestamp!.difference(_lastLocation.timestamp!).inSeconds;

    if (timeDelta == 0) {
      return;
    }

    final distance = haversineDistance(
      lastLoc.latitude,
      lastLoc.longitude,
      currentLoc.latitude,
      currentLoc.longitude,
    );

    final speedMetersPerSecond = distance / timeDelta;

    if (speedMetersPerSecond > 30){
      dev.log('ABNORMAL HIGH SPEED DETECTED - ${speedMetersPerSecond.toStringAsFixed(2)} m/s - GPS GLITCH?', name: 'RunTracker');
    }

    _speed = _speed.update(speedMetersPerSecond);

    dev.log('Calculated speed: ${speedMetersPerSecond.toStringAsFixed(2)} m/s', name: 'RunTracker');
  }

  // Helper function for Haversine distance in meters
  double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000; // meters

    double toRadians(double degree) => degree * pi / 180;

    final dLat = toRadians(lat2 - lat1);
    final dLon = toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(toRadians(lat1)) * cos(toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

}