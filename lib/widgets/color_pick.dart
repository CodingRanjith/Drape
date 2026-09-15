import 'package:flutter/material.dart';

import '../models/wardrobe.dart';
import '../theme/app_theme.dart';

Future<Color?> pickAppColor(
  BuildContext context, {
  required Color current,
}) {
  return showDialog<Color>(
    context: context,
    builder: (context) => _ColorPickerDialog(current: current),
  );
}

class ColorChoiceRow extends StatelessWidget {
  const ColorChoiceRow({
    super.key,
    required this.color,
    required this.onPick,
  });

  final Color color;
  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) {
    final name = colorNameOf(color);
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.ink,
                ),
              ),
              const Text(
                'This is the color you picked',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: () async {
            final next = await pickAppColor(context, current: color);
            if (next != null) onPick(next);
          },
          child: const Text('Pick color'),
        ),
      ],
    );
  }
}

class ColorPaletteGrid extends StatelessWidget {
  const ColorPaletteGrid({
    super.key,
    required this.selected,
    required this.onPick,
  });

  final Color selected;
  final ValueChanged<Color> onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final swatch in fashionPalette)
          _SwatchDot(
            color: swatch.value,
            label: swatch.name,
            selected: colorsMatch(colorArgb(swatch.value), selected),
            onTap: () => onPick(swatch.value),
          ),
      ],
    );
  }
}

class _SwatchDot extends StatelessWidget {
  const _SwatchDot({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final light = color.computeLuminance() > 0.55;
    return SizedBox(
      width: 58,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.ink : AppColors.line,
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      size: 22,
                      color: light ? AppColors.ink : Colors.white,
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.ink : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.current});

  final Color current;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.current);
  }

  Color get _color => _hsv.toColor();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pick a color'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              colorNameOf(_color) == 'Custom'
                  ? 'Your color'
                  : colorNameOf(_color),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _HueBar(
              hue: _hsv.hue,
              onChanged: (hue) => setState(() => _hsv = _hsv.withHue(hue)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const SizedBox(width: 72, child: Text('Light')),
                Expanded(
                  child: Slider(
                    value: _hsv.value,
                    onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
                    activeColor: _color,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 72, child: Text('Strong')),
                Expanded(
                  child: Slider(
                    value: _hsv.saturation,
                    onChanged: (v) =>
                        setState(() => _hsv = _hsv.withSaturation(v)),
                    activeColor: _color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ColorPaletteGrid(
              selected: _color,
              onPick: (color) => setState(() => _hsv = HSVColor.fromColor(color)),
            ),
          ],
        ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('Use this color'),
        ),
      ],
    );
  }
}

class _HueBar extends StatelessWidget {
  const _HueBar({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hue', style: TextStyle(fontWeight: FontWeight.w700)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 12,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: hue,
            max: 359,
            onChanged: onChanged,
            activeColor: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
          ),
        ),
        Container(
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
