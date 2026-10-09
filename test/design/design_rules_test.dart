// Design-system rules enforced by test (FLUTTER_ARCHITECTURE.md §7, UX_UI_SPEC.md §3, §7).
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/design/theme/app_colors.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.2 contrast ratio.
double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('no raw design values outside lib/design', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.startsWith('lib/design/'));

    final rawColour = RegExp(r'Color\(0x|Colors\.[a-z]');
    final rawFontSize = RegExp(r'fontSize:\s*\d');
    final edgeInsets = RegExp(r'EdgeInsets\.\w+\(([^()]*)\)');
    final literalArg = RegExp(r'(^|[(:,])\s*\d+(\.\d+)?\s*(,|$)');

    for (final file in files) {
      test(file.path, () {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final where = '${file.path}:${i + 1}: $line';
          expect(rawColour.hasMatch(line), isFalse, reason: 'raw colour at $where');
          expect(rawFontSize.hasMatch(line), isFalse, reason: 'raw font size at $where');
          for (final m in edgeInsets.allMatches(line)) {
            expect(literalArg.hasMatch(m[1]!), isFalse, reason: 'raw spacing at $where');
          }
        }
      });
    }
  });

  group('text contrast meets WCAG AA in both themes (UX_UI_SPEC §3.3)', () {
    for (final (name, c) in [('light', AppColors.light), ('dark', AppColors.dark)]) {
      test(name, () {
        final pairs = <String, (Color, Color, double)>{
          'textPrimary/bg': (c.textPrimary, c.bg, 4.5),
          'textPrimary/surface': (c.textPrimary, c.surface, 4.5),
          'textPrimary/reader': (c.textPrimary, c.surfaceReader, 4.5),
          'textSecondary/surface': (c.textSecondary, c.surface, 4.5),
          'textSecondary/reader': (c.textSecondary, c.surfaceReader, 4.5),
          'textTertiary/surface': (c.textTertiary, c.surface, 4.5),
          'textTertiary/bg': (c.textTertiary, c.bg, 4.5),
          'primary/surface': (c.primary, c.surface, 4.5),
          'primary/bg': (c.primary, c.bg, 4.5),
          'onPrimary/primary': (c.onPrimary, c.primary, 4.5),
          'onPrimaryContainer/primaryContainer': (c.onPrimaryContainer, c.primaryContainer, 4.5),
          'secondary/surface': (c.secondary, c.surface, 4.5),
          'highlightText/surface': (c.highlightText, c.surface, 4.5),
          'success/surface': (c.success, c.surface, 4.5),
          'warning/surface': (c.warning, c.surface, 4.5),
          'error/surface': (c.error, c.surface, 4.5),
          'onSurfaceBrand/surfaceBrand': (c.onSurfaceBrand, c.surfaceBrand, 4.5),
          'navSelected/navIndicator': (c.navSelected, c.navIndicator, 4.5),
          'navUnselected/navSurface': (c.navUnselected, c.navSurface, 4.5),
          'outline/surface (non-text)': (c.outline, c.surface, 3),
          'textPrimary/warningContainer': (c.textPrimary, c.warningContainer, 4.5),
        };
        pairs.forEach((pair, v) {
          final ratio = contrast(v.$1, v.$2);
          expect(ratio, greaterThanOrEqualTo(v.$3), reason: '$pair is ${ratio.toStringAsFixed(2)}');
        });
      });
    }
  });
}
