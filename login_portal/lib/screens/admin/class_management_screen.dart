import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'class_enrollment_screen.dart';  // ✅ Must be in the same folder
import '../../core/app_colors.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  String _adminName = 'Admin';
  String _profileImageUrl = '';
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  static const String _defaultProfileImageUrl =
      'https://res.cloudinary.com/dqeptzlsb/image/upload/v1782734371/default_il19eg.png';

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
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

  // ---- Modern Header (matches Admin Dashboard) ----
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
            'Class Management',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage all teacher classes and enrollments',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Search Bar ----
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by teacher name or stream...',
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade400),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ---- Combined Payment Settings Dialog (Payment + Gateway) ----
  Future<void> _showPaymentSettingsDialog(
      BuildContext context, String teacherId, Map<String, dynamic> teacher) async {
    bool paymentRequired = teacher['paymentRequired'] ?? false;
    double fee = teacher['monthlyFee'] ?? 0.0;
    bool gatewayEnabled = teacher['paymentGateway']?['enabled'] ?? false;
    String gatewayLink = teacher['paymentGateway']?['link'] ?? '';
    double gatewayAmount = teacher['paymentGateway']?['amount'] ?? 0.0;

    final TextEditingController feeController = TextEditingController(text: fee.toString());
    final TextEditingController linkController = TextEditingController(text: gatewayLink);
    final TextEditingController amountController = TextEditingController(text: gatewayAmount.toString());

    return showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: const Text('Payment & Gateway Settings'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Payment Required
                  SwitchListTile(
                    title: const Text('Require Payment'),
                    value: paymentRequired,
                    onChanged: (val) => setStateDialog(() => paymentRequired = val),
                  ),
                  if (paymentRequired)
                    TextField(
                      controller: feeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Fee (LKR)',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const Divider(height: 30),
                  // Payment Gateway
                  SwitchListTile(
                    title: const Text('Enable Payment Gateway'),
                    value: gatewayEnabled,
                    onChanged: (val) => setStateDialog(() => gatewayEnabled = val),
                  ),
                  if (gatewayEnabled) ...[
                    TextField(
                      controller: linkController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Link (URL)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Gateway Amount (LKR)',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(),
                      ),
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
                  final newFee = double.tryParse(feeController.text) ?? 0.0;
                  final newGatewayAmount = double.tryParse(amountController.text) ?? 0.0;
                  final updateData = {
                    'paymentRequired': paymentRequired,
                    'monthlyFee': paymentRequired ? newFee : 0.0,
                    'paymentGateway': {
                      'enabled': gatewayEnabled,
                      'link': gatewayEnabled ? linkController.text.trim() : '',
                      'amount': gatewayEnabled ? newGatewayAmount : 0.0,
                    },
                  };
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(teacherId)
                        .update(updateData);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment and gateway settings saved!'),
                        backgroundColor: AppColors.primaryPurple,
                      ),
                    );
                    setState(() {});
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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

  // ---- Teacher Card (Modern) ----
  Widget _buildTeacherCard(
    Map<String, dynamic> teacher,
    String teacherId,
    BuildContext context,
  ) {
    final name = teacher['name'] ?? 'Unknown';
    final email = teacher['email'] ?? '';
    final stream = teacher['stream'] ?? '';
    final subjects = List<String>.from(teacher['subjects'] ?? []);
    final profileImage = teacher['profileImageUrl'] ?? '';
    final paymentRequired = teacher['paymentRequired'] ?? false;
    final monthlyFee = teacher['monthlyFee'] ?? 0.0;
    final gatewayEnabled = teacher['paymentGateway']?['enabled'] ?? false;
    final gatewayAmount = teacher['paymentGateway']?['amount'] ?? 0.0;

    // Determine main payment status icon
    IconData paymentIcon;
    Color paymentColor;
    if (paymentRequired) {
      paymentIcon = Icons.lock;
      paymentColor = Colors.orange;
    } else {
      paymentIcon = Icons.lock_open;
      paymentColor = Colors.green;
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade100, width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage: profileImage.isNotEmpty
                      ? NetworkImage(profileImage)
                      : null,
                  backgroundColor: Colors.grey.shade200,
                  child: profileImage.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Payment status icon (click to open settings)
                    IconButton(
                      icon: Icon(paymentIcon, color: paymentColor, size: 20),
                      tooltip: paymentRequired ? 'Payment Required' : 'Free',
                      onPressed: () => _showPaymentSettingsDialog(context, teacherId, teacher),
                    ),
                    // Gateway indicator
                    if (gatewayEnabled)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          '💳',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (stream.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.place_outlined, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          stream,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ...subjects.map(
                  (s) => Container(
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
                          s,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (paymentRequired)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.currency_rupee, size: 14, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Rs. ${monthlyFee.toStringAsFixed(2)}/month',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (gatewayEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.credit_card, size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Gateway: Rs. ${gatewayAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('enrollments')
                      .where('classId', isEqualTo: teacherId)
                      .get(),
                  builder: (context, snapshot) {
                    int count = 0;
                    if (snapshot.hasData) {
                      count = snapshot.data!.docs.length;
                    }
                    return Row(
                      children: [
                        Icon(Icons.people_outline, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          '$count enrolled',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClassEnrollmentScreen(
                          teacherId: teacherId,
                          teacherName: name,
                          teacherEmail: email,
                          stream: stream,
                          subjects: subjects,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.people_alt, size: 18),
                  label: const Text('Manage Students'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'teacher')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(
                              color: AppColors.primaryPurple,
                            ),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'Error: ${snapshot.error}',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        );
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.class_outlined, size: 80, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'No Classes Found',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No teachers have been registered yet.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      var teachers = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? '').toLowerCase();
                        final stream = (data['stream'] ?? '').toLowerCase();
                        final query = _searchQuery.toLowerCase();
                        return name.contains(query) || stream.contains(query);
                      }).toList();

                      if (teachers.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 60, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'No matching classes',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try adjusting your search',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount: teachers.length,
                          itemBuilder: (context, index) {
                            final teacher = teachers[index].data() as Map<String, dynamic>;
                            final teacherId = teachers[index].id;
                            return _buildTeacherCard(teacher, teacherId, context);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}