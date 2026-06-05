import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Biometric authentication service using `local_auth`.
/// Works on Android (fingerprint, face), iOS (Touch ID, Face ID).
/// Credentials stored encrypted via flutter_secure_storage:
///   - Android: AES-256 in Android Keystore (hardware-backed)
///   - iOS: Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Encrypted storage — uses Android Keystore / iOS Keychain
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,  // AES-256 via Android Keystore
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _keyEmail    = 'bio_email';
  static const _keyPassword = 'bio_password';
  static const _keyEnabled  = 'biometric_enabled';

  // ── Availability ──────────────────────────────────────────────────────────

  /// Check if the device has biometric hardware + enrolled biometrics.
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck          = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException catch (e) {
      debugPrint('Biometric availability check failed: $e');
      return false;
    }
  }

  /// Returns the list of enrolled biometric types (face, fingerprint, iris).
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  // ── Authentication ────────────────────────────────────────────────────────

  /// Prompt the user for biometric authentication.
  /// Falls back to device PIN/pattern if biometrics fail.
  Future<bool> authenticate({
    String reason = 'Authenticate to sign in to CUBAG',
  }) async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication failed: $e');
      return false;
    }
  }

  // ── Preferences (non-sensitive — SharedPreferences is fine) ──────────────

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  // ── Encrypted credential storage ──────────────────────────────────────────

  /// Store email + password encrypted in Android Keystore / iOS Keychain.
  Future<void> saveCredentials(String email, String password) async {
    await _secureStorage.write(key: _keyEmail,    value: email);
    await _secureStorage.write(key: _keyPassword, value: password);
    debugPrint('[BiometricService] Credentials saved to secure storage.');
  }

  /// Read credentials from secure encrypted storage.
  Future<Map<String, String>?> getSavedCredentials() async {
    try {
      final email    = await _secureStorage.read(key: _keyEmail);
      final password = await _secureStorage.read(key: _keyPassword);
      if (email != null && password != null) {
        return {'email': email, 'password': password};
      }
      return null;
    } catch (e) {
      debugPrint('[BiometricService] Failed to read secure credentials: $e');
      return null;
    }
  }

  /// Wipe all stored credentials and biometric preference.
  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _keyEmail);
    await _secureStorage.delete(key: _keyPassword);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEnabled);
    debugPrint('[BiometricService] Credentials cleared from secure storage.');
  }
}
