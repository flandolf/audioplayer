import 'dart:async';
import 'dart:io';
import 'package:audioplayer/widgets/player.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../main.dart';
import '../services/youtubeservice.dart';

class Home extends StatefulWidget {
  final Database database;

  const Home(this.database, {Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Map<String, dynamic> nowPlaying = {};
  List<Map<String, dynamic>> allSongs = [];
  bool batchEdit = false;
  Map<String, bool> selectedFiles = {};
  bool currentlyDownloading = false;

  @override
  void initState() {
    super.initState();
    loadProviders();
    updatePlaylist();
    scanLibrary();
  }

  Future<void> loadProviders() async {
    print(await getDatabasesPath());
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? directory = prefs.getString('directory');
    final int? seedColor = prefs.getInt('seedColor');
    if (directory != null && seedColor != null && context.mounted) {
      Provider.of<MainProvider>(context, listen: false).dlMusicDir = directory;
      Provider.of<MainProvider>(context, listen: false).seedColor =
          Color(seedColor);
      Provider.of<MainProvider>(context, listen: false).isDarkMode =
          prefs.getBool('isDarkMode') ?? false;
    }
  }

  Future<void> updatePlaylist() async {
    final List<Map<String, dynamic>> files =
        await widget.database.query('files');

    setState(() {
      allSongs = files;
    });
  }

  Future<void> addToDB(dynamic data) async {
    var name = data['name'];
    var path = data['path'];
    var artist = data['artist'];
    var album = data['album'];
    await widget.database.insert(
      'files',
      {'name': name, 'path': path, 'artist': artist, 'album': album},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print("Added $name to database");
  }

  Future<void> addFile() async {
    FilePicker.platform
        .pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'flac'],
      allowMultiple: true,
    )
        .then((value) async {
      if (value == null) return;
      final files = value.files;
      for (final file in files) {
        final path = file.path!;
        Metadata metadata = await MetadataGod.readMetadata(file: path);
        await addToDB({
          'name': metadata.title ?? p.basename(path),
          'path': path,
          'artist': metadata.artist ?? 'Unknown',
          'album': metadata.album ?? 'Unknown',
        });
      }

      updatePlaylist();

      setState(() {});
    });
  }

  Future<void> addFolder() async {
    FilePicker.platform.getDirectoryPath().then((value) async {
      if (value == null) return;
      final directory = Directory(value);
      final files = directory.listSync(recursive: false);
      for (final file in files) {
        final path = file.path;
        if (!path.endsWith("mp3") ||
            !path.endsWith("m4a") ||
            !path.endsWith("flac")) return;
        print("Path: $path");
        Metadata metadata = await MetadataGod.readMetadata(file: path);
        await addToDB({
          'name': metadata.title ?? p.basename(path),
          'path': path,
          'artist': metadata.artist ?? 'Unknown',
          'album': metadata.album ?? 'Unknown',
        });
      }

      updatePlaylist();
      setState(() {});
    });
  }

  Future<void> addUrl(BuildContext context) async {
    final tEC = TextEditingController();
    await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, snapshot) {
          return AlertDialog(
            title: const Text("Add URL"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tEC,
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    labelText: 'URL',
                  ),
                  onSubmitted: (value) async {
                    var result = await downloadLink(
                        value,
                        Provider.of<MainProvider>(context, listen: false)
                            .dlMusicDir,
                        {
                          'client_id':
                              Provider.of<MainProvider>(context, listen: false)
                                  .spotifyClientId,
                          'client_secret':
                              Provider.of<MainProvider>(context, listen: false)
                                  .spotifyClientSecret,
                        });
                    await addToDB(result);
                    updatePlaylist();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  var result = await downloadLink(
                      tEC.value.text,
                      Provider.of<MainProvider>(context, listen: false)
                          .dlMusicDir,
                      {
                        'client_id':
                            Provider.of<MainProvider>(context, listen: false)
                                .spotifyClientId,
                        'client_secret':
                            Provider.of<MainProvider>(context, listen: false)
                                .spotifyClientSecret,
                      });
                  await addToDB(result);
                  updatePlaylist();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Submit'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> addPlaylistUrl(BuildContext context) async {
    final tEC = TextEditingController();
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Add Playlist"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    border: UnderlineInputBorder(),
                    labelText: 'URL',
                  ),
                  controller: tEC,
                  onSubmitted: (value) async {
                    setState(() {
                      currentlyDownloading = true;
                    });
                    await downloadPlaylist(tEC.value.text);
                    setState(() {
                      currentlyDownloading = false;
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  setState(() {
                    currentlyDownloading = true;
                  });
                  await downloadPlaylist(tEC.value.text)
                      .then((value) => setState(() {
                            currentlyDownloading = false;
                          }));
                  setState(() {
                    currentlyDownloading = false;
                  });
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Submit'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        });
  }

  Future<void> downloadPlaylist(String value) async {
    var playlist = await YoutubeExplode().playlists.get(value);
    var playlistName = playlist.title;

    var videos = YoutubeExplode().playlists.getVideos(playlist.id);
    var videosList = await videos.toList();
    for (var video in videosList) {
      downloadLink(video.url,
          Provider.of<MainProvider>(context, listen: false).dlMusicDir, {
        'client_id':
            Provider.of<MainProvider>(context, listen: false).spotifyClientId,
        'client_secret': Provider.of<MainProvider>(context, listen: false)
            .spotifyClientSecret,
        playlist: playlistName,
      });
    }
    updatePlaylist();
  }

  Future<void> scanLibrary() async {
    final files = await widget.database.query('files');
    for (var element in files) {
      String path = element['path'] as String;
      if (!File(path).existsSync()) {
        widget.database.delete(
          'files',
          where: 'id = ?',
          whereArgs: [element['id']],
        );
      }
      setState(() {});
    }
  }

  Future<void> batchEditDialog(BuildContext context) async {
    final TextEditingController nTC = TextEditingController();
    final TextEditingController arTC = TextEditingController();
    final TextEditingController alTC = TextEditingController();
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Batch Edit"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nTC,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                  ),
                ),
                TextField(
                  controller: arTC,
                  decoration: const InputDecoration(
                    labelText: 'Artist',
                  ),
                ),
                TextField(
                  controller: alTC,
                  decoration: const InputDecoration(
                    labelText: 'Album',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  for (var element in selectedFiles.keys) {
                    if (nTC.text.isNotEmpty) {
                      widget.database.update(
                        'files',
                        {'name': nTC.text},
                        where: 'path = ?',
                        whereArgs: [element],
                      );
                      MetadataGod.writeMetadata(
                          file: element,
                          metadata: Metadata(
                            title: nTC.text,
                          ));
                    }
                    if (arTC.text.isNotEmpty) {
                      widget.database.update(
                        'files',
                        {'artist': arTC.text},
                        where: 'path = ?',
                        whereArgs: [element],
                      );
                      MetadataGod.writeMetadata(
                          file: element,
                          metadata: Metadata(
                            artist: arTC.text,
                          ));
                    }
                    if (alTC.text.isNotEmpty) {
                      widget.database.update(
                        'files',
                        {'album': alTC.text},
                        where: 'path = ?',
                        whereArgs: [element],
                      );
                      MetadataGod.writeMetadata(
                          file: element,
                          metadata: Metadata(
                            album: alTC.text,
                          ));
                    }
                  }
                  updatePlaylist();
                  setState(() {
                    batchEdit = false;
                    selectedFiles = {};
                  });
                  Navigator.pop(context);
                },
                child: const Text('Submit'),
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              scanLibrary();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Scan Library',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: addFile,
            tooltip: 'Add File',
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: addFolder,
            tooltip: 'Add Folder',
          ),
          IconButton(
            onPressed: () {
              addUrl(context);
            },
            icon: const Icon(Icons.link),
            tooltip: 'Add URL',
          ),
          IconButton(
              onPressed: () {
                addPlaylistUrl(context);
              },
              icon: const Icon(Icons.list),
              tooltip: 'Add Playlist'),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              setState(() {
                if (batchEdit) {
                  batchEdit = false;
                  selectedFiles = {};
                } else {
                  batchEdit = true;
                }
              });
            },
            tooltip: 'Batch Edit',
          ),
        ],
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Audio Player',
                style: TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(
              width: 10,
            ),
            if (currentlyDownloading)
              const SizedBox(
                  width: 15, height: 15, child: CircularProgressIndicator())
            else
              Text(
                Provider.of<MainProvider>(context).dlMusicDir,
                style: const TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (batchEdit)
            FutureBuilder(
                future: widget.database.query('files'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else {
                    final files = snapshot.data!;
                    return Row(
                      children: [
                        const SizedBox(
                          width: 10,
                        ),
                        FilledButton(
                            onPressed: () {
                              selectedFiles = files.fold<Map<String, bool>>({},
                                  (previousValue, element) {
                                previousValue[element['path'].toString()] =
                                    true;
                                return previousValue;
                              });
                              setState(() {});
                            },
                            child: const Text("Select All")),
                        const SizedBox(
                          width: 10,
                        ),
                        FilledButton(
                            onPressed: () {
                              batchEditDialog(context);
                              setState(() {});
                            },
                            child: const Text("Edit")),
                        const SizedBox(
                          width: 10,
                        ),
                        FilledButton(
                            onPressed: () {
                              for (var element in selectedFiles.keys) {
                                widget.database.delete(
                                  'files',
                                  where: 'path = ?',
                                  whereArgs: [element],
                                );
                                File(element).deleteSync();
                              }
                              setState(() {});
                            },
                            child: const Text("Delete"))
                      ],
                    );
                  }
                })
          else
            const SizedBox.shrink(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: widget.database.query('files'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  final files = snapshot.data!;
                  if (files.isEmpty) {
                    return const Center(child: Text('No songs found'));
                  } else if (batchEdit) {
                    return ListView.builder(
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index];
                        return ListTile(
                          title: Text(file['name']),
                          leading: Checkbox(
                            value:
                                selectedFiles[file['path'].toString()] ?? false,
                            onChanged: (value) async {
                              if (value!) {
                                selectedFiles[file['path'].toString()] = true;
                              } else {
                                selectedFiles.remove(file['path'].toString());
                              }
                              setState(() {});
                            },
                          ),
                          subtitle:
                              Text("${file['artist']} - ${file['album']}"),
                          trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                final nameTextController =
                                    TextEditingController(text: file['name']);
                                final artistTextController =
                                    TextEditingController(text: file['artist']);
                                final albumTextController =
                                    TextEditingController(text: file['album']);
                                if (context.mounted) {
                                  showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: Text("Edit ${file['name']}"),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Name',
                                                ),
                                                controller: nameTextController,
                                              ),
                                              TextField(
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Artist',
                                                ),
                                                controller:
                                                    artistTextController,
                                              ),
                                              TextField(
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Album',
                                                ),
                                                controller: albumTextController,
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                                onPressed: () {
                                                  albumTextController.dispose();
                                                  artistTextController
                                                      .dispose();
                                                  nameTextController.dispose();
                                                  if (context.mounted) {
                                                    Navigator.pop(context);
                                                  }
                                                },
                                                child: const Text("Cancel")),
                                            TextButton(
                                                onPressed: () async {
                                                  await widget.database.delete(
                                                    'files',
                                                    where: 'id = ?',
                                                    whereArgs: [file['id']],
                                                  );
                                                  setState(() {});
                                                  albumTextController.dispose();
                                                  artistTextController
                                                      .dispose();
                                                  nameTextController.dispose();
                                                  if (context.mounted) {
                                                    Navigator.pop(context);
                                                  }
                                                },
                                                child: const Text("Delete")),
                                            TextButton(
                                                onPressed: () async {
                                                  // Edit database
                                                  await widget.database.update(
                                                    'files',
                                                    {
                                                      'name': nameTextController
                                                          .text,
                                                      'artist':
                                                          artistTextController
                                                              .text,
                                                      'album':
                                                          albumTextController
                                                              .text,
                                                    },
                                                    where: 'id = ?',
                                                    whereArgs: [file['id']],
                                                  );
                                                  updatePlaylist();
                                                  setState(() {});
                                                  albumTextController.dispose();
                                                  artistTextController
                                                      .dispose();
                                                  nameTextController.dispose();
                                                  if (context.mounted) {
                                                    Navigator.pop(context);
                                                  }
                                                },
                                                child: const Text("Submit")),
                                          ],
                                        );
                                      });
                                }
                              }),
                          onTap: () {
                            setState(() {
                              nowPlaying = {
                                'path': file['path'],
                                'name': file['name'],
                                'artist': file['artist'],
                                'album': file['album'],
                              };
                            });
                          },
                        );
                      },
                    );
                  } else {
                    return ListView.builder(
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index];
                        return ListTile(
                          title: Text(file['name']),
                          subtitle:
                              Text("${file['artist']} - ${file['album']}"),
                          trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                final nameTextController =
                                    TextEditingController(text: file['name']);
                                final artistTextController =
                                    TextEditingController(text: file['artist']);
                                final albumTextController =
                                    TextEditingController(text: file['album']);
                                if (context.mounted) {
                                  showDialog(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: Text("Edit ${file['name']}"),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextField(
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Name',
                                                ),
                                                controller: nameTextController,
                                              ),
                                              TextField(
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Artist',
                                                ),
                                                controller:
                                                    artistTextController,
                                              ),
                                              TextField(
                                                decoration:
                                                    const InputDecoration(
                                                  labelText: 'Album',
                                                ),
                                                controller: albumTextController,
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                                onPressed: () {
                                                  albumTextController.dispose();
                                                  artistTextController
                                                      .dispose();
                                                  nameTextController.dispose();
                                                  if (context.mounted) {
                                                    Navigator.pop(context);
                                                  }
                                                },
                                                child: const Text("Cancel")),
                                            TextButton(
                                                onPressed: () async {
                                                  await widget.database.delete(
                                                    'files',
                                                    where: 'id = ?',
                                                    whereArgs: [file['id']],
                                                  );
                                                  setState(() {});
                                                  albumTextController.dispose();
                                                  artistTextController
                                                      .dispose();
                                                  nameTextController.dispose();
                                                  if (context.mounted) {
                                                    Navigator.pop(context);
                                                  }
                                                },
                                                child: const Text("Delete")),
                                            TextButton(
                                                onPressed: () async {
                                                  // Edit database
                                                  await widget.database.update(
                                                    'files',
                                                    {
                                                      'name': nameTextController
                                                          .text,
                                                      'artist':
                                                          artistTextController
                                                              .text,
                                                      'album':
                                                          albumTextController
                                                              .text,
                                                    },
                                                    where: 'id = ?',
                                                    whereArgs: [file['id']],
                                                  );
                                                  MetadataGod.writeMetadata(
                                                      file: file['path'],
                                                      metadata: Metadata(
                                                        title:
                                                            nameTextController
                                                                .text,
                                                        artist:
                                                            artistTextController
                                                                .text,
                                                        album:
                                                            albumTextController
                                                                .text,
                                                      ));
                                                  updatePlaylist();
                                                  setState(() {});
                                                  albumTextController.dispose();
                                                  artistTextController
                                                      .dispose();
                                                  nameTextController.dispose();
                                                  if (context.mounted) {
                                                    Navigator.pop(context);
                                                  }
                                                },
                                                child: const Text("Submit")),
                                          ],
                                        );
                                      });
                                }
                              }),
                          onTap: () {
                            setState(() {
                              nowPlaying = {
                                'path': file['path'],
                                'name': file['name'],
                                'artist': file['artist'],
                                'album': file['album'],
                              };
                            });
                          },
                        );
                      },
                    );
                  }
                }
              },
            ),
          ),
          PlayerWidget(allSongs: allSongs, nowPlaying: nowPlaying)
        ],
      ),
    );
  }
}
