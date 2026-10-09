import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/links/links.dart';
import '../../design/components/app_icons.dart';
import '../../design/components/dialogs.dart';
import '../../design/components/pickers.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../shell/tab_page.dart';
import 'cheer.dart';
import 'sobriety_controller.dart';
import 'sobriety_date.dart';

/// Recovery date (S-21, F-051): the date, total days, years/months/days, change and clear.
class RecoveryDateScreen extends ConsumerWidget {
  const RecoveryDateScreen({super.key});

  static final firstDate = DateTime(1935, 6, 10);

  Future<void> _change(BuildContext context, WidgetRef ref) async {
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final current = ref.read(sobrietyProvider) ?? today;
    final picked = await pickDate(
      context,
      initial: current.isAfter(today) ? today : current,
      first: firstDate,
      last: today, // no future dates
      title: 'Your recovery date',
    );
    if (picked != null) await ref.read(sobrietyProvider.notifier).set(picked);
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final ok = await confirmAction(
      context,
      title: 'Clear your recovery date?',
      message: 'The day count will disappear until you set a date again.',
      confirmLabel: 'Clear date',
    );
    if (ok) await ref.read(sobrietyProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final date = ref.watch(sobrietyProvider);
    final now = ref.watch(clockProvider)();
    final soberToday = AppLinks.isApple
        ? AppLinks.appleApp('1239464706')
        : AppLinks.playApp('com.ibyteapps.sobertoday');

    return Scaffold(
      appBar: AppBar(title: const Text('Recovery date')),
      body: ContentWidth(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.all(Space.l),
          children: [
            Container(
              padding: const EdgeInsets.all(Space.xxl),
              decoration: BoxDecoration(color: c.surfaceBrand, borderRadius: Radii.lgAll),
              child: date == null
                  ? Column(
                      children: [
                        Icon(AppIcons.calendar, size: IconSizes.xl, color: c.onSurfaceBrand),
                        const SizedBox(height: Space.m),
                        Text(
                          'Set the date your recovery began to see your sober time.',
                          textAlign: TextAlign.center,
                          style: TypeScale.body.copyWith(color: c.onSurfaceBrand),
                        ),
                      ],
                    )
                  : _Stats(date: date, now: now),
            ),
            const SizedBox(height: Space.xxl),
            FilledButton.icon(
              onPressed: () => _change(context, ref),
              icon: const Icon(AppIcons.calendar),
              label: Text(date == null ? 'Set your recovery date' : 'Change date'),
            ),
            if (date != null) ...[
              const SizedBox(height: Space.s),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: c.error),
                onPressed: () => _clear(context, ref),
                child: const Text('Clear date'),
              ),
            ],
            const SizedBox(height: Space.x3),
            Text(
              'Your date is kept only on this device. It is never sent anywhere.',
              textAlign: TextAlign.center,
              style: TypeScale.bodySmall.copyWith(color: c.textTertiary),
            ),
            const SizedBox(height: Space.l),
            TextButton.icon(
              onPressed: () => ref.read(linkOpenerProvider).open(soberToday),
              icon: const Icon(AppIcons.openExternal, size: IconSizes.s),
              label: const Text('Get Sober Today for detailed stats'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stats extends ConsumerWidget {
  const _Stats({required this.date, required this.now});

  final DateTime date;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final days = SobrietyDate.days(date, now);
    final b = SobrietyDate.breakdown(date, now);
    final onBrand = c.onSurfaceBrand;
    return Column(
      children: [
        Text('SOBER SINCE', style: TypeScale.overline.copyWith(color: onBrand.withAlpha(200))),
        const SizedBox(height: Space.xs),
        Text(
          SobrietyDate.formatLong(date),
          textAlign: TextAlign.center,
          style: TypeScale.title.copyWith(color: onBrand),
        ),
        const SizedBox(height: Space.l),
        Semantics(
          button: true,
          label: days == 0
              ? 'Today. Double tap to celebrate.'
              : '${SobrietyDate.daysLabel(days)}. Double tap to celebrate.',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: Radii.mdAll,
            onTap: () => ref.read(cheerPlayerProvider).play(),
            child: Padding(
              padding: const EdgeInsets.all(Space.xs),
              child: Text(
                days == 0 ? 'Today' : SobrietyDate.daysLabel(days),
                textAlign: TextAlign.center,
                style: TypeScale.display.copyWith(color: onBrand),
              ),
            ),
          ),
        ),
        if (days > 0) ...[
          const SizedBox(height: Space.s),
          Text(
            SobrietyDate.breakdownLabel(b),
            textAlign: TextAlign.center,
            style: TypeScale.body.copyWith(color: onBrand.withAlpha(220)),
          ),
        ],
      ],
    );
  }
}
