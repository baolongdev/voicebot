---
name: flutter-security-patterns
description: Security best practices for Flutter apps. Covers secure storage, API security, authentication, data protection, and common vulnerability prevention.
---

# Flutter Security Patterns

Production-ready security patterns to protect user data and prevent vulnerabilities.

## Secure Storage

### ✅ Never Store Sensitive Data in Plain Text

```dart
// ❌ NEVER DO THIS
await prefs.setString('password', 'user_password');
await prefs.setString('api_token', 'secret_token');

// ✅ Use flutter_secure_storage
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();

// Store
await storage.write(key: 'auth_token', value: token);

// Read
final token = await storage.read(key: 'auth_token');

// Delete
await storage.delete(key: 'auth_token');

// Delete all
await storage.deleteAll();
```

### ✅ Secure Storage Configuration

```dart
// Android: Use EncryptedSharedPreferences
// iOS: Uses Keychain by default

const secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  ),
);
```

## API Security

### ✅ HTTPS Only

```dart
// ❌ NEVER use HTTP in production
final response = await http.get(Uri.parse('http://api.example.com/data'));

// ✅ Always use HTTPS
final response = await http.get(Uri.parse('https://api.example.com/data'));

// ✅ Enforce HTTPS in dio
final dio = Dio(BaseOptions(
  baseUrl: 'https://api.example.com',
  validateStatus: (status) {
    return status! < 500;
  },
));
```

### ✅ Certificate Pinning

```dart
import 'package:dio/dio.dart';
import 'package:dio/adapter.dart';

class SecureApiClient {
  final Dio dio;

  SecureApiClient() : dio = Dio() {
    (dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
        (client) {
      client.badCertificateCallback = (cert, host, port) {
        // Certificate pinning
        final certSha256 = sha256.convert(cert.der).toString();
        const expectedHash = 'YOUR_CERTIFICATE_SHA256_HASH';
        return certSha256 == expectedHash;
      };
      return client;
    };
  }
}
```

## Authentication Security

### ✅ Secure Token Management

```dart
class AuthService {
  final FlutterSecureStorage _storage;
  final Dio _dio;

  AuthService(this._storage, this._dio) {
    _setupInterceptors();
  }

  void _setupInterceptors() {
    // Add token to requests
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Token expired - attempt refresh
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry original request
            final options = error.requestOptions;
            final token = await _storage.read(key: 'auth_token');
            options.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(options);
            return handler.resolve(response);
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await _dio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      final newToken = response.data['access_token'];
      final newRefreshToken = response.data['refresh_token'];

      await _storage.write(key: 'auth_token', value: newToken);
      await _storage.write(key: 'refresh_token', value: newRefreshToken);

      return true;
    } catch (e) {
      await logout();
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    // Navigate to login screen
  }
}
```

### ✅ Biometric Authentication

```dart
import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  Future<bool> authenticate({
    required String localizedReason,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}

// Usage
final biometricAuth = BiometricAuth();

if (await biometricAuth.canCheckBiometrics()) {
  final authenticated = await biometricAuth.authenticate(
    localizedReason: 'Authenticate to access your account',
  );

  if (authenticated) {
    // Proceed to app
  }
}
```

## Data Encryption

### ✅ Encrypt Sensitive Data

```dart
import 'package:encrypt/encrypt.dart';

class DataEncryption {
  static final _key = Key.fromSecureRandom(32);
  static final _iv = IV.fromSecureRandom(16);
  static final _encrypter = Encrypter(AES(_key));

  static String encrypt(String plainText) {
    final encrypted = _encrypter.encrypt(plainText, iv: _iv);
    return encrypted.base64;
  }

  static String decrypt(String encryptedText) {
    final encrypted = Encrypted.fromBase64(encryptedText);
    return _encrypter.decrypt(encrypted, iv: _iv);
  }
}

// Store encrypted data
final encrypted = DataEncryption.encrypt(sensitiveData);
await prefs.setString('encrypted_data', encrypted);

// Read and decrypt
final encrypted = prefs.getString('encrypted_data') ?? '';
final decrypted = DataEncryption.decrypt(encrypted);
```

### ✅ Secure Key Storage

