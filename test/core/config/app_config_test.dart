import 'package:flutter_test/flutter_test.dart';
import 'package:twelve_step_guide/core/config/app_config.dart';
import 'package:twelve_step_guide/core/config/app_env.dart';

void main() {
  group('AppConfig.resolve', () {
    test('no flavour and no config is dev (unit tests, bare IDE run)', () {
      expect(AppConfig.resolve(flavor: null, envDefine: '').env, AppEnv.dev);
      expect(AppConfig.resolve(flavor: '', envDefine: '').env, AppEnv.dev);
    });

    test('matching flavour and config', () {
      for (final env in AppEnv.values) {
        expect(
          AppConfig.resolve(flavor: env.name, envDefine: env.name).env,
          env,
        );
      }
    });

    test('dev flavour without a config file is allowed', () {
      expect(AppConfig.resolve(flavor: 'dev', envDefine: '').env, AppEnv.dev);
    });

    test('staging or prod without a config file is refused', () {
      for (final flavor in ['staging', 'prod']) {
        expect(
          () => AppConfig.resolve(flavor: flavor, envDefine: ''),
          throwsA(isA<ConfigException>()),
          reason: flavor,
        );
      }
    });

    test('flavour and config naming different environments is refused', () {
      expect(
        () => AppConfig.resolve(flavor: 'prod', envDefine: 'dev'),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('--flavor prod --dart-define-from-file=config/prod.json'),
          ),
        ),
      );
      expect(
        () => AppConfig.resolve(flavor: 'dev', envDefine: 'staging'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('unknown names are refused, not treated as dev', () {
      expect(
        () => AppConfig.resolve(flavor: 'production', envDefine: ''),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => AppConfig.resolve(flavor: null, envDefine: 'Prod'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('config without a flavour (Xcode run) follows the config', () {
      expect(
        AppConfig.resolve(flavor: null, envDefine: 'staging').env,
        AppEnv.staging,
      );
    });
  });

  test('only prod serves live ads', () {
    expect(AppEnv.dev.usesTestAds, isTrue);
    expect(AppEnv.staging.usesTestAds, isTrue);
    expect(AppEnv.prod.usesTestAds, isFalse);
  });
}
