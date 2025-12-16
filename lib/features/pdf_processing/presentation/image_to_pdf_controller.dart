import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mintpdf/features/pdf_processing/data/providers.dart';

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

  // Action: User clicks "Convert to PDF"
  Future<void> convert() async {
    if (state.selectedImages.isEmpty) return;

    // 1. Set Loading
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 2. Call our Repository (The Engine)
      final repository = ref.read(pdfRepositoryProvider);
      final pdfFile = await repository.createPdfFromImages(state.selectedImages);

      // 3. Success!
      state = state.copyWith(
        isLoading: false,
        generatedPdf: pdfFile,
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