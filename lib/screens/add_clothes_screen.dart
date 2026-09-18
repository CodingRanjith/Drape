import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/mine_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/closet_add.dart';
import '../widgets/page_background.dart';
import 'collection_sets_screen.dart';
import 'garment_editor_screen.dart';

class AddClothesScreen extends StatelessWidget {
  const AddClothesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MineState>();

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackIcon(),
          title: const Text('My outfit'),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => pickClothesType(
            context,
            title: 'Add clothes',
            onPick: (type) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GarmentEditorScreen(
                    initialCategory: type.category,
                    initialTopKind: type.topKind,
                  ),
                ),
              );
            },
          ),
          child: const Icon(Icons.add_rounded),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Text(
              '${state.garments.length} items · 10 collections',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text('Collections', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Open a card to upload sets. Empty cards show Coming soon until you add a set.',
            ),
            const SizedBox(height: 18),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.88,
              children: [
                for (final collection in StyleCollection.values)
                  _CollectionCard(
                    collection: collection,
                    wearer: state.profile.wearer,
                    setCount: state.setsFor(collection).length,
                    singleCount: state.singlesFor(collection).length,
                    isEmpty: !state.collectionHasContent(collection),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.collection,
    required this.wearer,
    required this.setCount,
    required this.singleCount,
    required this.isEmpty,
  });

  final StyleCollection collection;
  final Wearer wearer;
  final int setCount;
  final int singleCount;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    final status = isEmpty
        ? 'Coming soon'
        : [
            if (setCount > 0) '$setCount sets',
            if (singleCount > 0) '$singleCount items',
          ].join(' · ');
    final cover = collection.coverAssetFor(wearer);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CollectionSetsScreen(collection: collection),
          ),
        ),
        child: Ink(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                cover,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      collection.coverGradient.first.withValues(alpha: 0.45),
                      collection.coverGradient.last.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(collection.icon, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      collection.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: isEmpty
                            ? const Color(0xFFFFD8C2)
                            : Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
