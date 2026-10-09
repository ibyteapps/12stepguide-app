import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reminder settings. Completed in P5.
class RemindersController extends Notifier<int> {
  @override
  int build() => 0;

  /// Onboarding's "Turn on reminders": asks for permission, then turns the hourly reminder on.
  Future<bool> turnOnHourlyFromOnboarding() async => false;
}

final remindersProvider = NotifierProvider<RemindersController, int>(RemindersController.new);
