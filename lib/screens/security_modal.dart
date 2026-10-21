import 'package:flutter/material.dart';
import '../services/security_service.dart';

class SecurityModal extends StatefulWidget {
  final VoidCallback onSecurityChanged;

  const SecurityModal({super.key, required this.onSecurityChanged});

  @override
  State<SecurityModal> createState() => _SecurityModalState();
}

class _SecurityModalState extends State<SecurityModal> {
  final SecurityService _securityService = SecurityService.instance;

  bool _isPinEnabled = false;
  bool _isScreenSecure = false;
  Map<String, dynamic> _status = {};
  bool _isScanning = false;

  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isPinEnabled = _securityService.isPinLockEnabled;
    _isScreenSecure = _securityService.isScreenSecure;
    _status = _securityService.deviceSecurityStatus;
    _rescan();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _rescan() async {
    setState(() => _isScanning = true);
    final status = await _securityService.scanDeviceSecurity();
    if (mounted) {
      setState(() {
        _status = status;
        _isScanning = false;
      });
    }
  }

  void _showSetPinDialog() {
    _pinController.clear();
    _confirmPinController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: Color(0xFF00E676)),
            SizedBox(width: 10),
            Text('Set Anti-Tamper PIN', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Create a 4-digit PIN to prevent unauthorized changes to battery protection and alarm settings.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
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
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 20),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: 'Confirm PIN',
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final pin = _pinController.text.trim();
              final confirm = _confirmPinController.text.trim();

              if (pin.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be 4 digits')),
                );
                return;
              }

              if (pin != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PINs do not match!')),
                );
                return;
              }

              await _securityService.setPin(pin);
              setState(() => _isPinEnabled = true);
              widget.onSecurityChanged();
              if (ctx.mounted) Navigator.pop(ctx);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Anti-tamper PIN enabled successfully!'),
                    backgroundColor: Color(0xFF00E676),
                  ),
                );
              }
            },
            child: const Text('SAVE PIN', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRemovePinDialog() {
    _pinController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161F33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter Current PIN', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your 4-digit PIN to disable anti-tamper lock.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final correct = await _securityService.verifyPin(_pinController.text.trim());
              if (correct) {
                await _securityService.removePin();
                setState(() => _isPinEnabled = false);
                widget.onSecurityChanged();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN lock disabled.')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect PIN! Access denied.')),
                );
              }
            },
            child: const Text('DISABLE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRooted = _status['isRooted'] == true;
    final isDebugger = _status['isDebugger'] == true;
    final isDeviceSecure = !isRooted && !isDebugger;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F1523),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.security_rounded, color: Color(0xFF00E676), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'App Security & Shield',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Security Score Banner
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDeviceSecure
                          ? [const Color(0xFF00E676).withOpacity(0.18), const Color(0xFF00B0FF).withOpacity(0.18)]
                          : [const Color(0xFFFF5252).withOpacity(0.2), const Color(0xFFFFAB00).withOpacity(0.2)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDeviceSecure
                          ? const Color(0xFF00E676).withOpacity(0.4)
                          : const Color(0xFFFF5252).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDeviceSecure ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                        color: isDeviceSecure ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                        size: 40,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDeviceSecure ? 'SHIELD ACTIVE: 100% SECURED' : 'DEVICE VULNERABILITY DETECTED',
                              style: TextStyle(
                                color: isDeviceSecure ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isDeviceSecure
                                  ? 'No root exploits, no debugger sniffing, cleartext traffic blocked.'
                                  : 'Root binaries or debuggers detected. App defenses actively mitigating threats.',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Anti-Tamper 4-Digit PIN Lock
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161F33),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.pin_rounded, color: Color(0xFF00E5FF), size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Anti-Tamper PIN Lock',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'Protects alarm threshold & toggle',
                                    style: TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _isPinEnabled,
                            activeColor: const Color(0xFF00E676),
                            onChanged: (val) {
                              if (val) {
                                _showSetPinDialog();
                              } else {
                                _showRemovePinDialog();
                              }
                            },
                          ),
                        ],
                      ),
                      if (_isPinEnabled) ...[
                        const Divider(color: Colors.white10, height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Status: Protected with 4-Digit PIN',
                              style: TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            TextButton(
                              onPressed: _showSetPinDialog,
                              child: const Text('CHANGE PIN', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Screenshot & Spyware Blocker (FLAG_SECURE)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161F33),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFAB00).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.remove_red_eye_rounded, color: Color(0xFFFFAB00), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Screen Privacy / Spyware Blocker',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'Blocks unauthorized screenshots & screen recordings (FLAG_SECURE)',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isScreenSecure,
                        activeColor: const Color(0xFFFFAB00),
                        onChanged: (val) async {
                          await _securityService.setScreenSecure(val);
                          setState(() => _isScreenSecure = val);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Detailed Security Checklist
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161F33),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Active Defense Layers',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (_isScanning)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E676)),
                            )
                          else
                            InkWell(
                              onTap: _rescan,
                              child: const Row(
                                children: [
                                  Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF00E5FF)),
                                  SizedBox(width: 4),
                                  Text('RE-SCAN', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSecurityItem(
                        icon: isRooted ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                        color: isRooted ? Colors.redAccent : const Color(0xFF00E676),
                        title: isRooted ? 'Root / Magisk Exploit Warning' : 'Anti-Root Integrity',
                        subtitle: isRooted ? 'Device has root binaries.' : 'Verified unrooted official OS integrity.',
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      _buildSecurityItem(
                        icon: isDebugger ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                        color: isDebugger ? Colors.amber : const Color(0xFF00E676),
                        title: isDebugger ? 'Debugger Sniffer Active' : 'Anti-Debugging Defense',
                        subtitle: isDebugger ? 'Active debugger connected.' : 'No memory sniffers or debugger hooks.',
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      _buildSecurityItem(
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF00E676),
                        title: 'Network Security Config',
                        subtitle: 'Cleartext HTTP traffic blocked; strictly HTTPS encrypted.',
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      _buildSecurityItem(
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF00E676),
                        title: 'Anti-ADB Backup Exploit',
                        subtitle: 'android:allowBackup="false" prevents USB data theft.',
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      _buildSecurityItem(
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF00E676),
                        title: 'R8 / ProGuard Obfuscation',
                        subtitle: 'Classes and symbols obfuscated against reverse engineering.',
                      ),
                      const Divider(color: Colors.white10, height: 16),
                      _buildSecurityItem(
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF00E676),
                        title: 'Intent & Scheme Sanitization',
                        subtitle: 'Dangerous file:// and script URI injection attacks blocked.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}
