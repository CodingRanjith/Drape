import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../logic/detect_image_color.dart';
import '../models/wardrobe.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import 'app_image_pick.dart';
import 'manage_categories_sheet.dart';

/// Centered add-item form — wardrobe-simple: category, price, photo.
Future<bool> showAddItemFormDialog(
  BuildContext context, {
  WardrobeCategory? initialCategory,
  String? initialCustomShelf,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (context) => AddItemFormDialog(
      initialCategory: initialCategory,
      initialCustomShelf: initialCustomShelf,
    ),
  );
  return saved == true;
}

class AddItemFormDialog extends StatefulWidget {
  const AddItemFormDialog({
    super.key,
    this.initialCategory,
    this.initialCustomShelf,
  });

  final WardrobeCategory? initialCategory;
  final String? initialCustomShelf;

  @override
  State<AddItemFormDialog> createState() => _AddItemFormDialogState();
}

class _AddItemFormDialogState extends State<AddItemFormDialog> {
  WardrobeCategory? _category;
  String? _customShelf;
  Uint8List? _imageBytes;
  List<int> _detectedColors = const [];
  bool _processing = false;
  bool _saving = false;
  String? _error;
  late final Wearer _wearer;

  final TextEditingController _price = TextEditingController();

  String? get _selectedLabel {
    if (_customShelf != null) return _customShelf;
    return _category?.label;
  }

