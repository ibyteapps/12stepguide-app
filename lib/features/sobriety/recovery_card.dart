import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../design/components/app_icons.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import 'cheer.dart';
import 'sobriety_controller.dart';
import 'sobriety_date.dart';

/// "Your recovery" at the top of Readings (S-20, F-050). The day count is the hero; tapping it
/// plays the cheer (F-053). Celebrated, never streak-shamed (UX_UI_SPEC §1).
class RecoveryCard extends ConsumerWidget {
  const RecoveryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final date = ref.watch(sobrietyProvider);
    final now = ref.watch(clockProvider)();
    final onBrand = c.onSurfaceBrand;
    final soft = onBrand.withAlpha(200);

    final Widget content;
    if (date == null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keep track of your sober time.',
            style: TypeScale.titleSmall.copyWith(color: onBrand),
          ),
          const SizedBox(height: Space.xs),
          Text('Your date stays on this device.', style: TypeScale.bodySmall.copyWith(color: soft)),
          const SizedBox(height: Space.l),
          FilledButton.tonalIcon(
            onPressed: () => context.push(Routes.recoveryDate),
            icon: const Icon(AppIcons.calendar),
            label: const Text('Set your recovery date'),
          ),
        ],
      );
    } else {
      final days = SobrietyDate.days(date, now);
      final label = days == 0 ? 'Today' : SobrietyDate.daysLabel(days);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: days == 0
                ? 'Today is your first day. Double tap to celebrate.'
                : '$label sober. Double tap to celebrate.',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: Radii.mdAll,
              onTap: () => ref.read(cheerPlayerProvider).play(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: Text(label, style: TypeScale.display.copyWith(color: onBrand)),
              ),
            ),
          ),
          Text(
            days == 0 ? 'Your first day. Welcome.' : 'Sober since ${SobrietyDate.formatLong(date)}',
            style: TypeScale.body.copyWith(color: soft),
          ),
          const SizedBox(height: Space.s),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: onBrand, padding: EdgeInsets.zero),
              onPressed: () => context.push(Routes.recoveryDate),
              child: const Text('Details and change date'),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.l, Space.xl, Space.m),
      decoration: BoxDecoration(color: c.surfaceBrand, borderRadius: Radii.lgAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('YOUR RECOVERY', style: TypeScale.overline.copyWith(color: soft)),
          ),
          const SizedBox(height: Space.s),
          content,
        ],
      ),
    );
  }
}
