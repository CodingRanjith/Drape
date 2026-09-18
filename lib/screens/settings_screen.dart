import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/backup_share.dart';
import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
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
    final profile = context.read<DrapeState>().profile;
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
    final state = context.read<DrapeState>();
    change(state.profile);
    await state.updateProfile(state.profile);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<DrapeState>().profile;

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 20, 8),
          child: Column(
            children: [
              Row(
                children: [
                  const AppBackIcon(),
                  Expanded(
                    child: Text(
                      'My Profile',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  _LogoutMark(onTap: () => confirmLogout(context)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _WhiteCard(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
                    child: Column(
                    children: [
                      _MenuRow(
                        title: 'My Profile',
                        value: _nameValue(profile),
                        onTap: _editIdentity,
                      ),
                      _MenuRow(
                        title: 'Notifications',
                        value: _noticeValue(context),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                      ),
                      _MenuRow(
                        title: 'Gender',
                        value: profile.wearer.genderLabel,
                        onTap: _pickGender,
                      ),
                      _MenuRow(
                        title: 'Date of birth',
                        value: profile.dateOfBirth == null
                            ? null
                            : DateFormat('d MMM yyyy').format(profile.dateOfBirth!),
                        onTap: _pickDob,
                      ),
                      _MenuRow(
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
                        title: 'BMI',
                        value: profile.bmi == null ? null : profile.bmiLabel,
                        valueColor: _bmiColor(profile),
                        groupEnd: true,
                      ),
                      _MenuRow(
                        title: 'Export',
                        onTap: _busy ? null : _backup,
                      ),
                      _MenuRow(
                        title: 'Import',
                        groupEnd: true,
                        onTap: _busy ? null : _import,
                      ),
                      _MenuRow(
                        title: 'Clear data',
                        danger: true,
                        onTap: _busy ? null : _openClearData,
                      ),
                      if (_busy) ...[
                        const SizedBox(height: 12),
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ),
                ),
              ),
              ),
            ],
          ),
        ),
        ),
      ),
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
    final count = context.read<DrapeState>().homeNoticeCount;
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
    await context.read<DrapeState>().saveProfilePhoto(bytes);
  }

  Future<void> _editIdentity() async {
    _name.text = context.read<DrapeState>().profile.name == 'there'
        ? ''
        : context.read<DrapeState>().profile.name;
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
    final profile = context.read<DrapeState>().profile;
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
    final profile = context.read<DrapeState>().profile;
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
        final excel = await context.read<DrapeState>().buildExcelBackup();
        await saveBackupFile(
          excel,
          'drape-clothes-$stamp.xlsx',
          kind: BackupFileKind.excel,
        );
      } else {
        final zip = await context.read<DrapeState>().buildBackup();
        await saveBackupFile(
          zip,
          'drape-backup-$stamp.zip',
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
      final result = await context.read<DrapeState>().restoreBackup(bytes);
      if (!mounted) return;
      final profile = context.read<DrapeState>().profile;
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

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.title,
    this.value,
    this.valueColor,
    this.onTap,
    this.groupEnd = false,
    this.danger = false,
  });

  final String title;
  final String? value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final bool groupEnd;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE24B4B) : AppColors.ink;
    final shown = value?.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Row(
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: shown == null || shown.isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                          shown,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: valueColor ?? AppColors.muted,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        if (groupEnd)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Divider(height: 1, color: Color(0xFFE6E0DA)),
          ),
      ],
      ),
    );
  }
}
