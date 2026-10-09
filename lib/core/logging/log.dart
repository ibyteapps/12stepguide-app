import 'package:flutter/foundation.dart';

/// Where log lines go besides the debug console. Crashlytics registers one in production.
abstract interface class LogSink {
  void breadcrumb(String message);
  void nonFatal(Object error, StackTrace? stack, {String? reason});
}

/// The app's logger (FLUTTER_ARCHITECTURE.md §12).
///
/// Debug builds print to the console. Warnings and errors also go to the registered [LogSink]
/// (Crashlytics breadcrumbs and non-fatals). Everything is redacted first: the app never sends
/// an email address or a date that could be a sobriety date or birthday.
abstract final class Log {
  static LogSink? sink;

  static void d(String message) {
    if (kDebugMode) debugPrint('[d] ${redact(message)}');
  }

  static void i(String message) {
    if (kDebugMode) debugPrint('[i] ${redact(message)}');
  }

  static void w(String message) {
    final m = redact(message);
    if (kDebugMode) debugPrint('[w] $m');
    sink?.breadcrumb(m);
  }

  static void e(String message, [Object? error, StackTrace? stack]) {
    final m = redact(message);
    if (kDebugMode) debugPrint('[e] $m ${error == null ? '' : redact('$error')}');
    if (error != null) {
      sink?.nonFatal(error, stack, reason: m);
    } else {
      sink?.breadcrumb(m);
    }
  }

  static final _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  static final _isoDate = RegExp(r'\b\d{4}-\d{2}-\d{2}\b');
  static final _dmyDate = RegExp(r'\b\d{1,2}[/.]\d{1,2}[/.]\d{2,4}\b');

  /// Removes anything that looks like personal data.
  static String redact(String input) => input
      .replaceAll(_email, '<email>')
      .replaceAll(_isoDate, '<date>')
      .replaceAll(_dmyDate, '<date>');
}
