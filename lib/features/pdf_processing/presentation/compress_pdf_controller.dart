import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mintpdf/features/pdf_processing/data/providers.dart';
import 'package:mintpdf/features/pdf_processing/data/pdf_repository.dart';
import 'package:share_plus/share_plus.dart';

/// State for the Compress PDF feature
class CompressPdfState {
  final bool isLoading;
  final bool isCompressing;
  final File? selectedPdf;
  final String? selectedPdfName;
  final int? originalSize;
  final CompressionLevel selectedLevel;
  final CompressionResult? result;
  final String? error;
  final double compressionProgress; // 0.0 to 1.0

  const CompressPdfState({
    this.isLoading = false,
    this.isCompressing = false,
    this.selectedPdf,
    this.selectedPdfName,
    this.originalSize,
    this.selectedLevel = CompressionLevel.medium,
    this.result,
    this.error,
    this.compressionProgress = 0.0,
  });

  /// Check if we have a PDF ready to compress
  bool get canCompress => selectedPdf != null && !isCompressing;

  /// Get formatted original size
  String get originalSizeFormatted {
    if (originalSize == null) return '--';
    return _formatBytes(originalSize!);
  }

  /// Get estimated size based on selected level
  String getEstimatedSize(IPdfRepository repo) {
    if (originalSize == null) return '--';
    final estimated = repo.estimateCompressedSize(originalSize!, selectedLevel);
    return _formatBytes(estimated);
  }

  /// Get estimated reduction percentage
  String getEstimatedReduction(IPdfRepository repo) {
    if (originalSize == null) return '--';
    final estimated = repo.estimateCompressedSize(originalSize!, selectedLevel);
    final reduction = ((originalSize! - estimated) / originalSize! * 100);
    return '~${reduction.toStringAsFixed(0)}%';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  CompressPdfState copyWith({
    bool? isLoading,
    bool? isCompressing,
    File? selectedPdf,
    String? selectedPdfName,
    int? originalSize,
    CompressionLevel? selectedLevel,
    CompressionResult? result,
    String? error,
    double? compressionProgress,
    bool clearResult = false,
    bool clearPdf = false,
  }) {
    return CompressPdfState(
      isLoading: isLoading ?? this.isLoading,
      isCompressing: isCompressing ?? this.isCompressing,
      selectedPdf: clearPdf ? null : (selectedPdf ?? this.selectedPdf),
      selectedPdfName: clearPdf ? null : (selectedPdfName ?? this.selectedPdfName),
      originalSize: clearPdf ? null : (originalSize ?? this.originalSize),
      selectedLevel: selectedLevel ?? this.selectedLevel,
      result: clearResult ? null : (result ?? this.result),
      error: error,
      compressionProgress: compressionProgress ?? this.compressionProgress,
    );
  }
}

/// Controller for Compress PDF feature
class CompressPdfNotifier extends StateNotifier<CompressPdfState> {
  final Ref ref;

  CompressPdfNotifier(this.ref) : super(const CompressPdfState());

  /// Pick a PDF file from device
  Future<void> pickPdf() async {
    try {
      state = state.copyWith(isLoading: true, error: null, clearResult: true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        final size = await file.length();

        state = state.copyWith(
          isLoading: false,
          selectedPdf: file,
          selectedPdfName: result.files.first.name,
          originalSize: size,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to pick PDF: $e',
      );
    }
  }

  /// Change compression level
  void setCompressionLevel(CompressionLevel level) {
    state = state.copyWith(selectedLevel: level, clearResult: true);
  }

  /// Compress the selected PDF
  Future<void> compress() async {
    if (state.selectedPdf == null) return;

    try {
      state = state.copyWith(
        isCompressing: true,
        error: null,
        compressionProgress: 0.0,
        clearResult: true,
      );

      // Simulate progress (since actual compression doesn't report progress)
      _simulateProgress();

      final repository = ref.read(pdfRepositoryProvider);
      final result = await repository.compressPdf(
        state.selectedPdf!,
        level: state.selectedLevel,
      );

      state = state.copyWith(
        isCompressing: false,
        compressionProgress: 1.0,
        result: result,
      );
    } catch (e) {
      state = state.copyWith(
        isCompressing: false,
        compressionProgress: 0.0,
        error: 'Compression failed: $e',
      );
    }
  }

  /// Simulate progress for better UX
  void _simulateProgress() async {
    for (int i = 1; i <= 9; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!state.isCompressing) break;
      state = state.copyWith(compressionProgress: i * 0.1);
    }
  }

  // ...existing code until shareResult method...

  /// Share/Save the compressed PDF
  Future<void> shareResult(String? customName) async {
    if (state.result == null) return;

    try {
      File fileToShare = state.result!.compressedFile;

      // Rename if custom name provided
      if (customName != null && customName.trim().isNotEmpty) {
        final dir = fileToShare.parent.path;
        // Clean the filename - remove any existing .pdf and add it back
        String cleanName = customName.trim();
        if (cleanName.toLowerCase().endsWith('.pdf')) {
          cleanName = cleanName.substring(0, cleanName.length - 4);
        }
        // Remove any invalid characters
        cleanName = cleanName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        final newPath = '$dir/$cleanName.pdf';
        
        // Copy instead of rename to avoid issues
        fileToShare = await fileToShare.copy(newPath);
      }

      // Verify file exists and is valid
      if (!await fileToShare.exists()) {
        throw Exception('Compressed file not found');
      }

      final fileSize = await fileToShare.length();
      if (fileSize == 0) {
        throw Exception('Compressed file is empty');
      }

      await Share.shareXFiles(
        [XFile(fileToShare.path, mimeType: 'application/pdf')],
        subject: 'Compressed PDF',
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to share: $e');
    }
  }

// ...existing code...

  /// Clear selected PDF and start fresh
  void clearSelection() {
    state = state.copyWith(clearPdf: true, clearResult: true);
  }

  /// Reset entire state
  void reset() {
    state = const CompressPdfState();
  }
}

/// Provider for Compress PDF feature
final compressPdfProvider = StateNotifierProvider<CompressPdfNotifier, CompressPdfState>((ref) {
  return CompressPdfNotifier(ref);
});