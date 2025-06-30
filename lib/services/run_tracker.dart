import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'dart:math';
import 'dart:async';
import 'dart:developer' as dev;
import '../models/run.dart';
import '../models/run_point.dart';
import '../models/location_spec.dart';
import '../models/dimension_spec.dart';
import '../models/sensor_snapshot.dart';
import '../services/rotation_vector_stream.dart';

class RunTracker {
  Run? activeRun;
  bool isReady = false;
  static final ValueNotifier<bool> runIsActive = ValueNotifier<bool>(false);
  final ValueNotifier<RunPoint?> lastPoint = ValueNotifier(null);
  final ValueNotifier<LocationSpec?> currentRawLocation = ValueNotifier(null);
  final ValueNotifier<List<AccelerometerEvent>> currentRawVibration = ValueNotifier([]);


  SensorSnapshot<LocationSpec> _lastLocation = SensorSnapshot();
  SensorSnapshot<LocationSpec> _currentLocation = SensorSnapshot();
  SensorSnapshot<DimensionalSpec> _vibration = SensorSnapshot();
  SensorSnapshot<double> _speed = SensorSnapshot();

  //List<double> _rotationQuaternion = [0.0, 0.0, 0.0, 1.0]; 
  vm.Matrix3 _rotationMatrix = vm.Matrix3.identity();
  
  final Location _locationService = Location();
  late StreamSubscription<LocationData>? _locationSubscription;
  late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
  late StreamSubscription<List<double>>? _rotationSub;

  RunTracker._();

  static RunTracker create() {
    final tracker = RunTracker._();
    Future.microtask(()=> 
      tracker._startLocationWatch()
    );
    tracker.subscribeToSensors();
    return tracker;
  }

  void subscribeToSensors(){
    dev.log('Subcribing to sensors', name: 'RunTracker');
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      currentRawVibration.value = [event];
      onVibrationEvent(event);
    });
    _rotationSub = RotationVectorStream.stream.listen((values) {
      if (values.length >= 4) {
        //_rotationQuaternion = values;
        onQuanternionEvent(values);
      }
    });
  }

  void _startLocationWatch() async {
    bool serviceEnabled = await _locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationService.requestService();
      if (!serviceEnabled) {
        throw ('Locationservice couldnt be enabled!');
      }
    }
    PermissionStatus permissionGranted = await _locationService.hasPermission(); //should be enabled through permission gate
    if (permissionGranted != PermissionStatus.granted) {
        throw ('Access rights are missing for the phones location data!');
    }
    if (serviceEnabled && (permissionGranted == PermissionStatus.granted)){
      _locationService.changeSettings(interval: 2000, accuracy: LocationAccuracy.high);
      
      _locationSubscription = _locationService.onLocationChanged.listen((locationData) {
        Future.microtask(() => onNewLocationPoint(locationData));
      });
      isReady = true;
    }
  }

  void onNewLocationPoint(LocationData locationData){
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
        currentRawLocation.value = loc;
        if (_lastLocation.value != null && _currentLocation.value != null) {
          updateSpeed();
        }
        return true;
      }
      return false;
  }

  void addNewPoint(){
    final now = DateTime.now();
    final threshold = Duration(milliseconds: 1000);

    if (hasAllMeasurementsNeeded(now, threshold)) {
      final point = RunPoint(
        timestamp: now,
        location: _currentLocation.value!,
        vibrationSpec: _vibration.value!, 
        speed: _speed.value!,
      );

      activeRun?.addPoint(point);
      lastPoint.value = point;
      clearSensorSnapshots();
    }
  } 

  bool hasAllMeasurementsNeeded(now, threshold){
    if (_currentLocation.value!=null 
        && _vibration.isFresh(threshold, now)
        && _speed.isFresh(threshold, now)) 
    {
      return true;
    }
    else {
      return false;
    }
  }

  void onVibrationEvent(event){
    final rawAccel = vm.Vector3(event.x, event.y, event.z);
    final worldAccel = _rotationMatrix.transformed(rawAccel);
    _vibration = _vibration.update(DimensionalSpec(
      type: 'Vibration',
      xCoordinate: worldAccel.x,
      yCoordinate: worldAccel.y,
      zCoordinate: worldAccel.z,
    ));
  }

  void onQuanternionEvent(List<double> event) {
    vm.Quaternion q = vm.Quaternion(event[0], event[1], event[2], event[3]);
    vm.Matrix3 rotationMatrix = q.asRotationMatrix();
    //_rotationQuaternion = event;
    _rotationMatrix = rotationMatrix.clone()..invert();
  }

  void clearSensorSnapshots(){
    _vibration = _vibration.clear();
    _speed = _speed.clear();
  }

  void startRun(String vehicleType) async {
    Future.microtask(() => {
      activeRun = Run.create(DateTime.now(), vehicleType),
      runIsActive.value = true,
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
    _accelerometerSubscription.cancel();
    _rotationSub?.cancel();
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
    final speedKmh = speedMetersPerSecond * 3.6;

    if (speedMetersPerSecond > 30){
      dev.log('ABNORMAL HIGH SPEED DETECTED - ${speedMetersPerSecond.toStringAsFixed(2)} m/s - GPS GLITCH?', name: 'RunTracker');
    }

    _speed = _speed.update(speedKmh);
  }

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