  @override
  void initState() {
    super.initState();
    _wearer = context.read<MineState>().profile.wearer;
    final allowed = _wearer.wardrobeCategories;
    final initialCustom = widget.initialCustomShelf?.trim();
    if (initialCustom != null && initialCustom.isNotEmpty) {
      _customShelf = initialCustom;
    } else if (widget.initialCategory != null &&
        allowed.contains(widget.initialCategory)) {
      _category = widget.initialCategory;
    }
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _openCategoriesManager() async {
    await showManageCategoriesSheet(context);
    if (!mounted) return;
    // Drop selection if that custom shelf was deleted.
    final customs = context.read<MineState>().profile.customShelves;
    final custom = _customShelf;
    if (custom != null &&
        !customs.any((e) => e.toLowerCase() == custom.toLowerCase())) {
      setState(() {
        _customShelf = null;
        _category = null;
      });
    } else {
      setState(() {});
    }
  }

  Future<void> _pickCategory() async {
    final state = context.read<MineState>();
    final labels = state.orderedShelfLabels;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _CategoryPickSheet(
          labels: labels,
          selected: _selectedLabel,
          iconFor: (label) {
            for (final c in _wearer.wardrobeCategories) {
              if (c.label.toLowerCase() == label.toLowerCase()) return c.icon;
            }
            return Icons.category_outlined;
          },
          onManage: () async {
            Navigator.pop(context);
            await _openCategoriesManager();
          },
        );
      },
    );
    if (!mounted || chosen == null) return;
    _applyLabel(chosen);
  }

  void _applyLabel(String label) {
    WardrobeCategory? builtin;
    for (final c in _wearer.wardrobeCategories) {
      if (c.label.toLowerCase() == label.toLowerCase()) {
        builtin = c;
        break;
      }
    }
    setState(() {
      if (builtin != null) {
        _category = builtin;
        _customShelf = null;
      } else {
        _customShelf = label;
        _category = null;
      }
      _error = null;
    });
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final bytes = await pickAppImage(
        context,
        source: source,
        maxWidth: 1600,
        imageQuality: 92,
        wardrobeCategory: _category,
        guideLabel: _selectedLabel,
      );
      if (!mounted) return;
      if (bytes == null) {
        setState(() => _processing = false);
        return;
      }
      final colors = detectClothesColors(bytes);
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _detectedColors = colors;
        _processing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = 'Could not load that photo. Try again.';
      });
    }
  }

  Future<void> _chooseSource() async {
    if (_selectedLabel == null) {
      setState(() => _error = 'Pick a category first.');
      return;
    }
    await _pick(ImageSource.camera);
  }

  Future<void> _chooseGallery() async {
    if (_selectedLabel == null) {
      setState(() => _error = 'Pick a category first.');
      return;
    }
    await _pick(ImageSource.gallery);
  }

  Future<void> _save() async {
    final bytes = _imageBytes;
    final hasBuiltin = _category != null;
    final hasCustom = _customShelf != null && _customShelf!.trim().isNotEmpty;
    if (!hasBuiltin && !hasCustom) {
      setState(() => _error = 'Pick a category first.');
      return;
    }
    if (bytes == null) {
      setState(() => _error = 'Add an item photo first.');
      return;
    }

    double? cost;
    final priceText = _price.text.trim();
    if (priceText.isNotEmpty) {
      cost = double.tryParse(priceText.replaceAll(',', ''));
      if (cost == null) {
        setState(() => _error = 'Enter a valid price, or leave it blank.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final builtin = _category;
    final custom = _customShelf?.trim();
    final shelfName = custom ?? builtin!.label;
    final mapped = builtin ?? WardrobeCategory.accessories;

    final colors = _detectedColors.isNotEmpty
        ? _detectedColors
        : detectClothesColors(bytes);

    final garment = Garment(
      id: const Uuid().v4(),
      name: shelfName,
      category: mapped.garmentCategory,
      colors: colors,
      topKind: mapped.topKind,
      wardrobeCategory: mapped,
      customShelf: custom,
      cost: cost,
    );

    try {
      final state = context.read<MineState>();
      if (custom != null) await state.addCustomShelf(custom);
      await state.saveGarment(garment, imageBytes: bytes);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = size.width.clamp(280.0, 420.0);
    final busy = _processing || _saving;
    final selected = _selectedLabel;
    // Keep watch for shelf order / custom list changes.
    context.watch<MineState>();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: size.height * 0.88,
        ),
        child: Material(
          color: const Color(0xFFF6EDE3),
          elevation: 12,
          shadowColor: Colors.black38,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add items',
                          style: GoogleFonts.manrope(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed:
                            busy ? null : () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'Category',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: AppColors.ink.withValues(alpha: 0.7),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: busy ? null : _openCategoriesManager,
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(
                          'Categories',
                          style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.terracotta,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Material(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: busy ? null : _pickCategory,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _category?.icon ??
                                  (selected != null
                                      ? Icons.category_outlined
                                      : Icons.grid_view_rounded),
                              color: AppColors.terracotta,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selected ?? 'Choose category',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: selected == null
                                      ? AppColors.muted
                                      : AppColors.ink,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.expand_more_rounded,
                              color: AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Item price',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _price,
                    enabled: !busy,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'e.g. 1299',
                      prefixText: '₹ ',
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.88),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.terracotta,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Item photo',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.ink.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  AspectRatio(
                    aspectRatio: 1,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: busy ? null : _chooseSource,
                        child: _processing
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: AppColors.terracotta,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Removing background…',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _imageBytes == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.photo_camera_outlined,
                                        size: 42,
                                        color: AppColors.terracotta,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Tap to take a photo',
                                        style: GoogleFonts.manrope(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        selected == null
                                            ? 'Pick a category first'
                                            : 'Camera · $selected',
                                        style: GoogleFonts.manrope(
                                          color: AppColors.muted,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextButton.icon(
                                        onPressed:
                                            busy ? null : _chooseGallery,
                                        icon: const Icon(
                                          Icons.photo_library_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Gallery instead'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.terracotta,
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
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: FilledButton.tonal(
                                                  onPressed: busy
                                                      ? null
                                                      : _chooseSource,
                                                  child: const Text('Retake'),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: busy
                                                      ? null
                                                      : _chooseGallery,
                                                  child: const Text('Gallery'),
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
                  if (_imageBytes != null && _detectedColors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final argb in _detectedColors.take(2)) ...[
                          Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: colorFromArgb(argb),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.line),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            'Color: ${_detectedColors.map((c) => colorNameOf(colorFromArgb(c))).join(' · ')}',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: GoogleFonts.manrope(
                        color: const Color(0xFFB42318),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: busy ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Save item',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPickSheet extends StatelessWidget {
  const _CategoryPickSheet({
    required this.labels,
    required this.selected,
    required this.iconFor,
    required this.onManage,
  });

  final List<String> labels;
  final String? selected;
  final IconData Function(String label) iconFor;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.62,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF6EDE3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Choose category',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onManage,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Manage'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.terracotta,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 16 + bottom),
              itemCount: labels.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final label = labels[index];
                final isSelected = selected != null &&
                    selected!.toLowerCase() == label.toLowerCase();
                return Material(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    onTap: () => Navigator.pop(context, label),
                    leading: Icon(iconFor(label), color: AppColors.terracotta),
                    title: Text(
                      label,
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.sage)
                        : const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.muted,
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
