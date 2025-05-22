import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/tracking_page.dart';
import 'pages/settings_page.dart';
import 'pages/history_page.dart';


void main() {
  runApp(RoadQualityTrackerApp());
}

class RoadQualityTrackerApp extends StatelessWidget {
  const RoadQualityTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GlobalAppState(),
      child: MaterialApp(
          title: 'Road Quality Tracker',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          home: HomePage(),
        )
    );
  }
}

class GlobalAppState extends ChangeNotifier {
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = [
    TrackingPage(),
    LastRunsPage(),
    SettingsPage(),
  ];

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
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: appColorScheme.onPrimary,
        unselectedItemColor: Colors.white70,
        backgroundColor: appColorScheme.primary,
        unselectedFontSize: 12,
        selectedFontSize: 14,
        selectedIconTheme: IconThemeData(size: 31),
        unselectedIconTheme: IconThemeData(size: 27),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Tracking'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Run History'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
