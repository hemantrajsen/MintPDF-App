import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mintpdf/features/pdf_processing/data/providers.dart';
import 'package:mintpdf/features/pdf_processing/data/pdf_repository.dart';

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
  final double compressionProgress; 

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

  bool get canCompress => selectedPdf != null && !isCompressing;

  String get originalSizeFormatted {
    if (originalSize == null) return '--';
    return _formatBytes(originalSize!);
  }

  String getEstimatedSize(IPdfRepository repo) {
    if (originalSize == null) return '--';
    final estimated = repo.estimateCompressedSize(originalSize!, selectedLevel);
    return _formatBytes(estimated);
  }

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

class CompressPdfNotifier extends StateNotifier<CompressPdfState> {
  final Ref ref;

  CompressPdfNotifier(this.ref) : super(const CompressPdfState());

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
      state = state.copyWith(isLoading: false, error: 'Failed to pick PDF: $e');
    }
  }

  void setCompressionLevel(CompressionLevel level) {
    state = state.copyWith(selectedLevel: level, clearResult: true);
  }

  Future<void> compress() async {
    if (state.selectedPdf == null) return;

    try {
      state = state.copyWith(
        isCompressing: true,
        error: null,
        compressionProgress: 0.0,
        clearResult: true,
      );

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

  void _simulateProgress() async {
    for (int i = 1; i <= 9; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!state.isCompressing) break;
      state = state.copyWith(compressionProgress: i * 0.1);
    }
  }

  void clearSelection() {
    state = state.copyWith(clearPdf: true, clearResult: true);
  }

  void reset() {
    state = const CompressPdfState();
  }
}

final compressPdfProvider = StateNotifierProvider<CompressPdfNotifier, CompressPdfState>((ref) {
  return CompressPdfNotifier(ref);
});