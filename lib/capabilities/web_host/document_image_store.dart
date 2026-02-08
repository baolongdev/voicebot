import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../core/config/app_config.dart';

class DocumentImageStore {
  DocumentImageStore({
    required Directory rootDirectory,
    this.maxFileBytes = defaultMaxFileBytes,
  }) : _rootDirectory = rootDirectory;

  static const int defaultMaxFileBytes = AppConfig.webHostImageUploadMaxBytes;

  final Directory _rootDirectory;
  final int maxFileBytes;
  final Map<String, _StoredDocumentImage> _imagesById =
      <String, _StoredDocumentImage>{};
  final Random _random = Random();

  bool _isInitialized = false;
  File? _metaFile;
  Directory? _filesDirectory;

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    if (!await _rootDirectory.exists()) {
      await _rootDirectory.create(recursive: true);
    }
    _filesDirectory = Directory('${_rootDirectory.path}${Platform.pathSeparator}files');
    if (!await _filesDirectory!.exists()) {
      await _filesDirectory!.create(recursive: true);
    }
    _metaFile = File('${_rootDirectory.path}${Platform.pathSeparator}images_meta.json');
    await _load();
    _isInitialized = true;
  }

  Future<Map<String, Object?>> saveImage({
    required String docName,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    String? caption,
  }) async {
    await initialize();
    final safeDocName = docName.trim();
    if (safeDocName.isEmpty) {
      throw Exception('Thiếu tên tài liệu.');
    }
    if (bytes.isEmpty) {
      throw Exception('File ảnh trống.');
    }
    if (bytes.length > maxFileBytes) {
      throw Exception('Kích thước ảnh vượt quá giới hạn ${maxFileBytes ~/ (1024 * 1024)}MB.');
    }

    final safeMime = mimeType.trim().toLowerCase();
    final safeFileName = _sanitizeFileName(fileName);
    final extension =
        _resolveExtension(fileName: safeFileName, mimeType: safeMime);
    final id =
        '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 20)}';
    final storageFileName = '$id$extension';
    final filePath =
        '${_filesDirectory!.path}${Platform.pathSeparator}$storageFileName';
    final target = File(filePath);
    await target.writeAsBytes(bytes, flush: true);

    final now = DateTime.now().toIso8601String();
    final image = _StoredDocumentImage(
      id: id,
      docName: safeDocName,
      fileName: safeFileName,
      mimeType: safeMime,
      bytes: bytes.length,
      createdAt: now,
      storageFileName: storageFileName,
      caption: caption?.trim(),
    );
    _imagesById[id] = image;
    await _persist();
    return _toPublicMap(image);
  }

  Future<Map<String, Object?>> saveImageFile({
    required String docName,
    required String fileName,
    required String mimeType,
    required File sourceFile,
    required int bytes,
    String? caption,
  }) async {
    await initialize();
    final safeDocName = docName.trim();
    if (safeDocName.isEmpty) {
      throw Exception('Thiếu tên tài liệu.');
    }
    if (bytes <= 0) {
      await _safeDelete(sourceFile);
      throw Exception('File ảnh trống.');
    }
    if (bytes > maxFileBytes) {
      await _safeDelete(sourceFile);
      throw Exception(
        'Kích thước ảnh vượt quá giới hạn ${maxFileBytes ~/ (1024 * 1024)}MB.',
      );
    }

    final safeMime = mimeType.trim().toLowerCase();
    final safeFileName = _sanitizeFileName(fileName);
    final extension =
        _resolveExtension(fileName: safeFileName, mimeType: safeMime);
    final id =
        '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 20)}';
    final storageFileName = '$id$extension';
    final filePath =
        '${_filesDirectory!.path}${Platform.pathSeparator}$storageFileName';
    final target = File(filePath);
    try {
      await _moveToTarget(sourceFile, target);
    } catch (error) {
      await _safeDelete(target);
      await _safeDelete(sourceFile);
      throw Exception('Không thể lưu ảnh: $error');
    }

    final now = DateTime.now().toIso8601String();
    final image = _StoredDocumentImage(
      id: id,
      docName: safeDocName,
      fileName: safeFileName,
      mimeType: safeMime,
      bytes: bytes,
      createdAt: now,
      storageFileName: storageFileName,
      caption: caption?.trim(),
    );
    _imagesById[id] = image;
    await _persist();
    return _toPublicMap(image);
  }

  Future<List<Map<String, Object?>>> listImagesByDocument(String docName) async {
    await initialize();
    final safeDocName = docName.trim();
    if (safeDocName.isEmpty) {
      return <Map<String, Object?>>[];
    }
    final items = _imagesById.values
        .where((item) => item.docName == safeDocName)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.map(_toPublicMap).toList();
  }

  Future<List<Map<String, Object?>>> listAllImages() async {
    await initialize();
    final items = _imagesById.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.map(_toPublicMap).toList();
  }

  Future<StoredImageBinary?> readImageBinary(String imageId) async {
    await initialize();
    final id = imageId.trim();
    if (id.isEmpty) {
      return null;
    }
    final image = _imagesById[id];
    if (image == null) {
      return null;
    }
    final file = File(
      '${_filesDirectory!.path}${Platform.pathSeparator}${image.storageFileName}',
    );
    if (!await file.exists()) {
      _imagesById.remove(id);
      await _persist();
      return null;
    }
    final bytes = await file.readAsBytes();
    return StoredImageBinary(
      id: image.id,
      docName: image.docName,
      fileName: image.fileName,
      mimeType: image.mimeType,
      bytes: bytes,
      createdAt: image.createdAt,
      caption: image.caption,
    );
  }

  Future<bool> deleteImage(String imageId) async {
    await initialize();
    final id = imageId.trim();
    if (id.isEmpty) {
      return false;
    }
    final image = _imagesById.remove(id);
    if (image == null) {
      return false;
    }
    final file = File(
      '${_filesDirectory!.path}${Platform.pathSeparator}${image.storageFileName}',
    );
    if (await file.exists()) {
      await file.delete();
    }
    await _persist();
    return true;
  }

  Future<int> migrateDocumentName({
    required String oldName,
    required String newName,
  }) async {
    await initialize();
    final from = oldName.trim();
    final to = newName.trim();
    if (from.isEmpty || to.isEmpty || from == to) {
      return 0;
    }
    var moved = 0;
    for (final entry in _imagesById.values) {
      if (entry.docName == from) {
        entry.docName = to;
        moved += 1;
      }
    }
    if (moved > 0) {
      await _persist();
    }
    return moved;
  }

  Future<int> clearDocument(String docName) async {
    await initialize();
    final safeDocName = docName.trim();
    if (safeDocName.isEmpty) {
      return 0;
    }
    final targetIds = _imagesById.values
        .where((item) => item.docName == safeDocName)
        .map((item) => item.id)
        .toList();
    for (final id in targetIds) {
      await deleteImage(id);
    }
    return targetIds.length;
  }

  Future<int> clearAll() async {
    await initialize();
    final removed = _imagesById.length;
    _imagesById.clear();
    if (_filesDirectory != null && await _filesDirectory!.exists()) {
      await _filesDirectory!.delete(recursive: true);
      await _filesDirectory!.create(recursive: true);
    }
    await _persist();
    return removed;
  }

  Future<void> _load() async {
    if (_metaFile == null || !await _metaFile!.exists()) {
      return;
    }
    try {
      final raw = await _metaFile!.readAsString();
      if (raw.trim().isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final images = decoded['images'];
      if (images is! List) {
        return;
      }
      _imagesById.clear();
      for (final item in images) {
        if (item is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(item);
        final image = _StoredDocumentImage.fromJson(map);
        if (image == null) {
          continue;
        }
        _imagesById[image.id] = image;
      }
    } catch (_) {
      // Keep empty state if metadata is malformed.
    }
  }

  Future<void> _persist() async {
    if (_metaFile == null) {
      return;
    }
    final payload = <String, Object?>{
      'version': '1',
      'saved_at': DateTime.now().toIso8601String(),
      'images': _imagesById.values
          .map((item) => item.toJson())
          .toList(growable: false),
    };
    await _metaFile!.writeAsString(jsonEncode(payload), flush: true);
  }

  Map<String, Object?> _toPublicMap(_StoredDocumentImage image) {
    return <String, Object?>{
      'id': image.id,
      'doc_name': image.docName,
      'file_name': image.fileName,
      'mime_type': image.mimeType,
      'bytes': image.bytes,
      'created_at': image.createdAt,
      'caption': image.caption,
    };
  }

  String _sanitizeFileName(String fileName) {
    final base = fileName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (base.isEmpty) {
      return 'image';
    }
    if (base.length > 120) {
      return base.substring(0, 120);
    }
    return base;
  }

  String _resolveExtension({
    required String fileName,
    required String mimeType,
  }) {
    final extFromName = _extractExtension(fileName);
    if (extFromName.isNotEmpty) {
      return extFromName;
    }
    switch (mimeType) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      default:
        return '.bin';
    }
  }

  String _extractExtension(String fileName) {
    final index = fileName.lastIndexOf('.');
    if (index <= 0 || index >= fileName.length - 1) {
      return '';
    }
    final extension = fileName.substring(index).toLowerCase();
    if (!RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension)) {
      return '';
    }
    return extension;
  }

  Future<void> _moveToTarget(File source, File target) async {
    try {
      await source.rename(target.path);
    } on FileSystemException {
      await source.copy(target.path);
      await _safeDelete(source);
    }
  }

  Future<void> _safeDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

