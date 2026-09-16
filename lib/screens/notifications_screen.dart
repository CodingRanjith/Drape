import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/life.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/page_background.dart';
import 'event_editor_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _days = [
    (1, 'Mon'),
    (2, 'Tue'),
    (3, 'Wed'),
    (4, 'Thu'),
    (5, 'Fri'),
    (6, 'Sat'),
    (7, 'Sun'),
  ];

  var _step = 0;
  late Set<int> _daysSelected;
  var _alarmOn = true;
  late TimeOfDay _time;
  Uint8List? _musicBytes;
  String? _musicExt;
  String? _musicMime;
  String? _musicName;
  var _filled = false;
  var _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    final profile = context.read<DrapeState>().profile;
    _daysSelected = {...profile.workdays};
    _alarmOn = profile.officeAlarmOn;
    _time = profile.officeAlarmTime;
    _musicName = profile.officeAlarmMusicName;
    _filled = true;
  }

  String get _musicLabel {
    if (_musicName != null && _musicName!.isNotEmpty) return _musicName!;
    if (_musicBytes != null) return 'Custom song';
    final path = context.read<DrapeState>().profile.officeAlarmMusicPath;
    if (path != null && path.isNotEmpty) return 'Custom song';
    return 'Default bell';
  }

  Future<void> _pickMusic() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read that song. Try another file.')),
      );
      return;
    }
    final ext = (file.extension ?? 'mp3').toLowerCase();
    setState(() {
      _musicBytes = bytes;
      _musicExt = ext;
      _musicMime = switch (ext) {
        'wav' => 'audio/wav',
        'm4a' => 'audio/mp4',
        'aac' => 'audio/aac',
        'ogg' => 'audio/ogg',
        _ => 'audio/mpeg',
      };
      _musicName = file.name;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null) return;
    setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_daysSelected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose at least one office day.')),
      );
      setState(() => _step = 0);
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<DrapeState>().saveOfficeAlarm(
        workdays: _daysSelected,
        alarmOn: _alarmOn,
        hour: _time.hour,
        minute: _time.minute,
        musicBytes: _musicBytes,
        musicExt: _musicExt,
        musicMime: _musicMime,
        musicName: _musicName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _alarmOn
                ? 'Office alarm saved for ${_time.format(context)}.'
                : 'Office days saved. Alarm is off.',
          ),
        ),
      );
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    if (_step == 0 && _daysSelected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose at least one office day.')),
      );
      return;
    }
    if (_step == 1 && !_alarmOn) {
      _save();
      return;
    }
    if (_step >= 3) {
      _save();
      return;
    }
    setState(() => _step += 1);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    final upcoming = state.upcomingEvents;

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        leading: const AppBackIcon(),
        title: const Text('Notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (upcoming.isNotEmpty) ...[
            Text('Upcoming events', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            for (final event in upcoming.take(6)) _EventNotice(event: event),
            const SizedBox(height: 24),
          ],
          Text(
            'Office day alarm',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose office days, turn on the alarm, pick music, then set the time.',
          ),
          const SizedBox(height: 16),
          _StepDots(index: _step, total: 4),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (_step) {
              0 => _DaysStep(
                  key: const ValueKey(0),
                  days: _days,
                  selected: _daysSelected,
                  onToggle: (day) {
                    setState(() {
                      if (_daysSelected.contains(day)) {
                        if (_daysSelected.length == 1) return;
                        _daysSelected.remove(day);
                      } else {
                        _daysSelected.add(day);
                      }
                    });
                  },
                ),
              1 => _AlarmStep(
                  key: const ValueKey(1),
                  alarmOn: _alarmOn,
                  onChanged: (v) => setState(() => _alarmOn = v),
                ),
              2 => _MusicStep(
                  key: const ValueKey(2),
                  label: _musicLabel,
                  onPick: _pickMusic,
                ),
              _ => _TimeStep(
                  key: const ValueKey(3),
                  time: _time,
                  onPick: _pickTime,
                ),
            },
          ),
          const SizedBox(height: 24),
          if (_saving)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step -= 1),
                      child: const Text('Back'),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _next,
                    child: Text(_step >= 3 || (_step == 1 && !_alarmOn) ? 'Save' : 'Next'),
                  ),
                ),
              ],
            ),
        ],
      ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    const labels = ['Days', 'Alarm', 'Music', 'Time'];
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= index ? AppColors.terracotta : AppColors.line,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == index ? FontWeight.w800 : FontWeight.w600,
                    color: i <= index ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (i < total - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _DaysStep extends StatelessWidget {
  const _DaysStep({
    super.key,
    required this.days,
    required this.selected,
    required this.onToggle,
  });

  final List<(int, String)> days;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      icon: Icons.event_available_rounded,
      title: 'Select office days',
      body: 'These days get an outfit plan and the morning alarm.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final day in days)
            FilterChip(
              label: Text(day.$2),
              selected: selected.contains(day.$1),
              onSelected: (_) => onToggle(day.$1),
              selectedColor: AppColors.ink,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: selected.contains(day.$1) ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _AlarmStep extends StatelessWidget {
  const _AlarmStep({
    super.key,
    required this.alarmOn,
    required this.onChanged,
  });

  final bool alarmOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      icon: Icons.alarm_rounded,
      title: 'Days alarm',
      body: 'Ring on every selected office day, so you can get dressed on time.',
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          alarmOn ? 'Alarm on' : 'Alarm off',
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        subtitle: Text(alarmOn ? 'Next you will pick music and time.' : 'Save without a morning alarm.'),
        value: alarmOn,
        activeThumbColor: AppColors.terracotta,
        onChanged: onChanged,
      ),
    );
  }
}

class _MusicStep extends StatelessWidget {
  const _MusicStep({
    super.key,
    required this.label,
    required this.onPick,
  });

  final String label;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      icon: Icons.music_note_rounded,
      title: 'Select music',
      body: 'This song plays when the office alarm rings. You can keep the default bell.',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.library_music_outlined),
        title: const Text('Alarm music'),
        subtitle: Text(label),
        trailing: TextButton(onPressed: onPick, child: const Text('Choose')),
      ),
    );
  }
}

class _TimeStep extends StatelessWidget {
  const _TimeStep({
    super.key,
    required this.time,
    required this.onPick,
  });

  final TimeOfDay time;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return _StepCard(
      icon: Icons.schedule_rounded,
      title: 'Set time',
      body: 'The alarm rings at this time on each office day.',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.access_time_rounded),
        title: const Text('Alarm time'),
        subtitle: Text(time.format(context)),
        trailing: TextButton(onPressed: onPick, child: const Text('Change')),
        onTap: onPick,
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.terracotta),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(body),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EventNotice extends StatelessWidget {
  const _EventNotice({required this.event});

  final LifeEvent event;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EventEditorScreen(existing: event)),
          ),
          leading: CircleAvatar(
            backgroundColor: AppColors.terracottaSoft,
            child: Icon(
              event.alarmOn ? Icons.notifications_active_outlined : Icons.event_outlined,
              color: AppColors.terracotta,
            ),
          ),
          title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
            '${event.kind.label} · ${DateFormat('EEE d MMM, h:mm a').format(event.at)}'
            '${event.alarmOn ? ' · Alarm on' : ''}',
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ),
      ),
    );
  }
}
