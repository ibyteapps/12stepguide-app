import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../core/prefs/key_value_store.dart';
import '../../design/components/app_icons.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../migration/migration.dart';
import '../sobriety/sobriety_controller.dart';
import '../sobriety/sobriety_date.dart';

/// "Welcome to the new 12 Step Guide" (S-03, F-003): shown once to every upgrading user, listing
/// only what actually came across, then what's new for their platform.
class WelcomeBackScreen extends ConsumerWidget {
  const WelcomeBackScreen({super.key});

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    final store = ref.read(kvStoreProvider);
    await store.setBool(PrefKeys.welcomeBackPending, false);
    if (!context.mounted) return;
    final tab = store.getInt(PrefKeys.lastTab) ?? 0;
    context.go(Routes.tabs[tab.clamp(0, Routes.tabs.length - 1)]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final raw = ref.watch(kvStoreProvider).getString(PrefKeys.migrationSummary);
    final summary = raw == null
        ? null
        : MigrationSummary.fromJson(jsonDecode(raw) as Map<String, Object?>);
    final date = ref.watch(sobrietyProvider);
    final now = ref.watch(clockProvider)();
    final ios = summary?.platform != LegacyPlatform.android;

    final kept = <(IconData, String)>[
      if (summary?.sobrietyDate ?? false)
        if (date != null)
          (
            AppIcons.calendar,
            'Your recovery date (${SobrietyDate.daysLabel(SobrietyDate.days(date, now))})',
          ),
      if (summary?.reminders ?? false) (AppIcons.reminders, 'Your reminders'),
      if ((summary?.downloads ?? 0) > 0)
        (
          AppIcons.downloaded,
          '${summary!.downloads} downloaded ${summary.downloads == 1 ? 'recording' : 'recordings'}',
        ),
      if (summary?.premium == 'lifetime')
        (AppIcons.premium, 'Your supporter status: Premium for life'),
      if (summary?.premium == 'annual') (AppIcons.premium, 'Your Premium subscription'),
      if (summary?.textSize ?? false) (AppIcons.textSize, 'Your reading text size'),
    ];
    final news = <(IconData, String)>[
      (AppIcons.dark, 'A fresh look, with dark mode'),
      if (ios) ...[
        (AppIcons.steps, 'The Twelve Traditions, beside the Steps'),
        (AppIcons.calendar, 'Your recovery date and day count'),
        (AppIcons.tip, 'Sobriety tips'),
      ] else ...[
        (AppIcons.audio, 'Over 90 hours of recovery audio'),
        (AppIcons.reminders, 'Hourly reminders with a thought for the day'),
      ],
      (AppIcons.bookmark, 'The app remembers where you stopped reading'),
    ];

    Widget line((IconData, String) item, Color color) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Row(
        children: [
          Icon(item.$1, color: color),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text(item.$2, style: TypeScale.body.copyWith(color: c.textPrimary)),
          ),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(Space.xxl),
                    children: [
                      const SizedBox(height: Space.xl),
                      Center(
                        child: ClipRRect(
                          borderRadius: Radii.lgAll,
                          child: Image.asset(
                            'assets/images/app-icon.png',
                            width: 96,
                            height: 96,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.xxl),
                      Semantics(
                        header: true,
                        child: Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: TypeScale.headline.copyWith(color: c.textPrimary),
                        ),
                      ),
                      const SizedBox(height: Space.s),
                      Text(
                        'This is the new version of 12 Step Guide.',
                        textAlign: TextAlign.center,
                        style: TypeScale.body.copyWith(color: c.textSecondary),
                      ),
                      if (kept.isNotEmpty) ...[
                        const SizedBox(height: Space.x3),
                        Text(
                          'CAME ACROSS WITH YOU',
                          style: TypeScale.overline.copyWith(color: c.textTertiary),
                        ),
                        for (final k in kept) line(k, c.success),
                      ],
                      const SizedBox(height: Space.xxl),
                      Text("WHAT'S NEW", style: TypeScale.overline.copyWith(color: c.textTertiary)),
                      for (final n in news) line(n, c.primary),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.xxl, Space.s, Space.xxl, Space.xxl),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _continue(context, ref),
                      child: const Text('Continue'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
