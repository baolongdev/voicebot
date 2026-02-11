import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:voicebot/core/config/app_config.dart';
import 'package:voicebot/core/logging/app_logger.dart';

class GithubUpdater {
  GithubUpdater({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> checkAndUpdateIfNeeded() async {
    if (!Platform.isAndroid) {
      return;
    }
    if (!AppConfig.githubAutoUpdateEnabled) {
      return;
    }
    try {
      final updateInfo = await _fetchUpdateInfo();
      if (updateInfo == null) {
        return;
      }
      final info = await PackageInfo.fromPlatform();
      if (!_isNewerVersion(info, updateInfo)) {
        AppLogger.log('Update', 'Already on latest version.');
        return;
      }
      final file = await _downloadApk(updateInfo.downloadUrl);
      if (file == null) {
        return;
      }
      await _installApk(file);
    } catch (e) {
      AppLogger.log('Update', 'Update check failed: $e', level: 'E');
    }
  }

  Future<_UpdateInfo?> _fetchUpdateInfo() async {
    final uri = Uri.parse(AppConfig.githubUpdateJsonUrl);
    final headers = <String, String>{};
    if (AppConfig.githubToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${AppConfig.githubToken}';
    }
    final response = await _getWithRetry(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.log(
        'Update',
        'Update JSON failed: ${response.statusCode}',
        level: 'W',
      );
      return null;
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _UpdateInfo.fromJson(json);
  }

  Future<File?> _downloadApk(String url) async {
    final uri = Uri.parse(url);
    final headers = <String, String>{};
    if (AppConfig.githubToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${AppConfig.githubToken}';
    }
    final response = await _getWithRetry(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.log(
        'Update',
        'Download failed: ${response.statusCode}',
        level: 'W',
      );
      return null;
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}app-release.apk',
    );
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }

  Future<http.Response> _getWithRetry(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _client
            .get(uri, headers: headers)
            .timeout(Duration(milliseconds: AppConfig.githubUpdateCheckTimeoutMs));
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        final delayMs = 1000 * attempt;
        AppLogger.log(
          'Update',
          'Request failed (attempt $attempt/$maxAttempts): $e',
          level: 'W',
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
    throw StateError('Unreachable');
  }

  Future<void> _installApk(File file) async {
    const channel = MethodChannel('voicebot/update');
    await channel.invokeMethod<void>(
      'installApk',
      <String, dynamic>{'path': file.path},
    );
  }
}

class _UpdateInfo {
  const _UpdateInfo({
    required this.latestVersion,
    required this.latestVersionCode,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.mandatory,
    required this.releasedAt,
  });

  final String latestVersion;
  final int latestVersionCode;
  final String downloadUrl;
  final String releaseNotes;
  final bool mandatory;
  final String releasedAt;

  factory _UpdateInfo.fromJson(Map<String, dynamic> json) {
    return _UpdateInfo(
      latestVersion: json['latestVersion'] as String? ?? '',
      latestVersionCode: json['latestVersionCode'] as int? ?? 0,
      downloadUrl: json['downloadUrl'] as String? ?? '',
      releaseNotes: json['releaseNotes'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
      releasedAt: json['releasedAt'] as String? ?? '',
    );
  }
}

bool _isNewerVersion(PackageInfo info, _UpdateInfo update) {
  final currentCode = int.tryParse(info.buildNumber) ?? 0;
  if (update.latestVersionCode > currentCode) {
    return true;
  }
  if (update.latestVersionCode < currentCode) {
    return false;
  }
  return update.latestVersion != info.version;
}