```dart
// Generate and store encryption key securely
class KeyManager {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'encryption_key';

  static Future<String> getOrCreateKey() async {
    var key = await _storage.read(key: _keyName);

    if (key == null) {
      // Generate new key
      key = base64.encode(List<int>.generate(32, (_) => Random.secure().nextInt(256)));
      await _storage.write(key: _keyName, value: key);
    }

    return key;
  }

  static Future<void> deleteKey() async {
    await _storage.delete(key: _keyName);
  }
}
```

## Input Validation

### ✅ Sanitize User Input

```dart
class InputValidator {
  // Email validation
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // Password strength
  static bool isStrongPassword(String password) {
    if (password.length < 8) return false;

    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasDigits = password.contains(RegExp(r'[0-9]'));
    final hasSpecialCharacters = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    return hasUppercase && hasLowercase && hasDigits && hasSpecialCharacters;
  }

  // SQL Injection prevention (use parameterized queries)
  static String sanitizeSql(String input) {
    return input.replaceAll(RegExp(r"[';\"\\]"), '');
  }

  // XSS prevention
  static String sanitizeHtml(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');
  }

  // Phone number validation
  static bool isValidPhone(String phone) {
    final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
    return phoneRegex.hasMatch(phone);
  }

  // URL validation
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}
```

## Platform Security

### ✅ Android Security

```xml
<!-- android/app/src/main/AndroidManifest.xml -->

<!-- Prevent screenshots in sensitive screens -->
<application>
  <activity
    android:name=".MainActivity"
    android:windowSoftInputMode="adjustResize">

    <!-- Add this for secure screens -->
    <meta-data
      android:name="io.flutter.embedding.android.EnableScreenshotSecurity"
      android:value="true" />
  </activity>
</application>

<!-- Network security config -->
<application
  android:networkSecurityConfig="@xml/network_security_config">
</application>
```

```xml
<!-- android/app/src/main/res/xml/network_security_config.xml -->
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
  <domain-config cleartextTrafficPermitted="false">
    <domain includeSubdomains="true">yourdomain.com</domain>
  </domain-config>
</network-security-config>
```

### ✅ iOS Security

```xml
<!-- ios/Runner/Info.plist -->

<!-- Prevent screenshots -->
<key>UIApplicationExitsOnSuspend</key>
<false/>

<!-- App Transport Security -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <false/>
  <key>NSAllowsLocalNetworking</key>
  <false/>
</dict>
```

## Code Obfuscation

### ✅ Enable Obfuscation

```bash
# Build with obfuscation
flutter build apk --obfuscate --split-debug-info=./debug-info

# iOS
flutter build ios --obfuscate --split-debug-info=./debug-info
```

### ✅ ProGuard Rules

```proguard
# android/app/proguard-rules.pro

# Keep Flutter classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep your model classes
-keep class com.yourapp.models.** { *; }

# Remove logging
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
```

## Secure Deep Links

### ✅ Validate Deep Link Parameters

```dart
class DeepLinkHandler {
  static Future<void> handleDeepLink(Uri uri) async {
    // Validate scheme
    if (uri.scheme != 'https' && uri.scheme != 'yourapp') {
      throw SecurityException('Invalid scheme');
    }

    // Validate host
    if (uri.host != 'yourdomain.com') {
      throw SecurityException('Invalid host');
    }

    // Sanitize parameters
    final params = uri.queryParameters.map(
      (key, value) => MapEntry(
        key,
        InputValidator.sanitizeHtml(value),
      ),
    );

    // Route based on path
    switch (uri.path) {
      case '/profile':
        final userId = params['id'];
        if (userId != null && isValidUserId(userId)) {
          navigateToProfile(userId);
        }
        break;
      default:
        throw SecurityException('Invalid path');
    }
  }

  static bool isValidUserId(String id) {
    return RegExp(r'^[a-zA-Z0-9]{10,}$').hasMatch(id);
  }
}
```

## Logging Security

### ✅ Never Log Sensitive Data

