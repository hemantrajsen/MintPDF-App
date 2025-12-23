import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:mintpdf/core/utils/file_helper.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

/// Compression level for PDF compression feature
enum CompressionLevel {
  low, // ~10-20% reduction, best quality
  medium, // ~30-50% reduction, good quality
  high, // ~50-70% reduction, acceptable quality
  extreme, // ~70-90% reduction, lower quality
}

/// Result of PDF compression with statistics
class CompressionResult {
  final File compressedFile;
  final int originalSize;
  final int compressedSize;
  final double reductionPercentage;

  CompressionResult({
    required this.compressedFile,
    required this.originalSize,
    required this.compressedSize,
  }) : reductionPercentage = originalSize > 0
           ? ((originalSize - compressedSize) / originalSize * 100)
           : 0;

  String get originalSizeFormatted => _formatBytes(originalSize);
  String get compressedSizeFormatted => _formatBytes(compressedSize);
  String get savedSizeFormatted => _formatBytes(originalSize - compressedSize);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

// Defines the contract for our PDF operations
abstract class IPdfRepository {
  Future<File> createPdfFromImages(
    List<File> images, {
    PdfCompressionLevel quality = PdfCompressionLevel.normal,
  });
  Future<CompressionResult> compressPdf(
    File pdfFile, {
    CompressionLevel level = CompressionLevel.medium,
  });
  Future<File> mergePdfs(List<File> pdfFiles);
  Future<File> splitPdf(File pdfFile, String pageRange);
  int estimateCompressedSize(int originalSize, CompressionLevel level);
}

// TOP-LEVEL FUNCTION for image processing (used in image-to-pdf)
Uint8List _processImage(Map<String, dynamic> params) {
  final Uint8List bytes = params['bytes'];
  final int jpegQuality = params['jpegQuality'];
  final int maxDimension = params['maxDimension'];

  img.Image? image = img.decodeImage(bytes);
  if (image == null) return bytes;

  if (image.width > maxDimension || image.height > maxDimension) {
    if (image.width > image.height) {
      image = img.copyResize(image, width: maxDimension);
    } else {
      image = img.copyResize(image, height: maxDimension);
    }
  }

  return Uint8List.fromList(img.encodeJpg(image, quality: jpegQuality));
}

// TOP-LEVEL HELPER for Isolate (Compressing raw image bytes)
Uint8List _compressImageBytes(Map<String, dynamic> params) {
  final Uint8List bytes = params['bytes'];
  final int quality = params['quality'];

  final img.Image? image = img.decodeImage(bytes);
  if (image == null) return bytes;

  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

class PdfRepository implements IPdfRepository {
  final FileHelper _fileHelper;

  PdfRepository(this._fileHelper);

  int _getJpegQuality(PdfCompressionLevel level) {
    switch (level) {
      case PdfCompressionLevel.none:
        return 95;
      case PdfCompressionLevel.normal:
        return 75;
      case PdfCompressionLevel.best:
        return 50;
      default:
        return 75;
    }
  }

  int _getMaxDimension(PdfCompressionLevel level) {
    switch (level) {
      case PdfCompressionLevel.none:
        return 3000;
      case PdfCompressionLevel.normal:
        return 2000;
      case PdfCompressionLevel.best:
        return 1200;
      default:
        return 2000;
    }
  }

  Future<Uint8List> _compressImage(
    File imageFile,
    PdfCompressionLevel level,
  ) async {
    final bytes = await imageFile.readAsBytes();

    return await compute(_processImage, {
      'bytes': Uint8List.fromList(bytes),
      'jpegQuality': _getJpegQuality(level),
      'maxDimension': _getMaxDimension(level),
    });
  }

  @override
  int estimateCompressedSize(int originalSize, CompressionLevel level) {
    // Estimates based on destructive compression (rasterization)
    switch (level) {
      case CompressionLevel.low:
        return (originalSize * 0.70).round(); // ~30% reduction
      case CompressionLevel.medium:
        return (originalSize * 0.50).round(); // ~50% reduction
      case CompressionLevel.high:
        return (originalSize * 0.30).round(); // ~70% reduction
      case CompressionLevel.extreme:
        return (originalSize * 0.15).round(); // ~85% reduction
    }
  }

  @override
  Future<File> createPdfFromImages(
    List<File> images, {
    PdfCompressionLevel quality = PdfCompressionLevel.normal,
  }) async {
    final PdfDocument document = PdfDocument();
    document.compressionLevel = quality;

    for (final imageFile in images) {
      final PdfPage page = document.pages.add();
      final Uint8List compressedBytes = await _compressImage(
        imageFile,
        quality,
      );
      PdfBitmap bitmap = PdfBitmap(compressedBytes);

      page.graphics.drawImage(
        bitmap,
        ui.Rect.fromLTWH(
          0,
          0,
          page.getClientSize().width,
          page.getClientSize().height,
        ),
      );
    }

    final List<int> bytes = await document.save();
    document.dispose();

    final tempDir = await _fileHelper.getTempDir();
    final outputFile = File(
      '${tempDir.path}/generated_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    return await outputFile.writeAsBytes(bytes);
  }

  @override
  Future<CompressionResult> compressPdf(
    File pdfFile, {
    CompressionLevel level = CompressionLevel.medium,
  }) async {
    final int originalSize = await pdfFile.length();

    // 1. Open the PDF using pdfrx
    final document = await pdfrx.PdfDocument.openFile(pdfFile.path);
    final int pageCount = document.pages.length;

    // 2. Create NEW PDF using Syncfusion
    final syncfusionPdf = PdfDocument();
    syncfusionPdf.compressionLevel = PdfCompressionLevel.best;

    // 3. Settings
    int jpegQuality = 75;
    double scale = 1.0; // 1.0 = 72 DPI

    switch (level) {
      case CompressionLevel.low:
        jpegQuality = 85;
        scale = 2.0;
        break;
      case CompressionLevel.medium:
        jpegQuality = 70;
        scale = 1.5;
        break;
      case CompressionLevel.high:
        jpegQuality = 50;
        scale = 1.0;
        break;
      case CompressionLevel.extreme:
        jpegQuality = 30;
        scale = 0.8;
        break;
    }

    // 4. Process Pages
    for (int i = 0; i < pageCount; i++) {
      final page = document.pages[i];

      // Render to image
      final pageImage = await page.render(
        width: (page.width * scale).toInt(),
        height: (page.height * scale).toInt(),
      );

      if (pageImage == null) continue;

      // Get bytes
      final ui.Image image = await pageImage.createImage();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();

        // Compress to JPEG in Isolate
        final Uint8List compressedBytes = await compute(_compressImageBytes, {
          'bytes': pngBytes,
          'quality': jpegQuality,
        });

        // Add to new PDF
        final PdfPage newPage = syncfusionPdf.pages.add();
        final PdfBitmap bitmap = PdfBitmap(compressedBytes);

        newPage.graphics.drawImage(
          bitmap,
          ui.Rect.fromLTWH(
            0,
            0,
            newPage.getClientSize().width,
            newPage.getClientSize().height,
          ),
        );
      }

      // Dispose image to free memory
      image.dispose();
    }

    // 5. Save
    final List<int> bytes = await syncfusionPdf.save();
    syncfusionPdf.dispose();
    document.dispose();

    // 6. Write file
    final tempDir = await _fileHelper.getTempDir();
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final outputFile = File('${tempDir.path}/compressed_$timestamp.pdf');

    await outputFile.writeAsBytes(bytes, flush: true);

    return CompressionResult(
      compressedFile: outputFile,
      originalSize: originalSize,
      compressedSize: bytes.length,
    );
  }

  @override
  Future<File> mergePdfs(List<File> pdfFiles) async {
    final PdfDocument document = PdfDocument();

    for (final file in pdfFiles) {
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument inputDoc = PdfDocument(inputBytes: bytes);

      for (int i = 0; i < inputDoc.pages.count; i++) {
        final PdfPage sourcePage = inputDoc.pages[i];
        final PdfPage newPage = document.pages.add();
        final PdfTemplate template = sourcePage.createTemplate();
        newPage.graphics.drawPdfTemplate(template, const ui.Offset(0, 0));
      }

      inputDoc.dispose();
    }

    final List<int> mergedBytes = await document.save();
    document.dispose();

    final tempDir = await _fileHelper.getTempDir();
    final outputFile = File(
      '${tempDir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    return await outputFile.writeAsBytes(mergedBytes);
  }

  @override
  Future<File> splitPdf(File pdfFile, String pageRange) async {
    final PdfDocument document = PdfDocument();
    final List<int> bytes = await pdfFile.readAsBytes();
    final PdfDocument inputDoc = PdfDocument(inputBytes: bytes);
    final int pageCount = inputDoc.pages.count;

    // Parse range
    final List<int> pagesToExtract = _parsePageRange(pageRange, pageCount);

    if (pagesToExtract.isEmpty) {
      inputDoc.dispose();
      throw Exception("No valid pages selected");
    }

    for (final index in pagesToExtract) {
      final PdfPage sourcePage = inputDoc.pages[index];
      final PdfPage newPage = document.pages.add();
      final PdfTemplate template = sourcePage.createTemplate();
      newPage.graphics.drawPdfTemplate(template, const ui.Offset(0, 0));
    }

    inputDoc.dispose();

    final List<int> newBytes = await document.save();
    document.dispose();

    final tempDir = await _fileHelper.getTempDir();
    final outputFile = File(
      '${tempDir.path}/split_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    return await outputFile.writeAsBytes(newBytes);
  }

  List<int> _parsePageRange(String range, int maxPages) {
    final Set<int> pages = {};
    final parts = range.split(',');

    for (var part in parts) {
      part = part.trim();
      if (part.isEmpty) continue;

      if (part.contains('-')) {
        final rangeParts = part.split('-');
        if (rangeParts.length == 2) {
          final start = int.tryParse(rangeParts[0]);
          final end = int.tryParse(rangeParts[1]);

          if (start != null && end != null) {
            // Adjust for 1-based input to 0-based index
            final s = start - 1;
            final e = end - 1;

            if (s >= 0 && e < maxPages && s <= e) {
              for (int i = s; i <= e; i++) {
                pages.add(i);
              }
            }
          }
        }
      } else {
        final page = int.tryParse(part);
        if (page != null) {
          final p = page - 1;
          if (p >= 0 && p < maxPages) {
            pages.add(p);
          }
        }
      }
    }
    final sortedList = pages.toList()..sort();
    return sortedList;
  }
}
