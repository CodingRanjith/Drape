import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../product.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_avatar.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  Wearer? _wearer;
  DateTime? _dob;
  Uint8List? _photoBytes;
  var _filled = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _nameFocus.addListener(() => setState(() {}));
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    final profile = context.read<MineState>().profile;
    if (profile.name.isNotEmpty && profile.name != 'there') {
      _name.text = profile.name;
    }
    _wearer = profile.onboarded ? profile.wearer : _wearer;
    _dob = profile.dateOfBirth;
    _filled = true;
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_name.text.trim().isEmpty) {
      _nameFocus.requestFocus();
      _toast('Please enter your full name.');
      return;
    }
    if (_wearer == null) {
      _toast('Please choose a gender.');
      return;
    }
    if (_dob == null) {
      _toast('Please choose your date of birth.');
      return;
    }
    await context.read<MineState>().completeOnboarding(
      name: _name.text,
      workdays: {1, 2, 3, 4, 5},
      workStyle: Formality.smartCasual,
      wearer: _wearer!,
      dateOfBirth: _dob,
      photoBytes: _photoBytes,
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final bytes = await pickProfileImage(context);
    if (bytes == null || !mounted) return;
    setState(() => _photoBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth =
        (MediaQuery.sizeOf(context).width * dpr).round().clamp(1, 4096);
    final hasPhoto = _photoBytes != null ||
        (context.watch<MineState>().profile.photoPath?.isNotEmpty ?? false);
    final nameFocused = _nameFocus.hasFocus;

    return Scaffold(
      backgroundColor: AppColors.parchment,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.parchment),
          Image.asset(
            'assets/onboarding_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.medium,
            isAntiAlias: true,
            cacheWidth: cacheWidth,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: AppColors.parchment),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xEEF7F7F7),
                  Color(0xD8F7F7F7),
                  Color(0xF5F7F7F7),
                ],
                stops: [0, 0.42, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _MineBrandHeader(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 8),
                      children: [
                        const _WelcomeStrip(),
                        const SizedBox(height: 22),
                        _IdentityBlock(
                          photoBytes: _photoBytes,
                          wearer: _wearer ?? Wearer.woman,
                          hasPhoto: hasPhoto,
                          nameController: _name,
                          nameFocus: _nameFocus,
                          nameFocused: nameFocused,
                          onPickPhoto: _pickPhoto,
                        ),
                        const SizedBox(height: 28),
                        const _GoldRule(),
                        const SizedBox(height: 22),
                        const _SectionTitle(
                          'Gender',
                          'Helps tailor outfit suggestions',
                        ),
                        const SizedBox(height: 14),
                        _GenderToggle(
                          selected: _wearer,
                          onSelect: (wearer) =>
                              setState(() => _wearer = wearer),
                        ),
                        const SizedBox(height: 28),
                        const _GoldRule(),
                        const SizedBox(height: 22),
                        const _SectionTitle(
                          'Date of birth',
                          'Used for age-aware outfit ideas',
                        ),
                        const SizedBox(height: 14),
                        _DobNumberLocker(
                          value: _dob,
                          onChanged: (value) => setState(() => _dob = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StartButton(
                    hasName: _name.text.trim().isNotEmpty,
                    hasGender: _wearer != null,
                    hasDob: _dob != null,
                    onPressed: _start,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MineBrandHeader extends StatelessWidget {
  const _MineBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/brand/app_icon.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: AppColors.terracottaSoft,
              child: Center(
                child: Text(
                  'M',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                MineProduct.appName,
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 2,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      MineProduct.tagline,
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                        letterSpacing: 0.15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WelcomeStrip extends StatelessWidget {
  const _WelcomeStrip();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your closet, introduced.',
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.4,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tell Mine who you are — then watch daily looks fall into place.',
          style: GoogleFonts.manrope(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _TraitChip(icon: Icons.face_retouching_natural, label: 'You'),
            _TraitChip(icon: Icons.checkroom_outlined, label: 'Style'),
            _TraitChip(icon: Icons.auto_awesome, label: 'Daily fits'),
          ],
        ),
      ],
    );
  }
}

class _TraitChip extends StatelessWidget {
  const _TraitChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.55),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.terracotta),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({
    required this.photoBytes,
    required this.wearer,
    required this.hasPhoto,
    required this.nameController,
    required this.nameFocus,
    required this.nameFocused,
    required this.onPickPhoto,
  });

  final Uint8List? photoBytes;
  final Wearer wearer;
  final bool hasPhoto;
  final TextEditingController nameController;
  final FocusNode nameFocus;
  final bool nameFocused;
  final VoidCallback onPickPhoto;

  @override
  Widget build(BuildContext context) {
    final filled = nameController.text.trim().isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 28),
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withValues(alpha: 0.55),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Full name',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'How should we greet you?',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: nameFocused
                      ? Colors.white
                      : AppColors.ink.withValues(alpha: 0.04),
                  border: Border.all(
                    color: nameFocused
                        ? AppColors.terracotta
                        : Colors.transparent,
                    width: 1.3,
                  ),
                ),
                child: TextField(
                  controller: nameController,
                  focusNode: nameFocus,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.manrope(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  cursorColor: AppColors.terracotta,
                  decoration: InputDecoration(
                    hintText: 'Write your name here',
                    hintStyle: GoogleFonts.manrope(
                      color: AppColors.muted.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w500,
                      fontSize: 14.5,
                    ),
                    prefixIcon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    suffixIcon: filled
                        ? IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: nameController.clear,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.muted,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                hasPhoto
                    ? 'Photo added · tap the circle to change'
                    : 'Tip: a clear face photo helps personalize looks',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: onPickPhoto,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.9),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.gold.withValues(alpha: 0.95),
                        AppColors.terracotta,
                      ],
                    ),
                  ),
                  child: ProfileAvatar(
                    radius: 32,
                    imageBytes: photoBytes,
                    wearer: wearer,
                    showEditBadge: true,
                    fallbackColor: AppColors.terracottaSoft,
                    onTap: onPickPhoto,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoldRule extends StatelessWidget {
  const _GoldRule();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.ink.withValues(alpha: 0.08),
          ),
        ),
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(1),
          ),
          transform: Matrix4.rotationZ(0.785398),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.ink.withValues(alpha: 0.08),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.hint);

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          hint,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _GenderToggle extends StatelessWidget {
  const _GenderToggle({
    required this.selected,
    required this.onSelect,
  });

  final Wearer? selected;
  final ValueChanged<Wearer> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GenderPick(
            title: 'Female',
            caption: 'Soft · fluid · bold',
            image: Wearer.woman.portraitAsset,
            selected: selected == Wearer.woman,
            onTap: () => onSelect(Wearer.woman),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GenderPick(
            title: 'Male',
            caption: 'Sharp · easy · clean',
            image: Wearer.man.portraitAsset,
            selected: selected == Wearer.man,
            onTap: () => onSelect(Wearer.man),
          ),
        ),
      ],
    );
  }
}

