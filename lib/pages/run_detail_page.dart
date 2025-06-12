import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/run.dart';

class RunDetailPage extends StatelessWidget {
  final Run run;

  const RunDetailPage({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    final points = run.runPoints;
    final startTime = run.startTime;
    final endTime = run.endTime;
    final duration = endTime?.difference(startTime) ?? Duration.zero;

    final startPoint = points.firstWhere(
      (p) => p.location.longitude != null,
      orElse: () => points.first,
    );

    final LatLng startLatLng =  LatLng(startPoint.location.latitude, startPoint.location.longitude);
    final LatLng targetLocation = LatLng(51.5, -0.09); // Your desired coordinates

    return Scaffold(
      appBar: AppBar(
        title: Text(run.name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _InfoRow(label: "Start Time", value: startTime.toString()),
          _InfoRow(label: "Duration", value: duration.toString()),
          _InfoRow(label: "Points", value: points.length.toString()),
          const SizedBox(height: 20),
          Text("Map Preview", style: Theme.of(context).textTheme.titleMedium),
          Text(startLatLng.toString()),
          const SizedBox(height: 8),
          // FlutterMap(
          //   options: MapOptions(
          //     initialCenter: LatLng(51.509364, -0.128928), // Center the map over London
          //     initialZoom: 9.2,
          //   ),
          //   children: [
          //     TileLayer( // Bring your own tiles
          //       urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // For demonstration only
          //       userAgentPackageName: 'com.roadQualityTracker.app', // Add your app identifier
          //       // And many more recommended properties!
          //     ),
          //     RichAttributionWidget( // Include a stylish prebuilt attribution widget that meets all requirments
          //       attributions: [
          //         TextSourceAttribution(
          //           'OpenStreetMap contributors',
          //           //onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')), // (external)
          //         ),
          //         // Also add images...
          //       ],
          //     ),
          //   ],
          // ),
          const SizedBox(height: 24),
          Text("Additional details coming soon...", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text("$label:")),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
