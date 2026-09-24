import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'services/battery_service.dart';

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

  final batteryService = BatteryService();
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
  final BatteryService _batteryService = BatteryService();
  final TextEditingController _uriController = TextEditingController();

  String _selectedPlatform = 'Spotify';
  bool _isProtectionActive = true;
  bool _isSharingApk = false;
  final List<String> _platforms = ['Spotify', 'JioSaavn', 'Default Ringtone/URL'];

  static const MethodChannel _apkChannel = MethodChannel('com.chargealarm.app/apk_share');

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedPlatform = prefs.getString('music_platform') ?? 'Spotify';
      _uriController.text = prefs.getString('music_uri') ?? '';
      _isProtectionActive = prefs.getBool('alarm_protection_enabled') ?? true;
    });
    _batteryService.setProtectionActive(_isProtectionActive);
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('music_platform', _selectedPlatform);
    await prefs.setString('music_uri', _uriController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $_selectedPlatform config updated!'),
          backgroundColor: const Color(0xFF00E676),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
        // Fallback: Share project instructions & direct download link
        await Share.share(
          '🔋 ChargeAlarm App: Protect your phone battery health at 80% charging with Spotify & JioSaavn music alarms!',
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

  String _getHintForPlatform(String platform) {
    switch (platform) {
      case 'Spotify':
        return 'e.g. spotify:track:4cOdK2wGLETKBW3PvgPWqT or song URL';
      case 'JioSaavn':
        return 'e.g. jiosaavn:// or https://www.jiosaavn.com/song/...';
      case 'Default Ringtone/URL':
      default:
        return 'e.g. https://... or leave empty for default alarm chime';
    }
  }

  IconData _getIconForPlatform(String platform) {
    switch (platform) {
      case 'Spotify':
        return Icons.music_note_rounded;
      case 'JioSaavn':
        return Icons.radio_rounded;
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
              // Alarm Triggered Banner
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'BATTERY HIT 80%!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Unplug charger now to protect battery.',
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
                          onPressed: () => _batteryService.resetAlarm(),
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

              const SizedBox(height: 20),

              // Master 80% Protection Alarm Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                        Icons.shield_rounded,
                        color: _isProtectionActive ? const Color(0xFF00E676) : Colors.white38,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '80% Charge Protection Alarm',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Triggers music when 80% is reached while plugged in.',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
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
                      onChanged: (val) {
                        setState(() => _isProtectionActive = val);
                        _batteryService.setProtectionActive(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Music Platform Selector & Custom URL Configuration Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF161F33),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alarm Music Platform',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Platform Selection Chips
                    Wrap(
                      spacing: 8,
                      children: _platforms.map((platform) {
                        final isSelected = _selectedPlatform == platform;
                        return ChoiceChip(
                          avatar: Icon(
                            _getIconForPlatform(platform),
                            size: 18,
                            color: isSelected ? Colors.black : Colors.white70,
                          ),
                          label: Text(
                            platform,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF00E5FF),
                          backgroundColor: const Color(0xFF0E1626),
                          side: BorderSide(
                            color: isSelected ? const Color(0xFF00E5FF) : Colors.white12,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedPlatform = platform);
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),

                    // Song Link / URI Input Field
                    Text(
                      '$_selectedPlatform Track URI / URL / Query',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _uriController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: _getHintForPlatform(_selectedPlatform),
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF0E1626),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.save_rounded, color: Color(0xFF00E676)),
                          tooltip: 'Save Music Target',
                          onPressed: _savePreferences,
                        ),
                      ),
                      onSubmitted: (_) => _savePreferences(),
                    ),

                    const SizedBox(height: 16),

                    // Save configuration button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: const Color(0xFF00E5FF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text(
                          'SAVE MUSIC CONFIG',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        onPressed: _savePreferences,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

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
                        onPressed: () {
                          _batteryService.triggerMusicPlayback(
                            _selectedPlatform,
                            _uriController.text.trim(),
                          );
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
                          foregroundColor: const Color(0xFF25D366), // WhatsApp Green
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

              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatteryDisplayCard(int level, bool isCharging) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
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
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
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
          const SizedBox(height: 8),
          Text(
            isCharging && level >= 80
                ? '🎯 Target 80% Reached — Unplug Device'
                : 'Target: 80% Battery Health Protection',
            style: TextStyle(
              color: isCharging && level >= 80 ? const Color(0xFFFF5252) : const Color(0xFF00E5FF),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
