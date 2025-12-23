import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mintpdf/features/pdf_processing/data/providers.dart';
import 'package:pdfrx/pdfrx.dart';

class SplitPdfState {
  final bool isLoading;
  final bool isProcessing;
  final File? selectedFile;
  final int? pageCount;
  final File? extractedPdf;
  final String? error;

  const SplitPdfState({
    this.isLoading = false,
    this.isProcessing = false,
    this.selectedFile,
    this.pageCount,
    this.extractedPdf,
    this.error,
  });

  SplitPdfState copyWith({
    bool? isLoading,
    bool? isProcessing,
    File? selectedFile,
    int? pageCount,
    File? extractedPdf,
    String? error,
  }) {
    return SplitPdfState(
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      selectedFile: selectedFile ?? this.selectedFile,
      pageCount: pageCount ?? this.pageCount,
      extractedPdf: extractedPdf ?? this.extractedPdf,
      error: error,
    );
  }
}

class SplitPdfNotifier extends StateNotifier<SplitPdfState> {
  final Ref ref;

  SplitPdfNotifier(this.ref) : super(const SplitPdfState());

  Future<void> pickFile() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        // Get page count using pdfrx
        final doc = await PdfDocument.openFile(file.path);
        final count = doc.pages.length;
        doc.dispose();

        state = state.copyWith(
          isLoading: false,
          selectedFile: file,
          pageCount: count,
          extractedPdf: null,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to pick file: $e",
      );
    }
  }

  void clearFile() {
    state = const SplitPdfState();
  }

  Future<void> extractPages(String range) async {
    if (state.selectedFile == null) return;

    try {
      state = state.copyWith(isProcessing: true, error: null);

      final repository = ref.read(pdfRepositoryProvider);
      final result = await repository.splitPdf(state.selectedFile!, range);

      state = state.copyWith(isProcessing: false, extractedPdf: result);
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: "Failed to split PDF: $e",
      );
    }
  }
}

final splitPdfProvider =
    StateNotifierProvider.autoDispose<SplitPdfNotifier, SplitPdfState>((ref) {
      return SplitPdfNotifier(ref);
    });
