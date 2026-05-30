import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintpdf/core/theme/app_colors.dart';
import 'package:mintpdf/features/pdf_processing/data/providers.dart';
import 'package:mintpdf/features/pdf_processing/data/pdf_repository.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'compress_pdf_controller.dart';

class CompressPdfScreen extends ConsumerWidget {
  const CompressPdfScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(compressPdfProvider);
    final controller = ref.read(compressPdfProvider.notifier);
    final repository = ref.read(pdfRepositoryProvider);

    ref.listen(compressPdfProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }

      // Show our universal success dialog when compression completes
      if (next.result != null && previous?.result != next.result) {
        final originalName = next.selectedPdfName ?? 'document.pdf';
        _showSuccessDialog(context, next.result!, originalName, controller);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compress PDF'),
        actions: [
          if (state.selectedPdf != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Start Over',
              onPressed: () => controller.clearSelection(),
            ),
        ],
      ),
      body: state.selectedPdf == null
          ? _buildEmptyState(context, controller, state)
          : _buildCompressionView(context, state, controller, repository),
    );
  }

  // NEW: The Unified Action Choice Dialog (Stats + Save / Share / Open)
  void _showSuccessDialog(
    BuildContext context, 
    CompressionResult result, 
    String originalName,
    CompressPdfNotifier controller
  ) {
    final File generatedFile = result.compressedFile;

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
                'Compression Complete!',
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
              // The Stats Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildStatRow('Original Size', result.originalSizeFormatted),
                    const Divider(height: 16),
                    _buildStatRow('Compressed Size', result.compressedSizeFormatted, valueColor: Colors.green),
                    const Divider(height: 16),
                    _buildStatRow('Space Saved', result.savedSizeFormatted, valueColor: Colors.green),
                    const Divider(height: 16),
                    _buildStatRow('Reduction', '${result.reductionPercentage.toStringAsFixed(1)}%', valueColor: Colors.green),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text("Next steps:", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),

              // Option 1: Save to local device
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_rounded, color: Colors.blue),
                title: const Text("Save to Device", style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () async {
                  try {
                    final String defaultSaveName = p.basename(generatedFile.path);
                    // 1. Read the raw binary data of the processed PDF
                    final bytes = await generatedFile.readAsBytes();

                    // 2. Ask OS for the destination path AND hand it the bytes simultaneously
                    final String? outputFile = await FilePicker.platform.saveFile(
                      dialogTitle: 'Save PDF Document',
                      fileName: defaultSaveName, // Ensure your dialog defines defaultSaveName above this!
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                      bytes: bytes, // <--- The magic key for Scoped Storage!
                    );

                    // 3. The OS handles the heavy lifting
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

              // Option 2: Share File 
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.share_rounded, color: Colors.purple),
                title: const Text("Share File", style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  Share.shareXFiles([XFile(generatedFile.path)], text: 'Compressed with MintPDF');
                },
              ),
              const Divider(height: 1),

              // Option 3: Quick Open View
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text("Open PDF", style: TextStyle(fontWeight: FontWeight.w500)),
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
              controller.clearSelection(); // Reset UI for next file
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: valueColor, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, CompressPdfNotifier controller, CompressPdfState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.compress, size: 64, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            Text(
              'Compress PDF',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Reduce file size while maintaining quality',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: state.isLoading ? null : () => controller.pickPdf(),
              icon: state.isLoading 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(state.isLoading ? 'Loading...' : 'Select PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompressionView(
    BuildContext context,
    CompressPdfState state,
    CompressPdfNotifier controller,
    IPdfRepository repository,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFileCard(context, state),
          const SizedBox(height: 24),
          Text(
            'Compression Level',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildCompressionOptions(context, state, controller, repository),
          const SizedBox(height: 24),
          _buildSizePreview(context, state, repository),
          const SizedBox(height: 32),
          _buildCompressButton(context, state, controller),
        ],
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, CompressPdfState state) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.selectedPdfName ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Original Size: ${state.originalSizeFormatted}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompressionOptions(
    BuildContext context,
    CompressPdfState state,
    CompressPdfNotifier controller,
    IPdfRepository repository,
  ) {
    return Column(
      children: CompressionLevel.values.map((level) {
        final isSelected = state.selectedLevel == level;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: state.isCompressing ? null : () => controller.setCompressionLevel(level),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppColors.accent : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: isSelected ? AppColors.accent.withOpacity(0.05) : null,
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? AppColors.accent : Colors.grey,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getLevelTitle(level),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppColors.accent : null,
                          ),
                        ),
                        Text(
                          _getLevelDescription(level),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getLevelColor(level).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getLevelReduction(level),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getLevelColor(level),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSizePreview(BuildContext context, CompressPdfState state, IPdfRepository repository) {
    return Card(
      elevation: 0,
      color: Colors.green.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Estimated Result',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSizeColumn('Original', state.originalSizeFormatted, Colors.grey),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                _buildSizeColumn('Estimated', state.getEstimatedSize(repository), Colors.green),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    state.getEstimatedReduction(repository),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeColumn(String label, String size, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          size,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
        ),
      ],
    );
  }

  Widget _buildCompressButton(BuildContext context, CompressPdfState state, CompressPdfNotifier controller) {
    if (state.isCompressing) {
      return Column(
        children: [
          LinearProgressIndicator(
            value: state.compressionProgress,
            backgroundColor: AppColors.accent.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
          const SizedBox(height: 12),
          Text(
            'Compressing... ${(state.compressionProgress * 100).toInt()}%',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    return FilledButton.icon(
      onPressed: state.canCompress ? () => controller.compress() : null,
      icon: const Icon(Icons.compress),
      label: const Text('Compress PDF'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: AppColors.accent,
      ),
    );
  }

  String _getLevelTitle(CompressionLevel level) {
    switch (level) {
      case CompressionLevel.low: return 'Low Compression';
      case CompressionLevel.medium: return 'Medium Compression';
      case CompressionLevel.high: return 'High Compression';
      case CompressionLevel.extreme: return 'Extreme Compression';
    }
  }

  String _getLevelDescription(CompressionLevel level) {
    switch (level) {
      case CompressionLevel.low: return 'Best quality, minimal size reduction';
      case CompressionLevel.medium: return 'Good balance of quality and size';
      case CompressionLevel.high: return 'Smaller file, acceptable quality';
      case CompressionLevel.extreme: return 'Smallest file, reduced quality';
    }
  }

  String _getLevelReduction(CompressionLevel level) {
    switch (level) {
      case CompressionLevel.low: return '~15%';
      case CompressionLevel.medium: return '~40%';
      case CompressionLevel.high: return '~60%';
      case CompressionLevel.extreme: return '~75%';
    }
  }

  Color _getLevelColor(CompressionLevel level) {
    switch (level) {
      case CompressionLevel.low: return Colors.blue;
      case CompressionLevel.medium: return Colors.green;
      case CompressionLevel.high: return Colors.orange;
      case CompressionLevel.extreme: return Colors.red;
    }
  }
}