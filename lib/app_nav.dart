import 'package:flutter/material.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

void Function(int tab)? goToShellTab;

/// Wardrobe tab registers this — double-tap center icon toggles doors.
VoidCallback? toggleWardrobeDoors;
