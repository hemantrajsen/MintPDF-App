import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mintpdf/features/pdf_processing/data/providers.dart';

class ProtectPdfState {
  final bool isLoading;
  final bool isProcessing;
  final File? selectedFile;
  final File? generatedPdf;
  final String? error;

  const ProtectPdfState({
    this.isLoading = false,
    this.isProcessing = false,
    this.selectedFile,
    this.generatedPdf,
    this.error,
  });

  ProtectPdfState copyWith({
    bool? isLoading,
    bool? isProcessing,
    File? selectedFile,
    File? generatedPdf,
    String? error,
  }) {
    return ProtectPdfState(
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      selectedFile: selectedFile ?? this.selectedFile,
      generatedPdf: generatedPdf ?? this.generatedPdf,
      error: error,
    );
  }
}

class ProtectPdfNotifier extends StateNotifier<ProtectPdfState> {
  final Ref ref;

  ProtectPdfNotifier(this.ref) : super(const ProtectPdfState());

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
        
        state = state.copyWith(
          isLoading: false,
          selectedFile: file,
          generatedPdf: null,
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
    state = const ProtectPdfState();
  }

  Future<void> encryptPdf(String password) async {
    if (state.selectedFile == null) return;

    try {
      state = state.copyWith(isProcessing: true, error: null);

      final repository = ref.read(pdfRepositoryProvider);
      final result = await repository.protectPdf(state.selectedFile!, password);

      state = state.copyWith(isProcessing: false, generatedPdf: result);
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: "Failed to encrypt PDF: $e",
      );
    }
  }
}

final protectPdfProvider =
    StateNotifierProvider.autoDispose<ProtectPdfNotifier, ProtectPdfState>((ref) {
      return ProtectPdfNotifier(ref);
    });