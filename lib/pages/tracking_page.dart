import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:road_quality_tracker/models/run_point.dart';
import '../services/run_tracker.dart';
import '../services/run_history_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/run.dart';
import 'package:provider/provider.dart';


class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  RunTracker runTracker = RunTracker.create();

  List<AccelerometerEvent> _accelerometerValue = [];
  List<GyroscopeEvent> _rotationValue = [];
  List<MagnetometerEvent> _compassValue = [];

  late StreamSubscription<AccelerometerEvent> _accelerometerSubscription;
  late StreamSubscription<GyroscopeEvent> _gyroscopeSubscription;
  late StreamSubscription<MagnetometerEvent> _magnetometerSubscription;

  void subscribeToSensors(){
    dev.log('Subcribing to sensors', name: 'TrackingPage');
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      setState(() {
        _accelerometerValue = [event];
        runTracker.onVibrationEvent(event);
      });
    });
    _gyroscopeSubscription = gyroscopeEvents.listen((event) {
      setState(() {
        _rotationValue = [event];
        runTracker.onRotationEvent(event);
      });
    });

    _magnetometerSubscription = magnetometerEvents.listen((event) {
      setState(() {
        _compassValue = [event];
        runTracker.onCompassEvent(event);
      });
    });
  }

  void disposeSensors(){
    _accelerometerSubscription.cancel();
    _gyroscopeSubscription.cancel();
    _magnetometerSubscription.cancel();
  }

  @override
  void initState() {
    super.initState();
    subscribeToSensors();
  }
  
  @override
  void dispose() {
    runTracker.dispose(); // Cancel the location stream
    disposeSensors();
    super.dispose();
  }

  void toggleRun(){
    if (runTracker.isReady) {
        if (runTracker.runIsActive.value) {
        Run? completedRun = runTracker.endRun();
        
        if (completedRun != null) {
          // Save completed run
          context.read<RunHistoryProvider>().addRun(completedRun);
        }
      } else {
        runTracker.startRun();
      }
    } else {
        ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("We can't access your location. Please check the app's permissions in your system settings."),
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.fixed,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );}
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme appColorScheme = Theme.of(context).colorScheme;
    
    return ValueListenableBuilder<bool>(
        valueListenable: runTracker.runIsActive,
        builder: (context, runIsActive, _) {
      String buttonText = runIsActive ?      'END RUN' :                 'START RUN';
      Color buttonColor = runIsActive ?      appColorScheme.secondary:   appColorScheme.primary;
      Color buttonTextColor = runIsActive ?  appColorScheme.onSecondary: appColorScheme.onPrimary;

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!runIsActive)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  PlainSensorOutput(type: 'Accelerometer / Vibration', valueList: _accelerometerValue, runIsActive: runIsActive,),
                  PlainSensorOutput(type: 'Gyroscope / Rotation', valueList: _rotationValue, runIsActive: runIsActive,),
                  PlainSensorOutput(type: 'Magnetometer / Compass', valueList: _compassValue, runIsActive: runIsActive,)
                  ]
              )
            )
          ),
          if (runIsActive)
          Expanded(
            child: Center(
              child: ValueListenableBuilder<RunPoint?>(
                valueListenable: runTracker.lastPoint,
                builder: (context, point, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 50,),
                      if (runIsActive)
                      BigCard(point: point, runIsActive: runIsActive),
                    ]
                  )
                ),
              ),
            )
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {toggleRun();}, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: buttonTextColor,
                  textStyle: Theme.of(context).textTheme.titleMedium,
                  elevation: 7,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  shape: const StadiumBorder(),
                ),
                child: Text(buttonText)),
            ],
          ),
          SizedBox(height: 50),
        ],
      );
    },);
  }
}

class PlainSensorOutput extends StatelessWidget {
    const PlainSensorOutput({
      super.key,
      required this.type,
      required this.valueList,
      required this.runIsActive
    });

    final String type;
    final List valueList;
    final bool runIsActive;

    @override
    Widget build(BuildContext context) {
          return Column(
                children: !runIsActive ?
                [
                  SizedBox(height: 10),
                  Text(
                    type,
                    style: TextStyle(fontSize: 20),
                  ),
                  SizedBox(height: 10),
                  if (valueList.isNotEmpty)
                    Text(
                      'X: ${valueList[0].x.toStringAsFixed(2)}, '
                      'Y: ${valueList[0].y.toStringAsFixed(2)}, '
                      'Z: ${valueList[0].z.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 16),
                    )
                  else
                    Text('No data available', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 10),
                  ]
                : [],
            );
      }
  }


class BigCard extends StatelessWidget {
    const BigCard({
      super.key,
      required this.point,
      required this.runIsActive,
    });

    final RunPoint? point;
    final bool runIsActive;

    @override
    Widget build(BuildContext context) {
      var theme = Theme.of(context);
      final screenSize = MediaQuery.of(context).size;
      var styleHeadline = theme.textTheme.headlineMedium!.copyWith(
        color: theme.colorScheme.onPrimary,
      );
      var style = theme.textTheme.bodyLarge!.copyWith(
        color: theme.colorScheme.onPrimary
      );

      return Center(
          child: SizedBox(
              width: screenSize.width * 0.8,
              height: screenSize.height * 0.66,
              child: Card(
                color: theme.colorScheme.primary,
                margin: EdgeInsets.all(24),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: point != null
                      ? [
                          Text("Last Read Point", style: styleHeadline),
                          const SizedBox(height: 11),
                          Text("Time: \n\t ${point!.timestamp.toString().split('.').first}", style: style),
                          const SizedBox(height: 7),
                          Text(point!.location.toPrint(), style: style),
                          const SizedBox(height: 7),
                          Text(point!.vibrationSpec.toPrint(), style: style),
                          const SizedBox(height: 7),
                          Text(point!.rotationSpec.toPrint(), style: style),
                          const SizedBox(height: 7),
                          Text(point!.compassSpec.toPrint(), style: style),
                          const SizedBox(height: 7),
                          Text("Speed: \n\t ${point!.speed}", style: style),
                        ]
                      : [
                          Text("No point was measured so far.", style: style),
                        ],
                  ),
                ),
              ),
            )
          );
    }
  }
