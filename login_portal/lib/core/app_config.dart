import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const String appName = 'Eduwide';
  static const String appVersion = '1.0.0+1';

  // Cloudinary Configuration (loaded securely from .env)
  static String get cloudinaryCloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME']?.trim() ?? '';

  static String get cloudinaryUploadPreset =>
      dotenv.env['CLOUDINARY_UPLOAD_PRESET']?.trim() ?? '';

  static String get cloudinaryUploadApiUrl =>
      'https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload';

  // Default Images (loaded securely from .env with dynamic fallback)
  static String get defaultProfileImageUrl =>
      dotenv.env['CLOUDINARY_DEFAULT_PROFILE_URL']?.trim() ??
      (cloudinaryCloudName.isNotEmpty
          ? 'https://res.cloudinary.com/$cloudinaryCloudName/image/upload/v1782734371/default_il19eg.png'
          : '');

  static String get defaultAdminProfileUrl => defaultProfileImageUrl;
  static String get defaultTeacherProfileUrl => defaultProfileImageUrl;
  static String get defaultStudentProfileUrl => defaultProfileImageUrl;

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String countersCollection = 'counters';
  static const String zoomMeetingsCollection = 'zoomMeetings';
  static const String enrollmentsCollection = 'enrollments';
  static const String paymentsCollection = 'payments';
}
