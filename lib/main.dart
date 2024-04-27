import 'package:audioplayer/screens/home.dart';
import 'package:audioplayer/screens/onboarding.dart';
import 'package:audioplayer/screens/settings.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Color sC = Colors.blue;
bool onboarding = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  MetadataGod.initialize();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1400, 1000),
    center: true,
    title: 'Audio Player',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  Database db;

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  db = await databaseFactory.openDatabase(
      join(await databaseFactoryFfi.getDatabasesPath(), 'audio_player.db'),
      options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            onboarding = true;
            db.execute(
              'CREATE TABLE files(id INTEGER PRIMARY KEY, name TEXT, path TEXT, artist TEXT, album TEXT)',
            );
            db.execute(
              'CREATE TABLE settings(id INTEGER PRIMARY KEY, key TEXT, value TEXT)',
            );
          }));

  await db.query('settings', where: 'key = ?', whereArgs: ['dlMusicDir']).then((value) {
    if (value.isNotEmpty) {
      onboarding = false;
    } else {
      onboarding = true;
    }
  });


  runApp(
    ChangeNotifierProvider(
      create: (_) => MainProvider(),
      child: MyApp(db),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Database database;

  const MyApp(this.database, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Audio Player',
      theme: ThemeData(
        colorSchemeSeed: Provider.of<MainProvider>(context).seedColor,
        brightness: Provider.of<MainProvider>(context).isDarkMode
            ? Brightness.dark
            : Brightness.light,
        useMaterial3: true,
      ),
      routes: {
        '/settings': (context) => Settings(database),
        '/home': (context) => Home(database),
        '/onboarding': (context) => OnboardingPage(database)
      },
      home: onboarding
          ? OnboardingPage(database)
          : Home(
              database,
            ),
    );
  }
}

class MainProvider extends ChangeNotifier {
  bool _isDarkMode = true;
  Color _seedColor = sC;
  String _dlMusicDir = "";
  Duration _sleepTimerDuration = const Duration(hours: 1);
  String _spotifyClientId = "";
  String _spotifyClientSecret = "";

  bool get isDarkMode => _isDarkMode;

  Color get seedColor => _seedColor;

  String get dlMusicDir => _dlMusicDir;

  Duration get sleepTimer => _sleepTimerDuration;

  String get spotifyClientId => _spotifyClientId;

  String get spotifyClientSecret => _spotifyClientSecret;

  set spotifyClientId(String id) {
    _spotifyClientId = id;
    notifyListeners();
  }

  set spotifyClientSecret(String secret) {
    _spotifyClientSecret = secret;
    notifyListeners();
  }

  set dlMusicDir(String dir) {
    _dlMusicDir = dir;
    notifyListeners();
  }

  set sleepTimer(Duration duration) {
    _sleepTimerDuration = duration;
    notifyListeners();
  }

  set seedColor(Color color) {
    _seedColor = color;
    notifyListeners();
  }

  set isDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }
}
