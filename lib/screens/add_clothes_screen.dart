import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';
import '../widgets/back_icon.dart';
import '../widgets/closet_add.dart';
import '../widgets/page_background.dart';
import '../widgets/profile_avatar.dart';
import 'collection_sets_screen.dart';
import 'garment_editor_screen.dart';

class AddClothesScreen extends StatelessWidget {
  const AddClothesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: const AppBackIcon(),
          title: const Text('My outfit'),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: ProfileAvatar()),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
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
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add clothes'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Text(
              '${state.garments.length} items',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text('Collections', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Open a card for singles or sets. Empty cards show Coming soon until you add something.',
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
    required this.setCount,
    required this.singleCount,
    required this.isEmpty,
  });

  final StyleCollection collection;
  final int setCount;
  final int singleCount;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    final status = isEmpty
        ? 'Coming soon'
        : [
            if (singleCount > 0) '$singleCount items',
            if (setCount > 0) '$setCount sets',
          ].join(' · ');

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
                collection.coverAsset,
                fit: BoxFit.cover,
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
