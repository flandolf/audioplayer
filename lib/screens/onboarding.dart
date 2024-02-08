import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../main.dart';

class OnboardingPage extends StatefulWidget {
  final Database database;
  const OnboardingPage(this.database, {super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome!'),
      ),
      body: Center(
        child: Column(
          children: [
            const Text("Welcome to the AudioPlayer!", style: TextStyle(fontSize: 20),),
            const Text("Some setup is required before you can use the app.", style: TextStyle(fontSize: 16),),
            const SizedBox(height: 20,),
            const Text("Please select a directory to store your music in.", style: TextStyle(fontSize: 16),),
            const SizedBox(height: 20,),
            ElevatedButton(
              onPressed: () async {
                Provider.of<MainProvider>(context, listen: false).dlMusicDir = (await FilePicker.platform.getDirectoryPath())!;
                final SharedPreferences prefs = await SharedPreferences.getInstance();
                if (!context.mounted) return;
                prefs.setString('directory', Provider.of<MainProvider>(context, listen: false).dlMusicDir);
              },
              child: const Text('Select Directory'),
            ),
            const SizedBox(height: 20,),
            Text("Selected Directory: ${Provider.of<MainProvider>(context).dlMusicDir}"),
            const SizedBox(height: 20,),
            Text("Current database location: ${widget.database.path}"),
            const SizedBox(height: 20,),
            FilledButton(onPressed: () {
              Navigator.pushReplacementNamed(context, '/home');
            }, child: const Text("Continue")),
          ],
        ),
      )
    );
  }
}
