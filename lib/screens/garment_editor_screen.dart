import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/wardrobe.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/color_pick.dart';
import '../widgets/common.dart';
import '../widgets/garment_photo.dart';

class GarmentEditorScreen extends StatefulWidget {
  const GarmentEditorScreen({
    super.key,
    this.existing,
    this.initialCategory,
    this.initialTopKind,
    this.pairWithId,
    this.assignToDate,
    this.assignToSetId,
    this.assignToCollection,
  });

  final Garment? existing;
  final GarmentCategory? initialCategory;
  final TopKind? initialTopKind;
  final String? pairWithId;
  final DateTime? assignToDate;
  final String? assignToSetId;
  final StyleCollection? assignToCollection;

  @override
  State<GarmentEditorScreen> createState() => _GarmentEditorScreenState();
}

class _GarmentEditorScreenState extends State<GarmentEditorScreen> {
  late Garment _garment;
  late TextEditingController _name;
  Uint8List? _pickedBytes;

  @override
  void initState() {
    super.initState();
    _garment = widget.existing ??
        Garment(
          id: const Uuid().v4(),
          name: '',
          category: widget.initialCategory ?? GarmentCategory.top,
          colors: [colorArgb(fashionPalette.first.value)],
          topKind: widget.initialTopKind ?? TopKind.top,
          styleCollection: widget.assignToCollection,
        );
    if (widget.assignToCollection != null) {
      _garment.styleCollection = widget.assignToCollection;
    }
    if (widget.pairWithId != null &&
        !_garment.pairsWithIds.contains(widget.pairWithId)) {
      _garment.pairsWithIds.add(widget.pairWithId!);
    }
    _name = TextEditingController(text: _garment.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final shot = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (shot == null) return;
    final bytes = await shot.readAsBytes();
    setState(() => _pickedBytes = bytes);
  }

  Future<bool> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name.')),
      );
      return false;
    }
    _garment.name = name;
    final state = context.read<MineState>();
    await state.saveGarment(
      _garment,
      imageBytes: _pickedBytes,
    );
    final assignDate = widget.assignToDate;
    if (assignDate != null) {
      final day = state.week?.forDate(assignDate);
      if (day != null) {
        await state.assignPiece(day, _garment.category, _garment.id);
      }
    }
    final setId = widget.assignToSetId;
    if (setId != null) {
      await state.assignToClothSet(setId, _garment.category, _garment.id);
    }
    return true;
  }

  Future<void> _saveAndClose() async {
    if (await _save() && mounted) Navigator.pop(context);
  }

  Future<void> _saveThenAddPant() async {
    if (!await _save() || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GarmentEditorScreen(
          initialCategory: GarmentCategory.bottom,
          pairWithId: _garment.id,
          assignToDate: widget.assignToDate,
          assignToSetId: widget.assignToSetId,
          assignToCollection:
              widget.assignToCollection ?? _garment.styleCollection,
        ),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final preview = _pickedBytes != null
        ? MemoryImage(_pickedBytes!)
        : garmentImageProvider(_garment.imagePath);
    final pairOptions = state.garments.where((g) {
      if (g.id == _garment.id) return false;
      if (_garment.category == GarmentCategory.top) {
        return g.category == GarmentCategory.bottom;
      }
      if (_garment.category == GarmentCategory.bottom) {
        return g.category == GarmentCategory.top;
      }
      return false;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackIcon(),
        title: Text(
          widget.existing == null
              ? 'Upload ${_garment.typeLabel.toLowerCase()}'
              : 'Edit ${_garment.typeLabel.toLowerCase()}',
        ),
        actions: [
          TextButton(onPressed: _saveAndClose, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Material(
              color: _garment.primaryColor,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _showPickSheet,
                child: preview == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 42,
                            color: _garment.primaryColor.computeLuminance() > 0.55
                                ? AppColors.ink
                                : Colors.white,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add a photo',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(image: preview, fit: BoxFit.cover),
                          const Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: _Pill('Change photo'),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Item name',
              hintText: 'Example: white shirt, blue pant',
            ),
          ),
          const SizedBox(height: 18),
          Text('Item type', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ClothesType.forWearer(state.profile.wearer).map((type) {
              final selected = _garment.category == type.category &&
                  (type.category != GarmentCategory.top ||
                      _garment.topKind == type.topKind);
              return ChoiceChip(
                label: Text(type.label),
                selected: selected,
                onSelected: (_) => setState(() {
                  _garment.category = type.category;
                  _garment.topKind = type.topKind;
                }),
                selectedColor: AppColors.ink,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Text('Collection', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text('Pick which card this item belongs to — change anytime.'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('None'),
                selected: _garment.styleCollection == null,
                onSelected: (_) => setState(() => _garment.styleCollection = null),
                selectedColor: AppColors.ink,
                labelStyle: TextStyle(
                  color: _garment.styleCollection == null
                      ? Colors.white
                      : AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ...StyleCollection.values.map((c) {
                final selected = _garment.styleCollection == c;
                return ChoiceChip(
                  label: Text(c.label),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _garment.styleCollection = c),
                  selectedColor: AppColors.ink,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 18),
          Text('Item color', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text('Pick the real color of this piece. You will see it below.'),
          const SizedBox(height: 12),
          ColorChoiceRow(
            color: _garment.primaryColor,
            onPick: (color) {
              setState(() {
                _garment.colors
                  ..clear()
                  ..add(colorArgb(color));
              });
            },
          ),
          const SizedBox(height: 14),
          ColorPaletteGrid(
            selected: _garment.primaryColor,
            onPick: (color) {
              setState(() {
                _garment.colors
                  ..clear()
                  ..add(colorArgb(color));
              });
            },
          ),
          if (pairOptions.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              _garment.category == GarmentCategory.bottom
                  ? 'This pant goes with these shirts / T-shirts'
                  : 'This ${_garment.typeLabel.toLowerCase()} goes with these pants',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...pairOptions.map((g) {
              final selected = _garment.pairsWithIds.contains(g.id);
              return CheckboxListTile(
                value: selected,
                contentPadding: EdgeInsets.zero,
                title: Text(g.name),
                secondary: SizedBox(
                  width: 44,
                  height: 44,
                  child: PhotoTile(garment: g, radius: 10),
                ),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _garment.pairsWithIds.add(g.id);
                    } else {
                      _garment.pairsWithIds.remove(g.id);
                    }
                  });
                },
              );
            }),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _saveAndClose, child: const Text('Save')),
          if (_garment.category == GarmentCategory.top) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saveThenAddPant,
              icon: const Icon(Icons.add),
              label: const Text('Save, then add a pant'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showPickSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pick(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pick(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}
