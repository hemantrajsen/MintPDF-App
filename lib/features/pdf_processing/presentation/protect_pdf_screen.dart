import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintpdf/core/theme/app_colors.dart';
import 'package:mintpdf/core/utils/file_helper.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;
import 'protect_pdf_controller.dart';

class ProtectPdfScreen extends ConsumerStatefulWidget {
  const ProtectPdfScreen({super.key});

  @override
  ConsumerState<ProtectPdfScreen> createState() => _ProtectPdfScreenState();
}

class _ProtectPdfScreenState extends ConsumerState<ProtectPdfScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(protectPdfProvider);
    final controller = ref.read(protectPdfProvider.notifier);

    ref.listen(protectPdfProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
      
      // Trigger our unified success dialog
      if (next.generatedPdf != null && previous?.generatedPdf != next.generatedPdf) {
        final originalName = next.selectedFile != null 
            ? p.basename(next.selectedFile!.path) 
            : 'document.pdf';
        _showSuccessDialog(context, next.generatedPdf!, originalName, controller);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Protect PDF'),
        actions: [
          if (state.selectedFile != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                controller.clearFile();
                _passwordController.clear();
                _confirmController.clear();
              },
            ),
        ],
      ),
      body: state.selectedFile == null
          ? _buildEmptyState(context, controller, state)
          : _buildProtectView(context, state, controller),
    );
  }

  // THE UNIFIED SUCCESS DIALOG (Save / Share / Open / Done)
  void _showSuccessDialog(
    BuildContext context, 
    File generatedFile, 
    String originalName, 
    ProtectPdfNotifier controller
  ) {
    final String baseName = p.basenameWithoutExtension(originalName);
    final String defaultSaveName = '${baseName}_locked.pdf';

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
              child: const Icon(Icons.lock_clock, color: AppColors.success, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'PDF Secured!',
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
              const Text("Your AES-256 encrypted file is ready:", style: TextStyle(fontSize: 14)),
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

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.share_rounded, color: Colors.purple),
                title: const Text("Share File", style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text("Send via messaging or apps"),
                onTap: () {
                  Share.shareXFiles([XFile(generatedFile.path)], text: 'Secured with MintPDF');
                },
              ),
              const Divider(height: 1),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text("Open PDF", style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text("Test your new password"),
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
              _passwordController.clear();
              _confirmController.clear();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ProtectPdfNotifier controller,
    ProtectPdfState state,
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
                color: Colors.blueGrey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.security, size: 64, color: Colors.blueGrey),
            ),
            const SizedBox(height: 24),
            Text(
              'Protect PDF',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Lock your file with AES-256 encryption',
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
              style: FilledButton.styleFrom(backgroundColor: Colors.blueGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtectView(
    BuildContext context,
    ProtectPdfState state,
    ProtectPdfNotifier controller,
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
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clearFile();
                  _passwordController.clear();
                  _confirmController.clear();
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Set Password",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: "Enter password",
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _confirmController,
            obscureText: _obscurePassword,
            decoration: const InputDecoration(
              hintText: "Confirm password",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          
          const SizedBox(height: 32),
          FilledButton(
            onPressed: state.isProcessing
                ? null
                : () {
                    if (_passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter a password")),
                      );
                      return;
                    }
                    if (_passwordController.text != _confirmController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Passwords do not match")),
                      );
                      return;
                    }
                    controller.encryptPdf(_passwordController.text);
                  },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              padding: const EdgeInsets.all(16),
            ),
            child: state.isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : const Text("Encrypt Document"),
          ),
        ],
      ),
    );
  }
}