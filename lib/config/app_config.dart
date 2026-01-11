/// App-wide constants and configuration values
class AppConfig {
  AppConfig._();

  // API Endpoints
  static const String updateLastLoginUrl =
      'https://us-central1-truck-dispatch-system.cloudfunctions.net/updateLastLoginHttp';

  // Timing Constants
  static const int splashScreenDelayMs = 1500;

  // Location Service Constants
  static const int locationUpdateIntervalSeconds = 10;
  static const int locationIdleTimeoutSeconds = 300;
  static const int locationBufferSize = 6;
  static const double locationMinMoveDistanceMeters = 10.0;
  static const double locationMinAccuracyMeters = 25.0;
  static const double locationHistoryMinDistanceMeters = 25.0;
  static const int locationHistoryRetentionHours = 24;
  static const int locationHistoryMaxPoints = 500;
  static const int locationHistoryCleanupIntervalHours = 24;

  // UI Constants
  static const int desktopBreakpoint = 900;
  static const int tabletBreakpoint = 600;

  // Colors
  static const int primaryColorValue = 0xFF1E3A5F;
  static const int backgroundColorValue = 0xFFF8FAFC;
}
