import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';
import 'package:mintpdf/core/theme/app_colors.dart';
import 'user_signature_controller.dart';

class UserSignatureScreen extends ConsumerWidget {
  const UserSignatureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userSignatureProvider);
    final controller = ref.read(userSignatureProvider.notifier);

    // Listen for errors
    ref.listen(userSignatureProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Signature'),
        actions: [
          if (state.savedSignatureFile != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: "Delete Signature",
              onPressed: () => controller.deleteSavedSignature(),
            ),
        ],
      ),
      body: SafeArea(
        child: state.savedSignatureFile != null
            ? _buildPreviewMode(context, state.savedSignatureFile!, controller)
            : _buildDrawingMode(context, state, controller),
      ),
    );
  }

  // --- 1. PREVIEW MODE ---
  Widget _buildPreviewMode(BuildContext context, File signatureFile, UserSignatureNotifier controller) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Your Active Signature",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const Text(
          "This signature will be used when stamping PDFs.",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 32),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Image.file(
              signatureFile,
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text("Error loading signature"),
            ),
          ),
        ),
        const SizedBox(height: 48),
        FilledButton.icon(
          onPressed: () {
            // Deleting the saved file automatically switches the UI back to the drawing pad
            controller.deleteSavedSignature();
          },
          icon: const Icon(Icons.draw),
          label: const Text("Create New Signature"),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.teal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ],
    );
  }

  // --- 2. DRAWING MODE ---
  Widget _buildDrawingMode(BuildContext context, UserSignatureState state, UserSignatureNotifier controller) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Draw your signature below. It will be saved securely on your device for stamping PDFs.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
        
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueGrey.shade200, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Signature(
                  controller: controller.signatureController,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => controller.clearPad(),
                  icon: const Icon(Icons.clear),
                  label: const Text("Clear"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.isSaving
                      ? null
                      : () async {
                          final success = await controller.saveSignature();
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Signature saved successfully!"),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            // We don't pop here anymore, the UI will automatically 
                            // rebuild into Preview Mode!
                          }
                        },
                  icon: state.isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: const Text("Save"),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}