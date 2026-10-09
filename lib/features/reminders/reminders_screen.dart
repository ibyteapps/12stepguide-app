import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/components/app_icons.dart';
import '../../design/components/list_row.dart';
import '../../design/components/pickers.dart';
import '../../design/components/states.dart';
import '../../design/theme/app_colors.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../shell/tab_page.dart';
import 'reminder_schedule.dart';
import 'reminders_controller.dart';

/// Reminders (S-52): the hourly consciousness reminder with its window, and "We miss you"
/// (A-13). Morning and night reminders are not offered (A-18).
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => ref.read(remindersProvider.notifier).refreshPermission());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the system settings: the permission may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(remindersProvider.notifier).refreshPermission();
    }
  }

  String _format(BuildContext context, ClockTime t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(hour: t.hour, minute: t.minute),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = ref.watch(remindersProvider);
    final s = r.settings;
    final controller = ref.read(remindersProvider.notifier);
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    final lastAt = ClockTime(s.end.hour, s.start.minute);
    final summary =
        '${s.hourlyCount} ${s.hourlyCount == 1 ? 'reminder' : 'reminders'} a day, '
        '${_format(context, s.start)} to ${_format(context, lastAt)}';

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Reminders')),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Space.x3),
          children: [
            if (r.permissionDenied)
              Padding(
                padding: const EdgeInsets.only(left: Space.l, top: Space.l, right: Space.l),
                child: InlineBanner(
                  icon: AppIcons.reminders,
                  tone: BannerTone.warning,
                  message:
                      'Notifications are turned off for 12 Step Guide, so reminders '
                      "can't arrive.",
                  actionLabel: 'Open settings',
                  onAction: controller.openSystemSettings,
                ),
              ),
            const SectionHeader('Hourly consciousness reminder'),
            RowGroup(
              children: [
                SwitchListTile.adaptive(
                  value: s.hourlyEnabled,
                  onChanged: (on) async {
                    final ok = await controller.setHourly(on);
                    if (!ok && context.mounted) {
                      showMessage(
                        context,
                        'Allow notifications for 12 Step Guide to get reminders.',
                        action: 'Settings',
                        onAction: controller.openSystemSettings,
                      );
                    }
                  },
                  title: Text(
                    'Hourly reminder',
                    style: TypeScale.body.copyWith(color: c.textPrimary),
                  ),
                  subtitle: Text(
                    s.hourlyEnabled ? summary : 'A quote to pause on, once an hour',
                    style: TypeScale.bodySmall.copyWith(color: c.textSecondary),
                  ),
                ),
                ListRow(
                  title: 'From',
                  trailing: Text(
                    _format(context, s.start),
                    style: TypeScale.body.copyWith(color: c.primary),
                  ),
                  semanticsLabel: 'First reminder at ${_format(context, s.start)}. Change',
                  onTap: () async {
                    final t = await pickTime(
                      context,
                      initial: TimeOfDay(hour: s.start.hour, minute: s.start.minute),
                      title: 'First reminder',
                    );
                    if (t != null) await controller.setStart(ClockTime(t.hour, t.minute));
                  },
                ),
                ListRow(
                  title: 'Until',
                  trailing: Text(
                    _format(context, lastAt),
                    style: TypeScale.body.copyWith(color: c.primary),
                  ),
                  semanticsLabel: 'Last reminder at ${_format(context, lastAt)}. Change',
                  onTap: () async {
                    final t = await pickTime(
                      context,
                      initial: TimeOfDay(hour: s.end.hour, minute: s.start.minute),
                      title: 'Last reminder (the hour)',
                    );
                    if (t != null) await controller.setEnd(ClockTime(t.hour, 0));
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xxl, Space.s, Space.xxl, Space.xs),
              child: Text(
                'Each reminder opens a quote of the hour.'
                '${isAndroid ? ' Android may deliver them a few minutes late to save battery.' : ''}',
                style: TypeScale.caption.copyWith(color: c.textSecondary),
              ),
            ),
            const SectionHeader('When you have been away'),
            RowGroup(
              children: [
                SwitchListTile.adaptive(
                  value: s.nudgesEnabled,
                  onChanged: controller.setNudges,
                  title: Text('We miss you', style: TypeScale.body.copyWith(color: c.textPrimary)),
                  subtitle: Text(
                    'A gentle note at 10:00 after 3 and 7 days without opening the app',
                    style: TypeScale.bodySmall.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
