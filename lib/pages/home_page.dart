import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:road_quality_tracker/pages/log_page.dart';
import 'package:road_quality_tracker/services/run_logger.dart';
import '../pages/tracking_page.dart';
import '../pages/settings_page.dart';
import '../pages/history_page.dart';
import '../services/run_tracker.dart';

class HomePage extends StatefulWidget {
  final FlutterBackgroundService backgroundService;
  final RunLogger runLogger;
  final RunTracker runTracker;

  const HomePage({
    super.key,
    required this.backgroundService,
    required this.runLogger,
    required this.runTracker,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    widget.backgroundService.startService();
    updateUnreviewedLogState();
    _pages = [
      TrackingPage(
        runTracker: widget.runTracker,
        backgroundService: widget.backgroundService,
        logger: widget.runLogger,
      ),
      HistoryPage(logger: widget.runLogger),
      SettingsPage(logger: widget.runLogger),
    ];
  }

  void _onItemTapped(int index) {
    final page =
        index == 0
            ? 'TrackingPage'
            : index == 1
            ? "HistoryPage"
            : "SettingsPage";
    widget.runLogger.log(
      '[HOME PAGE] Tapped on index $index ($page) in MenuBar.',
    );
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
                          child: Icon(
                            Icons.circle,
                            size: 10,
                            color: Colors.green,
                          ),
                        ),
                    ],
                  ),
                ),
                label: 'Tracking',
              ),
              BottomNavigationBarItem(
                icon: SizedBox(
                  width: 42,
                  height: 42,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.settings),
                      ValueListenableBuilder<bool>(
                        valueListenable: hasUnreviewedLogsNotifier,
                        builder: (context, hasUnreviewed, _) {
                          if (!hasUnreviewed) return const SizedBox.shrink();
                          return const Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(
                              Icons.circle,
                              size: 9,
                              color: Colors.red,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                label: 'Run History',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'Settings',
              ),
            ],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          );
        },
      ),
    );
  }
}
