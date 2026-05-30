import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mintpdf/features/pdf_processing/data/providers.dart';
import 'package:mintpdf/core/utils/file_helper.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart'; 

class StampPdfState {
  final bool isLoading;
  final bool isProcessing;
  final File? selectedFile;
  final File? signatureFile;
  final File? generatedPdf;
  final String? error;

  final double posX;
  final double posY;
  final double scaleMultiplier;
  final double sigAspectRatio; 
  
  final int currentPage;
  final int totalPages;
  
  // THE NEW SELECTOR STATE
  final bool isSignatureSelected;

  const StampPdfState({
    this.isLoading = false,
    this.isProcessing = false,
    this.selectedFile,
    this.signatureFile,
    this.generatedPdf,
    this.error,
    this.posX = 50.0,
    this.posY = 50.0,
    this.scaleMultiplier = 1.0,
    this.sigAspectRatio = 2.0, 
    this.currentPage = 1,
    this.totalPages = 1,
    this.isSignatureSelected = false, // Defaults to unselected
  });

  StampPdfState copyWith({
    bool? isLoading,
    bool? isProcessing,
    File? selectedFile,
    File? signatureFile,
    File? generatedPdf,
    String? error,
    double? posX,
    double? posY,
    double? scaleMultiplier,
    double? sigAspectRatio,
    int? currentPage,
    int? totalPages,
    bool? isSignatureSelected,
  }) {
    return StampPdfState(
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      selectedFile: selectedFile ?? this.selectedFile,
      signatureFile: signatureFile ?? this.signatureFile,
      generatedPdf: generatedPdf ?? this.generatedPdf,
      error: error,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      scaleMultiplier: scaleMultiplier ?? this.scaleMultiplier,
      sigAspectRatio: sigAspectRatio ?? this.sigAspectRatio,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      isSignatureSelected: isSignatureSelected ?? this.isSignatureSelected,
    );
  }
}

class StampPdfNotifier extends StateNotifier<StampPdfState> {
  final Ref ref;
  final double baseSigWidth = 150.0;
  double _gestureStartScale = 1.0;

  StampPdfNotifier(this.ref) : super(const StampPdfState()) {
    _loadSignatureFile();
  }

  Future<void> refreshSignature() async {
    await _loadSignatureFile();
  }

  Future<void> _loadSignatureFile() async {
    final docDir = await FileHelper.instance.getTempDir();
    final file = File('${docDir.path}/user_signature.png');
    
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      final image = await decodeImageFromList(bytes);
      final double exactRatio = image.width / image.height;
      
      state = state.copyWith(signatureFile: file, sigAspectRatio: exactRatio);
    }
  }

  Future<void> pickFile() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final File selectedFile = File(result.files.single.path!);
        
        final List<int> pdfBytes = await selectedFile.readAsBytes();
        final PdfDocument tempDoc = PdfDocument(inputBytes: pdfBytes);
        final int pages = tempDoc.pages.count;
        tempDoc.dispose();

        state = state.copyWith(
          isLoading: false,
          selectedFile: selectedFile,
          generatedPdf: null,
          posX: 50.0,
          posY: 50.0,
          scaleMultiplier: 1.0,
          currentPage: 1,
          totalPages: pages,
          isSignatureSelected: true, // Auto-select when file loads so user knows it's active
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Failed to pick file: $e");
    }
  }

  void changePage(int newPage) {
    state = state.copyWith(
      currentPage: newPage,
      posX: 50.0, 
      posY: 50.0,
      isSignatureSelected: false, // Deselect when changing pages
    );
  }

  // THE NEW TOGGLE METHOD
  void toggleSelection(bool isSelected) {
    state = state.copyWith(isSignatureSelected: isSelected);
  }

  void onScaleStart() {
    _gestureStartScale = state.scaleMultiplier;
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    final newX = state.posX + details.focalPointDelta.dx;
    final newY = state.posY + details.focalPointDelta.dy;
    final newScale = (_gestureStartScale * details.scale).clamp(0.3, 4.0);

    state = state.copyWith(posX: newX, posY: newY, scaleMultiplier: newScale);
  }

  void clearWorkspace() {
    state = StampPdfState(
      signatureFile: state.signatureFile,
      sigAspectRatio: state.sigAspectRatio,
    );
  }

  Future<void> processStamp({
    required double renderWidth,
    required double renderHeight,
  }) async {
    if (state.selectedFile == null || state.signatureFile == null) return;

    try {
      state = state.copyWith(isProcessing: true, error: null, isSignatureSelected: false);

      final List<int> pdfBytes = await state.selectedFile!.readAsBytes();
      final PdfDocument tempDoc = PdfDocument(inputBytes: pdfBytes);
      
      final int targetPageIndex = state.currentPage - 1; 
      final double nativeWidth = tempDoc.pages[targetPageIndex].size.width;
      final double nativeHeight = tempDoc.pages[targetPageIndex].size.height;
      tempDoc.dispose();

      final double scaleX = nativeWidth / renderWidth;
      final double scaleY = nativeHeight / renderHeight;

      final double currentWidth = baseSigWidth * state.scaleMultiplier;
      final double currentHeight = currentWidth / state.sigAspectRatio;

      final double targetX = state.posX * scaleX;
      final double targetY = state.posY * scaleY; 
      final double targetWidth = currentWidth * scaleX;
      final double targetHeight = currentHeight * scaleY;

      final Rect nativeBounds = Rect.fromLTWH(targetX, targetY, targetWidth, targetHeight);

      final repository = ref.read(pdfRepositoryProvider);
      final result = await repository.stampSignature(
        state.selectedFile!,
        state.signatureFile!,
        targetPageIndex,
        nativeBounds,
      );

      state = state.copyWith(isProcessing: false, generatedPdf: result);
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: "Failed to stamp: $e");
    }
  }
}

final stampPdfProvider = StateNotifierProvider.autoDispose<StampPdfNotifier, StampPdfState>((ref) {
  return StampPdfNotifier(ref);
});