import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintpdf/core/theme/app_colors.dart';
import 'package:mintpdf/core/utils/file_helper.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'split_pdf_controller.dart';

class SplitPdfScreen extends ConsumerStatefulWidget {
  const SplitPdfScreen({super.key});

  @override
  ConsumerState<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends ConsumerState<SplitPdfScreen> {
  final TextEditingController _rangeController = TextEditingController();

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(splitPdfProvider);
    final controller = ref.read(splitPdfProvider.notifier);

    ref.listen(splitPdfProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
      
      // Trigger our unified success dialog when extraction completes
      if (next.extractedPdf != null && previous?.extractedPdf != next.extractedPdf) {
        final originalName = next.selectedFile != null 
            ? p.basename(next.selectedFile!.path) 
            : 'document.pdf';
        _showSuccessDialog(context, next.extractedPdf!, originalName, controller);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split PDF'),
        actions: [
          if (state.selectedFile != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                controller.clearFile();
                _rangeController.clear();
              },
            ),
        ],
      ),
      body: state.selectedFile == null
          ? _buildEmptyState(context, controller, state)
          : _buildSplitView(context, state, controller),
    );
  }

  // THE UNIFIED SUCCESS DIALOG (Save / Share / Open / Done)
  void _showSuccessDialog(
    BuildContext context, 
    File generatedFile, 
    String originalName, 
    SplitPdfNotifier controller
  ) {
    // Generate a default save name based on the original file
    final String baseName = p.basenameWithoutExtension(originalName);
    final String defaultSaveName = '${baseName}_split.pdf';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'PDF Split Complete!',
                style: TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Your extracted pages are ready:", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  defaultSaveName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16),

              // Option 1: Save to local device
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_rounded, color: Colors.blue),
                title: const Text("Save to Device", style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text("Choose local directory destination"),
                onTap: () async {
                  final savedPath = await FileHelper.instance.saveFileToUserDevice(generatedFile, defaultSaveName);
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

              // Option 2: Share File 
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.share_rounded, color: Colors.purple),
                title: const Text("Share File", style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text("Send via messaging or apps"),
                onTap: () {
                  Share.shareXFiles([XFile(generatedFile.path)], text: 'Extracted with MintPDF');
                },
              ),
              const Divider(height: 1),

              // Option 3: Quick Open View
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text("Open PDF", style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text("Preview extracted content"),
                onTap: () {
                  OpenFile.open(generatedFile.path);
                },
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.clearFile();
              _rangeController.clear();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    SplitPdfNotifier controller,
    SplitPdfState state,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_split, size: 64, color: Colors.teal),
            ),
            const SizedBox(height: 24),
            Text(
              'Split PDF',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Extract specific pages from your PDF',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: state.isLoading ? null : () => controller.pickFile(),
              icon: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(state.isLoading ? 'Loading...' : 'Select PDF'),
              style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitView(
    BuildContext context,
    SplitPdfState state,
    SplitPdfNotifier controller,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text(state.selectedFile!.path.split('/').last),
              subtitle: Text('${state.pageCount} Pages'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clearFile();
                  _rangeController.clear();
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Enter Page Range",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _rangeController,
            decoration: const InputDecoration(
              hintText: "e.g. 1-5, 8, 11-13",
              border: OutlineInputBorder(),
              helperText: "Use commas for single pages and hyphens for ranges",
            ),
            keyboardType: TextInputType.datetime, 
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: state.isProcessing
                ? null
                : () {
                    if (_rangeController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please enter a page range"),
                        ),
                      );
                      return;
                    }
                    controller.extractPages(_rangeController.text);
                  },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.all(16),
            ),
            child: state.isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : const Text("Extract Pages"),
          ),
        ],
      ),
    );
  }
}