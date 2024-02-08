import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../main.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final diC = TextEditingController();
  final ciC = TextEditingController();
  final csC = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    getDirectory();
    loadProviders();
  }

  String directory = '';

  Future<void> getDirectory() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    directory = prefs.getString('directory')!;
    diC.text = directory;
    if (context.mounted) {
      Provider.of<MainProvider>(context, listen: false).dlMusicDir = directory;
    }
  }

  Future<void> loadProviders() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? clientId = prefs.getString('client_id');
    final String? clientSecret = prefs.getString('client_secret');
    if (clientId != null && clientSecret != null && context.mounted) {
      Provider.of<MainProvider>(context, listen: false).spotifyClientId = clientId;
      Provider.of<MainProvider>(context, listen: false).spotifyClientSecret = clientSecret;
    }
  }

  Future<void> saveDirectory(String directory) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('directory', directory);
    if (context.mounted) {
      Provider.of<MainProvider>(context, listen: false).dlMusicDir = directory;
    }
  }

  Future<void> resetDatabase(BuildContext context) async {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Reset Database'),
            content: const Text('Are you sure you want to reset the database?'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('OK'),
                onPressed: () async {
                  final database = await openDatabase(
                      p.join(await getDatabasesPath(), 'audio_player.db'));
                  await database.execute('DROP TABLE files');
                  await database.execute(
                    'CREATE TABLE files(id INTEGER PRIMARY KEY, name TEXT, path TEXT, artist TEXT, album TEXT)',
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          );
        });
  }

  Future<void> setSleepTimer(BuildContext context) async {
    final sleepTimerController = TextEditingController();
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Sleep Timer'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: sleepTimerController,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('OK'),
                onPressed: () async {
                  final int duration = int.parse(sleepTimerController.text);
                  if (duration < 0) return;
                  Provider.of<MainProvider>(context, listen: false).sleepTimer =
                      Duration(minutes: duration);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  Future<void> setDownloadedMusicDirectory(BuildContext context) async {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Downloaded Music Directory'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: diC,
                  decoration: const InputDecoration(
                    labelText: 'Directory',
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                    onPressed: () async {
                      FilePicker.platform.getDirectoryPath().then((value) {
                        if (value != null) {
                          diC.text = value;
                          setState(() {
                            directory = value;
                          });
                        }
                      });
                    },
                    child: const Text('Select Directory')),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('OK'),
                onPressed: () async {
                  await saveDirectory(diC.text);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  Future<void> setSpotifyAPIKeys(BuildContext context) async {

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Spotify API Keys'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ciC,
                  decoration: const InputDecoration(
                    labelText: 'Client ID',
                  ),
                ),
                TextField(
                  controller: csC,
                  decoration: const InputDecoration(
                    labelText: 'Client Secret',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('OK'),
                onPressed: () async {
                  final SharedPreferences prefs = await SharedPreferences.getInstance();
                  prefs.setString('client_id', ciC.text);
                  prefs.setString('client_secret', csC.text);
                  if (!context.mounted) return;
                  Provider.of<MainProvider>(context, listen: false).spotifyClientId = ciC.text;
                  Provider.of<MainProvider>(context, listen: false).spotifyClientSecret = csC.text;

                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  Future<void> saveColor(Color color) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('color', color.value);
    if (context.mounted) {
      Provider.of<MainProvider>(context, listen: false).seedColor = color;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: ListView(
          children: [
            ListTile(
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: Provider.of<MainProvider>(context).isDarkMode,
                onChanged: (bool value) {
                  Provider.of<MainProvider>(context, listen: false).isDarkMode =
                      value;
                },
              ),
            ),
            ListTile(
              title: const Text('Accent Color'),
              trailing: IconButton(
                icon: Icon(
                  Icons.color_lens,
                  color: Provider.of<MainProvider>(context).seedColor,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Accent Color'),
                        content: MaterialColorPicker(
                          selectedColor:
                              Provider.of<MainProvider>(context).seedColor,
                          onColorChange: (Color color) {
                            saveColor(color);
                          },
                        ),
                        actions: [
                          TextButton(
                            child: const Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            ListTile(
              title: Text(
                  'Sleep Timer Duration (${Provider.of<MainProvider>(context).sleepTimer.inMinutes}m)'),
              trailing: IconButton(
                icon: const Icon(Icons.nightlight),
                onPressed: () {
                  setSleepTimer(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Set Downloaded Music Directory'),
              trailing: IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  setDownloadedMusicDirectory(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Spotify API Keys'),
              trailing: IconButton(
                icon: const Icon(Icons.music_note),
                onPressed: () {
                  setSpotifyAPIKeys(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Reset Database'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  resetDatabase(context);
                },
              ),
            ),
          ],
        ));
  }
}