```dart
import 'package:logger/logger.dart';

class SecureLogger {
  static final _logger = Logger(
    filter: ProductionFilter(), // Only log in debug mode
    printer: PrettyPrinter(),
  );

  static void log(String message, {dynamic error, StackTrace? stackTrace}) {
    // Remove sensitive data before logging
    final sanitized = _sanitizeLog(message);

    if (error != null) {
      _logger.e(sanitized, error, stackTrace);
    } else {
      _logger.i(sanitized);
    }
  }

  static String _sanitizeLog(String message) {
    // Remove potential sensitive patterns
    var sanitized = message;

    // Remove email addresses
    sanitized = sanitized.replaceAll(
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
      '[EMAIL_REDACTED]',
    );

    // Remove credit card numbers
    sanitized = sanitized.replaceAll(
      RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b'),
      '[CC_REDACTED]',
    );

    // Remove phone numbers
    sanitized = sanitized.replaceAll(
      RegExp(r'\b\+?[1-9]\d{1,14}\b'),
      '[PHONE_REDACTED]',
    );

    // Remove tokens (Bearer pattern)
    sanitized = sanitized.replaceAll(
      RegExp(r'Bearer\s+[\w-]+\.[\w-]+\.[\w-]+'),
      'Bearer [TOKEN_REDACTED]',
    );

    return sanitized;
  }
}

// ❌ NEVER log sensitive data
logger.d('User password: $password'); // NEVER!
logger.d('API token: $token'); // NEVER!
logger.d('Credit card: $ccNumber'); // NEVER!

// ✅ Use secure logger
SecureLogger.log('User login attempt'); // Safe
```

## Permissions Security

### ✅ Request Minimum Permissions

```yaml
# Only request what you need
# android/app/src/main/AndroidManifest.xml
<uses-permission android:name="android.permission.CAMERA" />

# NOT this unless you need it:
# <uses-permission android:name="android.permission.READ_CONTACTS" />
```

### ✅ Runtime Permission Handling

```dart
import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      // Show dialog to open settings
      await openAppSettings();
      return false;
    }

    return false;
  }
}
```

## Security Checklist

### ✅ Pre-Release Security Audit

- [ ] All secrets in secure storage (not SharedPreferences)
- [ ] HTTPS only for all network requests
- [ ] Certificate pinning implemented
- [ ] API tokens refreshed automatically
- [ ] Biometric auth for sensitive operations
- [ ] Data encrypted at rest
- [ ] Input validation on all user inputs
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (sanitize HTML)
- [ ] Code obfuscation enabled
- [ ] ProGuard/R8 configured
- [ ] Debug logs removed from production
- [ ] Sensitive data not logged
- [ ] Screenshots disabled for secure screens
- [ ] Deep links validated and sanitized
- [ ] Minimum permissions requested
- [ ] Runtime permissions handled gracefully
- [ ] No hardcoded API keys in code
- [ ] Environment variables for secrets
- [ ] Dependency vulnerabilities checked
- [ ] Security patches applied

### ✅ Environment Variables

```dart
// Use flutter_dotenv for environment variables
import 'package:flutter_dotenv/flutter_dotenv.dart';

// .env file (ADD TO .gitignore!)
// API_KEY=your_api_key_here
// API_URL=https://api.example.com

// Load in main()
await dotenv.load(fileName: ".env");

// Access
final apiKey = dotenv.env['API_KEY'];
final apiUrl = dotenv.env['API_URL'];

// ❌ NEVER commit .env to git!
// Add to .gitignore:
# .env
# .env.production
```

## Common Vulnerabilities

### ❌ Avoid These

```dart
// 1. Hardcoded secrets
const apiKey = 'abc123'; // NEVER!

// 2. Plain text storage
prefs.setString('password', 'secret'); // NEVER!

// 3. HTTP in production
final url = 'http://api.example.com'; // NEVER!

// 4. Unvalidated input
final userId = request.params['id']; // Validate first!

// 5. SQL injection
db.rawQuery('SELECT * FROM users WHERE id = $id'); // Use parameterized!

// 6. Logging sensitive data
print('Password: $password'); // NEVER!

// 7. Weak encryption
final hash = md5.convert(password.codeUnits); // Use bcrypt!

// 8. No authentication
// Unprotected routes without auth checks
```

This security guide ensures your Flutter app follows industry best practices.
