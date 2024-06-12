import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

class LogsPage extends StatelessWidget {
  final Database? database;

  const LogsPage({super.key, required this.database});

  Future<List<Map<String, dynamic>>> _fetchLogs() async {
    if (database != null) {
      return await database!.query('Logs');
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error fetching logs'));
          }
          final logs = snapshot.data!;
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                title: Text(
                    'Counter ${log['counter']} - Time: ${log['timestamp']}'),
                subtitle: Text(
                    'Old Value: ${log['oldValue']} -> New Value: ${log['newValue']}'),
              );
            },
          );
        },
      ),
    );
  }
}