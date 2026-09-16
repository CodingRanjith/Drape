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

class ClosetScreen extends StatelessWidget {
  const ClosetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DrapeState>();

    return PageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
        leading: const AppBackIcon(),
        title: const Text('Add clothes'),
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
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Text('Collections', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Open a card and add as many sets as you want, or tap Add clothes to upload a photo.'),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
            children: [
              for (final collection in StyleCollection.values)
                _CollectionCard(
                  collection: collection,
                  setCount: state.setsFor(collection).length,
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
  });

  final StyleCollection collection;
  final int setCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CollectionSetsScreen(collection: collection),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.terracottaSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(collection.icon, color: AppColors.terracotta),
              ),
              const Spacer(),
              Text(
                collection.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                collection.comingSoon
                    ? 'Coming soon'
                    : setCount == 0
                    ? 'Tap to add sets'
                    : '$setCount sets',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: collection.comingSoon ? AppColors.terracotta : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
