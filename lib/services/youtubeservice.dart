import 'dart:io';
import 'package:audioplayer/services/spotifyservice.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;

Future<dynamic> downloadLink(String url, String dlDir, dynamic apiKeys,
    {String playlist = "Youtube"}) async {
  var client = YoutubeExplode();
  var video = await client.videos.get(url);
  var manifest = await client.videos.streamsClient.getManifest(url);
  var streamInfo = manifest.audioOnly
      .where((element) => element.audioCodec.contains('mp4a'))
      .last;
  var stream = client.videos.streamsClient.get(streamInfo);
  var sanitized = video.title.replaceAll(RegExp(r'\s+'), "_");
  var noTopicAuthor = video.author.replaceAll("- Topic", "").trim();
  var album = playlist.replaceAll("Album - ", "").trim();
  sanitized = sanitized.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), "").trim();
  var file = File(join(dlDir, "$sanitized.m4a"));
  var fileStream = file.openWrite();
  await stream.pipe(fileStream);

  var searchResult = await search("${video.title} - $noTopicAuthor", apiKeys);
  var result = {
    'name': video.title,
    'artist': noTopicAuthor,
    'album': searchResult != null ? searchResult['album'] : album,
    'image': searchResult != null ? searchResult['image'] : null,
    'path': file.path,
  };

  var picture = http.get(Uri.parse(result['image']));

  MetadataGod.writeMetadata(
      file: file.path,
      metadata: Metadata(
          artist: noTopicAuthor,
          title: video.title,
          album: searchResult != null ? searchResult['album'] : album,
          picture: Picture(
            mimeType: 'image/jpeg',
            data: await picture.then((value) => value.bodyBytes),
          )));
  await fileStream.flush();
  await fileStream.close();
  client.close();
  return result;
}
