/// Route paths (FLUTTER_ARCHITECTURE.md §6).
abstract final class Routes {
  // Tabs (StatefulShellRoute branches, in tab order)
  static const steps = '/steps';
  static const readings = '/readings';
  static const bigBook = '/big-book';
  static const audio = '/audio';
  static const tabs = [steps, readings, bigBook, audio];

  // Over the shell
  static const onboarding = '/onboarding';
  static const welcomeBack = '/welcome-back';
  static const recoveryDate = '/recovery-date';
  static const player = '/player';
  static const premium = '/premium';
  static const paywall = '/paywall';
  static const reminders = '/reminders';
  static const appearance = '/appearance';
  static const downloads = '/downloads';
  static const otherApps = '/other-apps';
  static const about = '/about';
  static const quote = '/quote';

  /// Document ids contain "/", so they travel as a query parameter.
  static String read(String docId) => '/read?id=${Uri.encodeQueryComponent(docId)}';
  static const readPath = '/read';

  static String album(int id) => '$audio/album/$id';
}
