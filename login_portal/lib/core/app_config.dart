class AppConfig {
  static const String appName = 'Eduwide';
  static const String appVersion = '1.0.0+1';

  // Cloudinary Configuration
  static const String cloudinaryCloudName = 'dqeptzlsb';
  static const String cloudinaryUploadPreset = 'flutter_mediq_upload';
  static const String cloudinaryUploadApiUrl =
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload';

  // Default Images
  static const String defaultProfileImageUrl =
      'https://res.cloudinary.com/dqeptzlsb/image/upload/v1782734371/default_il19eg.png';
  static const String defaultAdminProfileUrl =
      'https://res.cloudinary.com/dqeptzlsb/image/upload/v1782734371/default_il19eg.png';
  static const String defaultTeacherProfileUrl =
      'https://res.cloudinary.com/dqeptzlsb/image/upload/v1782734371/default_il19eg.png';
  static const String defaultStudentProfileUrl =
      'https://res.cloudinary.com/dqeptzlsb/image/upload/v1782734371/default_il19eg.png';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String countersCollection = 'counters';
  static const String zoomMeetingsCollection = 'zoomMeetings';
  static const String enrollmentsCollection = 'enrollments';
  static const String paymentsCollection = 'payments';
}
