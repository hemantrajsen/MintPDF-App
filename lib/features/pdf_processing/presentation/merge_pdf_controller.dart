import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mintpdf/features/pdf_processing/data/providers.dart';
import 'package:share_plus/share_plus.dart';

class MergePdfState {
  final bool isLoading;
  final bool isMerging;
  final List<File> selectedFiles;
  final File? mergedPdf;
  final String? error;

  const MergePdfState({
    this.isLoading = false,
    this.isMerging = false,
    this.selectedFiles = const [],
    this.mergedPdf,
    this.error,
  });

  MergePdfState copyWith({
    bool? isLoading,
    bool? isMerging,
    List<File>? selectedFiles,
    File? mergedPdf,
    String? error,
  }) {
    return MergePdfState(
      isLoading: isLoading ?? this.isLoading,
      isMerging: isMerging ?? this.isMerging,
      selectedFiles: selectedFiles ?? this.selectedFiles,
      mergedPdf: mergedPdf ?? this.mergedPdf,
      error: error,
    );
  }
}

class MergePdfNotifier extends StateNotifier<MergePdfState> {
  final Ref ref;

  MergePdfNotifier(this.ref) : super(const MergePdfState());

  // 1. Pick Multiple PDFs
  Future<void> pickFiles() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true, // Crucial for merging
      );

      if (result != null) {
        final newFiles = result.paths
            .where((path) => path != null)
            .map((path) => File(path!))
            .toList();
            
        // Append to existing list
        state = state.copyWith(
          isLoading: false,
          selectedFiles: [...state.selectedFiles, ...newFiles],
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: "Failed to pick files: $e");
    }
  }

  // 2. Reorder Files (Drag & Drop logic)
  void reorderFiles(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final List<File> newList = List.from(state.selectedFiles);
    final File item = newList.removeAt(oldIndex);
    newList.insert(newIndex, item);
    
    state = state.copyWith(selectedFiles: newList);
  }

  // 3. Remove a file
  void removeFile(int index) {
    final newList = List<File>.from(state.selectedFiles);
    newList.removeAt(index);
    state = state.copyWith(selectedFiles: newList);
  }

  // 4. Execute Merge
  Future<void> mergeDocuments(String fileName) async {
    if (state.selectedFiles.length < 2) {
      state = state.copyWith(error: "Please select at least 2 PDF files");
      return;
    }

    try {
      state = state.copyWith(isMerging: true, error: null);

      final repository = ref.read(pdfRepositoryProvider);
      final File rawMerged = await repository.mergePdfs(state.selectedFiles);

      // Rename
      final String dir = rawMerged.parent.path;
      final String cleanName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
      final String newPath = '$dir/$cleanName';
      final File finalFile = await rawMerged.rename(newPath);

      state = state.copyWith(isMerging: false, mergedPdf: finalFile);

      // Share immediately
      await Share.shareXFiles(
        [XFile(finalFile.path)],
        text: 'Merged PDF from MintPDF',
      );

    } catch (e) {
      state = state.copyWith(isMerging: false, error: "Merge failed: $e");
    }
  }
  
  void reset() {
    state = const MergePdfState();
  }
}

final mergePdfProvider = StateNotifierProvider<MergePdfNotifier, MergePdfState>((ref) {
  return MergePdfNotifier(ref);
});