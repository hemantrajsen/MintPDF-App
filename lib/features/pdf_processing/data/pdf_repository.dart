import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:mintpdf/core/utils/file_helper.dart';

// Defines the contract for our PDF operations
abstract class IPdfRepository {
  Future<File> createPdfFromImages(List<File> images, {PdfCompressionLevel quality = PdfCompressionLevel.normal});
  Future<File> compressPdf(File pdfFile, {int quality = 50});
  Future<File> mergePdfs(List<File> pdfFiles);
}

// TOP-LEVEL FUNCTION (required for compute/isolate - must be outside class)
Uint8List _processImage(Map<String, dynamic> params) {
  final Uint8List bytes = params['bytes'];
  final int jpegQuality = params['jpegQuality'];
  final int maxDimension = params['maxDimension'];

  // Decode the image
  img.Image? image = img.decodeImage(bytes);
  if (image == null) return bytes; // Return original if decode fails

  // Resize if too large
  if (image.width > maxDimension || image.height > maxDimension) {
    if (image.width > image.height) {
      image = img.copyResize(image, width: maxDimension);
    } else {
      image = img.copyResize(image, height: maxDimension);
    }
  }

  // Encode as JPEG with specified quality
  return Uint8List.fromList(img.encodeJpg(image, quality: jpegQuality));
}

class PdfRepository implements IPdfRepository {
  final FileHelper _fileHelper;

  PdfRepository(this._fileHelper);

  // Helper: Get JPEG quality based on compression level
  int _getJpegQuality(PdfCompressionLevel level) {
    switch (level) {
      case PdfCompressionLevel.none:
        return 95; // High quality, large file
      case PdfCompressionLevel.normal:
        return 75; // Balanced
      case PdfCompressionLevel.best:
        return 50; // Low quality, small file
      default:
        return 75;
    }
  }

  // Helper: Get max dimension based on compression level
  int _getMaxDimension(PdfCompressionLevel level) {
    switch (level) {
      case PdfCompressionLevel.none:
        return 3000; // Full resolution
      case PdfCompressionLevel.normal:
        return 2000; // Medium
      case PdfCompressionLevel.best:
        return 1200; // Smaller
      default:
        return 2000;
    }
  }

  // Compress image in an isolate (background thread)
  Future<Uint8List> _compressImage(File imageFile, PdfCompressionLevel level) async {
    final bytes = await imageFile.readAsBytes();
    
    // Use compute() to run in background isolate (prevents UI freeze)
    return await compute(_processImage, {
      'bytes': Uint8List.fromList(bytes),
      'jpegQuality': _getJpegQuality(level),
      'maxDimension': _getMaxDimension(level),
    });
  }

  @override
  Future<File> createPdfFromImages(List<File> images, {PdfCompressionLevel quality = PdfCompressionLevel.normal}) async {
    // 1. Create a new PDF document
    final PdfDocument document = PdfDocument();
    document.compressionLevel = quality;

    // 2. Loop through every image
    for (final imageFile in images) {
      // Add a page to the document
      final PdfPage page = document.pages.add();
      
      // COMPRESS the image based on quality setting
      final Uint8List compressedBytes = await _compressImage(imageFile, quality);
      
      // Create a PDF Bitmap from compressed bytes
      PdfBitmap bitmap = PdfBitmap(compressedBytes);

      // Draw the image on the page to fill it
      page.graphics.drawImage(
        bitmap,
        ui.Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
      );
    }

    // 3. Save the document to bytes
    final List<int> bytes = await document.save();
    
    // 4. Dispose to free memory
    document.dispose();

    // 5. Save to a temporary file
    final tempDir = await _fileHelper.getTempDir();
    final outputFile = File('${tempDir.path}/generated_${DateTime.now().millisecondsSinceEpoch}.pdf');
    
    return await outputFile.writeAsBytes(bytes);
  }

  @override
  Future<File> compressPdf(File pdfFile, {int quality = 50}) async {
    // Load the existing PDF
    final List<int> bytes = await pdfFile.readAsBytes();
    final PdfDocument document = PdfDocument(inputBytes: bytes);

    // Set Compression Options
    document.compressionLevel = PdfCompressionLevel.best;
    
    final List<int> compressedBytes = await document.save();
    document.dispose();

    final tempDir = await _fileHelper.getTempDir();
    final outputFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.pdf');
    
    return await outputFile.writeAsBytes(compressedBytes);
  }

  @override
  Future<File> mergePdfs(List<File> pdfFiles) async {
    // 1. Create the master document
    final PdfDocument document = PdfDocument();

    for (final file in pdfFiles) {
      // 2. Load the source document
      final List<int> bytes = await file.readAsBytes();
      final PdfDocument inputDoc = PdfDocument(inputBytes: bytes);
      
      // 3. Create a 'template' (copy) of each page and draw it
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
    final outputFile = File('${tempDir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.pdf');
    
    return await outputFile.writeAsBytes(mergedBytes);
  }
}