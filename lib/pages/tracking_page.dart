import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:provider/provider.dart';
import '../models/dimension_spec.dart';
import '../models/location_spec.dart';
import '../models/run_point.dart';
import '../models/run.dart';
import '../services/run_tracker.dart';
import '../services/run_history_provider.dart';
import 'dart:developer' as dev;

class TrackingPage extends StatefulWidget {
  final RunTracker runTracker;
  final FlutterBackgroundService backgroundService;
  const TrackingPage({
    super.key,
    required this.runTracker,
    required this.backgroundService,
  });

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  late final RunTracker runTracker;
  late final FlutterBackgroundService backgroundService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    runTracker = widget.runTracker;
    backgroundService = widget.backgroundService;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<String?> selectVehicleType(BuildContext context) async {
    String? selected;

    return await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Select the Vehicle Type'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            selected = 'Bike';
                          });
                        },
                        child: Column(
                          children: [
                            Icon(
                              Icons.directions_bike,
                              size: 35,
                              color:
                                  selected == 'Bike'
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Bike',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            selected = 'Car';
                          });
                        },
                        child: Column(
                          children: [
                            Icon(
                              Icons.directions_car_rounded,
                              size: 35,
                              color:
                                  selected == 'Car'
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Car',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), // Cancel
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      selected != null
                          ? () => Navigator.pop(context, selected)
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        selected != null
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Start Run'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _stopRun() {
    Run? completedRun = runTracker.endRun();
    backgroundService.invoke('stopForeground');
    if (completedRun != null) {
      context.read<RunHistoryProvider>().addRun(completedRun);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Saved! Check your run history.",
            textAlign: TextAlign.center,
          ),
          duration: Duration(seconds: 1),
          backgroundColor: Theme.of(context).colorScheme.secondary,
        ),
      );
    }
  }

  void _startRun() {
    setState(() => _isLoading = true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final vehicleType = await selectVehicleType(context);

        if (vehicleType == null) {
          setState(() => _isLoading = false);
          return;
        }

        backgroundService.invoke('startAsForeground');
        await Future.delayed(Duration(milliseconds: 300));

        if (!mounted) return;

        runTracker.startRun(vehicleType, context.read<RunHistoryProvider>());
      } catch (e, st) {
        dev.log('Run start failed: $e', stackTrace: st);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  void toggleRun() async {
    if (runTracker.isReady.value) {
      if (RunTracker.runIsActive.value) {
        _stopRun();
      } else {
        _startRun();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "We can't access your location. Please check the app's permissions in your system settings.",
          ),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.fixed,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme appColorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: RunTracker.runIsActive,
      builder: (context, runIsActive, _) {
        String buttonText = runIsActive ? 'END RUN' : 'START RUN';
        Color buttonColor =
            runIsActive ? appColorScheme.secondary : appColorScheme.primary;
        Color buttonTextColor =
            runIsActive ? appColorScheme.onSecondary : appColorScheme.onPrimary;

        return Stack(
          children: [
            Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surfaceBright,
              body: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 90.0,
                        left: 16.0,
                        right: 16.0,
                        bottom: 16.0,
                      ),
                      child: Column(
                        children: [
                          if (!runIsActive) ...[
                            Text(
                              'Start a Run to Begin Tracking!',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Currently showing connected sensors…',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 25),
                          ],
                          if (runIsActive) ...[
                            Text(
                              'Tracking in Progress',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Monitoring movement and location…',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 25),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!runIsActive)
                    Expanded(
                      child: Center(
                        child: PreRunSensorCard(runTracker: runTracker),
                      ),
                    ),
                  if (runIsActive)
                    Expanded(
                      child: Center(
                        child: ValueListenableBuilder<RunPoint?>(
                          valueListenable: runTracker.lastPoint,
                          builder:
                              (context, point, _) => Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 50),
                                    buildRunSensorCard(
                                      context,
                                      runTracker.activeRun!,
                                      point,
                                    ),
                                  ],
                                ),
                              ),
                        ),
                      ),
                    ),
                  ValueListenableBuilder<bool>(
                    valueListenable: runTracker.isReady,
                    builder: (context, isReady, _) {
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed:
                                    (_isLoading || !isReady) ? null : toggleRun,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: buttonColor,
                                  foregroundColor: buttonTextColor,
                                  textStyle:
                                      Theme.of(context).textTheme.titleMedium,
                                  elevation: 7,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0,
                                    vertical: 16.0,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                child: Text(buttonText),
                              ),
                            ],
                          ),
                          SizedBox(height: 50),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!isReady) Icon(
                                  Icons.hourglass_top,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                              Text(
                                  !isReady ? "Setting up sensors.." : "",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium?.copyWith(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                                const SizedBox(width: 6),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withAlpha(50),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }
}

class PlainCoordinateOutput extends StatelessWidget {
  final LocationSpec? location;

  const PlainCoordinateOutput({super.key, this.location});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Current Location', style: TextStyle(fontSize: 22)),
        SizedBox(height: 10),
        if (location != null)
          Text(
            'Lat: ${location!.latitude.toStringAsFixed(6)}\nLon: ${location!.longitude.toStringAsFixed(6)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic,),
            textAlign: TextAlign.center,
          )
        else
          Text('No location yet', style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),),
        SizedBox(height: 20),
      ],
    );
  }
}

class PlainValueOutput extends StatelessWidget {
  final String identifier;
  final double? value;
  final String unit;

  const PlainValueOutput({
    super.key,
    required this.identifier,
    required this.unit,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Current $identifier', style: TextStyle(fontSize: 22)),
        SizedBox(height: 10),
        if (value != null)
          Text(
            '${value!.toStringAsFixed(2)} $unit',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic,),
            textAlign: TextAlign.center,
          )
        else
          Text(
            'No ${identifier.toLowerCase()} yet',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        SizedBox(height: 20),
      ],
    );
  }
}

class PlainSensorOutput extends StatelessWidget {
  const PlainSensorOutput({
    super.key,
    required this.type,
    required this.valueList,
  });

  final String type;
  final List valueList;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(type, style: TextStyle(fontSize: 22)),
        SizedBox(height: 10),
        if (valueList.isNotEmpty)
          Text(
            'X: ${valueList[0].x.toStringAsFixed(2)}, '
            'Y: ${valueList[0].y.toStringAsFixed(2)}, '
            'Z: ${valueList[0].z.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic,),
          )
        else
          Text('No data available', style: TextStyle(fontSize: 16)),
        SizedBox(height: 20),
      ],
    );
  }
}

