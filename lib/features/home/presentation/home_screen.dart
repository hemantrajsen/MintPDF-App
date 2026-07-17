import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintpdf/features/pdf_processing/presentation/stamp_pdf_screen.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:mintpdf/core/theme/app_colors.dart';
import 'package:mintpdf/features/home/domain/feature_model.dart';
import '../../pdf_processing/presentation/image_to_pdf_screen.dart';
import '../../pdf_processing/presentation/compress_pdf_screen.dart';
import '../../pdf_processing/presentation/merge_pdf_screen.dart';
import '../../pdf_processing/presentation/split_pdf_screen.dart';
import '../../pdf_processing/presentation/protect_pdf_screen.dart';
import '../../pdf_processing/presentation/unlock_pdf_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _animController;

  final List<FeatureModel> _features = const [
    FeatureModel(
      title: 'Images to PDF',
      description: 'Convert photos to a single PDF',
      icon: Icons.image_outlined,
      color: Color.fromARGB(255, 0, 150, 97),
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
      color: Colors.indigoAccent,
      type: FeatureType.splitPdf,
    ),
    FeatureModel(
      title: 'Protect PDF',
      description: 'Lock with AES-256',
      icon: Icons.security,
      color: Colors.blueGrey,
      type: FeatureType.protectPdf, 
    ),
    FeatureModel(
      title: 'Unlock PDF',
      description: 'Remove passwords permanently',
      icon: Icons.lock_open,
      color: Colors.green,
      type: FeatureType.unlockPdf, 
    ),
    FeatureModel(
      title: 'Stamp Signature',
      description: 'Put your signature in PDF',
      icon: Icons.draw,
      color: Colors.redAccent,
      type: FeatureType.stampSignature,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.95);
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  List<List<FeatureModel>> _getChunks() {
    List<List<FeatureModel>> chunks = [];
    for (var i = 0; i < _features.length; i += 4) {
      int end = (i + 4 < _features.length) ? i + 4 : _features.length;
      chunks.add(_features.sublist(i, end));
    }
    return chunks;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final featureChunks = _getChunks();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 1. STATIC HEADER
            _buildStaticHeader(isDark),

            // 2. SWIPEABLE CANVAS
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  _animController.reset();
                  _animController.forward();
                },
                itemCount: featureChunks.length,
                itemBuilder: (context, pageIndex) {
                  final chunk = featureChunks[pageIndex];
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 50), 
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85, 
                      ),
                      itemCount: chunk.length,
                      itemBuilder: (context, itemIndex) {
                        return _buildStaggeredCard(chunk[itemIndex], itemIndex);
                      },
                    ),
                  );
                },
              ),
            ),

            // 3. EXPANDING DOT INDICATOR
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: featureChunks.length,
                effect: ExpandingDotsEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  activeDotColor: AppColors.primary,
                  // ignore: deprecated_member_use
                  dotColor: Colors.grey.withOpacity(0.3),
                  expansionFactor: 4,
                ),
              ),
            ),

            // 4. STATIC FOOTER
            _buildTrustBadge(),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildStaticHeader(bool isDark) {
    return SizedBox(
      height: 140, 
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. The Cool Document Watermark!
          Positioned(
            top: 10,
            right: 15,
            child: Transform.rotate(
              angle: 0.15, // A slight tilt to make it look dynamic
              child: Icon(
                Icons.text_snippet_rounded, // The "docs image"
                size: 130, // Scaled up massively
                color: isDark 
                    // ignore: deprecated_member_use
                    ? Colors.white.withOpacity(0.04) 
                    // ignore: deprecated_member_use
                    : Colors.black.withOpacity(0.03),
              ),
            ),
          ),

          // 2. Original Background Blobs
          Positioned(
            top: -40,
            right: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  // ignore: deprecated_member_use
                  colors: [AppColors.primary.withOpacity(0.30), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: -30,
            child: Container(
              width: 150,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // ignore: deprecated_member_use
                color: AppColors.accent.withOpacity(0.08),
              ),
            ),
          ),
          
          // 3. Original Foreground Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      "MintPDF",
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w900, 
                        letterSpacing: -0.5,
                        fontSize: 32, 
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "What would you like to do?",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Theme.of(context).cardColor.withOpacity(0.8), // Slightly more opaque so the settings gear stands out against the watermark
                    shape: BoxShape.circle,
                    border: Border.all(
                      // ignore: deprecated_member_use
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaggeredCard(FeatureModel item, int index) {
    final double start = index * 0.15;
    final double end = (start + 0.5).clamp(0.0, 1.0);

    final animation = CurvedAnimation(
      parent: _animController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return FadeTransition(
          opacity: animation,
          child: Transform.translate(
            offset: Offset(0, 40 * (1.0 - animation.value)),
            child: child,
          ),
        );
      },
      child: _FeatureCard(item: item),
    );
  }

  Widget _buildTrustBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        // ignore: deprecated_member_use
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
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
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final FeatureModel item;

  const _FeatureCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      color: Theme.of(context).cardTheme.color,
      shape: Theme.of(context).cardTheme.shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
          if (item.type == FeatureType.imageToPdf) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ImageToPdfScreen()));
          } else if (item.type == FeatureType.compressPdf) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CompressPdfScreen()));
          } else if (item.type == FeatureType.mergePdf) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MergePdfScreen()));
          } else if (item.type == FeatureType.splitPdf) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SplitPdfScreen()));
          } else if (item.type == FeatureType.protectPdf) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProtectPdfScreen()));
          } else if (item.type == FeatureType.unlockPdf) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const UnlockPdfScreen()));
          } else if (item.type == FeatureType.stampSignature){
            Navigator.push(context,MaterialPageRoute(builder: (_) => const StampPdfScreen()) );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Coming Soon: ${item.title}')));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52, 
                height: 52,
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: item.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(item.icon, color: item.color, size: 28),
              ),
              const Spacer(),
              Text(
                item.title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                item.description,
                style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
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