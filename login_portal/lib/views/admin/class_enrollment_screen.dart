import '../../core/app_config.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/app_colors.dart';

class ClassEnrollmentScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String teacherEmail;
  final String stream;
  final List<String> subjects;

  const ClassEnrollmentScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.teacherEmail,
    required this.stream,
    required this.subjects,
  });

  @override
  State<ClassEnrollmentScreen> createState() => _ClassEnrollmentScreenState();
}

class _ClassEnrollmentScreenState extends State<ClassEnrollmentScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _selectedStudentId;
  Map<String, dynamic>? _selectedStudentData;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _enrolledSearchQuery = '';
  final TextEditingController _enrolledSearchController = TextEditingController();
  List<Map<String, dynamic>> _availableStudents = [];
  bool _isLoadingStudents = false;

  String _adminName = 'Admin';
  String _profileImageUrl = '';
  bool _isLoading = true;

  Map<String, dynamic> _paymentGateway = {
    'enabled': false,
    'link': '',
    'amount': 0.0,
  };
  bool _isLoadingGateway = true;

  String get _defaultProfileImageUrl => AppConfig.defaultProfileImageUrl;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _enrolledSearchController.addListener(() {
      setState(() {
        _enrolledSearchQuery = _enrolledSearchController.text.toLowerCase().trim();
      });
    });
    _loadAdminProfile();
    _loadPaymentGateway();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _enrolledSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminProfile() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _adminName = data['name'] ?? 'Admin';
            _profileImageUrl = data['profileImageUrl'] ?? _defaultProfileImageUrl;
            _isLoading = false;
          });
        }
      } catch (_) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPaymentGateway() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.teacherId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _paymentGateway = data['paymentGateway'] ?? _paymentGateway;
          _isLoadingGateway = false;
        });
      }
    } catch (_) {
      setState(() => _isLoadingGateway = false);
    }
  }

  Widget _buildHeader() {
    final String imageUrl =
        _profileImageUrl.isNotEmpty ? _profileImageUrl : _defaultProfileImageUrl;

    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _adminName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Logged in as: Admin',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(imageUrl),
                backgroundColor: Colors.grey.shade200,
                onBackgroundImageError: (_, __) {},
                child: _profileImageUrl.isEmpty
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Class Enrollment',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.teacherName,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.teacherName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.teacherEmail,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  'Stream: ${widget.stream}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.subjects.map((subject) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.book_outlined, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      subject,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _paymentGateway['enabled'] == true
                        ? Icons.credit_card
                        : Icons.credit_card_off,
                    color: _paymentGateway['enabled'] == true
                        ? Colors.green
                        : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _paymentGateway['enabled'] == true
                        ? 'Payment Gateway: Enabled'
                        : 'Payment Gateway: Disabled',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _paymentGateway['enabled'] == true
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _managePaymentGateway,
                icon: const Icon(Icons.settings, size: 18),
                label: const Text('Manage'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryPurple,
                ),
              ),
            ],
          ),
          if (_paymentGateway['enabled'] == true) ...[
            const SizedBox(height: 4),
            Text(
              'Amount: LKR ${_paymentGateway['amount']?.toStringAsFixed(2) ?? '0.00'}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            if (_paymentGateway['link'] != null && _paymentGateway['link'].isNotEmpty)
              Text(
                'Link: ${_paymentGateway['link']}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _managePaymentGateway() async {
    bool enabled = _paymentGateway['enabled'] ?? false;
    String link = _paymentGateway['link'] ?? '';
    String amountStr = (_paymentGateway['amount'] ?? 0.0).toString();

    return showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: const Text('Manage Payment Gateway'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Enable Payment Gateway'),
                    value: enabled,
                    onChanged: (val) => setStateDialog(() => enabled = val),
                  ),
                  if (enabled) ...[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Payment Link (URL)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => link = val,
                      controller: TextEditingController(text: link),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Amount (LKR)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => amountStr = val,
                      controller: TextEditingController(text: amountStr),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(amountStr) ?? 0.0;
                  final gatewayData = {
                    'enabled': enabled,
                    'link': enabled ? link.trim() : '',
                    'amount': enabled ? amount : 0.0,
                  };
                  try {
                    await _firestore
                        .collection('users')
                        .doc(widget.teacherId)
                        .update({'paymentGateway': gatewayData});
                    setState(() {
                      _paymentGateway = gatewayData;
                    });
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment gateway settings saved.'),
                        backgroundColor: AppColors.primaryPurple,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddStudentDialog() async {
    setState(() => _isLoadingStudents = true);
    _selectedStudentId = null;
    _selectedStudentData = null;

    final allStudents = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'user')
        .get();

    final enrolledDocs = await _firestore
        .collection('enrollments')
        .where('classId', isEqualTo: widget.teacherId)
        .get();

    final enrolledStudentIds =
        enrolledDocs.docs.map((doc) => doc['studentId'] as String).toSet();

    _availableStudents = allStudents.docs
        .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'uid': doc.id,
            'name': data['name'] ?? 'Unknown',
            'email': data['email'] ?? '',
            'profileImageUrl': data['profileImageUrl'] ?? '',
            'studentId': data['studentId'] ?? '',
          };
        })
        .where((s) => !enrolledStudentIds.contains(s['uid']))
        .toList();

    setState(() => _isLoadingStudents = false);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          final filtered = _availableStudents.where((s) {
            final name = s['name'].toLowerCase();
            final email = s['email'].toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();

          return AlertDialog(
            title: const Text('Add Student to Class'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search students...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _isLoadingStudents
                        ? const Center(child: CircularProgressIndicator())
                        : filtered.isEmpty
                            ? const Center(child: Text('No students available'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final student = filtered[index];
                                  final isSelected = _selectedStudentId == student['uid'];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 20,
                                      backgroundImage: student['profileImageUrl'].isNotEmpty
                                          ? NetworkImage(student['profileImageUrl'])
                                          : null,
                                      child: student['profileImageUrl'].isEmpty
                                          ? Text(student['name'][0].toUpperCase())
                                          : null,
                                    ),
                                    title: Text(student['name']),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(student['email']),
                                        if (student['studentId'].isNotEmpty)
                                          Text(
                                            'ID: ${student['studentId']}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle, color: Colors.green)
                                        : null,
                                    onTap: () {
                                      setStateDialog(() {
                                        _selectedStudentId = student['uid'];
                                        _selectedStudentData = student;
                                      });
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _selectedStudentId == null
                    ? null
                    : () {
                        _addStudentToClass(_selectedStudentData!);
                        Navigator.of(ctx).pop();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addStudentToClass(Map<String, dynamic> student) async {
    try {
      final now = DateTime.now();
      final isFreePeriod = now.day <= 9;
      final expiry = isFreePeriod
          ? DateTime(now.year, now.month, 9, 23, 59, 59)
          : now;
      final trialEnd = expiry;

      await _firestore.collection('enrollments').add({
        'studentId': student['uid'],
        'classId': widget.teacherId,
        'assignedDate': Timestamp.fromDate(now),
        'expiryDate': Timestamp.fromDate(expiry),
        'freeAccess': isFreePeriod,
        'paymentApproved': false,
        'trialStart': Timestamp.fromDate(now),
        'trialEnd': Timestamp.fromDate(trialEnd),
        'status': isFreePeriod ? 'trial' : 'expired',
        'currentMonth': '${now.year}-${now.month.toString().padLeft(2, '0')}',
        'paymentStatus': 'trial',
        'transactionId': '',
        'createdAt': FieldValue.serverTimestamp(),
        'studentName': student['name'],
        'studentEmail': student['email'],
        'studentProfileImageUrl': student['profileImageUrl'],
        'studentCustomId': student['studentId'] ?? '',
        'paymentMonth': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student added!'),
          backgroundColor: AppColors.primaryPurple,
        ),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeStudent(String enrollmentId, String studentName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text('Remove $studentName from this class?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('enrollments').doc(enrollmentId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student removed from class.'),
            backgroundColor: AppColors.primaryPurple,
          ),
        );
        setState(() {});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Method to mark payment for current month
  Future<void> _markPayment(String enrollmentId) async {
    try {
      final enrollmentDoc = await _firestore.collection('enrollments').doc(enrollmentId).get();
      if (!enrollmentDoc.exists) return;
      
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      
      // Get the last day of the current month
      final lastDay = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      final expiry = Timestamp.fromDate(lastDay);

      // Update enrollment with payment details
      await _firestore.collection('enrollments').doc(enrollmentId).update({
        'paymentApproved': true,
        'freeAccess': false,
        'expiryDate': expiry,
        'status': 'active',
        'currentMonth': month,
        'paymentStatus': 'paid',
        'transactionId': 'manual_mark_${DateTime.now().millisecondsSinceEpoch}',
        'lastPaymentDate': Timestamp.fromDate(now),
        'paymentMonth': month,
      });

      // Add payment record
      await _firestore.collection('payments').add({
        'enrollmentId': enrollmentId,
        'studentId': enrollmentDoc['studentId'],
        'classId': enrollmentDoc['classId'],
        'month': month,
        'amount': _paymentGateway['amount'] ?? 0.0,
        'paymentDate': Timestamp.fromDate(now),
        'status': 'paid',
        'transactionId': 'manual_mark_${DateTime.now().millisecondsSinceEpoch}',
        'approvedBy': _auth.currentUser!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment marked successfully! Student has access until end of month.'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _getAccessStatus(Map<String, dynamic> enrollment) {
    final now = DateTime.now();
    final today = now.day;
    final currentMonthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    
    // Check if there's a payment record for current month
    final paymentMonth = enrollment['paymentMonth'];
    final isPaidThisMonth = paymentMonth == currentMonthStr;

    // If paid for this month, show as paid
    if (isPaidThisMonth) {
      final expiry = (enrollment['expiryDate'] as Timestamp).toDate();
      final daysLeft = expiry.difference(now).inDays;
      if (daysLeft > 0) {
        return '✅ Paid (${daysLeft}d left)';
      } else {
        return '⏳ Payment Expired – Renew';
      }
    }

    // Free period (1st to 9th)
    if (today <= 9) {
      final day9 = DateTime(now.year, now.month, 9, 23, 59, 59);
      final daysLeft = day9.difference(now).inDays + 1;
      return '🆓 Free (${daysLeft}d left)';
    }

    // Not paid for this month and not in free period
    return '⛔ Payment Required';
  }

  Future<void> _showPaymentHistory(String enrollmentId) async {
    try {
      final paymentsSnapshot = await _firestore
          .collection('payments')
          .where('enrollmentId', isEqualTo: enrollmentId)
          .get();

      var payments = paymentsSnapshot.docs.map((d) => d.data()).toList();

      payments.sort((a, b) {
        final aDate = (a['paymentDate'] as Timestamp).toDate();
        final bDate = (b['paymentDate'] as Timestamp).toDate();
        return bDate.compareTo(aDate);
      });

      if (payments.isEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Payment History'),
            content: const Text('No payment records found.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Payment History'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: payments.length,
              itemBuilder: (ctx, index) {
                final p = payments[index];
                final date = (p['paymentDate'] as Timestamp).toDate();
                return ListTile(
                  leading: Icon(
                    p['status'] == 'paid' ? Icons.check_circle : Icons.pending,
                    color: p['status'] == 'paid' ? Colors.green : Colors.orange,
                  ),
                  title: Text('Month: ${p['month']}'),
                  subtitle: Text('Amount: LKR ${p['amount']?.toStringAsFixed(2) ?? '0.00'}'),
                  trailing: Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStudentDetails(
      List<QueryDocumentSnapshot> enrollments) async {
    final List<Map<String, dynamic>> result = [];

    for (var enrollmentDoc in enrollments) {
      final enrollment = enrollmentDoc.data() as Map<String, dynamic>;
      final enrollmentId = enrollmentDoc.id;
      final studentId = enrollment['studentId'];

      if (enrollment.containsKey('studentName') && enrollment['studentName'] != null) {
        final studentData = {
          'uid': studentId,
          'name': enrollment['studentName'],
          'email': enrollment['studentEmail'] ?? '',
          'profileImageUrl': enrollment['studentProfileImageUrl'] ?? '',
          'studentId': enrollment['studentCustomId'] ?? '',
        };
        result.add({
          'enrollment': {...enrollment, 'id': enrollmentId},
          'student': studentData,
        });
      } else {
        try {
          final studentDoc = await _firestore.collection('users').doc(studentId).get();
          Map<String, dynamic> studentData;
          if (studentDoc.exists) {
            final data = studentDoc.data() as Map<String, dynamic>;
            studentData = {
              'uid': studentId,
              'name': data['name'] ?? 'Unknown',
              'email': data['email'] ?? '',
              'profileImageUrl': data['profileImageUrl'] ?? '',
              'studentId': data['studentId'] ?? '',
            };
          } else {
            studentData = {
              'uid': studentId,
              'name': '⚠️ User not found',
              'email': '',
              'profileImageUrl': '',
              'studentId': '',
            };
          }
          result.add({
            'enrollment': {...enrollment, 'id': enrollmentId},
            'student': studentData,
          });
        } catch (e) {
          result.add({
            'enrollment': {...enrollment, 'id': enrollmentId},
            'student': {
              'uid': studentId,
              'name': '⚠️ Error loading',
              'email': '',
              'profileImageUrl': '',
              'studentId': '',
            },
          });
        }
      }
    }
    return result;
  }

  Widget _buildEnrollmentList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('enrollments')
          .where('classId', isEqualTo: widget.teacherId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple));
        }

        final enrollments = snapshot.data!.docs;
        if (enrollments.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No students enrolled yet.',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey(enrollments.length),
          future: _fetchStudentDetails(enrollments),
          builder: (context, studentSnapshot) {
            if (studentSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (studentSnapshot.hasError) {
              return Center(child: Text('Error: ${studentSnapshot.error}'));
            }

            final allData = studentSnapshot.data ?? [];
            final filteredData = allData.where((item) {
              if (_enrolledSearchQuery.isEmpty) return true;
              final student = item['student'];
              final name = (student['name'] ?? '').toLowerCase();
              final email = (student['email'] ?? '').toLowerCase();
              final id = (student['studentId'] ?? '').toLowerCase();
              return name.contains(_enrolledSearchQuery) ||
                  email.contains(_enrolledSearchQuery) ||
                  id.contains(_enrolledSearchQuery);
            }).toList();

            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _enrolledSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search enrolled students...',
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filteredData.length,
                    itemBuilder: (context, index) {
                      final item = filteredData[index];
                      final enrollment = item['enrollment'];
                      final student = item['student'];
                      final statusText = _getAccessStatus(enrollment);

                      final now = DateTime.now();
                      final today = now.day;
                      final currentMonthStr =
                          '${now.year}-${now.month.toString().padLeft(2, '0')}';
                      final paymentMonth = enrollment['paymentMonth'];
                      final isPaidThisMonth = paymentMonth == currentMonthStr;
                      
                      // Show Mark Payment button if not paid for this month
                      final showMarkPayment = !isPaidThisMonth;

                      final isPaid = statusText.startsWith('✅');
                      final isFree = statusText.startsWith('🆓');

                      return GestureDetector(
                        onTap: () => _showPaymentHistory(enrollment['id']),
                        child: Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundImage: student['profileImageUrl']
                                              .isNotEmpty
                                          ? NetworkImage(student['profileImageUrl'])
                                          : null,
                                      child: student['profileImageUrl'].isEmpty
                                          ? Text(student['name'][0].toUpperCase())
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student['name'],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          Text(
                                            student['email'],
                                            style: TextStyle(
                                                fontSize: 13, color: Colors.grey.shade600),
                                          ),
                                          if (student['studentId'] != null &&
                                              student['studentId'].isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.badge_outlined,
                                                      size: 12,
                                                      color: AppColors.primaryPurple),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'ID: ${student['studentId']}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                      color: AppColors.primaryPurple,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isPaid
                                            ? Colors.green.shade50
                                            : isFree
                                                ? Colors.orange.shade50
                                                : Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isPaid
                                              ? Colors.green.shade200
                                              : isFree
                                                  ? Colors.orange.shade200
                                                  : Colors.red.shade200,
                                        ),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: isPaid
                                              ? Colors.green.shade700
                                              : isFree
                                                  ? Colors.orange.shade700
                                                  : Colors.red.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Mark Payment button - shows when not paid for current month
                                    if (showMarkPayment)
                                      ElevatedButton(
                                        onPressed: () => _markPayment(enrollment['id']),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          textStyle: const TextStyle(fontSize: 12),
                                        ),
                                        child: const Text('Mark Payment'),
                                      ),
                                    // Show check icon when paid for current month
                                    if (isPaidThisMonth)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8),
                                        child: Icon(Icons.check_circle, color: Colors.green, size: 24),
                                      ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red, size: 20),
                                      onPressed: () =>
                                          _removeStudent(enrollment['id'], student['name']),
                                      tooltip: 'Remove student',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap card to view payment history',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: _isLoading || _isLoadingGateway
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildClassInfoCard(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Enrolled Students',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _showAddStudentDialog,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Student'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryPurple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _buildEnrollmentList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}