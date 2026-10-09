import 'package:flutter/material.dart';

import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../shell/tab_page.dart';
import 'text_size_sheet.dart';

/// Appearance (S-53): theme and reading text size, the same controls as the Aa sheet.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: ContentWidth(
        maxWidth: 560,
        child: ListView(
          children: [
            const AppearanceControls(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.xxl),
              child: Text(
                'The text size applies to every reading and to audio transcripts. Your '
                "device's own text size setting is added on top.",
                style: TypeScale.bodySmall.copyWith(color: c.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
