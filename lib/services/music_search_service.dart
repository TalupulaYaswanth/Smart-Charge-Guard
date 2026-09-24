import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/alarm_track.dart';
import 'preferences_service.dart';

class MusicSearchService {
  static const String _itunesSearchUrl = 'https://itunes.apple.com/search';

  // Search songs using public high-fidelity preview endpoint (works immediately out of the box)
  static Future<List<AlarmTrack>> searchTracks(String query) async {
    final results = <AlarmTrack>[];
    if (query.trim().isEmpty) return results;

    // Check if user has Spotify credentials configured
    final spotifyId = PreferencesService.instance.spotifyClientId;
    final spotifySecret = PreferencesService.instance.spotifyClientSecret;

    if (spotifyId.isNotEmpty && spotifySecret.isNotEmpty) {
      try {
        final spotifyResults = await _searchSpotify(query, spotifyId, spotifySecret);
        if (spotifyResults.isNotEmpty) {
          return spotifyResults;
        }
      } catch (_) {
        // Fall back to public catalog search if Spotify fails or lacks preview_url
      }
    }

    // Default fast public audio preview search (no auth required, instant preview audio streams)
    try {
      final uri = Uri.parse('$_itunesSearchUrl?term=${Uri.encodeComponent(query)}&entity=song&limit=25');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List items = data['results'] ?? [];

        for (final item in items) {
          final previewUrl = item['previewUrl'] as String?;
          if (previewUrl != null && previewUrl.isNotEmpty) {
            results.add(
              AlarmTrack(
                id: item['trackId']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
                title: item['trackName'] ?? 'Unknown Track',
                artist: item['artistName'] ?? 'Unknown Artist',
                previewUrl: previewUrl,
                albumArtUrl: (item['artworkUrl100'] as String?)?.replaceAll('100x100bb', '300x300bb'),
                source: 'itunes',
              ),
            );
          }
        }
      }
    } catch (e) {
      // Return empty or fallback on network error
    }

    return results;
  }

  // Spotify Web API Search with Client Credentials Token Exchange
  static Future<List<AlarmTrack>> _searchSpotify(
    String query,
    String clientId,
    String clientSecret,
  ) async {
    final tokenUri = Uri.parse('https://accounts.spotify.com/api/token');
    final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));

    final tokenRes = await http.post(
      tokenUri,
      headers: {
        'Authorization': 'Basic $credentials',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    ).timeout(const Duration(seconds: 6));

    if (tokenRes.statusCode != 200) {
      throw Exception('Spotify auth failed');
    }

    final tokenData = json.decode(tokenRes.body);
    final accessToken = tokenData['access_token'] as String;

    final searchUri = Uri.parse(
      'https://api.spotify.com/v1/search?q=${Uri.encodeComponent(query)}&type=track&limit=20',
    );

    final searchRes = await http.get(
      searchUri,
      headers: {'Authorization': 'Bearer $accessToken'},
    ).timeout(const Duration(seconds: 6));

    final results = <AlarmTrack>[];
    if (searchRes.statusCode == 200) {
      final searchData = json.decode(searchRes.body);
      final tracks = searchData['tracks']?['items'] as List? ?? [];

      for (final t in tracks) {
        final previewUrl = t['preview_url'] as String?;
        // If preview_url is null (Spotify deprecated some 30s previews), use external URL or fallback
        final streamUrl = previewUrl ?? t['external_urls']?['spotify'] ?? '';
        final images = t['album']?['images'] as List? ?? [];
        final artUrl = images.isNotEmpty ? images[0]['url'] as String? : null;
        final artists = (t['artists'] as List? ?? [])
            .map((a) => a['name'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .join(', ');

        results.add(
          AlarmTrack(
            id: t['id'] ?? '',
            title: t['name'] ?? 'Unknown',
            artist: artists.isNotEmpty ? artists : 'Unknown Artist',
            previewUrl: streamUrl,
            albumArtUrl: artUrl,
            source: 'spotify',
          ),
        );
      }
    }
    return results;
  }
}