class PreRunSensorCard extends StatelessWidget {
  final RunTracker runTracker;

  const PreRunSensorCard({super.key, required this.runTracker});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 75),
          ValueListenableBuilder<LocationSpec?>(
            valueListenable: runTracker.currentRawLocation,
            builder: (context, loc, _) {
              return PlainCoordinateOutput(location: loc);
            },
          ),
          SizedBox(height: 17),
          ValueListenableBuilder<double?>(
            valueListenable: runTracker.currentRawSpeed,
            builder: (context, speed, _) {
              return PlainValueOutput(
                identifier: 'Speed',
                value: speed,
                unit: 'km/h',
              );
            },
          ),
          SizedBox(height: 17),
          ValueListenableBuilder<List<AccelerometerEvent>>(
            valueListenable: runTracker.currentRawVibration,
            builder: (context, vib, _) {
              return PlainSensorOutput(
                type: 'Current Vibration',
                valueList: vib,
              );
            },
          ),
        ],
      ),
    );
  }
}

Widget buildRunSensorCard(
  BuildContext context,
  Run run,
  RunPoint? point,
) {
  final vehicleType = run.vehicleType;
  final labelStyle = Theme.of(
    context,
  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 16);
  final valueStyle = Theme.of(
    context,
  ).textTheme.bodyMedium?.copyWith(color: Colors.black87, fontSize: 16);
  final monoStyle = TextStyle(color: Colors.black87, fontSize: 16);

  Widget buildRow(String label, String? value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text(
            value ?? '--',
            style:
                color != null
                    ? valueStyle?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    )
                    : valueStyle,
          ),
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
              Text(
                "\t x: ${v?.xCoordinate.toStringAsFixed(2) ?? '0.00'}",
                style: monoStyle,
              ),
              Text(
                "y: ${v?.yCoordinate.toStringAsFixed(2) ?? '0.00'}",
                style: monoStyle,
              ),
              Text(
                "z: ${v?.zCoordinate.toStringAsFixed(2) ?? '0.00'}",
                style: monoStyle,
              ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Last Point",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 19,
                ),
              ),
              if (vehicleType == 'Bike')
                Icon(
                  Icons.directions_bike,
                  color: Theme.of(context).colorScheme.primary,
                ),
              if (vehicleType == 'Car')
                Icon(
                  Icons.directions_car,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
          Divider(),
          buildRow("Timestamp", point?.timestamp.toString()),
          buildRow("Passed Time", run.getFormattedDuration(live: true)),
          buildRow("Point Number", run.runPoints.length.toString()),
          buildRow("Speed", "${point?.speed.toStringAsFixed(1) ?? '0.0'} km/h"),
          SizedBox(height: 4),
          Text("Location", style: labelStyle),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("\t Latitude:", style: monoStyle),
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
              Text("\t Longitude:", style: monoStyle),
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
          buildRow(
            "Vibration Magnitude",
            point?.getVibMagnitude(),
            Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    ),
  );
}
