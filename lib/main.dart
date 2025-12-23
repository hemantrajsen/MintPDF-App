import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/home/presentation/home_screen.dart';

// [CHANGE 1] Add these two imports
import 'package:pdfrx/pdfrx.dart';
import 'package:path_provider/path_provider.dart';

// [CHANGE 2] Make main() async so we can wait for the directory
void main() async {
  // [CHANGE 3] Add this block to initialize the cache
  WidgetsFlutterBinding.ensureInitialized();
  
  Pdfrx.getCacheDirectory = () async {
    final dir = await getTemporaryDirectory();
    return dir.path;
  };

  runApp(const ProviderScope(child: MintPDFApp()));
}

class MintPDFApp extends ConsumerWidget {
  const MintPDFApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      home: const HomeScreen(),
      title: 'MintPDF',
      debugShowCheckedModeBanner: false,

      // Theme Configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
    );
  }
}