import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  Wearer? _wearer;
  var _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    final saved = context.read<DrapeState>().profile.name;
    if (saved.isNotEmpty && saved != 'there') _name.text = saved;
    _filled = true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final wearer = _wearer;
    if (wearer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose Women or Men.')),
      );
      return;
    }
    await context.read<DrapeState>().completeOnboarding(
      name: _name.text,
      workdays: {1, 2, 3, 4, 5},
      workStyle: Formality.smartCasual,
      wearer: wearer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMan = _wearer == Wearer.man;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Drape',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'Upload your clothes.\nSee what to wear each day.',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 34,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Who is this closet for?', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _WearerCard(
                            title: 'Women',
                            body: 'Top, pant, shawl, slippers, earrings',
                            selected: _wearer == Wearer.woman,
                            onTap: () => setState(() => _wearer = Wearer.woman),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _WearerCard(
                            title: 'Men',
                            body: 'Shirt or T-shirt, and pant',
                            selected: _wearer == Wearer.man,
                            onTap: () => setState(() => _wearer = Wearer.man),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isMan
                          ? 'Choose Men to see shirt, T-shirt and pant. Then add photos of each piece.'
                          : 'Choose Women to see top, dress, pant and shawl. Then add photos of each piece.',
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Your name',
                        hintText: 'Name',
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'After you tap Start, open Closet and add each item with a photo and a name.',
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _start,
                child: const SizedBox(
                  width: double.infinity,
                  child: Text('Start', textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WearerCard extends StatelessWidget {
  const _WearerCard({
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : AppColors.paper,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.ink : AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: TextStyle(
                  color: selected ? const Color(0xFFE8DCD2) : AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
