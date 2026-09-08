enum Environment { development, production }

class AppEnvironment {
  static const name = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static Environment get current {
    return name == 'production'
        ? Environment.production
        : Environment.development;
  }

  const AppEnvironment._();
}
