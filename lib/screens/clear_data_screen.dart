import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/page_background.dart';

class ClearDataScreen extends StatefulWidget {
  const ClearDataScreen({super.key});

  @override
  State<ClearDataScreen> createState() => _ClearDataScreenState();
}

class _ClearDataScreenState extends State<ClearDataScreen> {
  final _typed = TextEditingController();
  var _matches = false;
  var _busy = false;

  String get _expectedName {
    final name = context.read<MineState>().profile.name.trim();
    if (name.isEmpty || name == 'there') return 'CLEAR';
    return name;
  }

  @override
  void initState() {
    super.initState();
    _typed.addListener(_onChanged);
  }

  @override
  void dispose() {
    _typed
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {
      _matches =
          _typed.text.trim().toLowerCase() == _expectedName.toLowerCase();
    });
  }

  Future<void> _copyUsername() async {
    await Clipboard.setData(ClipboardData(text: _expectedName));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Username copied')),
    );
  }

  Future<void> _pasteUsername() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _typed
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _clear() async {
    if (!_matches || _busy) return;
    setState(() => _busy = true);
    try {
      await context.read<MineState>().clearAllData();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Cleared',
        barrierColor: Colors.black.withValues(alpha: 0.45),
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const _ClearedSuccessPopup();
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          );
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: curved, child: child),
          );
        },
      );
      if (!mounted) return;
      await context.read<MineState>().logoutToWearerChoice();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not clear data. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expected = _expectedName;

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 20, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    const AppBackIcon(),
                    Expanded(
                      child: Text(
                        'Clear data',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Material(
                          color: const Color(0xFFFFF6F1),
                          surfaceTintColor: Colors.transparent,
                          elevation: 0,
                          borderRadius: BorderRadius.circular(28),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Clear all data?',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Clothes, looks, events and profile details will be deleted from this phone. This cannot be undone.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.muted,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Text(
                                  'Type your username to confirm',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: _copyUsername,
                                    onLongPress: _copyUsername,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        12,
                                        8,
                                        12,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              expected,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.terracotta,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Copy username',
                                            onPressed: _copyUsername,
                                            icon: const Icon(
                                              Icons.copy_rounded,
                                              color: AppColors.terracotta,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _typed,
                                  autofocus: true,
                                  enabled: !_busy,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    hintText: 'Enter $expected',
                                    filled: true,
                                    fillColor: Colors.white,
                                    errorText:
                                        _typed.text.isNotEmpty && !_matches
                                        ? 'Username must match exactly'
                                        : null,
                                    suffixIcon: IconButton(
                                      tooltip: 'Paste username',
                                      onPressed: _busy ? null : _pasteUsername,
                                      icon: const Icon(Icons.paste_rounded),
                                    ),
                                  ),
                                  onSubmitted: (_) => _clear(),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => Navigator.pop(context),
                                      child: Text(
                                        'Cancel',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.terracotta,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: _matches && !_busy
                                          ? _clear
                                          : null,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFE8A39A,
                                        ),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: const Color(
                                          0xFFE8A39A,
                                        ).withValues(alpha: 0.45),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                        ),
                                      ),
                                      child: _busy
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Clear data'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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

class _ClearedSuccessPopup extends StatefulWidget {
  const _ClearedSuccessPopup();

  @override
  State<_ClearedSuccessPopup> createState() => _ClearedSuccessPopupState();
}

class _ClearedSuccessPopupState extends State<_ClearedSuccessPopup>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _pulse;
  late final Animation<double> _checkScale;
  late final Animation<double> _checkFade;
  late final Animation<double> _ring;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _checkScale = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(
        parent: _intro,
        curve: const Interval(0, 0.7, curve: Curves.elasticOut),
      ),
    );
    _checkFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.35, curve: Curves.easeOut),
    );
    _ring = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.15, 1, curve: Curves.easeOutCubic),
    );
    _intro.forward();
    _pulse.repeat();
    Future<void>.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, _pulse]),
            builder: (context, _) {
              final pulse = 1 + (_pulse.value * 0.08);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 108,
                    height: 108,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.scale(
                          scale: 0.85 + (_ring.value * 0.55),
                          child: Opacity(
                            opacity: (1 - _ring.value) * 0.45,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.sage,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: pulse,
                          child: Opacity(
                            opacity: _checkFade.value,
                            child: Transform.scale(
                              scale: _checkScale.value,
                              child: Container(
                                width: 78,
                                height: 78,
                                decoration: const BoxDecoration(
                                  color: AppColors.sageSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 44,
                                  color: AppColors.sage,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Opacity(
                    opacity: _checkFade.value,
                    child: Text(
                      'Successfully cleared',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: _checkFade.value,
                    child: Text(
                      'Your wardrobe data has been removed.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
