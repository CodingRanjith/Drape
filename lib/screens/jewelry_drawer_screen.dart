import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/jewelry.dart';
import '../models/wardrobe.dart';
import '../services/metal_prices.dart';
import '../state/mine_state.dart';
import '../widgets/app_image_pick.dart';
import '../widgets/common.dart';

/// Separate drawer: gold on the left, silver on the right.
class JewelryDrawerScreen extends StatefulWidget {
  const JewelryDrawerScreen({super.key, required this.gold});

  final bool gold;

  @override
  State<JewelryDrawerScreen> createState() => _JewelryDrawerScreenState();
}

class _JewelryDrawerScreenState extends State<JewelryDrawerScreen> {
  MetalQuote? _quote;
  Object? _error;
  var _loading = true;

  bool get _gold => widget.gold;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quote = await MetalPrices.instance.fetch(force: force);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  List<Garment> _pieces(MineState state) {
    return state.garments.where((garment) {
      if (!Jewelry.isPiece(garment)) return false;
      return Jewelry.isGold(garment) == _gold;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _add() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddJewelSheet(gold: _gold),
    );
    if (saved == true && mounted) {
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final pieces = _pieces(state);
    final quote = _quote;
    final accent = _gold ? const Color(0xFFE8C56A) : const Color(0xFFE4E7EC);
    final ink = _gold ? const Color(0xFF2A1A08) : const Color(0xFF1C2228);
    final velvet = _gold ? const Color(0xFF1A120C) : const Color(0xFF14181C);

    final worth = Jewelry.worth(pieces, quote == null
        ? null
        : (facts) => _gold
            ? quote.goldPerGram(facts.purity)
            : quote.silverPerGram(facts.purity));

    return Scaffold(
      backgroundColor: velvet,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: accent,
        title: Text(
          _gold ? 'Gold collection' : 'Silver collection',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accent,
        foregroundColor: ink,
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _gold ? 'Add gold' : 'Add silver',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          _PricePanel(
            gold: _gold,
            quote: quote,
            loading: _loading,
            error: _error != null,
            onRefresh: () => _load(force: true),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                pieces.isEmpty
                    ? 'No pieces yet'
                    : '${pieces.length} ${pieces.length == 1 ? 'piece' : 'pieces'}',
                style: GoogleFonts.manrope(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (quote != null &&
              (worth.purchased != null || worth.current != null)) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _WorthLabel(
                  title: 'Purchased value',
                  amount: worth.purchased,
                  color: Colors.white70,
                ),
                const SizedBox(width: 16),
                _WorthLabel(
                  title: 'Current value',
                  amount: worth.current,
                  color: accent,
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Add a piece with its weight to see today\'s metal value.',
              style: GoogleFonts.manrope(
                color: Colors.white70,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (pieces.isEmpty)
            _EmptyDrawer(gold: _gold, onAdd: _add)
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pieces.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.64,
              ),
              itemBuilder: (context, index) {
                final piece = pieces[index];
                final facts = Jewelry.read(piece);
                final grams = facts.grams;
                double? value;
                if (quote != null && grams != null) {
                  value = grams *
                      (_gold
                          ? quote.goldPerGram(facts.purity)
                          : quote.silverPerGram(facts.purity));
                }
                return _JewelCard(
                  garment: piece,
                  facts: facts,
                  value: value,
                  accent: accent,
                  onTap: () => _openPiece(piece.id),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openPiece(String id) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _JewelDetailSheet(garmentId: id, gold: _gold),
    );
  }
}

class _PricePanel extends StatelessWidget {
  const _PricePanel({
    required this.gold,
    required this.quote,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final bool gold;
  final MetalQuote? quote;
  final bool loading;
  final bool error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final accent = gold ? const Color(0xFFE8C56A) : const Color(0xFFE4E7EC);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gold
              ? const [Color(0xFF3A2A14), Color(0xFF24180E)]
              : const [Color(0xFF2C3238), Color(0xFF1A1E22)],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  gold ? 'Gold rate in Chennai' : 'Silver rate in Chennai',
                  style: GoogleFonts.manrope(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              IconButton(
                onPressed: loading ? null : onRefresh,
                color: accent,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (quote == null && error)
            Text(
              'Couldn\'t reach the Chennai rate. Try again.',
              style: GoogleFonts.manrope(color: Colors.white70, fontSize: 13),
            )
          else if (quote == null)
            Text(
              'Fetching the Chennai rate…',
              style: GoogleFonts.manrope(color: Colors.white70, fontSize: 13),
            )
          else if (gold)
            _GoldRateTable(quote: quote!)
          else
            _SilverRateTable(quote: quote!),
          if (quote != null) ...[
            const SizedBox(height: 8),
            Text(
              quote!.chennai
                  ? 'Chennai · ${_stamp(quote!.updatedAt)} · before making charges and GST'
                  : 'World spot in rupees · lower than the Chennai jeweller rate',
              style: GoogleFonts.manrope(color: Colors.white54, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  String _stamp(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $suffix';
  }
}

class _GoldRateTable extends StatelessWidget {
  const _GoldRateTable({required this.quote});

  final MetalQuote quote;

  @override
  Widget build(BuildContext context) {
    return _RateTable(
      header: const ['Purity', '1 gram', '10 grams', '100 grams'],
      rows: [
        _rateLine('24K', '99.9%', quote.gold24InrPerGram),
        _rateLine('22K', '91.6%', quote.gold22InrPerGram),
        _rateLine('18K', '75%', quote.gold18InrPerGram),
      ],
    );
  }
}

class _SilverRateTable extends StatelessWidget {
  const _SilverRateTable({required this.quote});

  final MetalQuote quote;

  @override
  Widget build(BuildContext context) {
    return _RateTable(
      header: const ['Purity', '1 gram', '10 grams', '100 grams'],
      rows: [
        _rateLine('999', 'Fine', quote.silverPerGram(999)),
        _rateLine('925', 'Sterling', quote.silverPerGram(925)),
      ],
    );
  }
}

List<String> _rateLine(String purity, String note, double perGram) {
  return [
    purity,
    note,
    formatInr(perGram),
    formatInr(perGram * 10),
    formatInr(perGram * 100),
  ];
}

class _RateTable extends StatelessWidget {
  const _RateTable({required this.header, required this.rows});

  final List<String> header;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.manrope(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 11,
    );
    final head = GoogleFonts.manrope(
      color: const Color(0xFFE8C56A),
      fontWeight: FontWeight.w800,
      fontSize: 10,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              for (final cell in header)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 12, 8),
                  child: Text(cell, style: head),
                ),
            ],
          ),
          for (final row in rows)
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 4, 12, 4),
                  child: Text('${row[0]}  ${row[1]}', style: style),
                ),
                for (final cell in row.skip(2))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 12, 4),
                    child: Text(cell, style: style),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EmptyDrawer extends StatelessWidget {
  const _EmptyDrawer({required this.gold, required this.onAdd});

  final bool gold;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final accent = gold ? const Color(0xFFE8C56A) : const Color(0xFFE4E7EC);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        color: Colors.white.withValues(alpha: 0.04),
      ),
      child: Column(
        children: [
          Icon(
            gold ? Icons.diamond_rounded : Icons.brightness_6_rounded,
            color: accent,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            gold ? 'This gold drawer is empty' : 'This silver drawer is empty',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add rings, chains, bangles, and coins. Weight turns into today\'s price.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(color: Colors.white70, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: gold ? const Color(0xFF2A1A08) : const Color(0xFF1C2228),
            ),
            onPressed: onAdd,
            child: Text(
              gold ? 'Add gold piece' : 'Add silver piece',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorthLabel extends StatelessWidget {
  const _WorthLabel({
    required this.title,
    required this.amount,
    required this.color,
  });

  final String title;
  final double? amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          amount == null ? '—' : formatInr(amount!),
          style: GoogleFonts.manrope(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MiniWorth extends StatelessWidget {
  const _MiniWorth({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double? amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: GoogleFonts.manrope(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: amount == null ? '—' : formatInr(amount!),
            style: GoogleFonts.manrope(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _JewelCard extends StatelessWidget {
  const _JewelCard({
    required this.garment,
    required this.facts,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  final Garment garment;
  final JewelryFacts facts;
  final double? value;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grams = facts.grams;
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: PhotoTile(
                  garment: garment,
                  radius: 12,
                  fit: BoxFit.contain,
                  backgroundColor: const Color(0xFF101114),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                garment.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                grams == null
                    ? facts.purityLabel
                    : '${grams.toStringAsFixed(grams >= 10 ? 1 : 2)} g · ${facts.purityLabel}',
                style: GoogleFonts.manrope(color: Colors.white60, fontSize: 11),
              ),
              if (value != null) ...[
                const SizedBox(height: 4),
                _MiniWorth(
                  label: 'Purchased',
                  amount: garment.cost,
                  color: Colors.white60,
                ),
                _MiniWorth(
                  label: 'Current',
                  amount: value,
                  color: accent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AddJewelSheet extends StatefulWidget {
  const _AddJewelSheet({required this.gold});

  final bool gold;

  @override
  State<_AddJewelSheet> createState() => _AddJewelSheetState();
}

class _AddJewelSheetState extends State<_AddJewelSheet> {
  final _name = TextEditingController();
  final _grams = TextEditingController();
  final _paid = TextEditingController();
  Uint8List? _photo;
  late int _purity;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _purity = widget.gold ? 22 : 925;
  }

  @override
  void dispose() {
    _name.dispose();
    _grams.dispose();
    _paid.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final bytes = await pickAppImage(
      context,
      source: source,
      guideLabel: widget.gold ? 'Gold jewellery' : 'Silver jewellery',
      removeBackground: false,
    );
    if (bytes == null || !mounted) return;
    setState(() => _photo = bytes);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final grams = double.tryParse(_grams.text.trim().replaceAll(',', ''));
    if (name.isEmpty) {
      setState(() => _error = 'Name the piece');
      return;
    }
    if (grams == null || grams <= 0) {
      setState(() => _error = 'Enter the weight in grams');
      return;
    }
    double? paid;
    final paidText = _paid.text.trim();
    if (paidText.isNotEmpty) {
      paid = double.tryParse(paidText.replaceAll(',', ''));
      if (paid == null) {
        setState(() => _error = 'Paid amount should be a number');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final garment = Garment(
      id: const Uuid().v4(),
      name: name,
      category: GarmentCategory.accessory,
      wardrobeCategory: WardrobeCategory.jewellery,
      colors: [
        widget.gold ? 0xFFE8C56A : 0xFFD5DAE0,
      ],
      customShelf: widget.gold ? Jewelry.goldShelf : Jewelry.silverShelf,
      notes: Jewelry.packNotes(purity: _purity, grams: grams),
      cost: paid,
    );
    await context.read<MineState>().saveGarment(garment, imageBytes: _photo);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final accent = widget.gold ? const Color(0xFF8A5A12) : const Color(0xFF3E4650);
    final purities = widget.gold ? Jewelry.goldKarats : Jewelry.silverFineness;
    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF1C1612),
      backgroundColor: const Color(0xFFFFF6EA),
      side: BorderSide(color: accent.withValues(alpha: 0.7)),
      padding: const EdgeInsets.symmetric(vertical: 12),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F0),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7CBBA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.gold ? 'Add gold piece' : 'Add silver piece',
                style: GoogleFonts.manrope(
                  color: const Color(0xFF1C1612),
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Name, weight, and purity. The live price fills in the value.',
                style: GoogleFonts.manrope(
                  color: const Color(0xFF6B5E52),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              _label('Name'),
              TextField(
                controller: _name,
                cursorColor: accent,
                style: _inputStyle,
                textCapitalization: TextCapitalization.words,
                decoration: _field('Ring, chain, bangle…'),
              ),
              const SizedBox(height: 12),
              _label('Weight in grams'),
              TextField(
                controller: _grams,
                cursorColor: accent,
                style: _inputStyle,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _field('Example: 8.5'),
              ),
              const SizedBox(height: 12),
              _label(widget.gold ? 'Karat' : 'Fineness'),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < purities.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _PurityButton(
                        label: purities[i] >= 100
                            ? '.${purities[i]}'
                            : '${purities[i]}K',
                        selected: _purity == purities[i],
                        accent: widget.gold
                            ? const Color(0xFFE8C56A)
                            : const Color(0xFFE4E7EC),
                        onTap: () => setState(() => _purity = purities[i]),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _label('What you paid (optional)'),
              TextField(
                controller: _paid,
                cursorColor: accent,
                style: _inputStyle,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _field('Amount in ₹'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: buttonStyle,
                      onPressed: () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(
                        'Camera',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: buttonStyle,
                      onPressed: () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_outlined, size: 18),
                      label: Text(
                        'Gallery',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
              if (_photo != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: const Color(0xFFF3E6D2),
                    child: Image.memory(
                      _photo!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF9A3412),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: widget.gold
                      ? const Color(0xFFE8C56A)
                      : const Color(0xFFD5DAE0),
                  foregroundColor: const Color(0xFF1C1612),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  disabledBackgroundColor: const Color(0xFFE7D7BE),
                ),
                onPressed: _saving ? null : _save,
                child: Text(
                  _saving ? 'Saving…' : 'Save to drawer',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          color: const Color(0xFF1C1612),
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }

  TextStyle get _inputStyle => GoogleFonts.manrope(
        color: const Color(0xFF1C1612),
        fontWeight: FontWeight.w700,
        fontSize: 15,
      );

  InputDecoration _field(String hint) {
    final accent = widget.gold ? const Color(0xFFC4A15A) : const Color(0xFF8E98A3);
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: GoogleFonts.manrope(
        color: const Color(0xFF8A7B6C),
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent.withValues(alpha: 0.9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: widget.gold ? const Color(0xFF8A5A12) : const Color(0xFF3E4650),
          width: 1.6,
        ),
      ),
    );
  }
}

class _PurityButton extends StatelessWidget {
  const _PurityButton({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? accent : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF8A5A12),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: const Color(0xFF1C1612),
            ),
          ),
        ),
      ),
    );
  }
}

class _JewelDetailSheet extends StatelessWidget {
  const _JewelDetailSheet({required this.garmentId, required this.gold});

  final String garmentId;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();
    final garment = state.garmentById(garmentId);
    final quote = MetalPrices.instance.cached;
    if (garment == null) {
      return const SizedBox.shrink();
    }
    final facts = Jewelry.read(garment);
    final grams = facts.grams;
    double? value;
    if (quote != null && grams != null) {
      value = grams *
          (gold
              ? quote.goldPerGram(facts.purity)
              : quote.silverPerGram(facts.purity));
    }
    final accent = gold ? const Color(0xFFE8C56A) : const Color(0xFFE4E7EC);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1814),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 180,
            child: PhotoTile(
              garment: garment,
              radius: 14,
              fit: BoxFit.contain,
              backgroundColor: const Color(0xFF101114),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            garment.name,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            grams == null
                ? facts.purityLabel
                : '${grams.toStringAsFixed(2)} g · ${facts.purityLabel}',
            style: GoogleFonts.manrope(color: Colors.white70),
          ),
          if (value != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _WorthLabel(
                  title: 'Purchased value',
                  amount: garment.cost,
                  color: Colors.white70,
                ),
                const SizedBox(width: 16),
                _WorthLabel(
                  title: 'Current value',
                  amount: value,
                  color: accent,
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              await context.read<MineState>().deleteGarment(garment.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: Text(
              'Remove from drawer',
              style: GoogleFonts.manrope(
                color: const Color(0xFFFFB4A8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
