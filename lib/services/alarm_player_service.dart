import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/alarm_track.dart';
import 'battery_service.dart';

class AlarmPlayerService extends ChangeNotifier {
  static AlarmPlayerService? _instance;
  static AlarmPlayerService get instance => _instance ??= AlarmPlayerService._();

  bool _isPlaying = false;
  AlarmTrack? _currentTrack;
  String? _errorMessage;

  bool get isPlaying => _isPlaying;
  AlarmTrack? get currentTrack => _currentTrack;
  String? get errorMessage => _errorMessage;

  AlarmPlayerService._() {
    BatteryService.instance.alarmTriggeredNotifier.addListener(() {
      final firing = BatteryService.instance.alarmTriggeredNotifier.value;
      if (_isPlaying != firing) {
        _isPlaying = firing;
        notifyListeners();
      }
    });
  }

  /// Triggers alarm playback with native service
  Future<void> triggerAlarm(AlarmTrack track, {double volume = 1.0}) async {
    _currentTrack = track;
    _errorMessage = null;
    _isPlaying = true;
    notifyListeners();

    await BatteryService.instance.triggerMusicPlayback(track.source, track.previewUrl);
  }

  /// Plays short preview of a track
  Future<void> playPreview(AlarmTrack track) async {
    _currentTrack = track;
    _isPlaying = true;
    notifyListeners();

    await BatteryService.instance.triggerMusicPlayback(track.source, track.previewUrl);
  }

  Future<void> stop() async {
    _isPlaying = false;
    _errorMessage = null;
    notifyListeners();

    await BatteryService.instance.stopAlarm();
  }
}
