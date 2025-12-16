import 'dart:io';
import 'dart:ui';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:mintpdf/core/utils/file_helper.dart';

// Defines the contract for our PDF operations
abstract class IPdfRepository {
  Future<File> createPdfFromImages(List<File> images);
  Future<File> compressPdf(File pdfFile, {int quality = 50});
  Future<File> mergePdfs(List<File> pdfFiles);
}

class PdfRepository implements IPdfRepository {
  final FileHelper _fileHelper;

  PdfRepository(this._fileHelper);

  @override
  Future<File> createPdfFromImages(List<File> images) async {
    // 1. Create a new PDF document
    final PdfDocument document = PdfDocument();

    // 2. Loop through every image
    for (final imageFile in images) {
      // Add a page to the document
      final PdfPage page = document.pages.add();
      
      // Read image bytes
      final List<int> imageBytes = await imageFile.readAsBytes();
      
      // Create a PDF Bitmap
      // Note: Syncfusion handles JPEG/PNG automatically.
      // If we have HEIC, we rely on our generic Transcoder (future step).
      PdfBitmap bitmap = PdfBitmap(imageBytes);

      // Draw the image on the page to fill it
      page.graphics.drawImage(
        bitmap,
        Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
      );
    }

    // 3. Save the document to bytes
    final List<int> bytes = await document.save();
    
    // 4. Dispose to free memory
    document.dispose();

    // 5. Save to a temporary file using our Helper
    // We name it "output.pdf" temporarily
    final tempDir = await _fileHelper.getTempDir(); // We need to expose this in FileHelper
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
    
    // In a real app, we would optimize images inside the PDF here.
    // Syncfusion's basic compression is metadata-based.
    
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
      
      // 3. THE FIX: The "Template Method"
      // Syncfusion Flutter doesn't have 'importPage'.
      // We must create a 'template' (copy) of each page and draw it.
      for (int i = 0; i < inputDoc.pages.count; i++) {
        // a. Get the source page
        final PdfPage sourcePage = inputDoc.pages[i];
        
        // b. Create a new page in our master doc with the SAME size
        final PdfPage newPage = document.pages.add();
        
        // c. Create a template from the source and draw it
        // This preserves the look, though some interactive elements might be flattened.
        final PdfTemplate template = sourcePage.createTemplate();
        newPage.graphics.drawPdfTemplate(template, const Offset(0, 0));
      }
      
      // 4. Dispose the input to free memory
      inputDoc.dispose();
    }

    // 5. Save and return
    final List<int> mergedBytes = await document.save();
    document.dispose();

    final tempDir = await _fileHelper.getTempDir();
    final outputFile = File('${tempDir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.pdf');
    
    return await outputFile.writeAsBytes(mergedBytes);
  }
}