import 'package:flutter/material.dart';

/// The shell's scaffold, which owns the drawer. Tab pages have their own scaffolds, so the ☰
/// button opens the drawer through this key.
final shellScaffoldKey = GlobalKey<ScaffoldState>(debugLabel: 'shell');

/// The root navigator, for routes that cover the shell (reader, player, drawer pages).
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
