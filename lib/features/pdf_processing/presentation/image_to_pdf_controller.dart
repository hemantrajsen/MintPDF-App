import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mintpdf/features/pdf_processing/data/providers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';


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


class ImageToPdfNotifier extends StateNotifier<ImageToPdfState> {
  final Ref ref;
  final _picker = ImagePicker();

  ImageToPdfNotifier(this.ref) : super(const ImageToPdfState());


  Future<void> pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        final imageFiles = images.map((x) => File(x.path)).toList();
        
        state = state.copyWith(
          selectedImages: [...state.selectedImages, ...imageFiles],
          error: null,
        );
      }
    } catch (e) {
      state = state.copyWith(error: "Failed to pick images: $e");
    }
  }

  void removeImage(int index) {
    final updatedList = List<File>.from(state.selectedImages);
    updatedList.removeAt(index);
    state = state.copyWith(selectedImages: updatedList);
  }

  void reorderImages(int oldIndex, int newIndex) {
    final updatedList = List<File>.from(state.selectedImages);
    final File item = updatedList.removeAt(oldIndex);
    updatedList.insert(newIndex, item);
    state = state.copyWith(selectedImages: updatedList);
  }

  Future<void> convert(String fileName, PdfCompressionLevel quality) async {
    if (state.selectedImages.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);

     try {
      final repository = ref.read(pdfRepositoryProvider);
      
      File rawPdf = await repository.createPdfFromImages(state.selectedImages, quality: quality);

      final String dir = rawPdf.parent.path;
      final String cleanName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
      final String newPath = '$dir/$cleanName';
      
      final File namedPdf = await rawPdf.rename(newPath);

      state = state.copyWith(
        isLoading: false,
        generatedPdf: namedPdf,
      );

    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Conversion failed: $e",
      );
    }
  }
  
  void reset() {
    state = const ImageToPdfState();
  }
}

final imageToPdfProvider = StateNotifierProvider<ImageToPdfNotifier, ImageToPdfState>((ref) {
  return ImageToPdfNotifier(ref);
});