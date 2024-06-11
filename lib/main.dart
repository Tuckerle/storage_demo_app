import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Storage Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Our Storage Demo App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counterOne = 0;
  int _counterTwo = 0;
  Database? database;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    _loadCounterOne();
    _loadCounterTwo();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      if (await Permission.storage.isDenied) {
        // Handle the case where user denied the permissions
        print('Permissions denied');
      }
    }
  }

  Future<void> _initializeDatabase() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'counter_logs.db');
    database = await openDatabase(
      path,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE Logs(id INTEGER PRIMARY KEY, timestamp TEXT, counter INTEGER, oldValue INTEGER, newValue INTEGER)',
        );
      },
      version: 1,
    );
  }

  Future<void> _logCounterEvent(int counter, int oldValue, int newValue) async {
    if (database != null) {
      await database!.insert(
        'Logs',
        {
          'timestamp': DateTime.now().toIso8601String(),
          'counter': counter,
          'oldValue': oldValue,
          'newValue': newValue,
        },
      );
    }
  }

  void _incrementCounterOne() {
    int oldValue = _counterOne;
    setState(() {
      _counterOne++;
    });
    _logCounterEvent(1, oldValue, _counterOne);
  }

  void _incrementCounterTwo() {
    int oldValue = _counterTwo;
    setState(() {
      _counterTwo++;
    });
    _logCounterEvent(2, oldValue, _counterTwo);
  }

  void exportCounterOne() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('counter_one', _counterOne);
  }

  Future<void> exportCounterTwoPrivate() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/counter_two_private.txt');
    await file.writeAsString('$_counterTwo');
  }

  Future<void> exportCounterTwoPublic(BuildContext context) async {
    await _openDirectoryPickerAndSaveFile(context);
  }

  Future<void> _openDirectoryPickerAndSaveFile(BuildContext context) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      final file = File('$selectedDirectory/counter_two_public.txt');
      await file.writeAsString('$_counterTwo');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File saved to $selectedDirectory')),
      );
    }
  }

  Future<void> _loadCounterOne() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _counterOne = prefs.getInt('counter_one') ?? 0;
    });
  }

  Future<void> _loadCounterTwo() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/counter_two_private.txt');
    if (await file.exists()) {
      String content = await file.readAsString();
      setState(() {
        _counterTwo = int.tryParse(content) ?? 0;
      });
    } else {
      setState(() {
        _counterTwo = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Icons.list),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => LogsPage(database: database),
            )),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Counter 1 has been incremented this many times:'),
            Text(
              '$_counterOne',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            TextButton(
              onPressed: exportCounterOne,
              child: const Text("Export Counter 1"),
            ),
            const Text('Counter 2 has been incremented this many times:'),
            Text(
              '$_counterTwo',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            TextButton(
              onPressed: exportCounterTwoPrivate,
              child: const Text("Export Counter 2 Private"),
            ),
            TextButton(
              onPressed: () => exportCounterTwoPublic,
              child: const Text("Export Counter 2 Public"),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _incrementCounterOne,
            tooltip: 'Increment Counter 1',
            child: const Icon(Icons.add),
            heroTag: 'counter1',
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _incrementCounterTwo,
            tooltip: 'Increment Counter 2',
            child: const Icon(Icons.add),
            heroTag: 'counter2',
          ),
        ],
      ),
    );
  }
}

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
