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
import '../widgets/page_background.dart';
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

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Profile',
                        style: GoogleFonts.manrope(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    _LogoutMark(onTap: () => confirmLogout(context)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          ProfileAvatar(
                            radius: 52,
                            showEditBadge: true,
                            borderColor: AppColors.terracottaSoft,
                            onTap: _changePhoto,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            displayName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.wearer.genderLabel,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: _editIdentity,
                            child: const Text('Edit profile'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SectionCard(
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
                          value: profile.dateOfBirth == null
                              ? null
                              : DateFormat('d MMM yyyy')
                                  .format(profile.dateOfBirth!),
                          onTap: _pickDob,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'Body',
                      children: [
                        _MenuRow(
                          icon: Icons.height_rounded,
                          title: 'Height',
                          value: profile.heightCm == null
                              ? null
                              : '${_pretty(profile.heightCm!)} cm',
                          onTap: () => _pickNumber(
                            title: 'Height',
                            suffix: 'cm',
                            value: profile.heightCm,
                            onSave: (v) => _persist((p) => p.heightCm = v),
                          ),
                        ),
                        _MenuRow(
                          icon: Icons.monitor_weight_outlined,
                          title: 'Weight',
                          value: profile.weightKg == null
                              ? null
                              : '${_pretty(profile.weightKg!)} kg',
                          onTap: () => _pickNumber(
                            title: 'Weight',
                            suffix: 'kg',
                            value: profile.weightKg,
                            onSave: (v) => _persist((p) => p.weightKg = v),
                          ),
                        ),
                        _MenuRow(
                          icon: Icons.favorite_outline_rounded,
                          title: 'BMI',
                          value: profile.bmi == null ? null : profile.bmiLabel,
                          valueColor: _bmiColor(profile),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
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
                    _SectionCard(
                      title: 'Data',
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
                          icon: Icons.delete_outline_rounded,
                          title: 'Clear data',
                          danger: true,
                          onTap: _busy ? null : _openClearData,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'App',
                      children: [
                        _MenuRow(
                          icon: Icons.info_outline_rounded,
                          title: 'About',
                          value: MineProduct.company,
                          onTap: _showAbout,
                        ),
                      ],
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 20),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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

  Color? _bmiColor(UserProfile profile) {
    switch (profile.bmiCategory) {
      case 'Underweight':
        return const Color(0xFF4A7C9B);
      case 'Normal':
        return AppColors.sage;
      case 'Overweight':
        return AppColors.terracotta;
      case 'Obese':
        return const Color(0xFFE24B4B);
      default:
        return null;
    }
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
      color: const Color(0x14C45C26),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 40,
          height: 40,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.muted,
            ),
          ),
        ),
        Material(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(
                    height: 1,
                    indent: 62,
                    endIndent: 16,
                    color: Color(0xFFE8E4DF),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    this.value,
    this.valueColor,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE24B4B) : AppColors.ink;
    final shown = value?.trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: danger
                    ? const Color(0x14E24B4B)
                    : AppColors.terracottaSoft.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: danger ? const Color(0xFFE24B4B) : AppColors.terracotta,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.muted,
                  ),
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: danger ? const Color(0xFFE24B4B) : AppColors.muted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
