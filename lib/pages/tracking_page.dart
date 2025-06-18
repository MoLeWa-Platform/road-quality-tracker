import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:provider/provider.dart';
import '../models/dimension_spec.dart';
import '../models/location_spec.dart';
import '../models/run_point.dart';
import '../models/run.dart';
import '../services/run_tracker.dart';
import '../services/run_history_provider.dart';

class TrackingPage extends StatefulWidget {
  const TrackingPage({super.key});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  RunTracker runTracker = RunTracker.create();
  
  @override
  void dispose() {
    runTracker.dispose(); // Cancel the location stream
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
                  ValueListenableBuilder<LocationSpec?>(
                    valueListenable: runTracker.currentRawLocation,
                    builder: (context, loc, _) {
                      return PlainCoordinateOutput(location: loc);
                    },
                  ),
                  ValueListenableBuilder<List<AccelerometerEvent>>(
                    valueListenable: runTracker.currentRawVibration,
                    builder: (context, vib, _) {
                      return PlainSensorOutput(type: 'Accelerometer / Vibration', valueList: vib, runIsActive: runIsActive,);
                    },
                  ),
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
                      buildLiveSensorCard(context, point),
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

class PlainCoordinateOutput extends StatelessWidget {
  final LocationSpec? location;

  const PlainCoordinateOutput({super.key, this.location});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 10),
        Text('Current Location', style: TextStyle(fontSize: 20)),
        SizedBox(height: 10),
        if (location != null)
          Text(
            'Lat: ${location!.latitude.toStringAsFixed(6)}\nLon: ${location!.longitude.toStringAsFixed(6)}',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          )
        else
          Text('No location yet', style: TextStyle(fontSize: 16)),
        SizedBox(height: 10),
      ],
    );
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

Widget buildLiveSensorCard(BuildContext context, RunPoint? point) {
  final labelStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);
  final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87);
  final monoStyle = TextStyle(fontFamily: 'monospace', color: Colors.black87);

  Widget buildRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text(value ?? '--', style: valueStyle),
        ],
      ),
    );
  }

  Widget buildVectorRow(String label, DimensionalSpec? v) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("\t x: ${v?.xCoordinate.toStringAsFixed(2) ?? '0.00'}", style: monoStyle),
              Text("y: ${v?.yCoordinate.toStringAsFixed(2) ?? '0.00'}", style: monoStyle),
              Text("z: ${v?.zCoordinate.toStringAsFixed(2) ?? '0.00'}", style: monoStyle),
            ],
          ),
        ],
      ),
    );
  }

  return Card(
    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 3,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Last Point", style: Theme.of(context).textTheme.titleLarge),
          Divider(),
          buildRow("Time", point?.timestamp.toString()),
          buildRow("Speed", "${point?.speed.toStringAsFixed(1) ?? '0.0'} m/s"),
          SizedBox(height: 4),
          Text("Location", style: labelStyle),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("\t Latitude:"),
              Expanded(
                child: Text(
                  point?.location.latitude.toStringAsFixed(6) ?? '--',
                  textAlign: TextAlign.right,
                  style: monoStyle,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("\t Longitude:"),
              Expanded(
                child: Text(
                  point?.location.longitude.toStringAsFixed(6) ?? '--',
                  textAlign: TextAlign.right,
                  style: monoStyle,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          buildVectorRow("Vibration", point?.vibrationSpec),
        ],
      ),
    ),
  );
}
