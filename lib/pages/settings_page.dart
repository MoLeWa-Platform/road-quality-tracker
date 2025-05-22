import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  final TextEditingController mqttController = TextEditingController();
  final TextEditingController portController = TextEditingController();
  final TextEditingController topicController = TextEditingController();

  SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: mqttController,
            decoration: InputDecoration(labelText: 'MQTT'),
          ),
          TextField(
            controller: portController,
            decoration: InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: topicController,
            decoration: InputDecoration(labelText: 'Topic'),
          ),
        ],
      ),
    );
  }
}
