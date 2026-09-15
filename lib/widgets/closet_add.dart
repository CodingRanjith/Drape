import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wardrobe.dart';
import '../state/drape_state.dart';
import '../theme/app_theme.dart';

Future<void> pickClothesType(
  BuildContext context, {
  required void Function(ClothesType type) onPick,
  String title = 'Add to this set',
}) async {
  final wearer = context.read<DrapeState>().profile.wearer;
  final types = ClothesType.forWearer(wearer);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
            for (final type in types)
              ListTile(
                leading: Icon(type.category.icon),
                title: Text(type.label),
                onTap: () {
                  Navigator.pop(context);
                  onPick(type);
                },
              ),
          ],
        ),
      );
    },
  );
}
