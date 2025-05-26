import 'package:flutter/material.dart';
import 'package:road_quality_tracker/models/run_point.dart';
import '../services/run_tracker.dart';


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
        runTracker.endRun();
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
          Expanded(
            child: ValueListenableBuilder<RunPoint?>(
              valueListenable: runTracker.lastPoint,
              builder: (context, point, _) => Center(
                child: BigCard(point: point, runIsActive: runIsActive,),
              ),
            ),
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
      var styleHeadline = theme.textTheme.headlineMedium!.copyWith(
        color: theme.colorScheme.onPrimary
      );
      var style = theme.textTheme.bodyLarge!.copyWith(
        color: theme.colorScheme.onPrimary
      );

      return Card(
        color: theme.colorScheme.primary,
        margin: EdgeInsets.all(24),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: !runIsActive
              ? [
                  Text("Start a run to see live data.", style: style),
                ] 
              : point != null
              ? [
                  Text("Last Read Point", style: styleHeadline),
                  const SizedBox(height: 11),
                  Text("Time: \n\t ${point!.timestamp.toString().split('.').first}", style: style),
                  const SizedBox(height: 7),
                  Text(point!.location.toPrint(), style: style),
                  const SizedBox(height: 7),
                  Text("Orientation: \n\t ${point!.orientation}°", style: style),
                  const SizedBox(height: 7),
                  Text(point!.vibrationSpec.toPrint(), style: style),
                  const SizedBox(height: 7),
                  Text("Speed: \n\t ${point!.speed}", style: style),
                ]
              : [
                  Text("No point was measured so far.", style: style),
                ],
          ),
        ),
      );
    }
  }
