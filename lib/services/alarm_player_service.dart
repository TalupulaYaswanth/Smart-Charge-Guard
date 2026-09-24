import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/alarm_track.dart';

class AlarmPlayerService extends ChangeNotifier {
  static AlarmPlayerService? _instance;
  static AlarmPlayerService get instance => _instance ??= AlarmPlayerService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  AlarmTrack? _currentTrack;
  String? _errorMessage;

  bool get isPlaying => _isPlaying;
  AlarmTrack? get currentTrack => _currentTrack;
  String? get errorMessage => _errorMessage;

  AlarmPlayerService._() {
    _player.onPlayerStateChanged.listen((state) {
      final playing = state == PlayerState.playing;
      if (_isPlaying != playing) {
        _isPlaying = playing;
        notifyListeners();
      }
    });

    _player.onPlayerComplete.listen((_) {
      // If single-shot preview finishes
      if (!_isPlaying) {
        notifyListeners();
      }
    });
  }

  /// Triggers full alarm playback with infinite loop until dismissed
  Future<void> triggerAlarm(AlarmTrack track, {double volume = 1.0}) async {
    _currentTrack = track;
    _errorMessage = null;

    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(volume);

      if (track.previewUrl.startsWith('http://') || track.previewUrl.startsWith('https://')) {
        await _player.play(UrlSource(track.previewUrl));
      } else if (track.previewUrl.startsWith('asset://')) {
        final path = track.previewUrl.replaceFirst('asset://', '').replaceFirst('assets/', '');
        await _player.play(AssetSource(path));
      } else {
        // Fallback default
        await _playFallback();
      }
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing primary audio alarm: $e. Falling back to local chime.');
      _errorMessage = 'Online track unreachable. Fallback alarm playing.';
      await _playFallback();
    }
  }

  /// Plays a short 10-second test preview of a track without looping
  Future<void> playPreview(AlarmTrack track) async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.setVolume(0.8);

      if (track.previewUrl.startsWith('http')) {
        await _player.play(UrlSource(track.previewUrl));
      } else {
        await _playFallback();
      }
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      await _playFallback();
    }
  }

  Future<void> _playFallback() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/alarm_chime.wav'));
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to play asset fallback: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping player: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
