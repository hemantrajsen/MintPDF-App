import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mintpdf/features/pdf_processing/data/providers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

// 1. The State (What the UI needs to know)
// We track: Is it loading? Which images are selected? Did we succeed?
class ImageToPdfState {
  final bool isLoading;
  final List<File> selectedImages;
  final File? generatedPdf;
  final String? error;

  const ImageToPdfState({
    this.isLoading = false,
    this.selectedImages = const [],
    this.generatedPdf,
    this.error,
  });

  // Helper to copy state efficiently
  ImageToPdfState copyWith({
    bool? isLoading,
    List<File>? selectedImages,
    File? generatedPdf,
    String? error,
  }) {
    return ImageToPdfState(
      isLoading: isLoading ?? this.isLoading,
      selectedImages: selectedImages ?? this.selectedImages,
      generatedPdf: generatedPdf ?? this.generatedPdf,
      error: error, // If we pass null, it clears the error
    );
  }
}

// 2. The Controller (The Logic)
class ImageToPdfNotifier extends StateNotifier<ImageToPdfState> {
  final Ref ref;
  final _picker = ImagePicker();

  ImageToPdfNotifier(this.ref) : super(const ImageToPdfState());

  // Action: User clicks "Pick Images"
  Future<void> pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        // Convert XFile (Camera/Gallery type) to File (IO type)
        final imageFiles = images.map((x) => File(x.path)).toList();
        
        // Update state: Add new images to existing list
        state = state.copyWith(
          selectedImages: [...state.selectedImages, ...imageFiles],
          error: null,
        );
      }
    } catch (e) {
      state = state.copyWith(error: "Failed to pick images: $e");
    }
  }

  // Action: User removes an image from the list
  void removeImage(int index) {
    final updatedList = List<File>.from(state.selectedImages);
    updatedList.removeAt(index);
    state = state.copyWith(selectedImages: updatedList);
  }
  // NEW: Action: User reorders images
  void reorderImages(int oldIndex, int newIndex) {
    final updatedList = List<File>.from(state.selectedImages);
    final File item = updatedList.removeAt(oldIndex);
    updatedList.insert(newIndex, item);
    state = state.copyWith(selectedImages: updatedList);
  }

  // Action: User clicks "Convert to PDF"
  Future<void> convert(String fileName, PdfCompressionLevel quality) async {
    if (state.selectedImages.isEmpty) return;

    // 1. Set Loading
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 2. Call our Repository (The Engine)
      final repository = ref.read(pdfRepositoryProvider);
      
      // 1. Generate the PDF (Raw)
      File rawPdf = await repository.createPdfFromImages(state.selectedImages, quality: quality);

      // 2. Rename it (Privacy-First: We rename the temp file before sharing)
      // We get the directory of the raw file
      final String dir = rawPdf.parent.path;
      // Ensure it ends with .pdf
      final String cleanName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
      final String newPath = '$dir/$cleanName';
      
      // Rename the file
      final File namedPdf = await rawPdf.rename(newPath);

      // 3. Success!
      state = state.copyWith(
        isLoading: false,
        generatedPdf: namedPdf,
      );

      // 4. Trigger the "Save/Share" Sheet immediately
      // This lets the user pick "Save to Files" (iOS) or "Copy to..." (Android)
      await Share.shareXFiles(
        [XFile(namedPdf.path)], 
        text: 'Here is your PDF created with MintPDF',
      );

    } catch (e) {
      // 4. Failure
      state = state.copyWith(
        isLoading: false,
        error: "Conversion failed: $e",
      );
    }
  }
  
  // Reset state when leaving the screen
  void reset() {
    state = const ImageToPdfState();
  }
}

// 3. The Provider (How the UI finds this logic)
final imageToPdfProvider = StateNotifierProvider<ImageToPdfNotifier, ImageToPdfState>((ref) {
  return ImageToPdfNotifier(ref);
});