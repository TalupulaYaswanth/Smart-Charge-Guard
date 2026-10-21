import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'models/alarm_track.dart';
import 'screens/track_selector_modal.dart';
import 'screens/security_modal.dart';
import 'services/battery_service.dart';
import 'services/preferences_service.dart';
import 'services/security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Modern transparent system bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F172A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await PreferencesService.instance.init();
  await SecurityService.instance.initialize();

  final batteryService = BatteryService.instance;
  await batteryService.initialize();

  runApp(const ChargeAlarmApp());
}

class ChargeAlarmApp extends StatelessWidget {
  const ChargeAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChargeAlarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F19),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E676),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF161F33),
          background: Color(0xFF0B0F19),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final BatteryService _batteryService = BatteryService.instance;
  final TextEditingController _uriController = TextEditingController();

  String _selectedPlatform = 'Search Songs';
  String _selectedSongTitle = 'Crystal Chime Alert';
  String _selectedSongArtist = 'Built-in Tone';
  String? _selectedSongArtwork;
  int _targetPercentage = 80;
  bool _isProtectionActive = true;
  bool _isSharingApk = false;
  bool _isBatteryOptimizationIgnored = false;
  bool _isSpotifyInstalled = false;
  bool _isJioSaavnInstalled = false;
  bool _isYtMusicInstalled = false;

  final List<String> _platforms = [
    'Search Songs',
    'Spotify',
    'JioSaavn',
    'YouTube Music',
    'Default Ringtone/URL'
  ];
  final List<int> _targetOptions = [70, 75, 80, 85, 90, 100];

  static const MethodChannel _apkChannel = MethodChannel('com.chargealarm.app/apk_share');

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final isIgnoring = await _batteryService.isIgnoringBatteryOptimizations();
    final isSpotify = await _batteryService.isAppInstalled('com.spotify.music');
    final isJioSaavn = await _batteryService.isAppInstalled('com.jiosaavn.android');
    final isYtMusic = await _batteryService.isAppInstalled('com.google.android.apps.youtube.music');

    setState(() {
      _selectedPlatform = prefs.getString('music_platform') ?? 'Search Songs';
      _uriController.text = prefs.getString('music_uri') ?? '';
      _selectedSongTitle = prefs.getString('selected_song_title') ?? 'Crystal Chime Alert';
      _selectedSongArtist = prefs.getString('selected_song_artist') ?? 'Built-in Tone';
      _selectedSongArtwork = prefs.getString('selected_song_artwork');
      _targetPercentage = prefs.getInt('target_percentage') ?? 80;
      _isProtectionActive = prefs.getBool('alarm_protection_enabled') ?? true;
      _isBatteryOptimizationIgnored = isIgnoring;
      _isSpotifyInstalled = isSpotify;
      _isJioSaavnInstalled = isJioSaavn;
      _isYtMusicInstalled = isYtMusic;
    });

    _batteryService.setProtectionActive(_isProtectionActive);
  }

  Future<void> _savePreferences({bool showFeedback = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('music_platform', _selectedPlatform);
    await prefs.setString('music_uri', _uriController.text.trim());
    await prefs.setInt('target_percentage', _targetPercentage);
    await prefs.setString('selected_song_title', _selectedSongTitle);
    await prefs.setString('selected_song_artist', _selectedSongArtist);
    if (_selectedSongArtwork != null) {
      await prefs.setString('selected_song_artwork', _selectedSongArtwork!);
    }

    await _batteryService.updateConfig(
      targetLevel: _targetPercentage,
      musicPlatform: _selectedPlatform,
      musicUri: _uriController.text.trim(),
    );

    if (showFeedback && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $_selectedPlatform config updated!'),
          backgroundColor: const Color(0xFF00E676),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onPlatformSelected(String platform) async {
    setState(() {
      _selectedPlatform = platform;
      if (platform == 'Spotify') {
        if (_uriController.text.contains('itunes') || _uriController.text.contains('saavn')) {
          _uriController.text = '';
        }
        _selectedSongTitle = 'Spotify Music Alarm';
        _selectedSongArtist = 'Opens Spotify & Plays Track';
        _selectedSongArtwork = null;
      } else if (platform == 'JioSaavn') {
        if (_uriController.text.contains('itunes') || _uriController.text.contains('spotify')) {
          _uriController.text = '';
        }
        _selectedSongTitle = 'JioSaavn Music Alarm';
        _selectedSongArtist = 'Opens JioSaavn & Plays Track';
        _selectedSongArtwork = null;
      } else if (platform == 'YouTube Music') {
        if (_uriController.text.contains('itunes') || _uriController.text.contains('spotify')) {
          _uriController.text = '';
        }
        _selectedSongTitle = 'YouTube Music Alarm';
        _selectedSongArtist = 'Opens YouTube Music & Plays Track';
        _selectedSongArtwork = null;
      } else if (platform == 'Default Ringtone/URL') {
        if (_uriController.text.contains('itunes') || _uriController.text.contains('spotify')) {
          _uriController.text = '';
        }
        _selectedSongTitle = 'Crystal Chime Alert';
        _selectedSongArtist = 'Loud Built-in Alarm Sound';
        _selectedSongArtwork = null;
      }
    });

    await _savePreferences(showFeedback: false);
  }

  void _openSongSelectorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrackSelectorModal(
        onTrackSelected: (AlarmTrack track) async {
          setState(() {
            _selectedPlatform = 'Search Songs';
            _uriController.text = track.previewUrl;
            _selectedSongTitle = track.title;
            _selectedSongArtist = track.artist;
            _selectedSongArtwork = track.albumArtUrl;
          });

          await _savePreferences();
        },
      ),
    );
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    final ignored = await _batteryService.requestIgnoreBatteryOptimizations();
    setState(() => _isBatteryOptimizationIgnored = ignored);
  }

  /// Extracts the currently installed APK and shares it directly via WhatsApp / system share
  Future<void> _shareApkViaWhatsApp() async {
    setState(() => _isSharingApk = true);

    try {
      final String? apkPath = await _apkChannel.invokeMethod<String>('getApkPath');

      if (apkPath != null && apkPath.isNotEmpty && File(apkPath).existsSync()) {
        final xFile = XFile(
          apkPath,
          name: 'ChargeAlarm.apk',
          mimeType: 'application/vnd.android.package-archive',
        );

        await Share.shareXFiles(
          [xFile],
          text: '⚡ Install ChargeAlarm: 80% Battery Protection & Music Alarm APK on your phone!',
          subject: 'ChargeAlarm APK File',
        );
      } else {
        await Share.share(
          '🔋 ChargeAlarm App: Protect your phone battery health at 80% charging with Spotify, JioSaavn & Music alarms!',
          subject: 'ChargeAlarm Android App',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharingApk = false);
      }
    }
  }

  void _openSecurityModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SecurityModal(
        onSecurityChanged: () {
          setState(() {});
        },
      ),
    );
  }

  Future<bool> _verifyPinIfEnabled({required String actionDescription}) async {
    if (!SecurityService.instance.isPinLockEnabled) return true;

    final controller = TextEditingController();
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: Color(0xFF00E676)),
            SizedBox(width: 10),
            Text('Enter Security PIN', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anti-tamper protection is active. Enter your 4-digit PIN to $actionDescription.',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 20),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '••••',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFF0E1626),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final ok = await SecurityService.instance.verifyPin(controller.text.trim());
              if (ok) {
                if (ctx.mounted) Navigator.pop(ctx, true);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Incorrect PIN! Access denied.')),
                  );
                }
              }
            },
            child: const Text('VERIFY', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return verified ?? false;
  }

  String _getHintForPlatform(String platform) {
    switch (platform) {
      case 'Search Songs':
        return 'Audio stream link or select a song from catalog';
      case 'Spotify':
        return 'Paste Spotify link (https://open.spotify.com/track/...) or song name';
      case 'JioSaavn':
        return 'Paste JioSaavn link (https://www.jiosaavn.com/song/...) or song name';
      case 'YouTube Music':
        return 'Paste YouTube Music link or song name';
      case 'Default Ringtone/URL':
      default:
        return 'Direct MP3/AAC stream link (or leave empty for loud system chime)';
    }
  }

  IconData _getIconForPlatform(String platform) {
    switch (platform) {
      case 'Search Songs':
        return Icons.queue_music_rounded;
      case 'Spotify':
        return Icons.music_note_rounded;
      case 'JioSaavn':
        return Icons.radio_rounded;
      case 'YouTube Music':
        return Icons.play_circle_filled_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  void dispose() {
    _uriController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bolt, color: Color(0xFF00E676), size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'ChargeAlarm',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Security & Anti-Tamper Shield',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 24),
                if (SecurityService.instance.isPinLockEnabled)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E5FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _openSecurityModal,
          ),
          IconButton(
            tooltip: 'Share APK',
            icon: const Icon(Icons.share_rounded, color: Color(0xFF00E5FF)),
            onPressed: _isSharingApk ? null : _shareApkViaWhatsApp,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Active Alarm Firing Banner
              ValueListenableBuilder<bool>(
                valueListenable: _batteryService.alarmTriggeredNotifier,
                builder: (context, triggered, _) {
                  if (!triggered) return const SizedBox.shrink();
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF1744), Color(0xFFFF5252)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF1744).withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BATTERY HIT $_targetPercentage%!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const Text(
                                'Unplug charger now to protect battery health.',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red.shade900,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            final ok = await _verifyPinIfEnabled(actionDescription: 'dismiss the alarm');
                            if (ok) {
                              _batteryService.stopAlarm();
                            }
                          },
                          child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Battery Percentage & Charging Gauge Card
              ValueListenableBuilder<int>(
                valueListenable: _batteryService.batteryLevelNotifier,
                builder: (context, level, _) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _batteryService.isChargingNotifier,
                    builder: (context, isCharging, _) {
                      return _buildBatteryDisplayCard(level, isCharging);
                    },
                  );
                },
              ),

              // Anti-Tamper Security Shield Badge
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _openSecurityModal,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131C2D),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00E676).withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_rounded, color: Color(0xFF00E676), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Anti-Tamper Shield Active',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: SecurityService.instance.isPinLockEnabled
                                        ? const Color(0xFF00E676).withOpacity(0.2)
                                        : Colors.white10,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    SecurityService.instance.isPinLockEnabled ? 'PIN LOCKED 🔒' : 'PIN UNLOCKED 🔓',
                                    style: TextStyle(
                                      color: SecurityService.instance.isPinLockEnabled
                                          ? const Color(0xFF00E676)
                                          : Colors.white54,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Device integrity safe · ProGuard obfuscated · HTTPS enforced',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Sleep-Mode Safe Background Service Status Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF131C2D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00E676).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_moon_rounded, color: Color(0xFF00E676), size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sleep-Mode Safe Foreground Service',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Wakes screen and rings alarm when phone is locked.',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (!_isBatteryOptimizationIgnored)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _requestBatteryOptimizationExemption,
                        child: const Text(
                          'DISABLE SAVER',
                          style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Master Protection Alarm Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F33),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isProtectionActive
                        ? const Color(0xFF00E676).withOpacity(0.35)
                        : Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isProtectionActive
                            ? const Color(0xFF00E676).withOpacity(0.18)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.power_settings_new_rounded,
                        color: _isProtectionActive ? const Color(0xFF00E676) : Colors.white38,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_targetPercentage% Charge Protection Alarm',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Rings song out loud when plugged in reaches threshold.',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isProtectionActive,
                      activeColor: const Color(0xFF00E676),
                      activeTrackColor: const Color(0xFF00E676).withOpacity(0.3),
                      inactiveThumbColor: Colors.white38,
                      inactiveTrackColor: Colors.white12,
                      onChanged: (val) async {
                        if (_isProtectionActive && !val) {
                          final ok = await _verifyPinIfEnabled(actionDescription: 'disable charge protection');
                          if (!ok) return;
                        }
                        setState(() => _isProtectionActive = val);
                        _batteryService.setProtectionActive(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Target Percentage Chooser Chips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F33),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Target Alarm Threshold',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '80% is recommended',
                          style: TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: _targetOptions.map((target) {
                        final isSelected = _targetPercentage == target;
                        return ChoiceChip(
                          label: Text('$target%'),
                          selected: isSelected,
                          selectedColor: const Color(0xFF00E676),
                          backgroundColor: const Color(0xFF0E1626),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF00E676) : Colors.white12,
                          ),
                          onSelected: (_) async {
                            if (_isProtectionActive && target != _targetPercentage) {
                              final ok = await _verifyPinIfEnabled(actionDescription: 'change the target charge threshold');
                              if (!ok) return;
                            }
                            setState(() => _targetPercentage = target);
                            _savePreferences();
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Music Platform Selector & Custom Song Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F33),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Alarm Song / Music Source',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Select preferred service',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Platform Selection Chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _platforms.map((platform) {
                        final isSelected = _selectedPlatform == platform;
                        return ChoiceChip(
                          avatar: Icon(
                            _getIconForPlatform(platform),
                            size: 16,
                            color: isSelected ? Colors.black : Colors.white70,
                          ),
                          label: Text(
                            platform,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF00E5FF),
                          backgroundColor: const Color(0xFF0E1626),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF00E5FF) : Colors.white12,
                          ),
                          onSelected: (_) => _onPlatformSelected(platform),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Dynamic Platform Specific UI
                    if (_selectedPlatform == 'Search Songs') ...[
                      // Search & Select Songs Catalog Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E5FF).withOpacity(0.15),
                            foregroundColor: const Color(0xFF00E5FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
                            ),
                          ),
                          icon: const Icon(Icons.search_rounded, size: 20),
                          label: const Text(
                            'SEARCH & SELECT ANY SONG 🎵',
                            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          onPressed: _openSongSelectorModal,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Selected Song Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1626),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _selectedSongArtwork != null && _selectedSongArtwork!.isNotEmpty
                                  ? Image.network(
                                      _selectedSongArtwork!,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 44,
                                        height: 44,
                                        color: const Color(0xFF00E5FF).withOpacity(0.1),
                                        child: const Icon(Icons.music_note, color: Color(0xFF00E5FF)),
                                      ),
                                    )
                                  : Container(
                                      width: 44,
                                      height: 44,
                                      color: const Color(0xFF00E5FF).withOpacity(0.1),
                                      child: const Icon(Icons.music_note, color: Color(0xFF00E5FF)),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedSongTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    _selectedSongArtist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: Color(0xFF00E5FF), size: 20),
                              tooltip: 'Change Song',
                              onPressed: _openSongSelectorModal,
                            ),
                          ],
                        ),
                      ),
                    ] else if (_selectedPlatform == 'Spotify') ...[
                      // Spotify Platform Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1626),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1DB954).withOpacity(0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1DB954),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.music_note, color: Colors.black, size: 16),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Spotify Music Alarm',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        'Launches Spotify app & triggers music playback',
                                        style: TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _isSpotifyInstalled
                                        ? const Color(0xFF1DB954).withOpacity(0.15)
                                        : Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _isSpotifyInstalled
                                          ? const Color(0xFF1DB954)
                                          : Colors.amber,
                                    ),
                                  ),
                                  child: Text(
                                    _isSpotifyInstalled ? 'Installed ✓' : 'App Not Found',
                                    style: TextStyle(
                                      color: _isSpotifyInstalled ? const Color(0xFF1DB954) : Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF1DB954),
                                      side: const BorderSide(color: Color(0xFF1DB954)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                    label: const Text('OPEN SPOTIFY APP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _batteryService.openAppOrUri('Spotify', _uriController.text.trim()),
                                  ),
                                ),
                                if (!_isSpotifyInstalled) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        side: const BorderSide(color: Colors.white24),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.download_rounded, size: 16),
                                      label: const Text('INSTALL SPOTIFY', style: TextStyle(fontSize: 11)),
                                      onPressed: () => _batteryService.openAppOrUri('Spotify', 'market://details?id=com.spotify.music'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Quick Search / Playlist Presets:',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                'Wake Up Happy',
                                'Morning Motivation',
                                'Top Hits 2026',
                              ].map((preset) => ActionChip(
                                label: Text(preset, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                backgroundColor: const Color(0xFF182338),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                onPressed: () {
                                  _uriController.text = 'spotify:search:${Uri.encodeComponent(preset)}';
                                  _selectedSongTitle = 'Spotify: $preset';
                                  _selectedSongArtist = 'Spotify Playlist Search';
                                  _savePreferences(showFeedback: false);
                                },
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_selectedPlatform == 'JioSaavn') ...[
                      // JioSaavn Platform Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1626),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF2BC5B4).withOpacity(0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2BC5B4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.radio_rounded, color: Colors.black, size: 16),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'JioSaavn Music Alarm',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        'Launches JioSaavn app & starts playback on alert',
                                        style: TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _isJioSaavnInstalled
                                        ? const Color(0xFF2BC5B4).withOpacity(0.15)
                                        : Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _isJioSaavnInstalled
                                          ? const Color(0xFF2BC5B4)
                                          : Colors.amber,
                                    ),
                                  ),
                                  child: Text(
                                    _isJioSaavnInstalled ? 'Installed ✓' : 'App Not Found',
                                    style: TextStyle(
                                      color: _isJioSaavnInstalled ? const Color(0xFF2BC5B4) : Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF2BC5B4),
                                      side: const BorderSide(color: Color(0xFF2BC5B4)),
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                    label: const Text('OPEN JIOSAAVN APP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _batteryService.openAppOrUri('JioSaavn', _uriController.text.trim()),
                                  ),
                                ),
                                if (!_isJioSaavnInstalled) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        side: const BorderSide(color: Colors.white24),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      icon: const Icon(Icons.download_rounded, size: 16),
                                      label: const Text('INSTALL JIOSAAVN', style: TextStyle(fontSize: 11)),
                                      onPressed: () => _batteryService.openAppOrUri('JioSaavn', 'market://details?id=com.jiosaavn.android'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Quick Presets:',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                'Bollywood Wake Up',
                                'Morning Bhajans',
                                'Trending Hindi',
                              ].map((preset) => ActionChip(
                                label: Text(preset, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                backgroundColor: const Color(0xFF182338),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                onPressed: () {
                                  _uriController.text = 'jiosaavn://search/${Uri.encodeComponent(preset)}';
                                  _selectedSongTitle = 'JioSaavn: $preset';
                                  _selectedSongArtist = 'JioSaavn Playlist';
                                  _savePreferences(showFeedback: false);
                                },
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_selectedPlatform == 'YouTube Music') ...[
                      // YouTube Music Platform Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1626),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFF0000).withOpacity(0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF0000),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 16),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'YouTube Music Alarm',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        'Opens YouTube Music track or search query on alert',
                                        style: TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _isYtMusicInstalled
                                        ? const Color(0xFFFF0000).withOpacity(0.15)
                                        : Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _isYtMusicInstalled
                                          ? const Color(0xFFFF0000)
                                          : Colors.amber,
                                    ),
                                  ),
                                  child: Text(
                                    _isYtMusicInstalled ? 'Installed ✓' : 'App Not Found',
                                    style: TextStyle(
                                      color: _isYtMusicInstalled ? const Color(0xFFFF0000) : Colors.amber,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFF5252),
                                side: const BorderSide(color: Color(0xFFFF5252)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.open_in_new_rounded, size: 16),
                              label: const Text('OPEN YOUTUBE MUSIC APP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () => _batteryService.openAppOrUri('YouTube Music', _uriController.text.trim()),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Default Ringtone/URL Info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1626),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.volume_up_rounded, color: Color(0xFF00E676), size: 28),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Built-in Crystal Chime Alert',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Loud system alarm tone. Works 100% offline with full volume override.',
                                    style: TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Song Link / URI Input Field
                    Text(
                      '$_selectedPlatform Track URL / Link / Query',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _uriController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: _getHintForPlatform(_selectedPlatform),
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFF0E1626),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.save_rounded, color: Color(0xFF00E676)),
                          tooltip: 'Save Target',
                          onPressed: () => _savePreferences(showFeedback: true),
                        ),
                      ),
                      onSubmitted: (_) => _savePreferences(showFeedback: true),
                    ),

                    const SizedBox(height: 12),

                    // Reliability reassurance banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF00E676), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Dual Alert: Charges wake screen, launches $_selectedPlatform & plays loud audible alarm.',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Action Buttons: Test Alarm & Share APK via WhatsApp
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 22),
                        label: const Text(
                          'TEST ALARM',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: () async {
                          await _savePreferences(showFeedback: false);
                          await _batteryService.triggerMusicPlayback(
                            _selectedPlatform,
                            _uriController.text.trim(),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⚡ Testing $_selectedPlatform Alarm! Ringing now...'),
                                backgroundColor: const Color(0xFF00E5FF),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(color: Color(0xFF25D366), width: 1.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _isSharingApk
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF25D366),
                                ),
                              )
                            : const Icon(Icons.share_rounded, size: 20),
                        label: const Text(
                          'SHARE APK',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: _isSharingApk ? null : _shareApkViaWhatsApp,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Stop Alarm Button (Visible when test alarm or active alarm is ringing)
              ValueListenableBuilder<bool>(
                valueListenable: _batteryService.alarmTriggeredNotifier,
                builder: (context, triggered, _) {
                  if (!triggered) return const SizedBox.shrink();
                  return SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF1744),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.stop_circle_rounded),
                      label: const Text(
                        'STOP ACTIVE ALARM',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _batteryService.stopAlarm(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatteryDisplayCard(int level, bool isCharging) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF161F33),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCharging
              ? const Color(0xFF00E676).withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isCharging
                  ? const Color(0xFF00E676).withOpacity(0.15)
                  : const Color(0xFF0E1626),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCharging ? const Color(0xFF00E676) : Colors.white24,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCharging ? Icons.power_rounded : Icons.power_off_rounded,
                  color: isCharging ? const Color(0xFF00E676) : Colors.white54,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  isCharging ? 'PLUGGED IN (CHARGING)' : 'UNPLUGGED (DISCHARGING)',
                  style: TextStyle(
                    color: isCharging ? const Color(0xFF00E676) : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 70,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Text(
                  '%',
                  style: TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isCharging && level >= _targetPercentage
                ? '🎯 Target $_targetPercentage% Reached — Unplug Device'
                : 'Target: $_targetPercentage% Battery Health Protection',
            style: TextStyle(
              color: isCharging && level >= _targetPercentage
                  ? const Color(0xFFFF5252)
                  : const Color(0xFF00E5FF),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
