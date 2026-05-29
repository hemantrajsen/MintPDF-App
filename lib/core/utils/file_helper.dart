import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart'; // Make sure to add this package

/// A utility class to handle safe file operations and caching.
/// strictly follows Android Scoped Storage rules.
class FileHelper {
  FileHelper._();
  static final FileHelper instance = FileHelper._();

  final _uuid = const Uuid();

  /// Gets the app's temporary directory (Sandbox).
  /// Files here can be safely read/written by our app.
  Future<Directory> getTempDir() async => await getTemporaryDirectory();

  /// Safely copies a file from an unknown source (Gallery/Downloads)
  /// to our app's local sandbox so we can process it without permission errors.
  Future<File> cacheFile(String sourcePath) async {
    final file = File(sourcePath);
    final filename = p.basename(sourcePath);
    final extension = p.extension(sourcePath);

    // Create a unique name to prevent overwriting (e.g., "doc_1234-5678.pdf")
    final uniqueName =
        '${p.basenameWithoutExtension(filename)}_${_uuid.v4()}$extension';

    final tempDir = await getTempDir();
    final newPath = '${tempDir.path}/$uniqueName';

    // Copy the file to our sandbox
    return await file.copy(newPath);
  }

  /// Safely saves a cached file to a user-selected directory.
  /// Returns the saved file path if successful, or null if the user canceled.
  Future<String?> saveFileToUserDevice(File cachedFile, String suggestedName) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select where to save your PDF',
      );

      if (selectedDirectory == null) return null;

      final String safeName = suggestedName.endsWith('.pdf') 
          ? suggestedName 
          : '$suggestedName.pdf';

      final String finalPath = '$selectedDirectory/$safeName';
      final File savedFile = File(finalPath);

      await cachedFile.copy(savedFile.path);

      return savedFile.path;
    } catch (e) {
      debugPrint('Error saving file: $e');
      return null;
    }
  }

  /// Clears all temporary files to free up disk space.
  /// Call this when the app starts or closes.
  Future<void> clearCache() async {
    try {
      final tempDir = await getTempDir();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Warning: Failed to clear cache: $e');
    }
  }

  /// Returns a nicely formatted file size string (e.g., "1.5 MB")
  String formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.bitLength - 1) ~/ 10; // Efficient bitwise calculation
    // Limit to TB
    if (i >= suffixes.length) i = suffixes.length - 1;

    final double size = bytes / (1 << (i * 10)); // 1 << 10 is 1024
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}