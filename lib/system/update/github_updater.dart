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
  GithubUpdater._internal({http.Client? client})
    : _client = client ?? http.Client();

  factory GithubUpdater({http.Client? client}) {
    if (client != null) {
      return GithubUpdater._internal(client: client);
    }
    return _shared;
  }

  final http.Client _client;
  static final GithubUpdater _shared = GithubUpdater._internal();
  static bool _inProgress = false;
  static final ValueNotifier<UpdateDownloadState> downloadState = ValueNotifier(
    UpdateDownloadState.idle(),
  );

  Future<void> checkAndUpdateIfNeeded() async {
    final isAndroid = Platform.isAndroid;
    if (!AppConfig.githubAutoUpdateEnabled) {
      return;
    }
    if (_inProgress) {
      AppLogger.log('Update', 'Check skipped: already running.', level: 'W');
      return;
    }
    try {
      _inProgress = true;
      _setDownloadState(UpdateDownloadState.checking());
      AppLogger.log('Update', 'Check start');
      final updateInfo = await _fetchUpdateInfo();
      if (updateInfo == null) {
        AppLogger.log('Update', 'No update info', level: 'W');
        _setDownloadState(UpdateDownloadState.idle());
        return;
      }
      _setDownloadState(
        downloadState.value.copyWith(
          latestVersion: updateInfo.latestVersion,
          releaseNotes: updateInfo.releaseNotes,
          commitMessage: updateInfo.commitMessage,
          releasedAt: updateInfo.releasedAt,
        ),
      );
      final info = await PackageInfo.fromPlatform();
      if (!_isNewerVersion(info, updateInfo)) {
        AppLogger.log('Update', 'Already on latest version.');
        _setDownloadState(
          UpdateDownloadState.idle().copyWith(
            latestVersion: updateInfo.latestVersion,
            releaseNotes: updateInfo.releaseNotes,
            commitMessage: updateInfo.commitMessage,
            releasedAt: updateInfo.releasedAt,
          ),
        );
        return;
      }
      if (!isAndroid) {
        AppLogger.log(
          'Update',
          'Update metadata fetched. APK download/install is Android-only.',
        );
        _setDownloadState(
          UpdateDownloadState.updateAvailable().copyWith(
            latestVersion: updateInfo.latestVersion,
            releaseNotes: updateInfo.releaseNotes,
            commitMessage: updateInfo.commitMessage,
            releasedAt: updateInfo.releasedAt,
          ),
        );
        return;
      }
      if (updateInfo.downloadUrl.isEmpty && updateInfo.apiDownloadUrl.isEmpty) {
        AppLogger.log('Update', 'No APK asset found for update.', level: 'W');
        _setDownloadState(
          downloadState.value.copyWith(
            status: UpdateDownloadStatus.failed,
            progress: null,
            error: 'No APK asset found',
          ),
        );
        return;
      }
      AppLogger.log(
        'Update',
        'Update available version=${updateInfo.latestVersion} '
            'code=${updateInfo.latestVersionCode} '
            'url=${updateInfo.downloadUrl}',
      );
      _setDownloadState(
        UpdateDownloadState.downloading(
          version: updateInfo.latestVersion,
          progress: 0,
          latestVersion: updateInfo.latestVersion,
          releaseNotes: updateInfo.releaseNotes,
          commitMessage: updateInfo.commitMessage,
          releasedAt: updateInfo.releasedAt,
        ),
      );
      final file = await _downloadApk(updateInfo);
      if (file == null) {
        return;
      }
      _setDownloadState(
        UpdateDownloadState.completed(
          version: updateInfo.latestVersion,
          latestVersion: updateInfo.latestVersion,
          releaseNotes: updateInfo.releaseNotes,
          commitMessage: updateInfo.commitMessage,
          releasedAt: updateInfo.releasedAt,
        ),
      );
      await _installApk(file);
    } catch (e) {
      AppLogger.log('Update', 'Update check failed: $e', level: 'E');
      _setDownloadState(
        downloadState.value.copyWith(
          status: UpdateDownloadStatus.failed,
          progress: null,
          error: e.toString(),
        ),
      );
    } finally {
      _inProgress = false;
    }
  }

  Future<_UpdateInfo?> _fetchUpdateInfo() async {
    try {
      final updateJsonInfo = await _fetchUpdateInfoFromUpdateJson();
      if (updateJsonInfo != null) {
        return updateJsonInfo;
      }
    } catch (e) {
      AppLogger.log('Update', 'update.json fetch error: $e', level: 'W');
    }
    try {
      return await _fetchUpdateInfoFromGithubRelease();
    } catch (e) {
      AppLogger.log('Update', 'GitHub release fetch error: $e', level: 'W');
      return null;
    }
  }

  Future<_UpdateInfo?> _fetchUpdateInfoFromUpdateJson() async {
    final rawUrl = AppConfig.githubUpdateJsonUrl.trim();
    if (rawUrl.isEmpty) {
      return null;
    }
    final uri = Uri.parse(rawUrl);
    AppLogger.log('Update', 'Fetching update json: $uri');
    final response = await _getWithRetry(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.log(
        'Update',
        'update.json fetch failed: ${response.statusCode}',
        level: 'W',
      );
      return null;
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      AppLogger.log('Update', 'update.json payload is not object', level: 'W');
      return null;
    }
    return _UpdateInfo.fromUpdateJson(json);
  }

  Future<_UpdateInfo?> _fetchUpdateInfoFromGithubRelease() async {
    final uri = Uri.parse(
      'https://api.github.com/repos/'
      '${AppConfig.githubOwner}/${AppConfig.githubRepo}/releases/latest',
    );
    final headers = <String, String>{};
    headers['Accept'] = 'application/vnd.github+json';
    headers['X-GitHub-Api-Version'] = '2022-11-28';
    if (AppConfig.githubToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${AppConfig.githubToken}';
    }
    AppLogger.log('Update', 'Fetching release: $uri');
    final response = await _getWithRetry(uri, headers: headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.log(
        'Update',
        'GitHub release fetch failed: ${response.statusCode}',
        level: 'W',
      );
      return null;
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return _UpdateInfo.fromGithubReleaseJson(json);
  }

  Future<File?> _downloadApk(_UpdateInfo updateInfo) async {
    http.StreamedResponse response;
    final apiUrl = updateInfo.apiDownloadUrl.trim();
    if (apiUrl.isNotEmpty) {
      final apiHeaders = _buildApiDownloadHeaders();
      AppLogger.log('Update', 'Downloading APK (API): $apiUrl');
      try {
        response = await _sendWithRetry(
          Uri.parse(apiUrl),
          headers: apiHeaders,
          timeoutMs: AppConfig.githubDownloadTimeoutMs,
        );
      } catch (e) {
        AppLogger.log('Update', 'API download failed: $e', level: 'W');
        response = await _downloadViaBrowser(updateInfo.downloadUrl);
      }
    } else {
      response = await _downloadViaBrowser(updateInfo.downloadUrl);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      AppLogger.log(
        'Update',
        'Download failed: ${response.statusCode}',
        level: 'W',
      );
      _setDownloadState(
        downloadState.value.copyWith(
          status: UpdateDownloadStatus.failed,
          progress: null,
          error: 'Download failed: ${response.statusCode}',
        ),
      );
      return null;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}app-release.apk');
    await _writeStreamToFile(response, file);
    return file;
  }

  Future<http.StreamedResponse> _downloadViaBrowser(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw StateError('Empty download url');
    }
    final headers = <String, String>{};
    if (AppConfig.githubToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${AppConfig.githubToken}';
    }
    AppLogger.log('Update', 'Downloading APK (browser): $trimmed');
    return _sendWithRetry(
      Uri.parse(trimmed),
      headers: headers,
      timeoutMs: AppConfig.githubDownloadTimeoutMs,
    );
  }

  Map<String, String> _buildApiDownloadHeaders() {
    final headers = <String, String>{
      'Accept': 'application/octet-stream',
      'X-GitHub-Api-Version': '2022-11-28',
    };
    if (AppConfig.githubToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${AppConfig.githubToken}';
    }
    return headers;
  }

  Future<void> _writeStreamToFile(
    http.StreamedResponse response,
    File file,
  ) async {
    final sink = file.openWrite();
    final totalBytes = response.contentLength ?? -1;
    var receivedBytes = 0;
    var lastProgress = -1;
    var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
    _setDownloadState(
      downloadState.value.copyWith(
        status: UpdateDownloadStatus.downloading,
        progress: totalBytes > 0 ? 0 : null,
        receivedBytes: 0,
        totalBytes: totalBytes > 0 ? totalBytes : null,
      ),
    );
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final progress = ((receivedBytes / totalBytes) * 100)
              .clamp(0, 100)
              .floor();
          final now = DateTime.now();
          if (progress != lastProgress &&
              now.difference(lastEmit).inMilliseconds >= 200) {
            lastProgress = progress;
            lastEmit = now;
            _setDownloadState(
              downloadState.value.copyWith(
                status: UpdateDownloadStatus.downloading,
                progress: receivedBytes / totalBytes,
                receivedBytes: receivedBytes,
                totalBytes: totalBytes,
              ),
            );
          }
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    if (totalBytes > 0 && receivedBytes != totalBytes) {
      _setDownloadState(
        downloadState.value.copyWith(
          status: UpdateDownloadStatus.failed,
          progress: null,
          error: 'Download incomplete',
        ),
      );
      throw StateError('Download incomplete');
    }
  }

  Future<http.Response> _getWithRetry(
    Uri uri, {
    Map<String, String>? headers,
    int? timeoutMs,
  }) async {
    const maxAttempts = 3;
    final effectiveTimeoutMs =
        timeoutMs ?? AppConfig.githubUpdateCheckTimeoutMs;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        AppLogger.log('Update', 'HTTP GET start url=$uri attempt=$attempt');
        return await _client
            .get(uri, headers: headers)
            .timeout(Duration(milliseconds: effectiveTimeoutMs));
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        final delayMs = 1000 * attempt;
        AppLogger.log(
          'Update',
          'HTTP GET failed url=$uri attempt=$attempt error=$e',
          level: 'W',
        );
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

  Future<http.StreamedResponse> _sendWithRetry(
    Uri uri, {
    Map<String, String>? headers,
    int? timeoutMs,
  }) async {
    const maxAttempts = 3;
    final effectiveTimeoutMs =
        timeoutMs ?? AppConfig.githubUpdateCheckTimeoutMs;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        AppLogger.log('Update', 'HTTP SEND start url=$uri attempt=$attempt');
        final request = http.Request('GET', uri);
        if (headers != null) {
          request.headers.addAll(headers);
        }
        return await _client
            .send(request)
            .timeout(Duration(milliseconds: effectiveTimeoutMs));
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        final delayMs = 1000 * attempt;
        AppLogger.log(
          'Update',
          'HTTP SEND failed url=$uri attempt=$attempt error=$e',
          level: 'W',
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
    throw StateError('Unreachable');
  }

  Future<void> _installApk(File file) async {
    const channel = MethodChannel('voicebot/update');
    await channel.invokeMethod<void>('installApk', <String, dynamic>{
      'path': file.path,
    });
  }

  static void _setDownloadState(UpdateDownloadState state) {
    if (downloadState.value == state) {
      return;
    }
    downloadState.value = state;
  }
}

enum UpdateDownloadStatus {
  idle,
  checking,
  updateAvailable,
  downloading,
  completed,
  failed,
}

@immutable
class UpdateDownloadState {
  const UpdateDownloadState({
    required this.status,
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
    required this.version,
    required this.error,
    required this.latestVersion,
    required this.releaseNotes,
    required this.commitMessage,
    required this.releasedAt,
  });

  final UpdateDownloadStatus status;
  final double? progress;
  final int receivedBytes;
  final int? totalBytes;
  final String? version;
  final String? error;
  final String? latestVersion;
  final String? releaseNotes;
  final String? commitMessage;
  final String? releasedAt;

  factory UpdateDownloadState.idle() => const UpdateDownloadState(
    status: UpdateDownloadStatus.idle,
    progress: null,
    receivedBytes: 0,
    totalBytes: null,
    version: null,
    error: null,
    latestVersion: null,
    releaseNotes: null,
    commitMessage: null,
    releasedAt: null,
  );

  factory UpdateDownloadState.checking() => const UpdateDownloadState(
    status: UpdateDownloadStatus.checking,
    progress: null,
    receivedBytes: 0,
    totalBytes: null,
    version: null,
    error: null,
    latestVersion: null,
    releaseNotes: null,
    commitMessage: null,
    releasedAt: null,
  );

  factory UpdateDownloadState.updateAvailable() => const UpdateDownloadState(
    status: UpdateDownloadStatus.updateAvailable,
    progress: null,
    receivedBytes: 0,
    totalBytes: null,
    version: null,
    error: null,
    latestVersion: null,
    releaseNotes: null,
    commitMessage: null,
    releasedAt: null,
  );

  factory UpdateDownloadState.downloading({
    required String? version,
    required double progress,
    String? latestVersion,
    String? releaseNotes,
    String? commitMessage,
    String? releasedAt,
  }) => UpdateDownloadState(
    status: UpdateDownloadStatus.downloading,
    progress: progress,
    receivedBytes: 0,
    totalBytes: null,
    version: version,
    error: null,
    latestVersion: latestVersion,
    releaseNotes: releaseNotes,
    commitMessage: commitMessage,
    releasedAt: releasedAt,
  );

  factory UpdateDownloadState.completed({
    required String? version,
    String? latestVersion,
    String? releaseNotes,
    String? commitMessage,
    String? releasedAt,
  }) => UpdateDownloadState(
    status: UpdateDownloadStatus.completed,
    progress: 1,
    receivedBytes: 0,
    totalBytes: null,
    version: version,
    error: null,
    latestVersion: latestVersion,
    releaseNotes: releaseNotes,
    commitMessage: commitMessage,
    releasedAt: releasedAt,
  );

  factory UpdateDownloadState.failed({required String? error}) =>
      UpdateDownloadState(
        status: UpdateDownloadStatus.failed,
        progress: null,
        receivedBytes: 0,
        totalBytes: null,
        version: null,
        error: error,
        latestVersion: null,
        releaseNotes: null,
        commitMessage: null,
        releasedAt: null,
      );

  UpdateDownloadState copyWith({
    UpdateDownloadStatus? status,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    String? version,
    String? error,
    String? latestVersion,
    String? releaseNotes,
    String? commitMessage,
    String? releasedAt,
  }) {
    return UpdateDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      version: version ?? this.version,
      error: error ?? this.error,
      latestVersion: latestVersion ?? this.latestVersion,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      commitMessage: commitMessage ?? this.commitMessage,
      releasedAt: releasedAt ?? this.releasedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpdateDownloadState &&
        other.status == status &&
        other.progress == progress &&
        other.receivedBytes == receivedBytes &&
        other.totalBytes == totalBytes &&
        other.version == version &&
        other.error == error &&
        other.latestVersion == latestVersion &&
        other.releaseNotes == releaseNotes &&
        other.commitMessage == commitMessage &&
        other.releasedAt == releasedAt;
  }

  @override
  int get hashCode => Object.hash(
    status,
    progress,
    receivedBytes,
    totalBytes,
    version,
    error,
    latestVersion,
    releaseNotes,
    commitMessage,
    releasedAt,
  );
}

class _UpdateInfo {
  const _UpdateInfo({
    required this.latestVersion,
    required this.latestVersionCode,
    required this.downloadUrl,
    required this.apiDownloadUrl,
    required this.releaseNotes,
    required this.commitMessage,
    required this.mandatory,
    required this.releasedAt,
  });

  final String latestVersion;
  final int latestVersionCode;
  final String downloadUrl;
  final String apiDownloadUrl;
  final String releaseNotes;
  final String commitMessage;
  final bool mandatory;
  final String releasedAt;

  factory _UpdateInfo.fromUpdateJson(Map<String, dynamic> json) {
    final latestVersion = (json['latestVersion'] as String? ?? '').trim();
    final latestVersionCodeRaw = json['latestVersionCode'];
    final latestVersionCode = latestVersionCodeRaw is int
        ? latestVersionCodeRaw
        : int.tryParse(latestVersionCodeRaw?.toString() ?? '') ?? 0;
    return _UpdateInfo(
      latestVersion: latestVersion,
      latestVersionCode: latestVersionCode,
      downloadUrl: (json['downloadUrl'] as String? ?? '').trim(),
      apiDownloadUrl: '',
      releaseNotes: (json['releaseNotes'] as String? ?? '').trim(),
      commitMessage: (json['commitMessage'] as String? ?? '').trim(),
      mandatory: json['mandatory'] == true,
      releasedAt: (json['releasedAt'] as String? ?? '').trim(),
    );
  }

  factory _UpdateInfo.fromGithubReleaseJson(Map<String, dynamic> json) {
    final tagName = (json['tag_name'] as String? ?? '').trim();
    final releaseNotes = json['body'] as String? ?? '';
    final commitMessage = (json['name'] as String? ?? '').trim();
    final publishedAt = json['published_at'] as String? ?? '';
    final assets = (json['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final asset = _pickApkAsset(assets);
    return _UpdateInfo(
      latestVersion: _normalizeTagToVersion(tagName),
      latestVersionCode: _parseVersionCodeFromTag(tagName),
      downloadUrl: asset?['browser_download_url'] as String? ?? '',
      apiDownloadUrl: asset?['url'] as String? ?? '',
      releaseNotes: releaseNotes,
      commitMessage: commitMessage,
      mandatory: false,
      releasedAt: publishedAt,
    );
  }
}

bool _isNewerVersion(PackageInfo info, _UpdateInfo update) {
  final currentCode = int.tryParse(info.buildNumber.trim()) ?? 0;
  final updateCode = update.latestVersionCode;
  final currentVersion = _normalizeTagToVersion(info.version.trim());
  final updateVersion = _normalizeTagToVersion(update.latestVersion.trim());

  if (updateVersion.isEmpty || currentVersion.isEmpty) {
    return false;
  }
  final versionCompare = _compareSemver(updateVersion, currentVersion);
  if (versionCompare > 0) {
    return true;
  }
  if (versionCompare < 0) {
    return false;
  }
  if (updateCode > 0 && currentCode > 0) {
    return updateCode > currentCode;
  }
  return false;
}

Map<String, dynamic>? _pickApkAsset(List<Map<String, dynamic>> assets) {
  final contains = AppConfig.githubAssetNameContains.trim();
  final extension = AppConfig.githubAssetExtension.trim();
  for (final asset in assets) {
    final name = (asset['name'] as String? ?? '').trim();
    if (name.isEmpty) {
      continue;
    }
    if (extension.isNotEmpty && !name.endsWith(extension)) {
      continue;
    }
    if (contains.isNotEmpty && !name.contains(contains)) {
      continue;
    }
    return asset;
  }
  return null;
}

String _normalizeTagToVersion(String tag) {
  var value = tag.trim();
  if (value.startsWith('v')) {
    value = value.substring(1);
  }
  final plusIndex = value.indexOf('+');
  if (plusIndex > 0) {
    return value.substring(0, plusIndex);
  }
  return value;
}

int _parseVersionCodeFromTag(String tag) {
  final normalized = tag.trim();
  final plusIndex = normalized.indexOf('+');
  if (plusIndex == -1 || plusIndex == normalized.length - 1) {
    return 0;
  }
  return int.tryParse(normalized.substring(plusIndex + 1)) ?? 0;
}

int _compareSemver(String left, String right) {
  List<int> parseParts(String value) {
    final clean = value
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^v'), '')
        .split('+')
        .first
        .split('-')
        .first;
    final parts = clean.split('.');
    return parts
        .map(
          (part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        )
        .toList(growable: false);
  }

  final a = parseParts(left);
  final b = parseParts(right);
  final length = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < length; i++) {
    final av = i < a.length ? a[i] : 0;
    final bv = i < b.length ? b[i] : 0;
    if (av > bv) {
      return 1;
    }
    if (av < bv) {
      return -1;
    }
  }
  return 0;
}
