import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/life.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/page_background.dart';

class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({super.key, this.existing, this.initialDate});

  final LifeEvent? existing;
  final DateTime? initialDate;

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  late LifeEvent _event;
  late TextEditingController _title;
  late TextEditingController _notes;
  Uint8List? _musicBytes;
  String? _musicExt;
  String? _musicMime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final seed = widget.initialDate ?? now;
    _event = widget.existing ??
        LifeEvent(
          id: const Uuid().v4(),
          title: '',
          kind: EventKind.function,
          at: DateTime(seed.year, seed.month, seed.day, now.hour, now.minute),
        );
    _title = TextEditingController(text: _event.title);
    _notes = TextEditingController(text: _event.notes);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _event.at,
      firstDate: DateTime(nowYear() - 1),
      lastDate: DateTime(nowYear() + 5),
    );
    if (picked == null) return;
    setState(() {
      _event.at = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _event.at.hour,
        _event.at.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_event.at),
    );
    if (picked == null) return;
    setState(() {
      _event.at = DateTime(
        _event.at.year,
        _event.at.month,
        _event.at.day,
        picked.hour,
        picked.minute,
      );
    });
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
    setState(() {
      _musicBytes = bytes;
      _musicExt = (file.extension ?? 'mp3').toLowerCase();
      _musicMime = _mimeFor(_musicExt!);
      _event.musicName = file.name;
    });
  }

  String _mimeFor(String ext) => switch (ext) {
        'wav' => 'audio/wav',
        'm4a' => 'audio/mp4',
        'aac' => 'audio/aac',
        'ogg' => 'audio/ogg',
        _ => 'audio/mpeg',
      };

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for this reminder.')),
      );
      return;
    }
    _event
      ..title = title
      ..notes = _notes.text.trim();
    await context.read<DrapeState>().saveEvent(
          _event,
          musicBytes: _musicBytes,
          musicExt: _musicExt,
          musicMime: _musicMime,
        );
    if (mounted) Navigator.pop(context);
  }

  int nowYear() => DateTime.now().year;

  InputDecoration _fieldDecoration({
    required String hintText,
    bool multiline = false,
  }) {
    final radius = BorderRadius.circular(multiline ? 16 : 22);
    final rest = OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: AppColors.ink, width: 1.15),
    );
    return InputDecoration(
      hintText: hintText,
      hintMaxLines: multiline ? 3 : 1,
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
      ),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      isCollapsed: false,
      alignLabelWithHint: true,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      constraints: BoxConstraints(minHeight: multiline ? 112 : 44),
      contentPadding: EdgeInsets.fromLTRB(16, multiline ? 14 : 12, 16, multiline ? 14 : 12),
      border: rest,
      enabledBorder: rest,
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AppColors.terracotta, width: 1.4),
      ),
      errorBorder: rest,
      focusedErrorBorder: rest,
      disabledBorder: rest,
    );
  }

  Widget _overrideField({required Widget child}) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          filled: false,
          isDense: true,
          isCollapsed: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
      child: child,
    );
  }

  String get _musicLabel =>
      _event.musicName ??
      (_event.musicPath == null ? 'Default bell' : 'Custom song');

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 12, 0),
                child: Row(
                  children: [
                    const AppBackIcon(),
                    Expanded(
                      child: Text(
                        isNew ? 'Add Reminder' : 'Edit Reminder',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _save,
                      child: Text(
                        'Save',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: AppColors.terracotta,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.terracottaSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: AppColors.terracotta,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isNew
                          ? 'Set a date, time and alarm'
                          : 'Update this reminder',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _ReminderCard(
                      children: [
                        _FieldBlock(
                          label: 'Name of Reminder',
                          child: _overrideField(
                            child: TextField(
                              controller: _title,
                              textCapitalization: TextCapitalization.sentences,
                              spellCheckConfiguration:
                                  const SpellCheckConfiguration.disabled(),
                              cursorColor: AppColors.terracotta,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                              decoration: _fieldDecoration(
                                hintText: 'Birthday, meeting…',
                              ),
                            ),
                          ),
                        ),
                        const _CardDivider(),
                        _ActionRow(
                          icon: Icons.calendar_month_rounded,
                          title: 'Date',
                          value: DateFormat('EEEE, d MMMM y').format(_event.at),
                          onTap: _pickDate,
                        ),
                        const _CardDivider(),
                        _ActionRow(
                          icon: Icons.schedule_rounded,
                          title: 'Time',
                          value: DateFormat('h:mm a').format(_event.at),
                          onTap: _pickTime,
                        ),
                        const _CardDivider(),
                        _SwitchRow(
                          icon: Icons.alarm_rounded,
                          title: 'Set Alarm',
                          value: _event.alarmOn,
                          onChanged: (v) => setState(() => _event.alarmOn = v),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: _event.alarmOn
                              ? Column(
                                  children: [
                                    const _CardDivider(),
                                    _ActionRow(
                                      icon: Icons.music_note_rounded,
                                      title: 'Set Music',
                                      valueMaxLines: 2,
                                      value:
                                          'Plays at ${DateFormat('h:mm a').format(_event.at)} · $_musicLabel',
                                      trailing: Text(
                                        'Choose',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.terracotta,
                                        ),
                                      ),
                                      onTap: _pickMusic,
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                        const _CardDivider(),
                        _FieldBlock(
                          label: 'Notes',
                          child: _overrideField(
                            child: TextField(
                              controller: _notes,
                              maxLines: 5,
                              minLines: 4,
                              keyboardType: TextInputType.multiline,
                              textAlignVertical: TextAlignVertical.top,
                              spellCheckConfiguration:
                                  const SpellCheckConfiguration.disabled(),
                              cursorColor: AppColors.terracotta,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color: AppColors.ink,
                              ),
                              decoration: _fieldDecoration(
                                hintText: 'Optional note',
                                multiline: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const StadiumBorder(),
                          textStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Save Reminder'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: children),
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18),
      child: Divider(height: 1, color: Color(0xFFF0EBE6)),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  const _FieldBlock({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.trailing,
    this.valueMaxLines = 1,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;
  final int valueMaxLines;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFF7F1EA),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.terracotta),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: valueMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB7AFA7),
                ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFF7F1EA),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.terracotta),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.terracotta,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
