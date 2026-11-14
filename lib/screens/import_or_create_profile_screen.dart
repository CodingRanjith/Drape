import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    extends State<ImportOrCreateProfileScreen>
    with SingleTickerProviderStateMixin {
  var _busy = false;
  var _createProfile = false;
  late final AnimationController _enter;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    HapticFeedback.selectionClick();
    final kind = await showModalBottomSheet<BackupFileKind>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.terracottaSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.table_chart_outlined,
                      color: AppColors.terracotta,
                    ),
                  ),
                  title: Text(
                    'Excel',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Full Mine .xlsx sheet',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, BackupFileKind.excel),
                ),
                ListTile(
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.sageSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.folder_zip_outlined,
                      color: AppColors.sage,
                    ),
                  ),
                  title: Text(
                    'Zip / JSON',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Backup with photos & live status',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
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
      backgroundColor: const Color(0xFFF5F1EC),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _WelcomeBackdropPainter()),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const MineLogoMark(size: 36, radius: 11, shadow: false),
                          const SizedBox(width: 10),
                          Text(
                            MineProduct.appName,
                            style: GoogleFonts.manrope(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _HeroMark(),
                            const SizedBox(height: 28),
                            Text(
                              MineProduct.appName,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 44,
                                height: 1.0,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.6,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              MineProduct.tagline,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: 36,
                              height: 2,
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              MineProduct.productLine,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: AppColors.muted.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Already have Mine data?',
                        style: GoogleFonts.manrope(
                          fontSize: 24,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Import a backup to restore your closet, or start fresh with a new profile.',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _ChoiceTile(
                        title: _busy ? 'Importing…' : 'Import my data',
                        subtitle: 'Excel or Zip backup',
                        icon: Icons.upload_file_rounded,
                        primary: true,
                        busy: _busy,
                        onTap: _busy ? null : _import,
                      ),
                      const SizedBox(height: 10),
                      _ChoiceTile(
                        title: 'Create new profile',
                        subtitle: 'Set up Mine from scratch',
                        icon: Icons.person_add_alt_1_rounded,
                        primary: false,
                        onTap: _busy
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                setState(() => _createProfile = true);
                              },
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_busy)
            ColoredBox(
              color: AppColors.ink.withValues(alpha: 0.08),
              child: const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: AppColors.terracotta,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroMark extends StatefulWidget {
  const _HeroMark();

  @override
  State<_HeroMark> createState() => _HeroMarkState();
}

class _HeroMarkState extends State<_HeroMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 1.0 + (t * 0.08),
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.terracotta.withValues(alpha: 0.08 + t * 0.04),
                ),
              ),
            ),
            Transform.scale(
              scale: 1.0 + (t * 0.04),
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.10 + t * 0.05),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: const MineLogoMark(size: 88, radius: 24, shadow: false),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primary,
    required this.onTap,
    this.busy = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool primary;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bg = primary ? AppColors.ink : Colors.white.withValues(alpha: 0.78);
    final fg = primary ? Colors.white : AppColors.ink;
    final muted = primary
        ? Colors.white.withValues(alpha: 0.72)
        : AppColors.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: primary
                ? null
                : Border.all(color: AppColors.ink.withValues(alpha: 0.12)),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: primary
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppColors.terracottaSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: busy
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: fg,
                          ),
                        )
                      : Icon(
                          icon,
                          color: primary ? Colors.white : AppColors.terracotta,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: primary
                      ? Colors.white.withValues(alpha: 0.7)
                      : AppColors.muted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeBackdropPainter extends CustomPainter {
  const _WelcomeBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF5F1EC),
    );
    final a = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x40C45C26), Color(0x00F5F1EC)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.85, size.height * 0.18),
          radius: size.width * 0.7,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.18),
      size.width * 0.7,
      a,
    );
    final b = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x2EB0894F), Color(0x00F5F1EC)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.08, size.height * 0.55),
          radius: size.width * 0.6,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.55),
      size.width * 0.6,
      b,
    );
    final c = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x1A3F5E51), Color(0x00F5F1EC)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.6, size.height * 1.02),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.6, size.height * 1.02),
      size.width * 0.55,
      c,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
