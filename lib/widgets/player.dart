import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import '../main.dart';

class PlayerWidget extends StatefulWidget {
  final List<Map<String, dynamic>> allSongs;
  final Map<String, dynamic> nowPlaying;

  const PlayerWidget({
    required this.allSongs,
    required this.nowPlaying,
    Key? key,
  }) : super(key: key);

  @override
  State<PlayerWidget> createState() => _PlayerWidgetState();
}

class _PlayerWidgetState extends State<PlayerWidget> {
  late final player = Player();
  bool isShuffle = false;
  String nowPlayingName = 'No song playing';
  String nowPlayingArtist = "Unknown";
  String nowPlayingAlbum = "Unknown";
  bool sleepTimer = false;
  int sleepTimerSeconds = 0;
  Timer? sleepTimerTimer;

  @override
  void didUpdateWidget(covariant PlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nowPlaying != widget.nowPlaying) {
      Playlist playlist = Playlist(
        widget.allSongs
            .map((e) => Media(e['path'], extras: {'title': e['name']}))
            .toList(),
        index: widget.allSongs.indexWhere(
          (element) => element['path'] == widget.nowPlaying['path'],
        ),
      );
      player.open(playlist, play: true);
      player.play();
      player.stream.playlist.listen((event) {
        setState(() {
          nowPlayingName = widget.allSongs[player.state.playlist.index]['name'];
          nowPlayingArtist =
              widget.allSongs[player.state.playlist.index]['artist'];
          nowPlayingAlbum =
              widget.allSongs[player.state.playlist.index]['album'];
        });
      });
    }
  }

  void setSleepTimer(int seconds) {
    sleepTimer = true;
    sleepTimerSeconds = seconds;
    sleepTimerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (sleepTimerSeconds == 0) {
        player.pause();
        sleepTimerTimer?.cancel();
        sleepTimer = false;
      } else {
        sleepTimerSeconds--;
      }
      setState(() {});
    });
  }

  static String formatDuration(Duration d) {
    var seconds = d.inSeconds;
    final days = seconds ~/ Duration.secondsPerDay;
    seconds -= days * Duration.secondsPerDay;
    final hours = seconds ~/ Duration.secondsPerHour;
    seconds -= hours * Duration.secondsPerHour;
    final minutes = seconds ~/ Duration.secondsPerMinute;
    seconds -= minutes * Duration.secondsPerMinute;

    final List<String> tokens = [];
    if (days != 0) {
      tokens.add('${days}d');
    }
    if (tokens.isNotEmpty || hours != 0) {
      tokens.add('${hours}h');
    }
    if (tokens.isNotEmpty || minutes != 0) {
      tokens.add('${minutes}m');
    }
    tokens.add('${seconds}s');

    return tokens.join(':');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(
            height: 10,
          ),
          StreamBuilder(
            stream: player.stream.position,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              Duration position = snapshot.data ?? Duration.zero;

              // Ensure that the position is not negative
              position = Duration(
                  milliseconds: position.inMilliseconds
                      .clamp(0, player.state.duration.inMilliseconds));

              return Column(
                children: [
                  Text(nowPlayingName, style: const TextStyle(fontSize: 20)),
                  Text("$nowPlayingArtist - $nowPlayingAlbum",
                      style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(position)),
                      Expanded(
                        child: Slider(
                          value: position.inMilliseconds.toDouble(),
                          max: player.state.duration.inMilliseconds.toDouble(),
                          onChanged: (value) {},
                          onChangeEnd: (value) {
                            player.seek(Duration(milliseconds: value.toInt()));
                            setState(() {});
                          },
                        ),
                      ),
                      Text(formatDuration(player.state.duration)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Slider(
                              value: player.state.volume,
                              label: player.state.volume.toString(),
                              onChanged: (e) {
                                player.setVolume(e);
                                setState(() {});
                              },
                              min: 0,
                              max: 100),
                          IconButton(
                              onPressed: () {
                                player.state.volume == 0
                                    ? player.setVolume(100)
                                    : player.setVolume(0);
                                setState(() {});
                              },
                              icon: Icon(player.state.volume == 0
                                  ? Icons.volume_off
                                  : Icons.volume_up)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // IconButton(
                          //   onPressed: () {
                          //     setState(() {
                          //       isShuffle = !isShuffle;
                          //     });
                          //   },
                          //   icon: Icon(
                          //     isShuffle? Icons.shuffle_on : Icons.shuffle,
                          //   ),
                          // ),
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            onPressed: () {
                              player.previous();
                              setState(() {});
                            },
                          ),
                          StreamBuilder(
                              stream: player.stream.playing,
                              builder: (context, snapshot) {
                                return IconButton(
                                  icon: Icon(
                                    player.state.playing
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    size: 45,
                                  ),
                                  onPressed: () {
                                    // Toggle play/pause functionality
                                    if (player.state.playing) {
                                      player.pause();
                                    } else {
                                      player.play();
                                    }
                                    setState(() {});
                                  },
                                );
                              }),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            onPressed: () {
                              player.next();
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              player.state.rate == 1
                                  ? player.setRate(1.5)
                                  : player.setRate(1);
                              setState(() {});
                            },
                            icon: const Icon(Icons.speed),
                          ),
                          Slider(
                              value: player.state.rate,
                              label: "${player.state.rate.toStringAsFixed(2)}x",
                              onChanged: (e) {
                                player.setRate(e);
                                setState(() {});
                              },
                              min: 0,
                              max: 2),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      StreamBuilder(
                          stream: player.stream.playlistMode,
                          builder: (context, snapshot) {
                            return IconButton(
                                onPressed: () {
                                  if (player.state.playlistMode ==
                                      PlaylistMode.loop) {
                                    player.setPlaylistMode(PlaylistMode.single);
                                  } else if (player.state.playlistMode ==
                                      PlaylistMode.single) {
                                    player.setPlaylistMode(PlaylistMode.none);
                                  } else {
                                    player.setPlaylistMode(PlaylistMode.loop);
                                  }
                                  setState(() {});
                                },
                                icon: player.state.playlistMode ==
                                        PlaylistMode.loop
                                    ? const Icon(Icons.repeat_on)
                                    : player.state.playlistMode ==
                                            PlaylistMode.single
                                        ? const Icon(Icons.repeat_one)
                                        : const Icon(Icons.repeat));
                          }),
                      FilledButton(
                          onPressed: () {
                            if (sleepTimer) {
                              sleepTimerTimer?.cancel();
                              sleepTimer = false;
                              sleepTimerSeconds = 0;
                            } else {
                              setSleepTimer(Provider.of<MainProvider>(context,
                                      listen: false)
                                  .sleepTimer
                                  .inSeconds);
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.nightlight),
                                  const SizedBox(width: 5),
                                  Text(
                                      'Sleep Timer ${sleepTimer ? formatDuration(Duration(seconds: sleepTimerSeconds)) : 'Off'}'),
                                ],
                              ),
                            ],
                          )),
                    ],
                  )
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
