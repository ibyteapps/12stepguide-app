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
import '../reminders/reminders_controller.dart';

/// First-run onboarding (S-02, F-002): Welcome → What's inside → Reminders → Free, with ads.
/// Skippable, shown once. No advert and no paywall appear during it.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  static const _count = 4;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish({String? then}) async {
    await ref.read(kvStoreProvider).setBool(PrefKeys.onboardingDone, true);
    if (!mounted) return;
    context.go(Routes.steps);
    if (then != null) await context.push(then);
  }

  void _next() {
    if (_page == _count - 1) {
      _finish();
      return;
    }
    _pages.nextPage(duration: Motion.of(context, Motion.medium), curve: Motion.standard);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hours = ref.watch(catalogueProvider).totalDuration.inHours;
    final roundedHours = (hours ~/ 10) * 10;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.all(Space.s),
                child: TextButton(onPressed: _finish, child: const Text('Skip')),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _Page(
                    art: Image.asset(
                      'assets/images/app-icon.png',
                      width: 112,
                      height: 112,
                      excludeFromSemantics: true,
                    ),
                    title: 'Welcome to 12 Step Guide',
                    body:
                        'A companion for working the Steps, written by a long-term sober '
                        'member.',
                  ),
                  _Page(
                    art: const _ArtIcon(AppIcons.bigBook),
                    title: "What's inside",
                    bodyWidget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Bullet(AppIcons.steps, 'The Twelve Steps and the Twelve Traditions'),
                        const _Bullet(
                          AppIcons.bigBook,
                          'The Big Book, with the stories from the first and second editions',
                        ),
                        _Bullet(AppIcons.audio, 'Over $roundedHours hours of recovery audio'),
                        const _Bullet(
                          AppIcons.readings,
                          'Prayers, readings and your recovery date',
                        ),
                      ],
                    ),
                  ),
                  _Page(
                    art: const _ArtIcon(AppIcons.reminders),
                    title: 'A reminder each hour',
                    body:
                        'Get a gentle nudge every hour, from 8 am to 10 pm, with a short '
                        'thought for the day. You can change the hours or turn it off at any '
                        'time.',
                    extra: const _SampleNotification(),
                    actions: [
                      FilledButton(
                        onPressed: () async {
                          await ref.read(remindersProvider.notifier).turnOnHourlyFromOnboarding();
                          _next();
                        },
                        child: const Text('Turn on reminders'),
                      ),
                      TextButton(onPressed: _next, child: const Text('Not now')),
                    ],
                  ),
                  _Page(
                    art: const _ArtIcon(AppIcons.support),
                    title: 'Free, with ads',
                    body:
                        'The app is free and supported by adverts. Premium removes the adverts '
                        'and lets you download audio to listen offline.',
                    actions: [
                      FilledButton(onPressed: _finish, child: const Text('Start')),
                      TextButton(
                        onPressed: () => _finish(then: Routes.paywall),
                        child: const Text('See Premium'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.xxl, Space.s, Space.xxl, Space.l),
              child: Row(
                children: [
                  Semantics(
                    label: 'Page ${_page + 1} of $_count',
                    child: Row(
                      children: [
                        for (var i = 0; i < _count; i++)
                          AnimatedContainer(
                            duration: Motion.of(context, Motion.fast),
                            margin: const EdgeInsets.only(right: Space.s),
                            width: i == _page ? Space.l + Space.xs : Space.s,
                            height: Space.s,
                            decoration: BoxDecoration(
                              color: i == _page ? c.primary : c.divider,
                              borderRadius: Radii.pillAll,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_page < 2) FilledButton(onPressed: _next, child: const Text('Next')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.art,
    required this.title,
    this.body,
    this.bodyWidget,
    this.extra,
    this.actions = const [],
  });

  final Widget art;
  final String title;
  final String? body;
  final Widget? bodyWidget;
  final Widget? extra;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: Space.x3),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              art,
              const SizedBox(height: Space.x3),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TypeScale.headline.copyWith(color: c.textPrimary),
                ),
              ),
              const SizedBox(height: Space.m),
              if (body != null)
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: TypeScale.body.copyWith(color: c.textSecondary),
                ),
              ?bodyWidget,
              if (extra != null) ...[const SizedBox(height: Space.xxl), extra!],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: Space.x3),
                for (final a in actions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.s),
                    child: SizedBox(width: double.infinity, child: a),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtIcon extends StatelessWidget {
  const _ArtIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(color: c.primaryContainer, borderRadius: Radii.lgAll),
        child: Icon(icon, size: Space.x5 + Space.l, color: c.onPrimaryContainer),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.s),
      child: Row(
        children: [
          Icon(icon, color: c.primary),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text(text, style: TypeScale.body.copyWith(color: c.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// What an hourly reminder looks like, before the system asks for permission.
class _SampleNotification extends StatelessWidget {
  const _SampleNotification();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Example reminder: Hourly consciousness reminder. Tap to reveal this hour’s quote.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(Space.m),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: Radii.mdAll,
          border: Border.all(color: c.divider),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: Radii.smAll,
              child: Image.asset('assets/images/app-icon.png', width: Space.x4, height: Space.x4),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hourly Consciousness Reminder',
                    style: TypeScale.label.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: Space.xxs),
                  Text(
                    'Tap to reveal this hour’s quote',
                    style: TypeScale.bodySmall.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
