class TeacherClassModel {
  final String teacherId;
  final String teacherName;
  final String stream;
  final List<String> subjects;
  final String? profileImageUrl;
  final bool paymentRequired;
  final double monthlyFee;
  final bool gatewayEnabled;
  final String gatewayLink;
  final double gatewayAmount;

  TeacherClassModel({
    required this.teacherId,
    required this.teacherName,
    required this.stream,
    required this.subjects,
    this.profileImageUrl,
    this.paymentRequired = false,
    this.monthlyFee = 0.0,
    this.gatewayEnabled = false,
    this.gatewayLink = '',
    this.gatewayAmount = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'name': teacherName,
      'stream': stream,
      'subjects': subjects,
      'profileImageUrl': profileImageUrl,
      'paymentRequired': paymentRequired,
      'monthlyFee': monthlyFee,
      'paymentGateway': {
        'enabled': gatewayEnabled,
        'link': gatewayLink,
        'amount': gatewayAmount,
      },
    };
  }

  factory TeacherClassModel.fromMap(String id, Map<String, dynamic> map) {
    final gateway = map['paymentGateway'] as Map<String, dynamic>? ?? {};
    return TeacherClassModel(
      teacherId: id,
      teacherName: map['name'] ?? 'Unknown Teacher',
      stream: map['stream'] ?? '',
      subjects: List<String>.from(map['subjects'] ?? []),
      profileImageUrl: map['profileImageUrl'] as String?,
      paymentRequired: map['paymentRequired'] ?? false,
      monthlyFee: (map['monthlyFee'] as num?)?.toDouble() ?? 0.0,
      gatewayEnabled: gateway['enabled'] ?? false,
      gatewayLink: gateway['link'] ?? '',
      gatewayAmount: (gateway['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
