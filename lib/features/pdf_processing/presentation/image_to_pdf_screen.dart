import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart'; // For opening the result
import 'package:mintpdf/core/theme/app_colors.dart';
import 'image_to_pdf_controller.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class ImageToPdfScreen extends ConsumerWidget {
  const ImageToPdfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Listen to the state
    final state = ref.watch(imageToPdfProvider);
    final controller = ref.read(imageToPdfProvider.notifier);

    // 2. Listen for Success (Side Effect)
    ref.listen(imageToPdfProvider, (previous, next) {
      if (next.generatedPdf != null && previous?.generatedPdf != next.generatedPdf) {
        // success! Open the file immediately
        OpenFile.open(next.generatedPdf!.path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("PDF Created Successfully!"),
            backgroundColor: AppColors.success,
          ),
        );
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
      
      // Floating Action Button (The "Convert" Trigger)
      floatingActionButton: state.selectedImages.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: state.isLoading 
              ? null
              : () => _showSaveDialog(context, controller),
              label: Text(state.isLoading ? "Converting..." : "Create PDF"),
              icon: state.isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Icon(Icons.save_as), //changed icon to represent saving
            )
          : null,
          
      body: state.selectedImages.isEmpty 
          ? _buildEmptyState(context, controller) 
          : _buildImageGrid(context, state, controller),
    );
  }

  // 2. ADD: The "Save Options" Dialog
  void _showSaveDialog(BuildContext context, ImageToPdfNotifier controller) {
    final textController = TextEditingController(text: "Scan_${DateTime.now().hour}_${DateTime.now().minute}");
    
    // Default quality
    PdfCompressionLevel selectedQuality = PdfCompressionLevel.normal;

    showDialog(
      context: context,
      builder: (ctx) {
        // StatefulBuilder allows the Dialog to update itself (for the Dropdown)
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Save PDF"),
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
                  
                  // The Quality Dropdown
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
                            // This 'setState' only rebuilds the Dialog, not the whole screen
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
                    // Pass BOTH name and quality to the controller
                    controller.convert(textController.text, selectedQuality);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Sub-Widget: Empty State ---
  Widget _buildEmptyState(BuildContext context, ImageToPdfNotifier controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
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

  // --- Sub-Widget: Image Grid ---
  Widget _buildImageGrid(BuildContext context, ImageToPdfState state, ImageToPdfNotifier controller) {
    return Column(
      children: [
         // SUBTLE HINT
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
            crossAxisCount: 3, // 3 Images per row
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
                  // The Image Thumbnail
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // The Delete Button (Top Right)
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
                  // Number Badge (Bottom Left)
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