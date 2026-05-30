import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:mintpdf/core/theme/app_colors.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'stamp_pdf_controller.dart';
import 'package:mintpdf/features/settings/presentation/user_signature_screen.dart';

// CHANGED TO STATEFUL WIDGET TO HOLD THE PDF CONTROLLER
class StampPdfScreen extends ConsumerStatefulWidget {
  const StampPdfScreen({super.key});

  @override
  ConsumerState<StampPdfScreen> createState() => _StampPdfScreenState();
}

class _StampPdfScreenState extends ConsumerState<StampPdfScreen> {
  // Controller to tell the PDF to jump pages
  final PdfViewerController _pdfController = PdfViewerController();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stampPdfProvider);
    final controller = ref.read(stampPdfProvider.notifier);

    ref.listen(stampPdfProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
      }
      if (next.generatedPdf != null && previous?.generatedPdf != next.generatedPdf) {
        _showSuccessDialog(context, next.generatedPdf!, p.basename(next.selectedFile!.path), controller);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stamp Signature'),
        actions: [
          if (state.selectedFile != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => controller.clearWorkspace(),
            ),
        ],
      ),
      body: state.signatureFile == null
          ? _buildMissingSignatureState(context, controller)
          : state.selectedFile == null
              ? _buildEmptyState(context, controller, state)
              : _buildWorkspace(context, state, controller),
    );
  }

  Widget _buildMissingSignatureState(BuildContext context, StampPdfNotifier controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.draw, size: 64, color: Colors.teal),
            ),
            const SizedBox(height: 24),
            const Text('No Signature Found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('You need to create your signature configuration first before stamping files.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSignatureScreen()));
                controller.refreshSignature();
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Configure Signature Now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, StampPdfNotifier controller, StampPdfState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.assignment_turned_in, size: 64, color: Colors.teal),
            ),
            const SizedBox(height: 24),
            const Text('Select Target PDF', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Choose a PDF document from storage to stamp your drawing onto.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: state.isLoading ? null : () => controller.pickFile(),
              icon: const Icon(Icons.upload_file),
              label: Text(state.isLoading ? 'Loading...' : 'Select Document File'),
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildWorkspace(BuildContext context, StampPdfState state, StampPdfNotifier controller) {
    final double currentWidth = controller.baseSigWidth * state.scaleMultiplier;
    final double currentHeight = currentWidth / state.sigAspectRatio;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          child: Text(
            "Tap signature to select it. Use two fingers anywhere to resize, or drag to move.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: AspectRatio(
                aspectRatio: 1 / 1.414,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400, width: 2),
                        color: Colors.white,
                      ),
                      // 1. THE UNIFIED SMART GESTURE DETECTOR
                      child: GestureDetector(
                        onTapUp: (details) {
                          // Find out where the user tapped on the workspace
                          final tapX = details.localPosition.dx;
                          final tapY = details.localPosition.dy;
                          
                          // Add a little 20px buffer so they don't have to tap perfectly on the edge
                          final padding = 20.0;
                          final bool hitX = tapX >= (state.posX - padding) && tapX <= (state.posX + currentWidth + padding);
                          final bool hitY = tapY >= (state.posY - padding) && tapY <= (state.posY + currentHeight + padding);
                          
                          // If they tapped the box, select it. If they tapped empty space, deselect it.
                          if (hitX && hitY) {
                            controller.toggleSelection(true);
                          } else {
                            controller.toggleSelection(false);
                          }
                        },
                        // Only allow dragging/pinching if the signature is actively selected
                        onScaleStart: (details) {
                          if (state.isSignatureSelected) controller.onScaleStart();
                        },
                        onScaleUpdate: (details) {
                          if (state.isSignatureSelected) controller.onScaleUpdate(details);
                        },
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            AbsorbPointer(
                              child: PdfViewer.file(
                                state.selectedFile!.path,
                                controller: _pdfController,
                                params: const PdfViewerParams(maxScale: 1.0),
                              ),
                            ),
                            // 2. THE DYNAMIC SIGNATURE UI
                            Positioned(
                              left: state.posX,
                              top: state.posY,
                              child: Container(
                                width: currentWidth,
                                height: currentHeight,
                                decoration: BoxDecoration(
                                  // Highlight border only shows when selected
                                  border: Border.all(
                                    color: state.isSignatureSelected ? Colors.teal : Colors.transparent, 
                                    width: 1.5, 
                                    style: BorderStyle.solid
                                  ),
                                  color: state.isSignatureSelected ? Colors.teal.withOpacity(0.1) : Colors.transparent,
                                ),
                                child: Image.file(
                                  state.signatureFile!,
                                  fit: BoxFit.fill, 
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        
        // --- PAGE NAVIGATOR UI ---
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 30),
                color: state.currentPage > 1 ? Colors.teal : Colors.grey.shade400,
                onPressed: state.currentPage > 1 
                  ? () {
                      final newPage = state.currentPage - 1;
                      controller.changePage(newPage);
                      _pdfController.goToPage(pageNumber: newPage);
                    } 
                  : null,
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Page ${state.currentPage} of ${state.totalPages}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 30),
                color: state.currentPage < state.totalPages ? Colors.teal : Colors.grey.shade400,
                onPressed: state.currentPage < state.totalPages 
                  ? () {
                      final newPage = state.currentPage + 1;
                      controller.changePage(newPage);
                      _pdfController.goToPage(pageNumber: newPage);
                    } 
                  : null,
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0, top: 8.0),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return FilledButton.icon(
                  onPressed: state.isProcessing
                      ? null
                      : () {
                          final double screenWidth = MediaQuery.of(context).size.width - 32;
                          final double workspaceHeight = screenWidth * 1.414;
                          
                          controller.processStamp(
                            renderWidth: screenWidth,
                            renderHeight: workspaceHeight,
                          );
                        },
                  style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                  icon: state.isProcessing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.assignment_turned_in),
                  label: Text(state.isProcessing ? "Processing Stamp..." : "Confirm & Save Document"),
                );
              }
            ),
          ),
        ),
      ],
    );
  }

  // --- Success dialog remains identical below ---
  void _showSuccessDialog(BuildContext context, File generatedFile, String originalName, StampPdfNotifier controller) {
    final String defaultSaveName = '${p.basenameWithoutExtension(originalName)}_signed.pdf';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Document Stamped!', style: TextStyle(fontSize: 18), overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Your signature has been permanently applied safely:", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                child: Text(defaultSaveName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
              ),
              const SizedBox(height: 16),
              
              // --- THE FILE SAVING FIX ---
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_rounded, color: Colors.blue),
                title: const Text("Save to Device", style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () async {
                  try {
                    // 1. Read the raw binary data of your generated PDF
                    final bytes = await generatedFile.readAsBytes();

                    // 2. Ask OS for the destination path AND hand it the bytes simultaneously
                    final String? outputFile = await FilePicker.platform.saveFile(
                      dialogTitle: 'Save Signed PDF',
                      fileName: defaultSaveName,
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                      bytes: bytes, // <--- THE CRITICAL FIX FOR ANDROID/IOS
                    );

                    // 3. Because we passed the bytes, the OS handles the actual copying for us!
                    if (outputFile != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Document saved safely to your device!"), 
                          backgroundColor: AppColors.success
                        )
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text("Error saving file: $e"), backgroundColor: AppColors.error)
                       );
                    }
                  }
                },
              ),
              const Divider(height: 1),
              
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.share_rounded, color: Colors.purple),
                title: const Text("Share File", style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => Share.shareXFiles([XFile(generatedFile.path)], text: 'Signed via MintPDF'),
              ),
              const Divider(height: 1),
              
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text("Open Signed PDF", style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => OpenFile.open(generatedFile.path),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.clearWorkspace();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}