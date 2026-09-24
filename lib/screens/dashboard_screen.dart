import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alarm_track.dart';
import '../services/battery_service.dart';
import '../services/alarm_player_service.dart';
import '../services/preferences_service.dart';
import '../widgets/battery_ring_widget.dart';
import 'track_selector_modal.dart';
import 'settings_modal.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late AlarmTrack _selectedTrack;
  bool _isProtectionEnabled = true;

  @override
  void initState() {
    super.initState();
    _selectedTrack = PreferencesService.instance.selectedTrack;
    _isProtectionEnabled = PreferencesService.instance.isAlarmEnabled;
  }

  void _onToggleProtection(bool value) async {
    setState(() => _isProtectionEnabled = value);
    await PreferencesService.instance.setAlarmEnabled(value);
    if (value) {
      await BatteryService.instance.startForegroundMonitoring();
    } else {
      await BatteryService.instance.stopForegroundMonitoring();
    }
  }

  void _openTrackSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrackSelectorModal(
        onTrackSelected: (track) {
          setState(() => _selectedTrack = track);
        },
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettingsModal(
        onSaved: () {
          setState(() {
            _selectedTrack = PreferencesService.instance.selectedTrack;
            _isProtectionEnabled = PreferencesService.instance.isAlarmEnabled;
          });
        },
      ),
    );
  }

  void _testAlarm() {
    final vol = PreferencesService.instance.volume;
    AlarmPlayerService.instance.triggerAlarm(_selectedTrack, volume: vol);
  }

  void _stopAlarm() {
    AlarmPlayerService.instance.stop();
    BatteryService.instance.resetSessionTrigger();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BatteryService, AlarmPlayerService>(
      builder: (context, batteryService, alarmPlayer, _) {
        final isAlarmPlaying = alarmPlayer.isPlaying;
        final targetPercentage = PreferencesService.instance.targetPercentage;

        return Scaffold(
          backgroundColor: const Color(0xFF0B0E14),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt, color: Color(0xFF00E676), size: 22),
                ),
                const SizedBox(width: 10),
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
                icon: const Icon(Icons.tune_rounded, color: Colors.white70),
                tooltip: 'Settings',
                onPressed: _openSettings,
              ),
            ],
          ),
          body: Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Active Alarm Alert Banner
                      if (isAlarmPlaying)
                        _buildAlarmFiringBanner(batteryService.batteryLevel),

                      const SizedBox(height: 12),

                      // Charging Status Badge
                      _buildChargingStatusBadge(batteryService.isCharging),

                      const SizedBox(height: 24),

                      // Battery Ring Meter
                      BatteryRingWidget(
                        percentage: batteryService.batteryLevel,
                        isCharging: batteryService.isCharging,
                      ),

                      const SizedBox(height: 32),

                      // Master Protection Toggle Switch Card
                      _buildProtectionToggleCard(targetPercentage),

                      const SizedBox(height: 16),

                      // Music / Alarm Selection Card
                      _buildTrackSelectionCard(),

                      const SizedBox(height: 20),

                      // Action Buttons: Test Alarm & Manual Stop
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00E5FF),
                                side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text(
                                'TEST ALARM',
                                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                              onPressed: isAlarmPlaying ? null : _testAlarm,
                            ),
                          ),
                          if (isAlarmPlaying) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF1744),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.stop_rounded),
                                label: const Text(
                                  'STOP ALARM',
                                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                                ),
                                onPressed: _stopAlarm,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Background service status indicator footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            batteryService.isServiceRunning
                                ? Icons.verified_user
                                : Icons.info_outline,
                            size: 14,
                            color: batteryService.isServiceRunning
                                ? const Color(0xFF00E676)
                                : Colors.white38,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            batteryService.isServiceRunning
                                ? 'Background Protection Active'
                                : 'Background Service Idle',
                            style: TextStyle(
                              color: batteryService.isServiceRunning
                                  ? const Color(0xFF00E676)
                                  : Colors.white38,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChargingStatusBadge(bool isCharging) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isCharging
            ? const Color(0xFF00E676).withOpacity(0.12)
            : const Color(0xFF1E2638),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCharging
              ? const Color(0xFF00E676).withOpacity(0.5)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCharging ? Icons.power : Icons.power_off,
            color: isCharging ? const Color(0xFF00E676) : Colors.white54,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            isCharging ? 'Plugged In — Power Connected' : 'Unplugged — Discharging',
            style: TextStyle(
              color: isCharging ? const Color(0xFF00E676) : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmFiringBanner(int level) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF1744), Color(0xFFFF5252)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF1744).withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BATTERY HIT $level%!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Unplug charger now to save battery life.',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red.shade900,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _stopAlarm,
            child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionToggleCard(int targetPercentage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151C2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isProtectionEnabled
              ? const Color(0xFF00E676).withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isProtectionEnabled
                  ? const Color(0xFF00E676).withOpacity(0.15)
                  : Colors.white10,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.shield_rounded,
              color: _isProtectionEnabled ? const Color(0xFF00E676) : Colors.white38,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable $targetPercentage% Protection Alarm',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isProtectionEnabled
                      ? 'Alarm triggers automatically when 80% is reached.'
                      : 'Protection disabled. Tap switch to activate.',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _isProtectionEnabled,
            activeColor: const Color(0xFF00E676),
            activeTrackColor: const Color(0xFF00E676).withOpacity(0.3),
            inactiveThumbColor: Colors.white38,
            inactiveTrackColor: Colors.white12,
            onChanged: _onToggleProtection,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF151C2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Alarm Sound / Music Track',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: _openTrackSelector,
                child: const Text(
                  'CHANGE',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _openTrackSelector,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1C253B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _selectedTrack.albumArtUrl != null
                        ? Image.network(
                            _selectedTrack.albumArtUrl!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 52,
                              height: 52,
                              color: const Color(0xFF232D48),
                              child: const Icon(Icons.music_note, color: Color(0xFF00E5FF)),
                            ),
                          )
                        : Container(
                            width: 52,
                            height: 52,
                            color: const Color(0xFF232D48),
                            child: const Icon(Icons.music_note, color: Color(0xFF00E5FF)),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedTrack.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedTrack.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white38),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
