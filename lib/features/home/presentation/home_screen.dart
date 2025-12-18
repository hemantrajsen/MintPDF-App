import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintpdf/core/theme/app_colors.dart';
import 'package:mintpdf/features/home/domain/feature_model.dart';
import '../../pdf_processing/presentation/image_to_pdf_screen.dart';
import '../../pdf_processing/presentation/compress_pdf_screen.dart';
import '../../pdf_processing/presentation/merge_pdf_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // Define our features list here for the UI to consume
  final List<FeatureModel> _features = const [
    FeatureModel(
      title: 'Images to PDF',
      description: 'Convert photos to a single PDF',
      icon: Icons.image_outlined,
      color: AppColors.primary,
      type: FeatureType.imageToPdf,
    ),
    FeatureModel(
      title: 'Compress PDF',
      description: 'Reduce file size',
      icon: Icons.compress,
      color: AppColors.accent,
      type: FeatureType.compressPdf,
    ),
    FeatureModel(
      title: 'Merge PDFs',
      description: 'Combine multiple files',
      icon: Icons.merge_type,
      color: Colors.purple,
      type: FeatureType.mergePdf,
    ),
    FeatureModel(
      title: 'Split PDF',
      description: 'Extract pages',
      icon: Icons.call_split,
      color: Colors.teal,
      type: FeatureType.splitPdf,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // 1. The Modern App Bar
          SliverAppBar.large(
            title: const Text(
              "MintPDF",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  // TODO: Navigate to settings
                },
              ),
              const SizedBox(width: 8),
            ],
          ),

          // 2. The Feature Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 Columns
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85, // Taller cards
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                return _FeatureCard(item: _features[index]);
              }, childCount: _features.length),
            ),
          ),

          // 3. The Privacy Trust Badge (Footer)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      // ignore: deprecated_member_use
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "100% On-Device Processing",
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------
// Sub-Widget: The Individual Feature Card
// -----------------------------------------------------------
class _FeatureCard extends StatelessWidget {
  final FeatureModel item;

  const _FeatureCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      // Use the theme's card color, but slightly elevated visually
      color: Theme.of(context).cardTheme.color,
      shape: Theme.of(context).cardTheme.shape,
      child: InkWell(
        onTap: () {
          if (item.type == FeatureType.imageToPdf) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ImageToPdfScreen()),
            );
          } else if (item.type == FeatureType.compressPdf) {
            // ADD THIS
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompressPdfScreen()),
            );
          } else if (item.type == FeatureType.mergePdf) {
            Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MergePdfScreen()),
            );
          } else {
            // Placeholder for other features
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Coming Soon: ${item.title}')),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: item.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 24),
              ),
              const Spacer(),
              // Text Content
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
