import 'package:flutter/material.dart';

import '../../design/components/app_icons.dart';
import '../../design/components/states.dart';

/// Temporary page for a destination whose phase has not landed yet.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: const StateMessage(icon: AppIcons.pending, message: 'Coming soon in this build.'),
  );
}
