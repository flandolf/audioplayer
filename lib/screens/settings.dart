import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_material_color_picker/flutter_material_color_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../main.dart';

class Settings extends StatefulWidget {
  final Database database;

  const Settings(this.database, {super.key});

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
    getSpotifyCreds();
    getDirectory();
  }

  String directory = '';

  Future<void> getDirectory() async {
    widget.database.query('settings').then((value) {
      for (final element in value) {
        if (element['key'] == 'dlMusicDir') {
          directory = element['value'].toString();
          diC.text = directory;
          if (context.mounted) {
            Provider.of<MainProvider>(context, listen: false).dlMusicDir =
                directory;
          }
        }
      }
    });
  }

  Future<void> getSpotifyCreds() async {
    widget.database.query('settings').then((value) {
      for (final element in value) {
        if (element['key'] == 'spotifyClientId') {
          ciC.text = element['value'].toString();
          if (context.mounted) {
            Provider.of<MainProvider>(context, listen: false).spotifyClientId =
                ciC.text;
          }
        } else if (element['key'] == 'spotifyClientSecret') {
          csC.text = element['value'].toString();
          if (context.mounted) {
            Provider.of<MainProvider>(context, listen: false)
                .spotifyClientSecret = csC.text;
          }
        }
      }
    });
  }

  Future<void> saveDirectory(String directory) async {
    if (context.mounted) {
      Provider.of<MainProvider>(context, listen: false).dlMusicDir = directory;
    }
    await widget.database.delete('settings', where: 'key = "dlMusicDir"');
    await widget.database
        .insert('settings', {'key': 'dlMusicDir', 'value': directory});
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
                  await database.execute('DROP TABLE settings');
                  await database.execute(
                    'CREATE TABLE settings(id INTEGER PRIMARY KEY, key TEXT, value TEXT)',
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed("/onboarding");
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
                  if (!context.mounted) return;
                  Provider.of<MainProvider>(context, listen: false)
                      .spotifyClientId = ciC.text;
                  Provider.of<MainProvider>(context, listen: false)
                      .spotifyClientSecret = csC.text;

                  // Save to database
                  await widget.database
                      .delete('settings', where: 'key = "spotifyClientId"');
                  await widget.database
                      .delete('settings', where: 'key = "spotifyClientSecret"');

                  await widget.database.insert('settings', {
                    'key': 'spotifyClientId',
                    'value': ciC.text,
                  });

                  await widget.database.insert('settings', {
                    'key': 'spotifyClientSecret',
                    'value': csC.text,
                  });

                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  Future<void> saveColor(Color color) async {
    await widget.database.delete('settings', where: 'key = "accentColor"');
    await widget.database.insert('settings', {
      'key': 'accentColor',
      'value': color.value.toString(),
    });
    if (context.mounted) {
      BuildContext c = context;
      Provider.of<MainProvider>(c, listen: false).seedColor = color;
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
                  widget.database.delete('settings', where: 'key = "darkMode"');
                  widget.database.insert('settings', {
                    'key': 'darkMode',
                    'value': value ? 'true' : 'false',
                  });
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
            ListTile(
              title: const Text('Read values from database'),
              trailing: IconButton(
                icon: const Icon(Icons.mark_chat_read_rounded),
                onPressed: () {
                  var data = [];
                  widget.database.query('settings').then((value) {
                    for (final element in value) {
                      data.add(element);
                    }
                  });
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Values in database'),
                        content: Text(data.toString()),
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
          ],
        ));
  }
}