class _GenderPick extends StatelessWidget {
  const _GenderPick({
    required this.title,
    required this.caption,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String caption;
  final String image;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.terracottaSoft.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.9),
                    ],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.55),
            border: Border.all(
              color: selected
                  ? AppColors.terracotta
                  : AppColors.gold.withValues(alpha: 0.28),
              width: selected ? 1.7 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AppColors.terracotta.withValues(alpha: 0.16)
                    : AppColors.ink.withValues(alpha: 0.04),
                blurRadius: selected ? 14 : 8,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: selected ? 72 : 64,
                    height: selected ? 72 : 64,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: selected
                          ? LinearGradient(
                              colors: [
                                AppColors.gold.withValues(alpha: 0.95),
                                AppColors.terracotta,
                              ],
                            )
                          : null,
                      color: selected
                          ? null
                          : AppColors.ink.withValues(alpha: 0.08),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        image,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.78),
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: AppColors.clay),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.terracotta,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? AppColors.terracotta
                      : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.hasName,
    required this.hasGender,
    required this.hasDob,
    required this.onPressed,
  });

  final bool hasName;
  final bool hasGender;
  final bool hasDob;
  final VoidCallback onPressed;

  bool get _enabled => hasName && hasGender && hasDob;

  int get _done =>
      (hasName ? 1 : 0) + (hasGender ? 1 : 0) + (hasDob ? 1 : 0);

  String get _title => _enabled ? 'Open my wardrobe' : 'Continue styling';

  String get _subtitle {
    if (_enabled) return 'Looks tailored to you are ready';
    if (!hasName) return 'Add your name to begin';
    if (!hasGender) return 'Pick a style lane next';
    return 'Set your birthday to unlock';
  }

  Future<void> _handleTap() async {
    HapticFeedback.mediumImpact();
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
    onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Profile $_done/3',
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _done / 3,
                  minHeight: 4,
                  backgroundColor: AppColors.ink.withValues(alpha: 0.08),
                  color: _enabled ? AppColors.terracotta : AppColors.gold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: _enabled
                      ? const [Color(0xFF1C1612), Color(0xFFC45C26)]
                      : const [Color(0xFFA39A92), Color(0xFF8E857D)],
                ),
                border: Border.all(
                  color: _enabled
                      ? AppColors.gold.withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink
                        .withValues(alpha: _enabled ? 0.2 : 0.07),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                      border: Border.all(
                        color: _enabled
                            ? AppColors.gold.withValues(alpha: 0.8)
                            : Colors.white38,
                      ),
                    ),
                    child: Icon(
                      _enabled
                          ? Icons.checkroom_rounded
                          : Icons.arrow_forward_rounded,
                      size: 18,
                      color: _enabled ? AppColors.gold : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: GoogleFonts.manrope(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle,
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _enabled
                          ? AppColors.gold
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: _enabled ? AppColors.ink : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact single-line gear-chain DOB scroller with click + haptic ticks.
class _DobNumberLocker extends StatefulWidget {
  const _DobNumberLocker({
    required this.value,
    required this.onChanged,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_DobNumberLocker> createState() => _DobNumberLockerState();
}

class _DobNumberLockerState extends State<_DobNumberLocker> {
  static const _itemExtent = 36.0;
  static const _visibleItems = 3;
  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  late final int _minYear;
  late final int _maxYear;
  late FixedExtentScrollController _dayCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _yearCtrl;

  late int _day;
  late int _month;
  late int _year;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _minYear = 1920;
    _maxYear = now.year;
    final initial =
        widget.value ?? DateTime(now.year - 18, now.month, now.day);
    _year = initial.year.clamp(_minYear, _maxYear);
    _month = initial.month.clamp(1, 12);
    _day = initial.day.clamp(1, _daysInMonth(_year, _month));

    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _yearCtrl = FixedExtentScrollController(initialItem: _year - _minYear);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ready = true;
      widget.onChanged(DateTime(_year, _month, _day));
    });
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  void _tick() {
    HapticFeedback.selectionClick();
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  void _emit() {
    final safeDay = _day.clamp(1, _daysInMonth(_year, _month));
    if (safeDay != _day) {
      _day = safeDay;
      if (_dayCtrl.hasClients) _dayCtrl.jumpToItem(_day - 1);
    }
    widget.onChanged(DateTime(_year, _month, _day));
  }

  void _onDayChanged(int index) {
    if (!_ready) return;
    final next = index + 1;
    if (next == _day) return;
    setState(() => _day = next);
    _tick();
    _emit();
  }

  void _onMonthChanged(int index) {
    if (!_ready) return;
    final next = index + 1;
    if (next == _month) return;
    setState(() {
      _month = next;
      final maxDay = _daysInMonth(_year, _month);
      if (_day > maxDay) {
        _day = maxDay;
        _dayCtrl.jumpToItem(_day - 1);
      }
    });
    _tick();
    _emit();
  }

  void _onYearChanged(int index) {
    if (!_ready) return;
    final next = _minYear + index;
    if (next == _year) return;
    setState(() {
      _year = next;
      final maxDay = _daysInMonth(_year, _month);
      if (_day > maxDay) {
        _day = maxDay;
        _dayCtrl.jumpToItem(_day - 1);
      }
    });
    _tick();
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final dayCount = _daysInMonth(_year, _month);
    final height = _itemExtent * _visibleItems;

    return Container(
      height: height + 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF4EFE9), Color(0xFFE8E0D6), Color(0xFFF7F3EE)],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Brushed metal sheen
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0x22FFFFFF),
                    Color(0x00FFFFFF),
                    Color(0x18FFFFFF),
                    Color(0x00FFFFFF),
                    Color(0x22FFFFFF),
                  ],
                ),
              ),
            ),
          ),
          // Gear tooth rails
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _GearToothRail(),
          ),
          const Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _GearToothRail(mirror: true),
          ),
          // Selection aperture
          IgnorePointer(
            child: Container(
              height: _itemExtent,
              margin: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.55),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.55),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  flex: 8,
                  child: _LockerColumn(
                    key: ValueKey('day-$dayCount'),
                    controller: _dayCtrl,
                    itemCount: dayCount,
                    itemExtent: _itemExtent,
                    labelBuilder: (i) => '${i + 1}'.padLeft(2, '0'),
                    selectedIndex: _day - 1,
                    onSelected: _onDayChanged,
                  ),
                ),
                const _GearCogDivider(),
                Expanded(
                  flex: 10,
                  child: _LockerColumn(
                    controller: _monthCtrl,
                    itemCount: 12,
                    itemExtent: _itemExtent,
                    labelBuilder: (i) => _monthNames[i],
                    selectedIndex: _month - 1,
                    onSelected: _onMonthChanged,
                  ),
                ),
                const _GearCogDivider(),
                Expanded(
                  flex: 10,
                  child: _LockerColumn(
                    controller: _yearCtrl,
                    itemCount: _maxYear - _minYear + 1,
                    itemExtent: _itemExtent,
                    labelBuilder: (i) => '${_minYear + i}',
                    selectedIndex: _year - _minYear,
                    onSelected: _onYearChanged,
                  ),
                ),
              ],
            ),
          ),
          // Top / bottom vignette — single-line gear window
          IgnorePointer(
            child: Column(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFF0E9E0),
                          const Color(0xFFF0E9E0).withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _itemExtent),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          const Color(0xFFEDE4DA),
                          const Color(0xFFEDE4DA).withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GearToothRail extends StatelessWidget {
  const _GearToothRail({this.mirror = false});

  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      child: CustomPaint(
        painter: _GearToothPainter(mirror: mirror),
      ),
    );
  }
}

