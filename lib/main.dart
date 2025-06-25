import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:road_quality_tracker/services/background_service.dart';
import 'pages/tracking_page.dart';
import 'pages/settings_page.dart';
import 'pages/history_page.dart';
import 'services/run_history_provider.dart';
import 'services/run_tracker.dart';
import 'models/run.dart';
import 'models/run_point.dart';
import 'models/location_spec.dart';
import 'models/dimension_spec.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Permission.notification.isDenied.then((value){
    if (value){
      Permission.notification.request();
    }
  });

  final backgroundService = await initService();
  
  await Hive.initFlutter();
  Hive.registerAdapter(RunAdapter());
  Hive.registerAdapter(RunPointAdapter());
  Hive.registerAdapter(DimensionalSpecAdapter());
  Hive.registerAdapter(LocationSpecAdapter());
  await Hive.openBox<Run>('runs');

  runApp(
    ChangeNotifierProvider(
      create: (_) => RunHistoryProvider(),
      child: RoadQualityTrackerApp(backgroundService: backgroundService), // replace with your root widget
    ),
  );
}

class RoadQualityTrackerApp extends StatelessWidget {
  final FlutterBackgroundService backgroundService;
  const RoadQualityTrackerApp({super.key, required this.backgroundService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => RunHistoryProvider(),
      child: MaterialApp(
          title: 'Road Quality Tracker',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          home: HomePage(backgroundService: backgroundService,),
        )
    );
  }
}

class HomePage extends StatefulWidget {
  final FlutterBackgroundService backgroundService;
  const HomePage({super.key, required this.backgroundService});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final RunTracker runTracker = RunTracker.create();
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    widget.backgroundService.startService();
    _pages = [
      TrackingPage(runTracker: runTracker, backgroundService: widget.backgroundService),
      HistoryPage(),
      SettingsPage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme appColorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
              color: appColorScheme.surfaceContainer,
              child: _pages[_selectedIndex],
            ),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: RunTracker.runIsActive,
        builder: (context, isTracking, _) {
          return BottomNavigationBar(
            selectedItemColor: appColorScheme.onPrimary,
            unselectedItemColor: Colors.white70,
            backgroundColor: appColorScheme.primary,
            unselectedFontSize: 12,
            selectedFontSize: 14,
            selectedIconTheme: IconThemeData(size: 31),
            unselectedIconTheme: IconThemeData(size: 27),
            items: [
              BottomNavigationBarItem(
                icon: SizedBox(
                  width: 42,
                  height: 42,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.map),
                      if (isTracking)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(Icons.circle, size: 10, color: Colors.green),
                        ),
                    ],
                  ),
                ),
                label: 'Tracking',
              ),
              const BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Run History'),
              const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          );
        },
      ),
    );
  }
}
