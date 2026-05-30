import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintpdf/core/theme/theme_provider.dart';
import 'package:mintpdf/core/utils/file_helper.dart';
import 'package:mintpdf/features/pdf_processing/presentation/user_signature_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme'),
            subtitle: Text(_getThemeText(themeMode)),
            onTap: () => _showThemeDialog(context, ref),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Storage'),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear Temporary Files'),
            subtitle: const Text('Free up space used by processed files'),
            onTap: () => _clearCache(context),
          ),
          ListTile(
            leading: const Icon(Icons.draw, color: Colors.teal),
            title: const Text("Manage My Signature"),
            subtitle: const Text("Draw and save your default signature"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserSignatureScreen()),
              );
            },
          ),
          const Divider(),
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            trailing: Text(
              _version,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

          // ▼▼▼ YOUR SIGNATURE / DEVELOPER CREDIT ▼▼▼
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Developer'),
            subtitle: const Text('Hemant Raj Sen'),
          ),

          // ▲▲▲ END OF SIGNATURE ▲▲▲
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('No data leaves your device'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Privacy Policy'),
                  content: const Text(
                    'MintPDF is designed with privacy first. \n\n'
                    'All PDF processing (merging, splitting, compressing, etc.) happens locally on your device. \n\n'
                    'We do not upload your files to any server. Your data stays in your hands.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),

          // Optional: A nice footer
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Made with ❤️ by Hemant',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getThemeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Theme'),
        children: [
          _buildThemeOption(context, ref, ThemeMode.system, 'System Default'),
          _buildThemeOption(context, ref, ThemeMode.light, 'Light'),
          _buildThemeOption(context, ref, ThemeMode.dark, 'Dark'),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref,
    ThemeMode mode,
    String text,
  ) {
    final currentMode = ref.read(themeModeProvider);
    return SimpleDialogOption(
      onPressed: () {
        ref.read(themeModeProvider.notifier).state = mode;
        Navigator.pop(context);
      },
      child: Row(
        children: [
          Icon(
            mode == currentMode
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: mode == currentMode
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: const Text(
          'This will delete all temporary files generated by the app. Your original files will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FileHelper.instance.clearCache();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared successfully')),
        );
      }
    }
  }
}
