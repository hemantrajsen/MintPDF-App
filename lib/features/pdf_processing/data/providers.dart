import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintpdf/core/utils/file_helper.dart';
import 'pdf_repository.dart';

// 1. Provider for the FileHelper (Singleton)
final fileHelperProvider = Provider<FileHelper>((ref) {
  return FileHelper.instance;
});

// 2. Provider for the PdfRepository
// We inject the fileHelper into it automatically
final pdfRepositoryProvider = Provider<IPdfRepository>((ref) {
  final fileHelper = ref.watch(fileHelperProvider);
  return PdfRepository(fileHelper);
});