import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/app_icons.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import 'appearance_controller.dart';

/// The "Aa" sheet (S-12): text size, a live preview line, and the theme. Changes apply at once
/// and are remembered.
Future<void> showTextSizeSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => const SafeArea(child: AppearanceControls(inSheet: true)),
);

/// Text size and theme controls, shared by the Aa sheet and the Appearance page (S-53).
class AppearanceControls extends ConsumerWidget {
  const AppearanceControls({this.inSheet = false, super.key});

  final bool inSheet;

  static const preview = 'Rarely have we seen a person fail who has thoroughly followed our path.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.xxl, inSheet ? 0 : Space.l, Space.xxl, Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (inSheet)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: Semantics(
                header: true,
                child: Text(
                  'Text and theme',
                  style: TypeScale.title.copyWith(color: c.textPrimary),
                ),
              ),
            ),
          Text('READING TEXT SIZE', style: TypeScale.overline.copyWith(color: c.textTertiary)),
          Row(
            children: [
              ExcludeSemantics(
                child: Text('A', style: TypeScale.bodySmall.copyWith(color: c.textSecondary)),
              ),
              Expanded(
                child: Slider(
                  value: settings.textStep.toDouble(),
                  min: ReaderType.minStep.toDouble(),
                  max: ReaderType.maxStep.toDouble(),
                  divisions: ReaderType.maxStep - ReaderType.minStep,
                  label: '${ReaderType.sizeFor(settings.textStep).toStringAsFixed(0)} pt',
                  semanticFormatterCallback: (v) => 'Text size ${v.round()} of 8',
                  onChanged: (v) => controller.setTextStep(v.round()),
                ),
              ),
              ExcludeSemantics(
                child: Text('A', style: TypeScale.headline.copyWith(color: c.textSecondary)),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Space.l),
            decoration: BoxDecoration(color: c.surfaceReader, borderRadius: Radii.mdAll),
            child: Text(
              preview,
              style: ReaderType.body(settings.textStep).copyWith(color: c.textPrimary),
            ),
          ),
          const SizedBox(height: Space.xxl),
          Text('THEME', style: TypeScale.overline.copyWith(color: c.textTertiary)),
          const SizedBox(height: Space.s),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(AppIcons.system),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(AppIcons.light),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(AppIcons.dark),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => controller.setThemeMode(s.first),
            ),
          ),
        ],
      ),
    );
  }
}
