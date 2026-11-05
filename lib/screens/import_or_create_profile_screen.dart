import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/backup_share.dart';
import '../product.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/mine_logo_mark.dart';
import 'onboarding_screen.dart';

/// Shown after walkthrough (slide 4): import existing Mine data, or create a profile.
class ImportOrCreateProfileScreen extends StatefulWidget {
  const ImportOrCreateProfileScreen({super.key});

  @override
  State<ImportOrCreateProfileScreen> createState() =>
      _ImportOrCreateProfileScreenState();
}

class _ImportOrCreateProfileScreenState
    extends State<ImportOrCreateProfileScreen> {
  var _busy = false;
  var _createProfile = false;

  Future<void> _import() async {
    final kind = await showModalBottomSheet<BackupFileKind>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Import your Mine backup to restore clothes, profile, week plan, and live status.',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('Excel'),
                  subtitle: const Text('Full Mine .xlsx sheet'),
                  onTap: () => Navigator.pop(context, BackupFileKind.excel),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_zip_outlined),
                  title: const Text('Zip / JSON'),
                  subtitle: const Text('Backup with photos & live status'),
                  onTap: () => Navigator.pop(context, BackupFileKind.json),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (kind == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final bytes = await pickBackupFile(kind: kind);
      if (bytes == null || !mounted) return;
      final result = await context.read<MineState>().restoreBackup(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.clothes} clothes, ${result.looks} looks, ${result.events} events.',
          ),
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read that backup file.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_createProfile) {
      return const OnboardingScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const MineLogoMark(size: 40, radius: 12, shadow: false),
                  const SizedBox(width: 12),
                  Text(
                    MineProduct.appName,
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Already have Mine data?',
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'If you used Mine before, import your backup. Otherwise create a new profile.',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _busy ? null : _import,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_file_rounded),
                label: Text(
                  _busy ? 'Importing…' : 'Import my data',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() => _createProfile = true),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(
                  'Create new profile',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: AppColors.ink, width: 1.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
