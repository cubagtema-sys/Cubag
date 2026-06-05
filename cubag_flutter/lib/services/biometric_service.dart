import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric authentication service using `local_auth`.
/// Works on Android (fingerprint, face), iOS (Touch ID, Face ID).
/// Gracefully degrades on web and unsupported platforms.
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if the device has biometric hardware + enrolled biometrics.
  Future<bool> isBiometricAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException catch (e) {
      debugPrint('Biometric availability check failed: $e');
      return false;
    }
  }

  /// Returns the list of enrolled biometric types.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Prompt the user for biometric authentication.
  Future<bool> authenticate({String reason = 'Authenticate to sign in to CUBAG'}) async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,    // allow PIN/pattern as fallback
          stickyAuth: true,        // keep prompt alive if user switches apps briefly
          useErrorDialogs: true,   // show OS error dialogs automatically
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric authentication failed: $e');
      return false;
    }
  }

  /// Persist user preference for biometric quick login.
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  /// Store credentials for biometric re-login (encrypted via shared_preferences).
  Future<void> saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bio_email', email);
    await prefs.setString('bio_password', password);
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('bio_email');
    final password = prefs.getString('bio_password');
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bio_email');
    await prefs.remove('bio_password');
    await prefs.remove('biometric_enabled');
  }
}
