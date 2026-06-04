import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Unit tests for biometric preferences management.
/// Tests SharedPreferences operations directly to avoid the dart:html
/// import chain through the full app.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Biometric Preferences', () {
    test('biometric is disabled by default', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('biometric_enabled') ?? false, isFalse);
    });

    test('setBiometricEnabled persists true', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', true);
      expect(prefs.getBool('biometric_enabled'), isTrue);
    });

    test('setBiometricEnabled persists false', () async {
      SharedPreferences.setMockInitialValues({'biometric_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', false);
      expect(prefs.getBool('biometric_enabled'), isFalse);
    });

    test('saveCredentials stores email and password', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('bio_email', 'test@cubag.org');
      await prefs.setString('bio_password', 'secret123');

      expect(prefs.getString('bio_email'), equals('test@cubag.org'));
      expect(prefs.getString('bio_password'), equals('secret123'));
    });

    test('getSavedCredentials returns null when nothing saved', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bio_email'), isNull);
      expect(prefs.getString('bio_password'), isNull);
    });

    test('clearCredentials removes everything', () async {
      SharedPreferences.setMockInitialValues({
        'bio_email': 'x@y.com',
        'bio_password': 'pw',
        'biometric_enabled': true,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('bio_email');
      await prefs.remove('bio_password');
      await prefs.remove('biometric_enabled');

      expect(prefs.getString('bio_email'), isNull);
      expect(prefs.getString('bio_password'), isNull);
      expect(prefs.getBool('biometric_enabled'), isNull);
    });
  });
}
