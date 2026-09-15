import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/life.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/garment_photo.dart';

class PartyWearEditorScreen extends StatefulWidget {
  const PartyWearEditorScreen({super.key, this.existing});

  final PartyLook? existing;

  @override
  State<PartyWearEditorScreen> createState() => _PartyWearEditorScreenState();
}

class _PartyWearEditorScreenState extends State<PartyWearEditorScreen> {
  late PartyLook _look;
  late TextEditingController _name;
  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    _look = widget.existing ??
        PartyLook(
          id: const Uuid().v4(),
          name: '',
          occasion: PartyOccasion.party,
        );
    _name = TextEditingController(text: _look.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final shot = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (shot == null) return;
    final bytes = await shot.readAsBytes();
    setState(() => _photo = bytes);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name.')),
      );
      return;
    }
    _look.name = name;
    await context.read<DrapeState>().savePartyLook(_look, imageBytes: _photo);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _photo != null
        ? MemoryImage(_photo!)
        : garmentImageProvider(_look.imagePath);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add party wear' : 'Edit party wear'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Material(
              color: AppColors.clay,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _pick,
                child: preview == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_camera_outlined, size: 42),
                          SizedBox(height: 8),
                          Text(
                            'Upload a photo',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      )
                    : Image(image: preview, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Red party dress, gold set…',
            ),
          ),
          const SizedBox(height: 18),
          Text('For', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: PartyOccasion.values.map((o) {
              final selected = _look.occasion == o;
              return ChoiceChip(
                label: Text(o.label),
                selected: selected,
                onSelected: (_) => setState(() => _look.occasion = o),
                selectedColor: AppColors.ink,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
