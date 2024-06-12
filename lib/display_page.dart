import 'package:flutter/material.dart';

class DisplayPage extends StatelessWidget {
  final String fileContent;

  const DisplayPage({super.key, required this.fileContent});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Content'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(fileContent),
        ),
      ),
    );
  }
}