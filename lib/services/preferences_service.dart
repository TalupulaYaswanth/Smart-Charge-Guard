import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm_track.dart';

class PreferencesService {
  static const String _keyAlarmEnabled = 'alarm_enabled';
  static const String _keyTargetPercentage = 'target_percentage';
  static const String _keySelectedTrack = 'selected_track';
  static const String _keyVolume = 'alarm_volume';
  static const String _keyVibrate = 'alarm_vibrate';
  static const String _keySpotifyClientId = 'spotify_client_id';
  static const String _keySpotifyClientSecret = 'spotify_client_secret';

  static PreferencesService? _instance;
  static PreferencesService get instance => _instance ??= PreferencesService._();
  PreferencesService._();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  bool get isAlarmEnabled => _prefs.getBool(_keyAlarmEnabled) ?? true;
  Future<void> setAlarmEnabled(bool value) async {
    await _prefs.setBool(_keyAlarmEnabled, value);
  }

  int get targetPercentage => _prefs.getInt(_keyTargetPercentage) ?? 80;
  Future<void> setTargetPercentage(int value) async {
    await _prefs.setInt(_keyTargetPercentage, value);
  }

  double get volume => _prefs.getDouble(_keyVolume) ?? 1.0;
  Future<void> setVolume(double value) async {
    await _prefs.setDouble(_keyVolume, value);
  }

  bool get vibrateEnabled => _prefs.getBool(_keyVibrate) ?? true;
  Future<void> setVibrateEnabled(bool value) async {
    await _prefs.setBool(_keyVibrate, value);
  }

  AlarmTrack get selectedTrack {
    final raw = _prefs.getString(_keySelectedTrack);
    if (raw != null && raw.isNotEmpty) {
      try {
        return AlarmTrack.fromJson(raw);
      } catch (_) {
        return AlarmTrack.defaultTrack;
      }
    }
    return AlarmTrack.defaultTrack;
  }

  Future<void> setSelectedTrack(AlarmTrack track) async {
    await _prefs.setString(_keySelectedTrack, track.toJson());
  }

  String get spotifyClientId => _prefs.getString(_keySpotifyClientId) ?? '';
  Future<void> setSpotifyClientId(String id) async {
    await _prefs.setString(_keySpotifyClientId, id);
  }

  String get spotifyClientSecret => _prefs.getString(_keySpotifyClientSecret) ?? '';
  Future<void> setSpotifyClientSecret(String secret) async {
    await _prefs.setString(_keySpotifyClientSecret, secret);
  }
}
