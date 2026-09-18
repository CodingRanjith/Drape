import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../logic/wardrobe_category_search.dart';
import '../models/wardrobe.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import 'color_pick.dart';

/// Centered add-item form: searchable category + item photo (pick / retake).
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
  Color _color = fashionPalette.first.value;
  Uint8List? _imageBytes;
  bool _processing = false;
  bool _saving = false;
  String? _error;
  bool _showSuggestions = false;
  List<WardrobeCategoryMatch> _suggestions = const [];
  late final Wearer _wearer;

  final TextEditingController _categorySearch = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final FocusNode _categoryFocus = FocusNode();

  List<String> get _customShelves =>
      context.read<MineState>().profile.customShelves;

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
      _categorySearch.text = initialCustom;
    } else {
      _category = widget.initialCategory != null &&
              allowed.contains(widget.initialCategory)
          ? widget.initialCategory
          : null;
      if (_category != null) {
        _categorySearch.text = _category!.label;
      }
    }
    _refreshSuggestions(forceAll: true);
    _categorySearch.addListener(_onSearchChanged);
    _categoryFocus.addListener(_onCategoryFocusChanged);
    // List opens on field tap / chevron — not on dialog open.
    _showSuggestions = false;
  }

  /// Empty query when browsing (field empty or still showing the selected label).
  String get _browseOrSearchQuery {
    final text = _categorySearch.text.trim();
    if (text.isEmpty) return '';
    final selected = _selectedLabel;
    if (selected != null && text.toLowerCase() == selected.toLowerCase()) {
      return '';
    }
    return text;
  }

  void _onCategoryFocusChanged() {
    if (_categoryFocus.hasFocus) {
      _openCategoryList();
      return;
    }
    // Delay hide so a suggestion tap can register before the list is removed.
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (!mounted || _categoryFocus.hasFocus) return;
      setState(() => _showSuggestions = false);
    });
  }

  void _openCategoryList() {
    setState(() {
      _showSuggestions = true;
      _refreshSuggestions(forceAll: true);
    });
    if (!_categoryFocus.hasFocus) {
      _categoryFocus.requestFocus();
    }
  }

  void _toggleCategoryList() {
    if (_showSuggestions) {
      setState(() => _showSuggestions = false);
      _categoryFocus.unfocus();
      return;
    }
    _openCategoryList();
  }

  void _refreshSuggestions({bool forceAll = false}) {
    _suggestions = searchWardrobeCategories(
      forceAll ? '' : _browseOrSearchQuery,
      wearer: _wearer,
      customShelves: context.read<MineState>().profile.customShelves,
    );
  }

  void _onSearchChanged() {
    final query = _categorySearch.text;
    final selected = _selectedLabel;
    final browsingSelected = selected != null &&
        query.trim().toLowerCase() == selected.toLowerCase();
    final next = searchWardrobeCategories(
      browsingSelected ? '' : query,
      wearer: _wearer,
      customShelves: _customShelves,
    );
    setState(() {
      _suggestions = next;
      _showSuggestions = true;
      if (selected != null &&
          query.trim().toLowerCase() != selected.toLowerCase()) {
        _category = null;
        _customShelf = null;
      }
    });
  }

  void _selectCategory(WardrobeCategoryMatch match) {
    _categorySearch.removeListener(_onSearchChanged);
    setState(() {
      if (match.isCustom) {
        _customShelf = match.label;
        _category = null;
      } else {
        _category = match.category;
        _customShelf = null;
      }
      _categorySearch.text = match.label;
      _categorySearch.selection = TextSelection.collapsed(
        offset: match.label.length,
      );
      _error = null;
      _showSuggestions = false;
    });
    _categorySearch.addListener(_onSearchChanged);
    _categoryFocus.unfocus();
  }

  Future<void> _createCustomShelf(String name) async {
    final label = name.trim();
    if (label.isEmpty) return;
    await context.read<MineState>().addCustomShelf(label);
    if (!mounted) return;
    _categorySearch.removeListener(_onSearchChanged);
    setState(() {
      _customShelf = label;
      _category = null;
      _categorySearch.text = label;
      _error = null;
      _showSuggestions = false;
      _refreshSuggestions();
    });
    _categorySearch.addListener(_onSearchChanged);
    _categoryFocus.unfocus();
  }

  Future<void> _promptAddCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Add category',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Category name',
            hintText: 'e.g. Watches, Dupatta…',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || name == null || name.isEmpty) return;

    final existsBuiltin = _wearer.wardrobeCategories.any(
      (c) => c.label.toLowerCase() == name.toLowerCase(),
    );
    final existsCustom = context.read<MineState>().profile.customShelves.any(
      (c) => c.toLowerCase() == name.toLowerCase(),
    );
    if (existsBuiltin || existsCustom) {
      setState(() {
        _error = 'That category already exists. Select it from the list.';
        _categorySearch.text = name;
        _refreshSuggestions(forceAll: true);
        _showSuggestions = true;
      });
      return;
    }
    await _createCustomShelf(name);
  }

  @override
  void dispose() {
    _categorySearch.removeListener(_onSearchChanged);
    _categoryFocus.removeListener(_onCategoryFocusChanged);
    _categorySearch.dispose();
    _price.dispose();
    _categoryFocus.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final shot = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 92,
    );
    if (shot == null) return;

    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
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
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Item photo',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.terracotta),
              title: const Text('Camera', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.terracotta),
              title: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (source != null) await _pick(source);
  }

  Future<void> _save() async {
    final bytes = _imageBytes;
    final hasBuiltin = _category != null;
    final hasCustom = _customShelf != null && _customShelf!.trim().isNotEmpty;
    if (!hasBuiltin && !hasCustom) {
      setState(() => _error = 'Select or create a category first.');
      return;
    }
    if (bytes == null) {
      setState(() => _error = 'Upload an item photo first.');
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

    final garment = Garment(
      id: const Uuid().v4(),
      name: shelfName,
      category: mapped.garmentCategory,
      colors: [colorArgb(_color)],
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
    final query = _categorySearch.text.trim();
    final visibleSuggestions = _suggestions;
    final selectedLabel = _selectedLabel;
    final showingHint = query.isNotEmpty &&
        selectedLabel == null &&
        visibleSuggestions.isNotEmpty;
    final offerCreate = canCreateCustomShelf(
      query,
      wearer: _wearer,
      customShelves: context.watch<MineState>().profile.customShelves,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxW,
          maxHeight: size.height * 0.88,
        ),
        child: Material(
          color: AppColors.paper,
          elevation: 12,
          shadowColor: Colors.black38,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 18, 10, 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFF6EF), AppColors.paper],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add items',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Search ${_wearer.label.toLowerCase()} categories, or add your own.',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: busy ? null : () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Category',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: busy ? null : _promptAddCategory,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              'Add category',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.terracotta,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _categorySearch,
                        focusNode: _categoryFocus,
                        enabled: !busy,
                        textCapitalization: TextCapitalization.sentences,
                        onTap: busy ? null : _openCategoryList,
                        decoration: InputDecoration(
                          hintText: _wearer.categorySearchHint,
                          filled: true,
                          fillColor: AppColors.terracottaSoft.withValues(alpha: 0.45),
                          prefixIcon: Icon(
                            _category?.icon ??
                                (_customShelf != null
                                    ? Icons.category_outlined
                                    : Icons.search_rounded),
                            color: AppColors.terracotta,
                          ),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (query.isNotEmpty)
                                IconButton(
                                  tooltip: 'Clear',
                                  onPressed: busy
                                      ? null
                                      : () {
                                          _categorySearch.clear();
                                          setState(() {
                                            _category = null;
                                            _customShelf = null;
                                          });
                                          _openCategoryList();
                                        },
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                ),
                              IconButton(
                                tooltip: _showSuggestions
                                    ? 'Hide categories'
                                    : 'Show all categories',
                                onPressed: busy ? null : _toggleCategoryList,
                                icon: Icon(
                                  _showSuggestions
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                ),
                              ),
                            ],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.line),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.line),
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
                      if (selectedLabel != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.sageSoft.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _category?.icon ?? Icons.category_outlined,
                                color: AppColors.sage,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Selected: $selectedLabel'
                                  '${_customShelf != null ? ' (custom)' : ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_showSuggestions || showingHint || offerCreate) ...[
                        const SizedBox(height: 10),
                        if (showingHint)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${_wearer.label} categories only — pick one, or create your own:',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (offerCreate)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: AppColors.line),
                              ),
                              tileColor: AppColors.terracottaSoft.withValues(alpha: 0.55),
                              leading: const Icon(Icons.add_circle_outline, color: AppColors.terracotta),
                              title: Text(
                                'Create category “$query”',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: const Text(
                                'Saved for your wardrobe',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              onTap: busy ? null : () => _createCustomShelf(query),
                            ),
                          ),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 280),
                          decoration: BoxDecoration(
                            color: AppColors.paper,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: visibleSuggestions.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Text(
                                    offerCreate
                                        ? 'No built-in match. Create “$query” above.'
                                        : 'Type to search ${_wearer.label.toLowerCase()} categories.',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  itemCount: visibleSuggestions.length,
                                  separatorBuilder: (_, _) => const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final match = visibleSuggestions[index];
                                    final selected = selectedLabel != null &&
                                        selectedLabel.toLowerCase() ==
                                            match.label.toLowerCase();
                                    return Material(
                                      color: Colors.transparent,
                                      child: ListTile(
                                        dense: true,
                                        selected: selected,
                                        selectedTileColor: AppColors.terracottaSoft.withValues(
                                          alpha: 0.55,
                                        ),
                                        leading: Icon(
                                          match.icon,
                                          color: AppColors.terracotta,
                                        ),
                                        title: Text(
                                          match.label,
                                          style: const TextStyle(fontWeight: FontWeight.w800),
                                        ),
                                        subtitle: match.reason == null
                                            ? null
                                            : Text(
                                                match.reason!,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                        trailing: selected
                                            ? const Icon(Icons.check_circle, color: AppColors.sage)
                                            : Icon(
                                                match.isCustom
                                                    ? Icons.bookmark_outline
                                                    : Icons.chevron_right_rounded,
                                              ),
                                        onTap: () => _selectCategory(match),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      const Text(
                        'Color',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      IgnorePointer(
                        ignoring: busy,
                        child: ColorChoiceRow(
                          color: _color,
                          onPick: (color) => setState(() => _color = color),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Item price',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _price,
                        enabled: !busy,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: 'e.g. 1299',
                          prefixText: '₹ ',
                          filled: true,
                          fillColor: AppColors.terracottaSoft.withValues(alpha: 0.45),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.line),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.line),
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
                      const SizedBox(height: 18),
                      const Text(
                        'Item photo',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      AspectRatio(
                        aspectRatio: 1,
                        child: Material(
                          color: const Color(0xFFEFE7DE),
                          borderRadius: BorderRadius.circular(22),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: busy ? null : _chooseSource,
                            child: _processing
                                ? const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(color: AppColors.terracotta),
                                        SizedBox(height: 12),
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
                                            size: 42,
                                            color: AppColors.terracotta,
                                          ),
                                          SizedBox(height: 10),
                                          Text(
                                            'Tap to upload item image',
                                            style: TextStyle(fontWeight: FontWeight.w800),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Camera or gallery · retake anytime',
                                            style: TextStyle(
                                              color: AppColors.muted,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
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
                                                      onPressed: busy ? null : _chooseSource,
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
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: busy ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(_saving ? 'Saving…' : 'Save item'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: busy ? null : () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
