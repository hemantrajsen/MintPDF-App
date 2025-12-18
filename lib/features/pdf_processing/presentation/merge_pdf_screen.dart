import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintpdf/core/theme/app_colors.dart';
import 'merge_pdf_controller.dart';

class MergePdfScreen extends ConsumerWidget {
  const MergePdfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mergePdfProvider);
    final controller = ref.read(mergePdfProvider.notifier);

    ref.listen(mergePdfProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
      }
      if (next.mergedPdf != null && prev?.mergedPdf != next.mergedPdf) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("PDF Merged Successfully!"), backgroundColor: AppColors.success),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Merge PDFs"),
        actions: [
          if (state.selectedFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => controller.pickFiles(),
            ),
        ],
      ),
      floatingActionButton: state.selectedFiles.length >= 2
          ? FloatingActionButton.extended(
              onPressed: state.isMerging ? null : () => _showSaveDialog(context, controller),
              label: Text(state.isMerging ? "Merging..." : "Merge Now"),
              icon: state.isMerging 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                : const Icon(Icons.merge_type),
            )
          : null,
      body: state.selectedFiles.isEmpty
          ? _buildEmptyState(context, controller)
          : _buildList(context, state, controller),
    );
  }

  Widget _buildEmptyState(BuildContext context, MergePdfNotifier controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.copy_all, size: 64, color: Colors.purple),
          ),
          const SizedBox(height: 24),
          const Text("No PDFs Selected", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Select multiple files to combine them", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => controller.pickFiles(),
            icon: const Icon(Icons.add),
            label: const Text("Select PDFs"),
            style: FilledButton.styleFrom(backgroundColor: Colors.purple),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, MergePdfState state, MergePdfNotifier controller) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Drag items to reorder • ${state.selectedFiles.length} files",
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: state.selectedFiles.length,
            onReorder: (oldIndex, newIndex) => controller.reorderFiles(oldIndex, newIndex),
            itemBuilder: (context, index) {
              final file = state.selectedFiles[index];
              final fileName = file.path.split('/').last;
              
              return Card(
                key: ValueKey(file.path), // Important for ReorderableListView
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                elevation: 0,
                color: Theme.of(context).cardTheme.color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 20),
                  ),
                  title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => controller.removeFile(index),
                      ),
                      const Icon(Icons.drag_handle, color: Colors.grey),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showSaveDialog(BuildContext context, MergePdfNotifier controller) {
    final textController = TextEditingController(text: "Merged_${DateTime.now().millisecondsSinceEpoch}");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Merge PDFs"),
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
                suffixText: ".pdf",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.mergeDocuments(textController.text);
            },
            child: const Text("Merge"),
          ),
        ],
      ),
    );
  }
}