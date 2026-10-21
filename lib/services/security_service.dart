import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'battery_service.dart';

class SecurityService {
  static SecurityService? _instance;
  static SecurityService get instance => _instance ??= SecurityService._();

  static const String _keyPinEnabled = 'security_pin_enabled';
  static const String _keyPinHash = 'security_pin_hash';
  static const String _keyScreenSecure = 'security_screen_secure';
  static const String _salt = 'ChargeAlarm_Secure_Salt_2026_@!';

  SecurityService._();

  bool _isPinLockEnabled = false;
  bool _isScreenSecure = false;
  Map<String, dynamic> _deviceSecurityStatus = {
    'isRooted': false,
    'isDebugger': false,
    'isEmulator': false,
    'isSecure': true,
  };

  bool get isPinLockEnabled => _isPinLockEnabled;
  bool get isScreenSecure => _isScreenSecure;
  Map<String, dynamic> get deviceSecurityStatus => _deviceSecurityStatus;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isPinLockEnabled = prefs.getBool(_keyPinEnabled) ?? false;
    _isScreenSecure = prefs.getBool(_keyScreenSecure) ?? false;

    // Apply screen capture protection if previously enabled
    if (_isScreenSecure) {
      await BatteryService.instance.setScreenSecure(true);
    }

    // Scan device integrity
    await scanDeviceSecurity();
  }

  /// Scans device for Root, Magisk, Test-keys, and live debuggers
  Future<Map<String, dynamic>> scanDeviceSecurity() async {
    final status = await BatteryService.instance.getSecurityStatus();
    _deviceSecurityStatus = status;
    return status;
  }

  /// Toggles Window FLAG_SECURE to block screen recording and screenshot spyware
  Future<void> setScreenSecure(bool enable) async {
    _isScreenSecure = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyScreenSecure, enable);
    await BatteryService.instance.setScreenSecure(enable);
  }

  /// Hashes a 4-digit PIN with a cryptographic salt using pure Dart SHA-256
  static String hashPin(String pin) {
    return _sha256Hex('$_salt:$pin:chargealarm');
  }

  /// Verifies entered PIN against stored secure hash
  Future<bool> verifyPin(String enteredPin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_keyPinHash);
    if (storedHash == null || storedHash.isEmpty) {
      return true; // No PIN set
    }
    final enteredHash = hashPin(enteredPin);
    return enteredHash == storedHash;
  }

  /// Sets a new 4-digit anti-tamper PIN
  Future<void> setPin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    final hashed = hashPin(newPin);
    await prefs.setString(_keyPinHash, hashed);
    await prefs.setBool(_keyPinEnabled, true);
    _isPinLockEnabled = true;
  }

  /// Disables anti-tamper PIN lock
  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPinHash);
    await prefs.setBool(_keyPinEnabled, false);
    _isPinLockEnabled = false;
  }

  /// Pure Dart SHA-256 implementation (zero external dependencies, 100% offline)
  static String _sha256Hex(String input) {
    final bytes = utf8.encode(input);
    final hashBytes = _sha256(bytes);
    return hashBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static List<int> _sha256(List<int> message) {
    // SHA-256 constants
    final k = <int>[
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    final length = message.length;
    final bitLength = length * 8;
    final paddedLength = ((length + 9 + 63) ~/ 64) * 64;
    final padded = List<int>.filled(paddedLength, 0);
    padded.setRange(0, length, message);
    padded[length] = 0x80;

    for (var i = 0; i < 8; i++) {
      padded[paddedLength - 1 - i] = (bitLength >> (i * 8)) & 0xff;
    }

    final w = List<int>.filled(64, 0);

    for (var chunk = 0; chunk < paddedLength; chunk += 64) {
      for (var i = 0; i < 16; i++) {
        w[i] = (padded[chunk + i * 4] << 24) |
            (padded[chunk + i * 4 + 1] << 16) |
            (padded[chunk + i * 4 + 2] << 8) |
            padded[chunk + i * 4 + 3];
      }

      for (var i = 16; i < 64; i++) {
        final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
        final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
      }

      var a = h0;
      var b = h1;
      var c = h2;
      var d = h3;
      var e = h4;
      var f = h5;
      var g = h6;
      var h = h7;

      for (var i = 0; i < 64; i++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ ((~e) & g);
        final temp1 = (h + s1 + ch + k[i] + w[i]) & 0xffffffff;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xffffffff;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xffffffff;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xffffffff;
      }

      h0 = (h0 + a) & 0xffffffff;
      h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff;
      h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff;
      h5 = (h5 + f) & 0xffffffff;
      h6 = (h6 + g) & 0xffffffff;
      h7 = (h7 + h) & 0xffffffff;
    }

    final result = <int>[];
    for (final val in [h0, h1, h2, h3, h4, h5, h6, h7]) {
      result.add((val >> 24) & 0xff);
      result.add((val >> 16) & 0xff);
      result.add((val >> 8) & 0xff);
      result.add(val & 0xff);
    }
    return result;
  }

  static int _rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & 0xffffffff;
}
