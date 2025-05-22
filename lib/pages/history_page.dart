import 'package:flutter/material.dart';

class LastRunsPage extends StatelessWidget {
  const LastRunsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(title: Text('22/04/2024 14:30'), trailing: Icon(Icons.chevron_right)),
        ListTile(title: Text('22/04/2024 14:20'), trailing: Icon(Icons.chevron_right)),
        ListTile(title: Text('22/04/2024 14:10'), trailing: Icon(Icons.chevron_right)),
      ],
    );
  }
}