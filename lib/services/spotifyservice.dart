import 'dart:convert';
import 'dart:io';
import 'dart:async'; // Import the async library
import 'package:http/http.dart' as http;

String? accessToken;
DateTime? tokenExpirationTime;

Future<String> getAccessToken(dynamic apiKeys) async {
  if (accessToken != null && tokenExpirationTime != null && DateTime.now().isBefore(tokenExpirationTime!)) {
    return accessToken!;
  }

  var url = Uri.https('accounts.spotify.com', '/api/token');
  var res = await http.post(url, body: {
    'grant_type': 'client_credentials',
    'client_id': apiKeys['client_id'],
    'client_secret': apiKeys['client_secret'],
  });

  var jsonRes = jsonDecode(res.body);
  accessToken = jsonRes['access_token'];
  int expiresIn = jsonRes['expires_in'];
  tokenExpirationTime = DateTime.now().add(Duration(seconds: expiresIn));

  return accessToken!;
}

Future<dynamic>search(String query, dynamic apiKeys) async {
  String token = await getAccessToken(apiKeys);
  var url = Uri.https('api.spotify.com', '/v1/search', {
    'q': query,
    'type': 'track',
    'limit': '1',
  });
  var res = await http.get(url, headers: {
    HttpHeaders.authorizationHeader: 'Bearer $token',
  });
  var json = jsonDecode(res.body);
  return {
    'name': json['tracks']['items'][0]['name'],
    'artist': json['tracks']['items'][0]['artists'][0]['name'],
    'album': json['tracks']['items'][0]['album']['name'],
    'image': json['tracks']['items'][0]['album']['images'][0]['url'],
  };
}