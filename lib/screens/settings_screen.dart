import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/backup_share.dart';
import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/closet_add.dart';
import '../widgets/logout_button.dart';
import 'garment_editor_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const days = [
    (1, 'Monday'),
    (2, 'Tuesday'),
    (3, 'Wednesday'),
    (4, 'Thursday'),
    (5, 'Friday'),
    (6, 'Saturday'),
    (7, 'Sunday'),
  ];

  late final TextEditingController _name;
  var _named = false;
  var _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_named) return;
    _name = TextEditingController(text: context.read<DrapeState>().profile.name);
    _named = true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final profile = state.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('Add, backup, import', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Add clothes to your closet. Backup saves a zip file with every uploaded photo, music, clothes and events. Import that zip to bring it all back.',
          ),
          const SizedBox(height: 14),
          _ActionCard(
            icon: Icons.add_photo_alternate_outlined,
            title: 'Add',
            subtitle: 'Add a photo and name to your closet',
            onTap: _busy ? null : _addClothes,
          ),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.backup_outlined,
            title: 'Backup',
            subtitle: 'Save a zip with all uploaded files',
            onTap: _busy ? null : _backup,
          ),
          const SizedBox(height: 10),
          _ActionCard(
            icon: Icons.file_download_outlined,
            title: 'Import',
            subtitle: 'Pick the backup zip to restore files',
            onTap: _busy ? null : _import,
          ),
          if (_busy) ...[
            const SizedBox(height: 14),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 28),
          Text('Your name', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (v) {
              profile.name = v;
              state.updateProfile(profile);
            },
          ),
          const SizedBox(height: 24),
          Text('Closet for', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Women: top, pant, shawl, slippers, earrings. Men: shirt or T-shirt, and pant.'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: Wearer.values.map((w) {
              final selected = profile.wearer == w;
              return ChoiceChip(
                label: Text(w.label),
                selected: selected,
                onSelected: (_) {
                  profile.wearer = w;
                  state.updateProfile(profile);
                },
                selectedColor: AppColors.ink,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text('Office days', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Choose the days you go to the office. Monday to Friday is already selected.'),
          const SizedBox(height: 12),
          ...days.map((d) {
            final selected = profile.workdays.contains(d.$1);
            return SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                d.$2,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              value: selected,
              activeThumbColor: AppColors.terracotta,
              onChanged: (v) {
                if (!v && profile.workdays.length == 1) return;
                if (v) {
                  profile.workdays.add(d.$1);
                } else {
                  profile.workdays.remove(d.$1);
                }
                state.updateProfile(profile);
              },
            );
          }),
          const SizedBox(height: 12),
          Text('Office style', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: Formality.values.map((f) {
              final selected = profile.workStyle == f;
              return ChoiceChip(
                label: Text(f.label),
                selected: selected,
                onSelected: (_) {
                  profile.workStyle = f;
                  state.updateProfile(profile);
                },
                selectedColor: AppColors.ink,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text('Do not repeat too soon', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Do not wear the same item again for ${profile.minRepeatDays} days.'),
          Slider(
            value: profile.minRepeatDays.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            label: '${profile.minRepeatDays}d',
            activeColor: AppColors.terracotta,
            onChanged: (v) {
              profile.minRepeatDays = v.round();
              state.updateProfile(profile);
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => state.refreshWeek(keepLocks: true),
            child: const Text('Make new outfits for this week'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => state.refreshWeek(keepLocks: false),
            child: const Text('Make new outfits for every day'),
          ),
          const SizedBox(height: 28),
          Text(
            'Backup makes a .zip file. Every photo and song you uploaded is inside that zip. Keep the zip in Drive or Files. After uninstall, tap Import and pick that zip.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          Text('Logout', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Logout takes you back to Women or Men selection. Your clothes stay on this phone.',
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() => confirmLogout(context);

  Future<void> _addClothes() async {
    await pickClothesType(
      context,
      title: 'Add clothes',
      onPick: (type) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GarmentEditorScreen(
              initialCategory: type.category,
              initialTopKind: type.topKind,
            ),
          ),
        );
      },
    );
  }

  Future<void> _backup() async {
    setState(() => _busy = true);
    try {
      final zip = await context.read<DrapeState>().buildBackup();
      final name =
          'drape-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.zip';
      await saveBackupFile(zip, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup zip is ready. It has your uploaded photos and files.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup failed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import backup?'),
        content: const Text(
          'Pick the .zip backup file. All uploaded photos and music in that zip will come back. This replaces clothes and events now in the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final bytes = await pickBackupFile();
      if (bytes == null || !mounted) return;
      final result = await context.read<DrapeState>().restoreBackup(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.clothes} clothes, ${result.looks} party looks, ${result.events} events.',
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
        const SnackBar(content: Text('Could not read that zip file.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.terracottaSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.terracotta),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
