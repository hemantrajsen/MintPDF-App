import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';
import 'package:mintpdf/core/utils/file_helper.dart'; 

class UserSignatureState {
  final bool isSaving;
  final File? savedSignatureFile;
  final String? error;

  const UserSignatureState({
    this.isSaving = false,
    this.savedSignatureFile,
    this.error,
  });

  UserSignatureState copyWith({
    bool? isSaving,
    File? savedSignatureFile,
    String? error,
  }) {
    return UserSignatureState(
      isSaving: isSaving ?? this.isSaving,
      savedSignatureFile: savedSignatureFile ?? this.savedSignatureFile,
      error: error,
    );
  }
}

class UserSignatureNotifier extends StateNotifier<UserSignatureState> {
  UserSignatureNotifier() : super(const UserSignatureState()) {
    _loadExistingSignature();
  }

  // The engine that manages the drawing strokes
  final SignatureController signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent, // CRITICAL: Keeps background clear
  );

  Future<void> _loadExistingSignature() async {
    try {
      final docDir = await FileHelper.instance.getTempDir(); // Or getApplicationDocumentsDirectory
      final file = File('${docDir.path}/user_signature.png');
      if (await file.exists()) {
        state = state.copyWith(savedSignatureFile: file);
      }
    } catch (e) {
      // Just ignore if it doesn't exist yet
    }
  }

  Future<bool> saveSignature() async {
    if (signatureController.isEmpty) {
      state = state.copyWith(error: "Please draw a signature first.");
      return false;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      // Export strokes to a transparent PNG
      final Uint8List? pngBytes = await signatureController.toPngBytes();
      
      if (pngBytes == null) throw Exception("Failed to encode signature.");

      // Save to local device storage permanently
      final docDir = await FileHelper.instance.getTempDir(); // Use app documents dir for permanence
      final file = File('${docDir.path}/user_signature.png');
      await file.writeAsBytes(pngBytes, flush: true);

      state = state.copyWith(isSaving: false, savedSignatureFile: file);
      return true;
      
    } catch (e) {
      state = state.copyWith(isSaving: false, error: "Failed to save: $e");
      return false;
    }
  }

  void clearPad() {
    signatureController.clear();
  }

  Future<void> deleteSavedSignature() async {
    if (state.savedSignatureFile != null) {
      if (await state.savedSignatureFile!.exists()) {
        await state.savedSignatureFile!.delete();
      }
      state = state.copyWith(savedSignatureFile: null);
      signatureController.clear();
    }
  }

  @override
  void dispose() {
    signatureController.dispose();
    super.dispose();
  }
}

final userSignatureProvider = StateNotifierProvider.autoDispose<UserSignatureNotifier, UserSignatureState>((ref) {
  return UserSignatureNotifier();
});