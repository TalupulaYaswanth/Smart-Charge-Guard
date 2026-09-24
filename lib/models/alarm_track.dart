import 'dart:convert';

class AlarmTrack {
  final String id;
  final String title;
  final String artist;
  final String previewUrl;
  final String? albumArtUrl;
  final String source; // 'spotify', 'itunes', 'custom', 'fallback'

  const AlarmTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.previewUrl,
    this.albumArtUrl,
    this.source = 'custom',
  });

  static const AlarmTrack defaultTrack = AlarmTrack(
    id: 'default_chime',
    title: 'Crystal Chime Alert',
    artist: 'ChargeAlarm Built-in Tone',
    previewUrl: 'asset://assets/sounds/alarm_chime.wav',
    albumArtUrl: null,
    source: 'fallback',
  );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'previewUrl': previewUrl,
      'albumArtUrl': albumArtUrl,
      'source': source,
    };
  }

  factory AlarmTrack.fromMap(Map<String, dynamic> map) {
    return AlarmTrack(
      id: map['id'] ?? 'default_chime',
      title: map['title'] ?? 'Default Alarm',
      artist: map['artist'] ?? 'System',
      previewUrl: map['previewUrl'] ?? 'asset://assets/sounds/alarm_chime.wav',
      albumArtUrl: map['albumArtUrl'],
      source: map['source'] ?? 'fallback',
    );
  }

  String toJson() => json.encode(toMap());

  factory AlarmTrack.fromJson(String source) =>
      AlarmTrack.fromMap(json.decode(source));
}
