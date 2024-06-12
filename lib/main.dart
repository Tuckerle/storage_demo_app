import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'display_page.dart';
import 'logs_page.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const HomePage(title: 'Our Storage Demo App'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _counterOne = 0;
  int _counterTwo = 0;
  Database? database;
  String _fileContent = '';

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.manageExternalStorage.request();
      if (await Permission.manageExternalStorage.isDenied) {
        // Handle the case where user denied the permissions
        if (kDebugMode) {
          print('Permissions denied');
        }
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

  // INFO: Logs the counter increments to the database
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

  //INFO: Exporting counter
  //Exporting to Shared Preferences
  void exportCounterOne() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('counter_one', _counterOne);
  }

  //Exporting to private File
  Future<void> exportCounterTwoPrivate() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/counter_two_private.txt');
    await file.writeAsString('$_counterTwo');
  }

  //Exporting to public File with filepicker
  Future<String?> exportCounterTwoPublic() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      final file = File('$selectedDirectory/counter_two_public.txt');
      await file.writeAsString('$_counterTwo');
      return selectedDirectory; // Return the selected directory path to show in the Snackbar later
    }
    return null;
  }

  //INFO: Loading Values
  //Loading from Shared Preferences
  Future<void> _loadCounterOne() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _counterOne = prefs.getInt('counter_one') ?? 0;
    });
  }

  //Loading from File
  Future<void> _loadCounterTwo() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/counter_two_private.txt');
    if (await file.exists()) {
      String content = await file.readAsString();
      if (!mounted) return;
      setState(() {
        _counterTwo = int.tryParse(content) ?? 0;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _counterTwo = 0;
      });
    }
  }

  // Read File Content and Navigate to Display Page
  Future<void> _pickAndReadFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if(mounted) {
      if (result != null && result.files.isNotEmpty) {
        String filePath = result.files.single.path!;
        File file = File(filePath);
        String fileContent = await file.readAsString();
        if (!mounted) return;
        setState(() {
          _fileContent = fileContent;
        });

          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => DisplayPage(fileContent: _fileContent),
          ));

      } else {
        _showSnackbar('No File selected', context);
      }
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
            icon: const Icon(Icons.list),
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
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all<Color>(Colors.indigo),
                backgroundColor: WidgetStateProperty.all<Color>(Colors.grey),
              ),
              child: const Text("Export Counter 1"),
            ),
            const Text('Counter 2 has been incremented this many times:'),
            Text(
              '$_counterTwo',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            TextButton(
              onPressed: exportCounterTwoPrivate,
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                backgroundColor: WidgetStateProperty.all<Color>(Colors.black),
              ),
              child: const Text("Export Counter 2 Private"),
            ),
            TextButton(
              onPressed: () async {
                final directory = await exportCounterTwoPublic();
                if (directory != null) {
                  _showSnackbar('File saved to $directory', context);
                } else {
                  _showSnackbar('No Directory selected', context);
                }
              },
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all<Color>(Colors.blueAccent),
                backgroundColor: WidgetStateProperty.all<Color>(Colors.black),
              ),
              child: const Text("Export Counter 2 Public"),
            ),
            TextButton(
              onPressed: () => _pickAndReadFile(context),
              style: ButtonStyle(
                foregroundColor: WidgetStateProperty.all<Color>(Colors.green),
                backgroundColor: WidgetStateProperty.all<Color>(Colors.black),
              ),
              child: const Text("Open and Read File"),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _incrementCounterOne,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all<Color>(Colors.indigo),
              foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
            ),
            child: const Text("Increment Counter 1"),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _incrementCounterTwo,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all<Color>(Colors.blue),
              foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
            ),
            child: const Text("Increment Counter 2"),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    _loadCounterOne();
    _loadCounterTwo();
    _requestPermissions();
  }

  void _showSnackbar(String message, BuildContext context) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
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
}

