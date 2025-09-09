import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive/hive.dart';
import 'package:road_quality_tracker/models/run_log.dart';
import 'package:road_quality_tracker/pages/log_page.dart';
import 'package:road_quality_tracker/services/run_logger.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:provider/provider.dart';
import '../models/dimension_spec.dart';
import '../models/location_spec.dart';
import '../models/run_point.dart';
import '../models/run.dart';
import '../services/run_tracker.dart';
import '../services/run_history_provider.dart';
import 'dart:developer' as dev;

class _VehicleTypeDialog extends StatefulWidget {
  const _VehicleTypeDialog({Key? key}) : super(key: key);

  @override
  State<_VehicleTypeDialog> createState() => _VehicleTypeDialogState();
}

class _VehicleTypeDialogState extends State<_VehicleTypeDialog> {
  final TextEditingController _customController = TextEditingController();

  String? _selectedKey; // 'Bike', 'Car', 'E-Scooter', 'Custom'
  String? _customLabel; // user-entered label after submit
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _submitCustom() {
    final text = _customController.text.trim();
    if (text.isNotEmpty && mounted) {
      final capitalized = text
          .split(' ')
          .where((w) => w.isNotEmpty)
          .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
          .join(' ');
      setState(() {
        _customLabel = capitalized;
        _showCustomInput = false;
        _selectedKey = 'Custom';
      });
    }
  }

  Widget _option({
    required IconData icon,
    required String keyValue,
    required String label,
  }) {
    final isSelected = _selectedKey == keyValue;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (!mounted) return;
        setState(() {
          _selectedKey = keyValue;
          _showCustomInput = keyValue == 'Custom';
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 38,
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canStart =
        _selectedKey != null &&
        (_selectedKey != 'Custom' ||
            (_customLabel?.trim().isNotEmpty ?? false));

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Text(
        'Select the Vehicle Type',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.start,
                spacing: 36,
                runSpacing: 24,
                children: [
                  _option(
                    icon: Icons.directions_bike,
                    keyValue: 'Bike',
                    label: 'Bike',
                  ),
                  _option(
                    icon: Icons.electric_scooter,
                    keyValue: 'E-Scooter',
                    label: 'E-Scooter',
                  ),
                  _option(
                    icon: Icons.directions_car_rounded,
                    keyValue: 'Car',
                    label: 'Car',
                  ),
                  _option(
                    icon: Icons.person_add,
                    keyValue: 'Custom',
                    label:
                        (_customLabel == null || _customLabel!.trim().isEmpty)
                            ? 'Custom'
                            : _customLabel!,
                  ),
                ],
              ),
              if (_showCustomInput) ...[
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child:
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 0, 0),
                        child: TextField(
                          controller: _customController,
                          autofocus: true,
                          onSubmitted: (_) => _submitCustom(),
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Enter your own vehicle',
                            hintText: 'e.g. Motorcycle, Tractor ..',
                            border: UnderlineInputBorder(),
                            isDense: true,
                          ),
                          minLines: 1,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Submit',
                      onPressed: _submitCustom,
                      icon: const Icon(Icons.check),
                    ),
                  ],
                ),
              ],
              const SizedBox(width: 15),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed:
              canStart
                  ? () {
                    final value =
                        (_selectedKey == 'Custom')
                            ? _customLabel!.trim()
                            : _selectedKey!;
                    Navigator.of(context).pop(value);
                  }
                  : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                canStart ? Theme.of(context).colorScheme.primary : Colors.grey,
            foregroundColor: Colors.white,
          ),
          child: const Text('Start Run'),
        ),
      ],
    );
  }
}

class TrackingPage extends StatefulWidget {
  final RunTracker runTracker;
  final RunLogger logger;
  final FlutterBackgroundService backgroundService;

  const TrackingPage({
    super.key,
    required this.runTracker,
    required this.backgroundService,
    required this.logger,
  });

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  late final RunTracker runTracker;
  late RunLogger logger;
  late final FlutterBackgroundService backgroundService;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    runTracker = widget.runTracker;
    logger = widget.logger;
    runTracker.init();
    backgroundService = widget.backgroundService;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final runHistory = Provider.of<RunHistoryProvider>(
        context,
        listen: false,
      );
      if (!logger.hasShownBugPopup) {
        final lastUnreviewed = await logger.getMostRecentUnreviewedLog();
        final Run? lastRun = runHistory.getMostRecentRun();
        if (lastUnreviewed != null &&
            lastRun != null &&
            lastUnreviewed.runId == lastRun.id) {
          _showBugLogDialog(lastUnreviewed);
          logger.markBugPopupShown();
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> checkLastRunForBugs(BuildContext context, Run run) async {
    final bugBox = await Hive.openBox('runLoggerBugReports');
    final latestLog = bugBox.values.cast<RunLog>().lastOrNull;
    await bugBox.close();

    if (!mounted) return;

    if (latestLog != null && !latestLog.reviewed && latestLog.runId == run.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBugLogDialog(latestLog);
      });
    }
    updateUnreviewedLogState();
  }

  void _showBugLogDialog(RunLog log) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Warning Detected"),
            content: const Text(
              "A warning occurred during your last run.\nWould you like to view the log?",
            ),
            actions: [
              TextButton(
                child: const Text("Later"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text("View Log"),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LogPage()),
                  );
                },
              ),
            ],
          ),
    );
  }

  Future<String?> selectVehicleType(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _VehicleTypeDialog(),
    );
  }

  void _stopRun() async {
    logger.log('[TRACKING PAGE] Tapped StopRun button. Initiate end.');
    Run? completedRun = await runTracker.endRun();
    backgroundService.invoke('stopForeground');
    if (completedRun != null && mounted) {
      context.read<RunHistoryProvider>().updateRun(completedRun);
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
      checkLastRunForBugs(context, completedRun);
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
                              if (!isReady)
                                Icon(
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          )
        else
          Text(
            'No location yet',
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
          ),
        );
      },
    );
  }
}

Widget buildRunSensorCard(BuildContext context, Run run, RunPoint? point) {
  final vehicleType = run.vehicleType;
  final vehicleIcon =
      (vehicleType == 'Bike')
          ? Icons.directions_bike
          : (vehicleType == 'E-Scooter')
          ? Icons.electric_scooter
          : (vehicleType == 'Car')
          ? Icons.directions_car
          : Icons.person_add;
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
              Icon(vehicleIcon, color: Theme.of(context).colorScheme.primary),
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
