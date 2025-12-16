import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart'; // For opening the result
import 'package:mintpdf/core/theme/app_colors.dart';
import 'image_to_pdf_controller.dart';

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
              onPressed: state.isLoading ? null : () => controller.convert(),
              label: Text(state.isLoading ? "Converting..." : "Create PDF"),
              icon: state.isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Icon(Icons.check),
            )
          : null,
          
      body: state.selectedImages.isEmpty 
          ? _buildEmptyState(context, controller) 
          : _buildImageGrid(context, state, controller),
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
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, // 3 Images per row
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: state.selectedImages.length,
      itemBuilder: (context, index) {
        final file = state.selectedImages[index];
        return Stack(
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
        );
      },
    );
  }
}