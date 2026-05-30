import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mintpdf/features/pdf_processing/data/providers.dart';

class UnlockPdfState {
  final bool isLoading;
  final bool isProcessing;
  final File? selectedFile;
  final File? generatedPdf;
  final String? error;

  const UnlockPdfState({
    this.isLoading = false,
    this.isProcessing = false,
    this.selectedFile,
    this.generatedPdf,
    this.error,
  });

  UnlockPdfState copyWith({
    bool? isLoading,
    bool? isProcessing,
    File? selectedFile,
    File? generatedPdf,
    String? error,
  }) {
    return UnlockPdfState(
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      selectedFile: selectedFile ?? this.selectedFile,
      generatedPdf: generatedPdf ?? this.generatedPdf,
      error: error,
    );
  }
}

class UnlockPdfNotifier extends StateNotifier<UnlockPdfState> {
  final Ref ref;

  UnlockPdfNotifier(this.ref) : super(const UnlockPdfState());

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
      state = state.copyWith(isLoading: false, error: "Failed to pick file: $e");
    }
  }

  void clearFile() {
    state = const UnlockPdfState();
  }

  Future<void> decryptPdf(String password) async {
    if (state.selectedFile == null) return;

    try {
      state = state.copyWith(isProcessing: true, error: null);

      final repository = ref.read(pdfRepositoryProvider);
      // Calls the unlock method we added earlier!
      final result = await repository.unlockPdf(state.selectedFile!, password);

      state = state.copyWith(isProcessing: false, generatedPdf: result);
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        error: "Failed to unlock PDF. Is the password correct?",
      );
    }
  }
}

final unlockPdfProvider =
    StateNotifierProvider.autoDispose<UnlockPdfNotifier, UnlockPdfState>((ref) {
      return UnlockPdfNotifier(ref);
    });