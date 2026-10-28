import '../../core/app_config.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'class_enrollment_screen.dart';
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

  String get _defaultProfileImageUrl => AppConfig.defaultProfileImageUrl;

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

  // ---- Modern Header ----
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
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, color: Colors.grey.shade400, size: 20),
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

  // ---- Payment Settings Dialog ----
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.settings, color: AppColors.primaryPurple, size: 22),
                SizedBox(width: 8),
                Text('Payment & Gateway'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: const Text('Require Payment', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: paymentRequired,
                      activeColor: AppColors.primaryPurple,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setStateDialog(() => paymentRequired = val),
                    ),
                  ),
                  if (paymentRequired) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: feeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Monthly Fee (LKR)',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      title: const Text('Payment Gateway', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: gatewayEnabled,
                      activeColor: AppColors.primaryPurple,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setStateDialog(() => gatewayEnabled = val),
                    ),
                  ),
                  if (gatewayEnabled) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: linkController,
                      decoration: InputDecoration(
                        labelText: 'Payment Link (URL)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Gateway Amount (LKR)',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
                        ),
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
                        content: Text('Settings saved!'),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---- MODERN COMPACT TEACHER CARD ----
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
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
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar + Info + Payment Icons
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: profileImage.isEmpty
                            ? const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                              )
                            : null,
                        image: profileImage.isNotEmpty
                            ? DecorationImage(image: NetworkImage(profileImage), fit: BoxFit.cover)
                            : null,
                        border: Border.all(color: Colors.grey.shade200, width: 2),
                      ),
                      child: profileImage.isEmpty
                          ? Center(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),

                    // Name & Email
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Payment Status Icons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Payment lock icon
                        GestureDetector(
                          onTap: () => _showPaymentSettingsDialog(context, teacherId, teacher),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: paymentRequired
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              paymentRequired ? Icons.lock : Icons.lock_open,
                              size: 16,
                              color: paymentRequired ? Colors.orange : Colors.green,
                            ),
                          ),
                        ),
                        if (gatewayEnabled) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.credit_card, size: 16, color: Colors.blue),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.chevron_right, size: 16, color: AppColors.primaryPurple),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Chips Row
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    // Stream Chip
                    if (stream.isNotEmpty)
                      _buildChip(
                        icon: Icons.school_rounded,
                        label: stream,
                        bgColor: Colors.purple.shade50,
                        textColor: Colors.purple.shade700,
                      ),
                    // Subjects (max 3)
                    ...subjects.take(3).map((s) => _buildChip(
                          icon: Icons.book_rounded,
                          label: s,
                          bgColor: Colors.blue.shade50,
                          textColor: Colors.blue.shade700,
                        )),
                    if (subjects.length > 3)
                      _buildChip(
                        icon: Icons.more_horiz,
                        label: '+${subjects.length - 3}',
                        bgColor: Colors.grey.shade100,
                        textColor: Colors.grey.shade600,
                      ),
                  ],
                ),

                // Payment Info Chips (if applicable)
                if (paymentRequired || gatewayEnabled)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (paymentRequired)
                          _buildChip(
                            icon: Icons.currency_rupee,
                            label: 'Rs. ${monthlyFee.toStringAsFixed(0)}/mo',
                            bgColor: Colors.red.shade50,
                            textColor: Colors.red.shade700,
                          ),
                        if (gatewayEnabled && gatewayAmount > 0)
                          _buildChip(
                            icon: Icons.credit_card,
                            label: 'Gateway: Rs. ${gatewayAmount.toStringAsFixed(0)}',
                            bgColor: Colors.teal.shade50,
                            textColor: Colors.teal.shade700,
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),

                // Bottom Row: Student Count + Manage Button
                Row(
                  children: [
                    // Student Count
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
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '$count Students',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    // Manage Button
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
                      icon: const Icon(Icons.people_alt, size: 14),
                      label: const Text('Manage', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Compact Chip ----
  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
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
                          child: CircularProgressIndicator(color: AppColors.primaryPurple),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
                              const SizedBox(height: 12),
                              Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.grey.shade600)),
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
                              Text('No Classes Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                              const SizedBox(height: 6),
                              Text('No teachers registered yet', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
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
                              Text('No matching teachers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: teachers.length,
                        itemBuilder: (context, index) {
                          final teacher = teachers[index].data() as Map<String, dynamic>;
                          final teacherId = teachers[index].id;
                          return _buildTeacherCard(teacher, teacherId, context);
                        },
                      );
                    },
                  ),
                ),
                // Fixed Footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.lightBackground,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200, width: 0.5),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Developed By Devlk',
                      style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}