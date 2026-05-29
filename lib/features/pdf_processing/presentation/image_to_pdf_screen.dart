import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart'; // For opening the result
import 'package:mintpdf/core/theme/app_colors.dart';
import 'package:mintpdf/core/utils/file_helper.dart'; // Added for file saving
import 'package:share_plus/share_plus.dart'; // Added for explicit share action
import 'image_to_pdf_controller.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:path/path.dart' as p;

class ImageToPdfScreen extends ConsumerWidget {
  const ImageToPdfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final state = ref.watch(imageToPdfProvider);
    final controller = ref.read(imageToPdfProvider.notifier);

    ref.listen(imageToPdfProvider, (previous, next) {
      if (next.generatedPdf != null && previous?.generatedPdf != next.generatedPdf) {
        _showSuccessDialog(context, next.generatedPdf!, controller);
      }
      
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Images to PDF"),
        actions: [
          if (state.selectedImages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: () => controller.pickImages(),
            ),
        ],
      ),
      
      floatingActionButton: state.selectedImages.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: state.isLoading 
              ? null
              : () => _showSaveDialog(context, controller),
              label: Text(state.isLoading ? "Converting..." : "Create PDF"),
              icon: state.isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Icon(Icons.save_as),
            )
          : null,
          
      body: state.selectedImages.isEmpty 
          ? _buildEmptyState(context, controller) 
          : _buildImageGrid(context, state, controller),
    );
  }

  void _showSuccessDialog(BuildContext context, File generatedFile, ImageToPdfNotifier controller) {
    final String fileName = p.basename(generatedFile.path);

    showDialog(
      context: context,
      barrierDismissible: false, // Force intentional choice
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: AppColors.success),
              SizedBox(width: 10),
              Text("PDF Generated!"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Your PDF is ready for your next steps:", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  fileName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),
              
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Colors.blue),
                title: const Text("Save to Device", style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text("Choose local directory destination"),
                onTap: () async {
                  final savedPath = await FileHelper.instance.saveFileToUserDevice(generatedFile, fileName);
                  if (savedPath != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Saved safely to: ${p.basename(savedPath)}"),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
              ),
              const Divider(height: 1),

              ListTile(
                leading: const Icon(Icons.share_rounded, color: Colors.purple),
                title: const Text("Share File", style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text("Send via messaging or cloud apps"),
                onTap: () {
                  Share.shareXFiles([XFile(generatedFile.path)], text: 'Created with MintPDF');
                },
              ),
              const Divider(height: 1),

              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text("Open PDF", style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text("Preview content immediately"),
                onTap: () {
                  OpenFile.open(generatedFile.path);
                },
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                controller.reset(); // Wipe selected images cache clean for the next usage
              },
              child: const Text("Done"),
            ),
          ],
        );
      },
    );
  }

  void _showSaveDialog(BuildContext context, ImageToPdfNotifier controller) {
    final textController = TextEditingController(text: "Scan_${DateTime.now().hour}_${DateTime.now().minute}");
    PdfCompressionLevel selectedQuality = PdfCompressionLevel.normal;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Configure PDF"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Filename", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "Enter file name",
                      suffixText: ".pdf",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Quality / Size", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<PdfCompressionLevel>(
                        value: selectedQuality,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                            value: PdfCompressionLevel.none,
                            child: Text("High Quality (Large File)"),
                          ),
                          DropdownMenuItem(
                            value: PdfCompressionLevel.normal,
                            child: Text("Medium (Recommended)"),
                          ),
                          DropdownMenuItem(
                            value: PdfCompressionLevel.best,
                            child: Text("Low Quality (Smallest Size)"),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              selectedQuality = value;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    controller.convert(textController.text, selectedQuality);
                  },
                  child: const Text("Generate"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, ImageToPdfNotifier controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.image_search_rounded,
              size: 64,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No Images Selected",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            "Select images from your gallery to start",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => controller.pickImages(),
            icon: const Icon(Icons.add),
            label: const Text("Select Images"),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(BuildContext context, ImageToPdfState state, ImageToPdfNotifier controller) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                "Long press and drag to reorder pages",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: ReorderableGridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: state.selectedImages.length,
            onReorder: (oldIndex, newIndex) {
              controller.reorderImages(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final file = state.selectedImages[index];
              return Container(
                key: ValueKey(file.path),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          file,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => controller.removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "${index + 1}",
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}