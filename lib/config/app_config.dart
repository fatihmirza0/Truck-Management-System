/// App-wide constants and configuration values
class AppConfig {
  AppConfig._();

  // API Configuration
  static const String apiBaseUrl = 'https://us-central1-truck-dispatch-system.cloudfunctions.net';

  // API Endpoints
  static const String updateLastLoginUrl = '$apiBaseUrl/updateLastLoginHttp';
  static const String getManagerDashboardUrl = '$apiBaseUrl/getManagerDashboardData';
  static const String getManagerLogsUrl = '$apiBaseUrl/getManagerLogs';
  static const String updateCompanyGoalsUrl = '$apiBaseUrl/updateCompanyGoals';
  static const String createJobUrl = '$apiBaseUrl/createJobHttp';
  static const String createDriverUrl = '$apiBaseUrl/createDriverHttp';
  static const String createUserUrl = '$apiBaseUrl/createUserHttp';
  static const String updateUserUrl = '$apiBaseUrl/updateUserHttp';
  static const String softDeleteUserUrl = '$apiBaseUrl/softDeleteUserHttp';
  static const String jobActionUrl = '$apiBaseUrl/jobActionHttp';

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
