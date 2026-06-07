// Web stub — loaded by dart2js instead of biometric_service_native.dart.
// All functions are no-ops: local_auth and flutter_secure_storage
// platform-specific code never enters the web bundle.

Future<bool> isBiometricAvailable() => Future.value(false);

Future<bool> authenticate({required String reason}) => Future.value(false);

Future<void> saveCredentials(String email, String password) => Future.value();

Future<Map<String, String>?> getSavedCredentials() => Future.value(null);

Future<void> clearCredentials() => Future.value();
