import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/backup_share.dart';
import '../models/wardrobe.dart';
import '../product.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/logout_button.dart';
import '../widgets/mine_logo_mark.dart';
import '../widgets/profile_avatar.dart';
import 'clear_data_screen.dart';
import 'notifications_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;
  var _filled = false;
  var _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    final profile = context.read<MineState>().profile;
    _name = TextEditingController(
      text: profile.name == 'there' ? '' : profile.name,
    );
    _filled = true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _persist(void Function(UserProfile profile) change) async {
    final state = context.read<MineState>();
    change(state.profile);
    await state.updateProfile(state.profile);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<MineState>().profile;
    final displayName = _nameValue(profile) ?? 'Your profile';
    final dob = profile.dateOfBirth == null
        ? 'Add DOB'
        : DateFormat('d MMM yyyy').format(profile.dateOfBirth!);

    // Distinct studio look — no portrait wash, cool sage atmosphere.
    return Scaffold(
      backgroundColor: const Color(0xFFEEF3F0),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _StudioBackdropPainter()),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 14, 0),
                    child: Row(
                      children: [
                        const MineLogoMark(size: 44, radius: 14),
                        const SizedBox(width: 12),
                        Text(
                          'You',
                          style: GoogleFonts.manrope(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                            color: const Color(0xFF1F2A26),
                          ),
                        ),
                        const Spacer(),
                        _LogoutMark(onTap: () => confirmLogout(context)),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    child: _IdentityBand(
                      displayName: displayName,
                      gender: profile.wearer.genderLabel,
                      onPhoto: _changePhoto,
                      onEdit: _editIdentity,
                      heightLabel: profile.heightCm == null
                          ? '—'
                          : _pretty(profile.heightCm!),
                      weightLabel: profile.weightKg == null
                          ? '—'
                          : _pretty(profile.weightKg!),
                      bmiLabel: profile.bmi == null
                          ? '—'
                          : profile.bmi!.toStringAsFixed(1),
                      bmiHint: profile.bmiCategory,
                      onHeight: () => _pickNumber(
                        title: 'Height',
                        suffix: 'cm',
                        value: profile.heightCm,
                        onSave: (v) => _persist((p) => p.heightCm = v),
                      ),
                      onWeight: () => _pickNumber(
                        title: 'Weight',
                        suffix: 'kg',
                        value: profile.weightKg,
                        onSave: (v) => _persist((p) => p.weightKg = v),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
                  sliver: SliverList.list(
                    children: [
                      _StudioPanel(
                        title: 'Personal',
                        children: [
                          _MenuRow(
                            icon: Icons.person_outline_rounded,
                            title: 'Name',
                            value: _nameValue(profile),
                            onTap: _editIdentity,
                          ),
                          _MenuRow(
                            icon: Icons.wc_rounded,
                            title: 'Gender',
                            value: profile.wearer.genderLabel,
                            onTap: _pickGender,
                          ),
                          _MenuRow(
                            icon: Icons.cake_outlined,
                            title: 'Date of birth',
                            value: dob,
                            onTap: _pickDob,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _StudioPanel(
                        title: 'Preferences',
                        children: [
                          _MenuRow(
                            icon: Icons.notifications_none_rounded,
                            title: 'Notifications',
                            value: _noticeValue(context),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _StudioPanel(
                        title: 'Data & app',
                        children: [
                          _MenuRow(
                            icon: Icons.ios_share_rounded,
                            title: 'Export',
                            onTap: _busy ? null : _backup,
                          ),
                          _MenuRow(
                            icon: Icons.download_outlined,
                            title: 'Import',
                            onTap: _busy ? null : _import,
                          ),
                          _MenuRow(
                            icon: Icons.info_outline_rounded,
                            title: 'About',
                            value: MineProduct.company,
                            onTap: _showAbout,
                          ),
                          _MenuRow(
                            icon: Icons.delete_outline_rounded,
                            title: 'Clear data',
                            danger: true,
                            onTap: _busy ? null : _openClearData,
                          ),
                        ],
                      ),
                      if (_busy) ...[
                        const SizedBox(height: 24),
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.sage,
                          ),
                        ),
                      ],
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

  Future<void> _showAbout() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MineProduct.appName,
                  style: GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  MineProduct.productLine,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.terracotta,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  MineProduct.shortDescription,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  MineProduct.developedBy,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _pretty(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(1);

  String? _nameValue(UserProfile profile) {
    final name = profile.name.trim();
    if (name.isEmpty || name == 'there') return null;
    return name;
  }

  String? _noticeValue(BuildContext context) {
    final count = context.read<MineState>().homeNoticeCount;
    if (count <= 0) return null;
    return '$count new';
  }

  Future<void> _changePhoto() async {
    final bytes = await pickProfileImage(context);
    if (bytes == null || !mounted) return;
    await context.read<MineState>().saveProfilePhoto(bytes);
  }

  Future<void> _editIdentity() async {
    _name.text = context.read<MineState>().profile.name == 'there'
        ? ''
        : context.read<MineState>().profile.name;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileAvatar(
                radius: 40,
                showEditBadge: true,
                onTap: _changePhoto,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await _persist((p) => p.name = _name.text.trim());
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy
                    ? null
                    : () {
                        Navigator.pop(context);
                        _openClearData();
                      },
                child: const Text(
                  'Clear data',
                  style: TextStyle(
                    color: Color(0xFFE24B4B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickGender() async {
    final profile = context.read<MineState>().profile;
    final picked = await showModalBottomSheet<Wearer>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final wearer in Wearer.values)
                ListTile(
                  leading: Icon(
                    wearer == Wearer.woman
                        ? Icons.female_rounded
                        : Icons.male_rounded,
                  ),
                  title: Text(wearer.genderLabel),
                  trailing: profile.wearer == wearer
                      ? const Icon(Icons.check_rounded, color: AppColors.terracotta)
                      : null,
                  onTap: () => Navigator.pop(context, wearer),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    await _persist((p) => p.wearer = picked);
  }

  Future<void> _pickDob() async {
    final profile = context.read<MineState>().profile;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: profile.dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked == null) return;
    await _persist((p) => p.dateOfBirth = picked);
  }

  Future<void> _pickNumber({
    required String title,
    required String suffix,
    required double? value,
    required Future<void> Function(double value) onSave,
  }) async {
    final controller = TextEditingController(
      text: value == null ? '' : _pretty(value),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(suffixText: suffix),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final parsed = double.tryParse(controller.text.trim());
    if (parsed == null || parsed <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a valid $title.')),
      );
      return;
    }
    await onSave(parsed);
  }

  Future<void> _backup() async {
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
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('Excel sheet'),
                  subtitle: const Text('Clothes and profile in a spreadsheet'),
                  onTap: () => Navigator.pop(context, BackupFileKind.excel),
                ),
                ListTile(
                  leading: const Icon(Icons.folder_zip_outlined),
                  title: const Text('Zip backup'),
                  subtitle: const Text('Photos, music and all app data'),
                  onTap: () => Navigator.pop(context, BackupFileKind.zip),
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
      final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (kind == BackupFileKind.excel) {
        final excel = await context.read<MineState>().buildExcelBackup();
        await saveBackupFile(
          excel,
          'mine-clothes-$stamp.xlsx',
          kind: BackupFileKind.excel,
        );
      } else {
        final zip = await context.read<MineState>().buildBackup();
        await saveBackupFile(
          zip,
          'mine-backup-$stamp.zip',
          kind: BackupFileKind.zip,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kind == BackupFileKind.excel
                ? 'Excel sheet is ready to save or share.'
                : 'Zip backup is ready. Photos and files are inside.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export failed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Import adds the file to what is already on this phone. Existing clothes stay.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('Excel'),
                  subtitle: const Text('Upload an .xlsx sheet'),
                  onTap: () => Navigator.pop(context, BackupFileKind.excel),
                ),
                ListTile(
                  leading: const Icon(Icons.data_object_outlined),
                  title: const Text('JSON'),
                  subtitle: const Text('Upload backup.json, or a zip that contains it'),
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
      final profile = context.read<MineState>().profile;
      _name.text = profile.name;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported without replacing your current clothes. Now ${result.clothes} clothes, ${result.looks} party looks, ${result.events} events.',
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

  void _openClearData() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ClearDataScreen()),
    );
  }
}

class _LogoutMark extends StatelessWidget {
  const _LogoutMark({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x22E24B4B),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            Icons.logout_rounded,
            size: 20,
            color: Color(0xFFE24B4B),
          ),
        ),
      ),
    );
  }
}

class _StudioBackdropPainter extends CustomPainter {
  const _StudioBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEEF3F0),
    );
    final a = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x663F5E51), Color(0x00EEF3F0)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.15, size.height * 0.08),
          radius: size.width * 0.7,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.08),
      size.width * 0.7,
      a,
    );
    final b = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x447A9EAE), Color(0x00EEF3F0)],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.95, size.height * 0.35),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.35),
      size.width * 0.55,
      b,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Identity + body metrics — soft studio card with Mine mark.
class _IdentityBand extends StatelessWidget {
  const _IdentityBand({
    required this.displayName,
    required this.gender,
    required this.onPhoto,
    required this.onEdit,
    required this.heightLabel,
    required this.weightLabel,
    required this.bmiLabel,
    required this.bmiHint,
    required this.onHeight,
    required this.onWeight,
  });

  final String displayName;
  final String gender;
  final VoidCallback onPhoto;
  final VoidCallback onEdit;
  final String heightLabel;
  final String weightLabel;
  final String bmiLabel;
  final String bmiHint;
  final VoidCallback onHeight;
  final VoidCallback onWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF7FAF8),
            Color(0xFFE4EDE8),
          ],
        ),
        border: Border.all(color: const Color(0xFF3F5E51).withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2A26).withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: onPhoto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1F2A26).withValues(alpha: 0.14),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ProfileAvatar(
                        radius: 39,
                        showEditBadge: false,
                        borderColor: Colors.transparent,
                        onTap: onPhoto,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3F5E51),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.photo_camera_outlined,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              color: const Color(0xFF1F2A26),
                            ),
                          ),
                        ),
                        const MineLogoMark(size: 28, radius: 8, shadow: false),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      gender.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: const Color(0xFF5A7A6C),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: onEdit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3F5E51),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Edit profile',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2F4A3F),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _BandStat(
                    label: 'Height',
                    value: heightLabel,
                    unit: 'cm',
                    onTap: onHeight,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
                Expanded(
                  child: _BandStat(
                    label: 'Weight',
                    value: weightLabel,
                    unit: 'kg',
                    onTap: onWeight,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
                Expanded(
                  child: _BandStat(
                    label: 'BMI',
                    value: bmiLabel,
                    unit: bmiHint,
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

class _BandStat extends StatelessWidget {
  const _BandStat({
    required this.label,
    required this.value,
    required this.unit,
    this.onTap,
  });

  final String label;
  final String value;
  final String unit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: const Color(0xFFB7D0C4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }
}

class _StudioPanel extends StatelessWidget {
  const _StudioPanel({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF1F2A26).withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: AppColors.sage,
            ),
          ),
          const SizedBox(height: 4),
          for (final child in children) child,
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE24B4B) : const Color(0xFF1F2A26);
    final shown = value?.trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: danger
                      ? const Color(0x18E24B4B)
                      : AppColors.sage.withValues(alpha: 0.14),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: danger ? const Color(0xFFE24B4B) : AppColors.sage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              if (shown != null && shown.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    shown,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B7A74),
                    ),
                  ),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: danger
                      ? const Color(0xFFE24B4B)
                      : const Color(0xFF1F2A26).withValues(alpha: 0.28),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
