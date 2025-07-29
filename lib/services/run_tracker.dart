import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:road_quality_tracker/services/run_history_provider.dart';
import 'package:road_quality_tracker/services/run_logger.dart';
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
  static int tactInMs = 1000;
  final minSpeedThreshold = 1.0; // km/h
  Timer? _saveTimer;

  late RunLogger _logger;

  bool _addingPoint = false;

  Run? activeRun;

  final ValueNotifier<bool> isReady = ValueNotifier<bool>(false);

  static final ValueNotifier<bool> runIsActive = ValueNotifier<bool>(false);
  static final ValueNotifier<String?> activeRunId = ValueNotifier(null);

  final ValueNotifier<RunPoint?> lastPoint = ValueNotifier(null);
  final ValueNotifier<LocationSpec?> currentRawLocation = ValueNotifier(null);
  final ValueNotifier<double?> currentRawSpeed = ValueNotifier(null);
  final ValueNotifier<List<AccelerometerEvent>> currentRawVibration =
      ValueNotifier([]);

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

  static RunTracker create(RunLogger runLogger) {
    final tracker = RunTracker._();
    tracker._logger = runLogger;
    return tracker;
  }

  Future<void> init() async {
    _startLocationWatch();
    subscribeToSensors();
    await waitForDataPoints();
  }

  Future<void> waitForDataPoints() {
    final completer = Completer<void>();

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_currentLocation.value != null &&
          _speed.value != null &&
          _vibration.value != null) {
        if (!completer.isCompleted) {
          final msg = 'All sensors ready';
          _logger.logEvent(msg);
          dev.log(msg, name: 'RunTracker');
          timer.cancel();
          completer.complete();
          isReady.value = true;
        }
      }
    });

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        final msg = "Sensor readiness timed out.";
          _logger.logEvent(msg);
        dev.log(msg, name: "RunTracker");
        if (!completer.isCompleted) {
          completer.complete(); // optionally fail silently
        }
        return;
      },
    );
  }

  void subscribeToSensors() {
    final msg = 'Subcribing to sensors.';
          _logger.logEvent(msg);
    dev.log(msg, name: 'RunTracker');
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
        final msg = 'Locationservice couldnt be enabled!';
        _logger.logWarning(msg);
        throw (msg);
      }
    }
    PermissionStatus permissionGranted = await _locationService.hasPermission(); //should be enabled through permission gate
    if (permissionGranted != PermissionStatus.granted) {
      final msg = 'Access rights are missing for the phones location data!';
      _logger.logWarning(msg);
      throw (msg);
    }
    if (serviceEnabled && (permissionGranted == PermissionStatus.granted)) {
      _locationService.changeSettings(
        interval: tactInMs,
        accuracy: LocationAccuracy.high,
      );

      _locationSubscription = _locationService.onLocationChanged.listen((
        locationData,
      ) {
        Future.microtask(() => onNewLocationPoint(locationData));
      });
    }
  }

  void onNewLocationPoint(LocationData locationData) {
    saveNewLocation(locationData);
    saveNewSpeed(locationData);
    if (runIsActive.value) {
      addNewPointThrottled();
    }
  }

  bool saveNewLocation(LocationData locationData) {
    if (locationData.latitude != null && locationData.longitude != null) {
      final loc = LocationSpec(
        latitude: locationData.latitude!,
        longitude: locationData.longitude!,
      );

      _currentLocation = _currentLocation.update(loc);
      currentRawLocation.value = loc;
      return true;
    }
    return false;
  }

  bool saveNewSpeed(LocationData locationData) {
    if (locationData.speed != null) {
      final rawSpeed = locationData.speed! * 3.6;
      final cleanedSpeed = rawSpeed < minSpeedThreshold ? 0.0 : rawSpeed;

      final newSpeed =
          _speed.value != null
              ? 0.1 * _speed.value! + 0.9 * cleanedSpeed
              : cleanedSpeed;
      _speed = _speed.update(newSpeed);
      currentRawSpeed.value = newSpeed;
      return true;
    } else {
      _speed = _speed.update(0.0);
      currentRawSpeed.value = null;
      return false;
    }
  }

  void addNewPointThrottled() {
    if (_addingPoint) {
      final msg = "Skipped point as the prior operation is still pending!";
      dev.log(msg, name: "RunTracker", level: 2);
      _logger.logWarning(msg);
      return;
    }

    _addingPoint = true;
    try {
      RunPoint? p = addNewPoint();
      if (p != null) _logger.logPoint(p.timestamp);
    } finally {
      _addingPoint = false;
    }
  }

  RunPoint? addNewPoint() {
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
      return point;
    }
    return null;
  }

  bool hasAllMeasurementsNeeded(now) {
    if (_currentLocation.value != null &&
        vibrationIsValid(now) &&
        speedIsValid(now)) {
      return true;
    } else {
      final threshold = Duration(milliseconds: tactInMs);
      String invalidValue = '';
      if (_currentLocation.value == null){
          invalidValue = 'Location = null';
      } else if (!speedIsValid(now)) {
          invalidValue = 'Speed = ${_speed.value}, fresh: ${_speed.isFresh(threshold, now)}';
      } {
        if (!_vibration.isFresh(threshold, now)) {
          invalidValue = 'Vibration: too old. No recent change.';
        }
          invalidValue = 'Vibration: value = ${_vibration.value}';
      }
      String msg =
          "[INVALID SENSOR VALUES] $invalidValue.";
      _logger.logEvent(msg);
      dev.log(msg, name: "RunTracker");
      return false;
    }
  }

  bool vibrationIsValid(DateTime now) {
    final threshold = Duration(milliseconds: tactInMs);
    if (_vibration.value != null && _vibration.isFresh(threshold, now)) {
      return true;
    } else {
      return false;
    }
  }

  bool speedIsValid(DateTime now) {
    final threshold = Duration(milliseconds: tactInMs);
    if (_speed.value != null && _speed.isFresh(threshold, now)) {
      return true;
    } else {
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
        newMag > _vibrationMagPeak.value!) {
      _vibrationMagPeak = _vibrationMagPeak.update(newMag);
      _vibration = _vibration.update(vib);
    }
  }

  void onQuanternionEvent(List<double> event) {
    vm.Quaternion q = vm.Quaternion(event[0], event[1], event[2], event[3]);
    vm.Matrix3 rotationMatrix = q.asRotationMatrix();
    //_rotationQuaternion = event;
    _rotationMatrix = rotationMatrix.clone()..invert();
  }

  double calcVibMagnitude(DimensionalSpec v) {
    return sqrt(
      v.xCoordinate * v.xCoordinate +
          v.yCoordinate * v.yCoordinate +
          v.zCoordinate * v.zCoordinate,
    );
  }

  void clearSensorSnapshots() {
    _vibration = _vibration.clear();
    _vibrationMagPeak = _vibrationMagPeak.clear();
    _speed = _speed.clear();
  }

  void startRun(
    String vehicleType,
    RunHistoryProvider runHistoryProvider,
  ) async {
    Future.microtask(() {
      activeRun = Run.create(DateTime.now(), vehicleType);
      runIsActive.value = true;
      activeRunId.value = activeRun?.id;
      _logger.startRunLog(activeRun!.id);
      addNewPointThrottled();
      runHistoryProvider.addRun(activeRun!);
      _saveTimer = Timer.periodic(Duration(seconds: 15), (_) {
        if (activeRun != null && runIsActive.value) {
          final msg = "Updating active Run ${activeRun!.id} on disk.";
          dev.log(msg, name: "RunTracker");
          _logger.logEvent(msg);
          activeRun?.setEndTime();
          runHistoryProvider.updateLatestRun(activeRun!);
        }
      });
    });
  }

  Future<Run?> endRun() async {
    activeRun?.setEndTime();
    runIsActive.value = false;
    activeRunId.value = null;
    lastPoint.value = null;
    _saveTimer?.cancel();
    _saveTimer = null;
    clearSensorSnapshots();
    await _logger.checkPointDensity(activeRun!);
    await _logger.endRun();
    return activeRun;
  }

  void dispose() {
    _locationSubscription?.cancel();
    _accelerometerSubscription.cancel();
    _rotationSub?.cancel();
    _logger.dispose();
  }
}
