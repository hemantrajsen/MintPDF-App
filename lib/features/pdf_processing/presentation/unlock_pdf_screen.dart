import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintpdf/core/theme/app_colors.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'unlock_pdf_controller.dart';

class UnlockPdfScreen extends ConsumerStatefulWidget {
  const UnlockPdfScreen({super.key});

  @override
  ConsumerState<UnlockPdfScreen> createState() => _UnlockPdfScreenState();
}

class _UnlockPdfScreenState extends ConsumerState<UnlockPdfScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(unlockPdfProvider);
    final controller = ref.read(unlockPdfProvider.notifier);

    ref.listen(unlockPdfProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
      }
      
      if (next.generatedPdf != null && previous?.generatedPdf != next.generatedPdf) {
        final originalName = next.selectedFile != null 
            ? p.basename(next.selectedFile!.path) 
            : 'document.pdf';
        _showSuccessDialog(context, next.generatedPdf!, originalName, controller);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock PDF'),
        actions: [
          if (state.selectedFile != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                controller.clearFile();
                _passwordController.clear();
              },
            ),
        ],
      ),
      body: state.selectedFile == null
          ? _buildEmptyState(context, controller, state)
          : _buildUnlockView(context, state, controller),
    );
  }

  void _showSuccessDialog(BuildContext context, File generatedFile, String originalName, UnlockPdfNotifier controller) {
    // Strips "_locked" if it exists, or just appends "_unlocked"
    String baseName = p.basenameWithoutExtension(originalName);
    baseName = baseName.replaceAll('_locked', '');
    final String defaultSaveName = '${baseName}_unlocked.pdf';

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
              child: const Icon(Icons.lock_open, color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('PDF Unlocked!', style: TextStyle(fontSize: 18), overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Password removed permanently. File ready:", style: TextStyle(fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                child: Text(defaultSaveName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_rounded, color: Colors.blue),
                title: const Text("Save to Device", style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () async {
                  try {
                    // Read the raw binary data of the decrypted PDF
                    final bytes = await generatedFile.readAsBytes();

                    // Ask OS for the destination path AND hand it the bytes simultaneously
                    final String? outputFile = await FilePicker.platform.saveFile(
                      dialogTitle: 'Save Unlocked PDF',
                      fileName: defaultSaveName,
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                      bytes: bytes, 
                    );

                    if (outputFile != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Unlocked PDF saved safely to your device!"), 
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
                onTap: () => Share.shareXFiles([XFile(generatedFile.path)], text: 'Unlocked with MintPDF'),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text("Open PDF", style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => OpenFile.open(generatedFile.path),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.clearFile();
              _passwordController.clear();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, UnlockPdfNotifier controller, UnlockPdfState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.lock_open, size: 64, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            Text('Unlock PDF', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Permanently remove password protection', style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: state.isLoading ? null : () => controller.pickFile(),
              icon: state.isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.upload_file),
              label: Text(state.isLoading ? 'Loading...' : 'Select Locked PDF'),
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockView(BuildContext context, UnlockPdfState state, UnlockPdfNotifier controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text(state.selectedFile!.path.split('/').last),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clearFile();
                  _passwordController.clear();
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text("Enter Current Password", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: "Password required to open",
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.vpn_key),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: state.isProcessing
                ? null
                : () {
                    if (_passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter the password")));
                      return;
                    }
                    controller.decryptPdf(_passwordController.text);
                  },
            style: FilledButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.all(16)),
            child: state.isProcessing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                : const Text("Unlock Document"),
          ),
        ],
      ),
    );
  }
}