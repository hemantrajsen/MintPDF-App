import 'package:flutter/material.dart';

enum FeatureType { imageToPdf, compressPdf, mergePdf, splitPdf, history, protectPdf, unlockPdf, stampSignature}

class FeatureModel {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final FeatureType type;

  const FeatureModel({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.type,
  });
}