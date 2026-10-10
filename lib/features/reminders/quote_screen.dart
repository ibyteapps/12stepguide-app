import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../design/components/app_icons.dart';
import '../../design/components/text_scale.dart';
import '../../design/tokens/color_tokens.dart';
import '../../design/tokens/spacing.dart';
import '../../design/tokens/typography.dart';
import '../ads/banner_slot.dart';

/// Picks the quote for one opening of the screen: any of the 61, never a blank line (fixes
/// BUG-24, where one line was unreachable and a blank one possible).
final quoteOfTheHourProvider = Provider.autoDispose<String>((ref) {
  final quotes = ref.watch(quotesProvider);
  if (quotes.isEmpty) return 'One day at a time.';
  return quotes[math.Random().nextInt(quotes.length)];
});

/// Quote of the hour (S-60, F-091): opened from the hourly reminder, also from a cold start.
class QuoteScreen extends ConsumerWidget {
  const QuoteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(quoteOfTheHourProvider);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: FixedTokens.brandGradient,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.topEnd,
                      child: IconButton(
                        icon: const Icon(AppIcons.close, color: FixedTokens.white),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: Space.x3),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const ExcludeSemantics(
                                  child: Icon(
                                    AppIcons.quote,
                                    color: FixedTokens.white,
                                    size: IconSizes.xl,
                                  ),
                                ),
                                const SizedBox(height: Space.l),
                                Text(
                                  'THIS HOUR',
                                  style: TypeScale.overline.copyWith(color: FixedTokens.white),
                                ),
                                const SizedBox(height: Space.l),
                                ReadingTextScale(
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      quote,
                                      textAlign: TextAlign.center,
                                      style: TypeScale.headline.copyWith(
                                        color: FixedTokens.white,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(Space.xxl),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FixedTokens.white,
                          side: const BorderSide(color: FixedTokens.white),
                          minimumSize: const Size(160, Space.touch),
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const BannerSlot(placement: BannerPlacement.quote),
          ],
        ),
      ),
    );
  }
}