class StoredImageBinary {
  const StoredImageBinary({
    required this.id,
    required this.docName,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.createdAt,
    this.caption,
  });

  final String id;
  final String docName;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final String createdAt;
  final String? caption;
}

class _StoredDocumentImage {
  _StoredDocumentImage({
    required this.id,
    required this.docName,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.createdAt,
    required this.storageFileName,
    this.caption,
  });

  final String id;
  String docName;
  final String fileName;
  final String mimeType;
  final int bytes;
  final String createdAt;
  final String storageFileName;
  final String? caption;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'doc_name': docName,
      'file_name': fileName,
      'mime_type': mimeType,
      'bytes': bytes,
      'created_at': createdAt,
      'storage_file_name': storageFileName,
      'caption': caption,
    };
  }

  static _StoredDocumentImage? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    final docName = (json['doc_name'] ?? '').toString().trim();
    final fileName = (json['file_name'] ?? '').toString().trim();
    final mimeType = (json['mime_type'] ?? '').toString().trim().toLowerCase();
    final createdAt = (json['created_at'] ?? '').toString().trim();
    final storageFileName = (json['storage_file_name'] ?? '').toString().trim();
    final bytes = (json['bytes'] as num?)?.toInt() ?? 0;
    final caption = json['caption']?.toString().trim();
    if (id.isEmpty ||
        docName.isEmpty ||
        fileName.isEmpty ||
        mimeType.isEmpty ||
        createdAt.isEmpty ||
        storageFileName.isEmpty ||
        bytes < 0) {
      return null;
    }
    return _StoredDocumentImage(
      id: id,
      docName: docName,
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
      createdAt: createdAt,
      storageFileName: storageFileName,
      caption: caption,
    );
  }
}
