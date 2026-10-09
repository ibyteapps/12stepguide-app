import 'app/bootstrap.dart';

/// One entry point for every environment. The environment comes from the build flavour and
/// `config/<env>.json`, checked against each other in `AppConfig.resolve`.
Future<void> main() => bootstrap();