class _GearToothPainter extends CustomPainter {
  _GearToothPainter({required this.mirror});

  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = AppColors.gold.withValues(alpha: 0.55);
    final edge = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const teeth = 9;
    final toothH = size.height / teeth;
    for (var i = 0; i < teeth; i++) {
      final top = i * toothH + 2;
      final mid = top + toothH * 0.42;
      final bot = top + toothH - 2;
      final path = Path();
      if (!mirror) {
        path
          ..moveTo(0, top)
          ..lineTo(size.width, mid)
          ..lineTo(0, bot)
          ..close();
      } else {
        path
          ..moveTo(size.width, top)
          ..lineTo(0, mid)
          ..lineTo(size.width, bot)
          ..close();
      }
      canvas.drawPath(path, fill);
      canvas.drawPath(path, edge);
    }
  }

  @override
  bool shouldRepaint(covariant _GearToothPainter oldDelegate) =>
      oldDelegate.mirror != mirror;
}

class _GearCogDivider extends StatelessWidget {
  const _GearCogDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.settings,
            size: 13,
            color: AppColors.gold.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 4),
          Container(
            width: 2,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.gold.withValues(alpha: 0.15),
                  AppColors.gold.withValues(alpha: 0.7),
                  AppColors.gold.withValues(alpha: 0.15),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            Icons.settings,
            size: 13,
            color: AppColors.gold.withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }
}

class _LockerColumn extends StatelessWidget {
  const _LockerColumn({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemExtent,
    required this.labelBuilder,
    required this.selectedIndex,
    required this.onSelected,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final double itemExtent;
  final String Function(int index) labelBuilder;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: itemExtent,
      physics: const FixedExtentScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      perspective: 0.0035,
      diameterRatio: 1.15,
      squeeze: 1.05,
      onSelectedItemChanged: onSelected,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) {
          final selected = index == selectedIndex;
          return Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 110),
              style: GoogleFonts.manrope(
                fontSize: selected ? 17 : 13.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected
                    ? AppColors.ink
                    : AppColors.muted.withValues(alpha: 0.55),
                letterSpacing: selected ? 0.4 : 0.1,
              ),
              child: Text(labelBuilder(index)),
            ),
          );
        },
      ),
    );
  }
}

