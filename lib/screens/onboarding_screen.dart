import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/profile_avatar.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  Wearer? _wearer;
  DateTime? _dob;
  Uint8List? _photoBytes;
  var _filled = false;

  @override
  void initState() {
    super.initState();
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
    final profile = context.read<DrapeState>().profile;
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
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked == null) return;
    setState(() => _dob = picked);
  }

  Future<void> _start() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a nickname.')),
      );
      return;
    }
    if (_wearer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a gender.')),
      );
      return;
    }
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose your date of birth.')),
      );
      return;
    }
    await context.read<DrapeState>().completeOnboarding(
      name: _name.text,
      workdays: {1, 2, 3, 4, 5},
      workStyle: Formality.smartCasual,
      wearer: _wearer!,
      dateOfBirth: _dob,
      photoBytes: _photoBytes,
    );
  }

  Future<void> _pickPhoto() async {
    final bytes = await pickProfileImage(context);
    if (bytes == null || !mounted) return;
    setState(() => _photoBytes = bytes);
  }

  InputDecoration _glassField(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.92),
      suffixIcon: suffix,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: AppColors.muted,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
        borderSide: const BorderSide(color: AppColors.ink, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth =
        (MediaQuery.sizeOf(context).width * dpr).round().clamp(1, 4096);

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
          const ColoredBox(color: Color(0xB8F7F7F7)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mine',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: ListView(
                      children: [
                        Center(
                          child: Column(
                            children: [
                              ProfileAvatar(
                                radius: 48,
                                imageBytes: _photoBytes,
                                wearer: _wearer ?? Wearer.woman,
                                showEditBadge: true,
                                borderColor: Colors.white,
                                fallbackColor: AppColors.terracottaSoft,
                                onTap: _pickPhoto,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _photoBytes != null ||
                                        (context
                                                .watch<DrapeState>()
                                                .profile
                                                .photoPath
                                                ?.isNotEmpty ??
                                            false)
                                    ? 'Change photo'
                                    : 'Add profile photo',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _label('Nickname'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          cursorColor: AppColors.ink,
                          decoration: _glassField('Your nickname'),
                        ),
                        const SizedBox(height: 22),
                        _label('Gender'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _GenderCard(
                                title: 'Female',
                                image: Wearer.woman.portraitAsset,
                                selected: _wearer == Wearer.woman,
                                onTap: () =>
                                    setState(() => _wearer = Wearer.woman),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _GenderCard(
                                title: 'Male',
                                image: Wearer.man.portraitAsset,
                                selected: _wearer == Wearer.man,
                                onTap: () =>
                                    setState(() => _wearer = Wearer.man),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _label('DOB'),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _pickDob,
                          borderRadius: BorderRadius.circular(16),
                          child: InputDecorator(
                            isEmpty: _dob == null,
                            decoration: _glassField(
                              'Date of birth',
                              suffix: Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: AppColors.muted,
                              ),
                            ),
                            child: Text(
                              _dob == null
                                  ? ''
                                  : DateFormat('d MMMM y').format(_dob!),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _start,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                        textStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Start'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.title,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String image;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.white.withValues(alpha: 0.08),
          child: InkWell(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 148,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.28),
                  width: selected ? 2.4 : 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    image,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.35),
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xB3000000)],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 18,
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
      ),
    );
  }
}
