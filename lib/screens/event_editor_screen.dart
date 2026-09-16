import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/life.dart';
import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/clothes_photo_row.dart';
import '../widgets/common.dart';
import '../widgets/garment_photo.dart';

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
        const SnackBar(content: Text('Please enter a name for this event.')),
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackIcon(),
        title: Text(widget.existing == null ? 'Add event' : 'Edit event'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Riya birthday, office function…',
            ),
          ),
          const SizedBox(height: 18),
          Text('Type', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: EventKind.values.map((k) {
              final selected = _event.kind == k;
              return ChoiceChip(
                label: Text(k.label),
                selected: selected,
                onSelected: (_) => setState(() => _event.kind = k),
                selectedColor: AppColors.ink,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_rounded),
            title: const Text('Date'),
            subtitle: Text(DateFormat('EEEE, d MMMM y').format(_event.at)),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('Time'),
            subtitle: Text(DateFormat('h:mm a').format(_event.at)),
            onTap: _pickTime,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Set alarm'),
            subtitle: const Text('The alarm will ring at this date and time, with music.'),
            value: _event.alarmOn,
            activeThumbColor: AppColors.terracotta,
            onChanged: (v) => setState(() => _event.alarmOn = v),
          ),
          if (_event.alarmOn) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.music_note_rounded),
              title: const Text('Alarm music'),
              subtitle: Text(
                _event.musicName ??
                    (_event.musicPath == null ? 'Default bell' : 'Custom song'),
              ),
              trailing: TextButton(
                onPressed: _pickMusic,
                child: const Text('Choose'),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text('Select your event clothes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Tap the clothes you will wear for this event. You can pick more than one.'),
          const SizedBox(height: 12),
          if (state.garments.isEmpty)
            const Text('Add clothes in Closet first, then pick them here.')
          else ...[
            if (_eventClothes(state).isNotEmpty) ...[
              ClothesPhotoRow(garments: _eventClothes(state)),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final garment in state.garments)
                  _EventClothChip(
                    garment: garment,
                    selected: _event.garmentIds.contains(garment.id),
                    onTap: () {
                      setState(() {
                        if (_event.garmentIds.contains(garment.id)) {
                          _event.garmentIds.remove(garment.id);
                        } else {
                          _event.garmentIds.add(garment.id);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Text('Party wear for this day', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (state.partyLooks.isEmpty)
            const Text('Upload party wear in Calendar first, then you can pick it here.')
          else
            ...state.partyLooks.map((look) {
              final selected = _event.partyLookId == look.id;
              final photo = garmentImageProvider(look.imagePath);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                selected: selected,
                onTap: () => setState(() => _event.partyLookId = look.id),
                leading: photo == null
                    ? const Icon(Icons.checkroom_outlined)
                    : SizedBox(
                        width: 44,
                        height: 44,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image(image: photo, fit: BoxFit.cover),
                        ),
                      ),
                title: Text(look.name),
                subtitle: Text(look.occasion.label),
                trailing: selected
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.terracotta)
                    : const Icon(Icons.circle_outlined),
              );
            }),
          if (_event.partyLookId != null)
            TextButton(
              onPressed: () => setState(() => _event.partyLookId = null),
              child: const Text('No party wear'),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Venue, gift, what to wear…',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save event')),
        ],
      ),
    );
  }

  List<Garment> _eventClothes(DrapeState state) {
    return _event.garmentIds
        .map(state.garmentById)
        .whereType<Garment>()
        .toList();
  }
}

class _EventClothChip extends StatelessWidget {
  const _EventClothChip({
    required this.garment,
    required this.selected,
    required this.onTap,
  });

  final Garment garment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 86,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppColors.ink : AppColors.line,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Stack(
                    children: [
                      Positioned.fill(child: PhotoTile(garment: garment, radius: 12)),
                      if (selected)
                        const Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.check_circle, color: Colors.white, size: 20),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              garment.typeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
