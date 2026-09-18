import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/wardrobe.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/page_background.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key, required this.category});

  final WardrobeCategory category;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  Uint8List? _imageBytes;
  bool _processing = false;
  late final TextEditingController _name;
  late final TextEditingController _cost;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category.label);
    _cost = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final shot = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 92,
    );
    if (shot == null) return;

    setState(() => _processing = true);
    try {
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _processing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load that photo. Try again.')),
      );
    }
  }

  void _showPickSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final bytes = _imageBytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an item photo first.')),
      );
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name.')),
      );
      return;
    }

    double? cost;
    final costText = _cost.text.trim();
    if (costText.isNotEmpty) {
      cost = double.tryParse(costText.replaceAll(',', ''));
      if (cost == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid cost, or leave it blank.')),
        );
        return;
      }
    }

    final garment = Garment(
      id: const Uuid().v4(),
      name: name,
      category: widget.category.garmentCategory,
      colors: [colorArgb(fashionPalette.first.value)],
      topKind: widget.category.topKind,
      wardrobeCategory: widget.category,
      cost: cost,
    );

    await context.read<MineState>().saveGarment(garment, imageBytes: bytes);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackIcon(),
          title: Text('Add ${category.label.toLowerCase()}'),
          actions: [
            TextButton(
              onPressed: _processing ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const Text(
              'Upload a photo of the item. You can retake it anytime before saving.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Material(
                color: const Color(0xFFEFE7DE),
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _processing ? null : _showPickSheet,
                  child: _processing
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: AppColors.terracotta),
                              SizedBox(height: 14),
                              Text(
                                'Loading photo…',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        )
                      : _imageBytes == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 44,
                                  color: AppColors.terracotta,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Tap to add item photo',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Camera or gallery',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(
                                  _imageBytes!,
                                  fit: BoxFit.cover,
                                ),
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton.tonal(
                                            onPressed: _showPickSheet,
                                            child: const Text('Retake'),
                                          ),
                                        ),
                                      ],
                                    ),
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
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Item cost (optional)',
                hintText: 'e.g. 1299',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _processing ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save to wardrobe'),
            ),
          ],
        ),
      ),
    );
  }
}
