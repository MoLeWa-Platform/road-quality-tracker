import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:road_quality_tracker/services/run_history_provider.dart';
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
  // model parameter
  int tactInMs = 1000;
  final minSpeedThreshold = 1.0; // km/h
  Timer? _saveTimer;

  bool _addingPoint = false;

  Run? activeRun;
  final ValueNotifier<bool> isReady = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> runIsActive = ValueNotifier<bool>(false);
  final ValueNotifier<RunPoint?> lastPoint = ValueNotifier(null);
  final ValueNotifier<LocationSpec?> currentRawLocation = ValueNotifier(null);
  final ValueNotifier<double?> currentRawSpeed = ValueNotifier(null);
  final ValueNotifier<List<AccelerometerEvent>> currentRawVibration = ValueNotifier([]);

  SensorSnapshot<LocationSpec> _currentLocation = SensorSnapshot();
  SensorSnapshot<double?> _speed = SensorSnapshot();
  SensorSnapshot<DimensionalSpec> _vibration = SensorSnapshot();
  SensorSnapshot<double?> _vibrationMagPeak = SensorSnapshot();

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
    tracker.waitForDataPoints();
    return tracker;
  }

  Future<void> waitForDataPoints () {
    final completer = Completer<void>();

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_currentLocation.value != null &&
          _speed.value != null &&
          _vibration.value != null) {
        if (!completer.isCompleted) {
          dev.log('All sensors ready', name: 'RunTracker');
          timer.cancel();
          completer.complete();
          isReady.value = true;
        }
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        dev.log("Sensor readiness timed out.", name: "RunTracker");
        if (!completer.isCompleted) completer.complete(); // optionally fail silently
        return;
      },
    );
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
      _locationService.changeSettings(interval: tactInMs, accuracy: LocationAccuracy.high);
      
      _locationSubscription = _locationService.onLocationChanged.listen((locationData) {
        Future.microtask(() => onNewLocationPoint(locationData));
      });
    }
  }

  void onNewLocationPoint(LocationData locationData){
    saveNewLocation(locationData);
    saveNewSpeed(locationData);
    if (runIsActive.value) {
      addNewPointThrottled();
    }
  }

  bool saveNewLocation(LocationData locationData){
      if (locationData.latitude != null && locationData.longitude != null) {
        final loc = LocationSpec(latitude: locationData.latitude!, longitude: locationData.longitude!);

        _currentLocation = _currentLocation.update(loc);
        currentRawLocation.value = loc;
        return true;
      }
      return false;
  }

  bool saveNewSpeed(LocationData locationData){
    if (locationData.speed != null) {
      final rawSpeed = locationData.speed! * 3.6;
      final cleanedSpeed = rawSpeed < minSpeedThreshold ? 0.0 : rawSpeed;

      final newSpeed = _speed.value != null
        ? 0.1 * _speed.value! + 0.9 * cleanedSpeed
        : cleanedSpeed;
      _speed = _speed.update(newSpeed);
      currentRawSpeed.value = newSpeed;
      dev.log('old speed: ${_speed.value} new: $cleanedSpeed smoothed: $newSpeed');
      return true;
    } else {
      _speed = _speed.update(0.0);
      currentRawSpeed.value = null;
      return false;
    }
  }

  void addNewPointThrottled() {
    if (_addingPoint) {
      dev.log("Skipping this point as the prior operation is still pending!!", name: "RunTracker", level: 2);
      return;
    }

    _addingPoint = true;
  try {
    addNewPoint(); 
  } finally {
    _addingPoint = false;
  }
}

  void addNewPoint(){
    final now = DateTime.now();

    if (hasAllMeasurementsNeeded(now)) {
      final point = RunPoint(
        timestamp: now,
        location: _currentLocation.value!,
        vibrationSpec: _vibration.value!, 
        speed: _speed.value!,
        vibMagnitude: _vibrationMagPeak.value!,
      );

      activeRun?.addPoint(point);
      lastPoint.value = point;
      clearSensorSnapshots();
    }
  } 

  bool hasAllMeasurementsNeeded(now){
    final threshold = Duration(milliseconds: tactInMs);
    if (_currentLocation.value!=null
        && _speed.value!=null
        && _vibration.value!=null
        && _vibration.isFresh(threshold, now)
        && _speed.isFresh(threshold, now)) 
    {
      return true;
    }
    else {
            return false;
    }
  }

  void onVibrationEvent(AccelerometerEvent event) {
  final rawAccel = vm.Vector3(event.x, event.y, event.z);
  final worldAccel = _rotationMatrix.transformed(rawAccel);
  final vib = DimensionalSpec(
    type: 'Vibration',
    xCoordinate: worldAccel.x,
    yCoordinate: worldAccel.y,
    zCoordinate: worldAccel.z,
  );

  final newMag = calcVibMagnitude(vib);
  final now = DateTime.now();
  final threshold = Duration(milliseconds: tactInMs);

  if (_vibrationMagPeak.value == null || 
      !_vibrationMagPeak.isFresh(threshold, now) ||
      newMag  > _vibrationMagPeak.value! ) {
        _vibrationMagPeak= _vibrationMagPeak.update(newMag);
        _vibration= _vibration.update(vib);
      }
}

  void onQuanternionEvent(List<double> event) {
    vm.Quaternion q = vm.Quaternion(event[0], event[1], event[2], event[3]);
    vm.Matrix3 rotationMatrix = q.asRotationMatrix();
    //_rotationQuaternion = event;
    _rotationMatrix = rotationMatrix.clone()..invert();
  }

  double calcVibMagnitude(DimensionalSpec v) {
  return sqrt(v.xCoordinate * v.xCoordinate +
              v.yCoordinate * v.yCoordinate +
              v.zCoordinate * v.zCoordinate);
  }

  void clearSensorSnapshots(){
    _vibration = _vibration.clear();
    _vibrationMagPeak = _vibrationMagPeak.clear();
    _speed = _speed.clear();
  }

  void startRun(String vehicleType, RunHistoryProvider runHistoryProvider) async {
    Future.microtask(() {
      activeRun = Run.create(DateTime.now(), vehicleType);
      runIsActive.value = true;
      addNewPointThrottled();
      runHistoryProvider.addRun(activeRun!);
      _saveTimer = Timer.periodic(Duration(seconds: 15), (_) {
        if (activeRun!= null && runIsActive.value) {
          dev.log("updating latest Run $activeRun ${runIsActive.value}");
          activeRun?.setEndTime();
          runHistoryProvider.updateLatestRun(activeRun!);
        }
      });
    });
  }
  
  Run? endRun() {
    activeRun?.setEndTime();
    runIsActive.value = false;
    lastPoint.value = null;
    _saveTimer?.cancel();
    _saveTimer = null;
    clearSensorSnapshots();
    return activeRun;
  }

  void dispose() {
    _locationSubscription?.cancel();
    _accelerometerSubscription.cancel();
    _rotationSub?.cancel();
  }
}