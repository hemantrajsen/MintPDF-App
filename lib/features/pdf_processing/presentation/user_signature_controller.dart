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

  final SignatureController signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent, 
  );

  Future<void> _loadExistingSignature() async {
    try {
      final docDir = await FileHelper.instance.getTempDir(); 
      final file = File('${docDir.path}/user_signature.png');
      if (await file.exists()) {
        state = state.copyWith(savedSignatureFile: file);
      }
    } catch (e) {
      // Ignore if file doesn't exist yet
    }
  }

  Future<bool> saveSignature() async {
    if (signatureController.isEmpty) {
      state = state.copyWith(error: "Please draw a signature first.");
      return false;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      final Uint8List? pngBytes = await signatureController.toPngBytes();
      if (pngBytes == null) throw Exception("Failed to encode signature.");

      final docDir = await FileHelper.instance.getTempDir(); 
      final file = File('${docDir.path}/user_signature.png');

      // 1. FORCE EVICT FROM FLUTTER'S IMAGE CACHE
      // This forces Flutter to clear any old image matching this file path from memory
      await FileImage(file).evict();

      // 2. Write the fresh new signature bytes
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
        // Evict from cache here too before erasing the physical file
        await FileImage(state.savedSignatureFile!).evict();
        await state.savedSignatureFile!.delete();
      }
      
      state = UserSignatureState(
        isSaving: state.isSaving,
        savedSignatureFile: null,
        error: state.error,
      );
      
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