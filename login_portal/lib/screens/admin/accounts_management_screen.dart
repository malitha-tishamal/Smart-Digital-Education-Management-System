import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/app_colors.dart';
import 'admin_drawer.dart';

class AccountsManagementScreen extends StatefulWidget {
  const AccountsManagementScreen({super.key});

  @override
  State<AccountsManagementScreen> createState() => _AccountsManagementScreenState();
}

class _AccountsManagementScreenState extends State<AccountsManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Filters
  String? _selectedStatusFilter;
  String? _selectedStreamFilter;

  final List<String> _statusOptions = ['All', 'Pending', 'Approved', 'Disabled', 'Locked'];
  final List<String> _streamOptions = ['All', 'Science', 'Commerce', 'Arts', 'Technology'];

  String _adminName = 'Admin';
  String _profileImageUrl = '';
  bool _isLoading = true;

  static const String _defaultProfileImageUrl =
      'https://res.cloudinary.com/dqeptzlsb/image/upload/v1782734371/default_il19eg.png';

  String get _currentRole {
    switch (_tabController.index) {
      case 0:
        return 'user';
      case 1:
        return 'teacher';
      case 2:
        return 'admin';
      default:
        return 'user';
    }
  }

  bool get _showStreamFilter => _currentRole == 'user' || _currentRole == 'teacher';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // 👇 Listen to tab changes and rebuild
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // Clear search and filters when tab changes (optional)
        // _searchController.clear();
        // setState(() { _searchQuery = ''; });
        setState(() {}); // triggers rebuild so the new tab's data loads
      }
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadAdminProfile();
  }

  Future<void> _loadAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          setState(() {
            _adminName = data['name'] ?? 'Admin';
            _profileImageUrl = data['profileImageUrl'] ?? _defaultProfileImageUrl;
            _isLoading = false;
          });
        }
      } catch (e) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---- Header ----
  Widget _buildHeader() {
    final String imageUrl = _profileImageUrl.isNotEmpty ? _profileImageUrl : _defaultProfileImageUrl;

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
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
            'Accounts Management',
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

  // ---- Drawer ----
  Widget _buildDrawer() {
    return AdminDrawer(
      userName: _adminName,
      userRole: 'Admin',
      profileImageUrl: _profileImageUrl,
      onLogout: () => _logout(context),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  // ---- Tab Bar ----
  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primaryPurple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.primaryPurple,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: '👨‍🎓 Students'),
          Tab(text: '👨‍🏫 Teachers'),
          Tab(text: '👨‍💼 Admins'),
        ],
      ),
    );
  }

  // ---- Filters Row (unchanged) ----
  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatusFilter,
                hint: const Text('Status'),
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryPurple),
                items: _statusOptions.map((status) {
                  return DropdownMenuItem(
                    value: status == 'All' ? null : status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedStatusFilter = value;
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (_showStreamFilter)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStreamFilter,
                  hint: const Text('Stream'),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryPurple),
                  items: _streamOptions.map((stream) {
                    return DropdownMenuItem(
                      value: stream == 'All' ? null : stream,
                      child: Text(stream),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStreamFilter = value;
                    });
                  },
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
        if (_selectedStatusFilter != null || _selectedStreamFilter != null)
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedStatusFilter = null;
                _selectedStreamFilter = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Icon(
                Icons.clear,
                size: 18,
                color: Colors.red.shade400,
              ),
            ),
          ),
      ],
    );
  }

  // ---- Search Bar ----
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name or email...',
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  // ---- User Card (unchanged) ----
  Widget _buildUserCard(Map<String, dynamic> user, String userId) {
    final bool isCurrentUser = user['id'] == FirebaseAuth.instance.currentUser?.uid;

    DateTime? lastLoginAt;
    if (user['lastLoginAt'] is Timestamp) {
      lastLoginAt = (user['lastLoginAt'] as Timestamp).toDate();
    } else if (user['lastLoginAt'] is DateTime) {
      lastLoginAt = user['lastLoginAt'] as DateTime;
    }

    String lastLoginText = 'Never logged in';
    if (lastLoginAt != null) {
      final diff = DateTime.now().difference(lastLoginAt);
      if (diff.inDays > 0) {
        lastLoginText = '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        lastLoginText = '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        lastLoginText = '${diff.inMinutes}m ago';
      } else {
        lastLoginText = 'Just now';
      }
    }

    Color statusColor;
    String statusIcon;
    switch (user['status']) {
      case 'Approved':
        statusColor = const Color(0xFF059669);
        statusIcon = '✅';
        break;
      case 'pending':
        statusColor = const Color(0xFFF59E0B);
        statusIcon = '⏳';
        break;
      case 'Disabled':
        statusColor = const Color(0xFFDC2626);
        statusIcon = '⛔';
        break;
      case 'Locked':
        statusColor = const Color(0xFF7C3AED);
        statusIcon = '🔒';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = '❓';
    }

    IconData roleIcon;
    switch (user['role']) {
      case 'admin':
        roleIcon = Icons.admin_panel_settings_rounded;
        break;
      case 'teacher':
        roleIcon = Icons.school_rounded;
        break;
      default:
        roleIcon = Icons.person_rounded;
    }

    final bool isApproved = user['status'] == 'Approved';
    final bool isDisabled = user['status'] == 'Disabled';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade100, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: NetworkImage(
                user['profileImageUrl'] ?? _defaultProfileImageUrl,
              ),
              backgroundColor: Colors.grey.shade200,
              child: user['profileImageUrl'] == null || user['profileImageUrl'].isEmpty
                  ? const Icon(Icons.person, size: 32, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(roleIcon, size: 16, color: AppColors.primaryPurple),
                      if (isCurrentUser)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user['email'] ?? 'No email',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$statusIcon ${user['status'] ?? 'Unknown'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (user['stream'] != null && user['stream'].isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '📚 ${user['stream']}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '🕐 $lastLoginText',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (user['subjects'] != null && (user['subjects'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: (user['subjects'] as List).take(3).map((subject) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              subject,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 80,
                  height: 30,
                  child: ElevatedButton(
                    onPressed: (isApproved || isCurrentUser)
                        ? null
                        : () => _showActionModal(user, userId, 'Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Approve',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (isApproved || isCurrentUser) ? Colors.white.withOpacity(0.5) : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 80,
                  height: 30,
                  child: ElevatedButton(
                    onPressed: (isDisabled || isCurrentUser)
                        ? null
                        : () => _showActionModal(user, userId, 'Disable'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Disable',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (isDisabled || isCurrentUser) ? Colors.white.withOpacity(0.5) : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 80,
                  height: 30,
                  child: ElevatedButton(
                    onPressed: isCurrentUser ? null : () => _showActionModal(user, userId, 'Delete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isCurrentUser ? Colors.white.withOpacity(0.5) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- Action Modal Dialog (unchanged) ----
  void _showActionModal(Map<String, dynamic> user, String userId, String action) {
    final bool isCurrentUser = user['id'] == FirebaseAuth.instance.currentUser?.uid;

    Color actionColor;
    String actionIcon;
    String actionMessage;

    switch (action) {
      case 'Approve':
        actionColor = const Color(0xFF059669);
        actionIcon = '✅';
        actionMessage = 'This will approve the user account. They will be able to log in.';
        break;
      case 'Disable':
        actionColor = const Color(0xFFF59E0B);
        actionIcon = '⛔';
        actionMessage = 'This will disable the user account. They will not be able to log in.';
        break;
      case 'Delete':
        actionColor = Colors.red;
        actionIcon = '🗑️';
        actionMessage = 'This will permanently delete the user account. This action cannot be undone.';
        break;
      default:
        actionColor = AppColors.primaryPurple;
        actionIcon = '⚙️';
        actionMessage = 'Are you sure?';
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: actionColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(actionIcon, style: const TextStyle(fontSize: 40)),
              ),
              const SizedBox(height: 16),
              Text(
                '$action User',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user['name'] ?? 'Unknown',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  actionMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              if (isCurrentUser)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Text(
                      '⚠️ You cannot perform this action on yourself',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isCurrentUser
                          ? null
                          : () {
                              Navigator.of(ctx).pop();
                              _performAction(user, userId, action);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actionColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        action,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Perform Action (unchanged) ----
  Future<void> _performAction(Map<String, dynamic> user, String userId, String action) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

      switch (action) {
        case 'Approve':
          await userRef.update({
            'status': 'Approved',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          _showSnackBar('✅ ${user['name']} has been approved!');
          break;
        case 'Disable':
          await userRef.update({
            'status': 'Disabled',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          _showSnackBar('⛔ ${user['name']} has been disabled.');
          break;
        case 'Delete':
          await userRef.delete();
          _showSnackBar('🗑️ ${user['name']} has been deleted.');
          break;
      }

      setState(() {});
    } catch (e) {
      _showSnackBar('Error performing action: ${e.toString()}');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primaryPurple,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ---- StreamBuilder for Users (updated to refresh on tab change) ----
  Widget _buildUserList() {
    // Use a key that changes when the tab changes to force the StreamBuilder to rebuild.
    // Alternatively, we rely on setState called from tab listener.
    // We'll use a unique key based on the current role.
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey(_currentRole), // 👈 forces rebuild on tab change
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: _currentRole)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
                const SizedBox(height: 12),
                Text(
                  'Error loading users',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(color: AppColors.primaryPurple),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 60,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No users found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    'Try adjusting your filters or search',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Apply filters (status, stream) and search in memory
        var users = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();

        // Status filter
        if (_selectedStatusFilter != null && _selectedStatusFilter != 'All') {
          users = users.where((u) => u['status'] == _selectedStatusFilter).toList();
        }

        // Stream filter (only for students/teachers)
        if (_showStreamFilter && _selectedStreamFilter != null && _selectedStreamFilter != 'All') {
          users = users.where((u) => u['stream'] == _selectedStreamFilter).toList();
        }

        // Search filter
        if (_searchQuery.isNotEmpty) {
          users = users.where((user) {
            final name = (user['name'] ?? '').toLowerCase();
            final email = (user['email'] ?? '').toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();
        }

        if (users.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 60,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No matches found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    'Try a different search term',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: _buildUserCard(user, user['id']),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSearchBar(),
                        const SizedBox(height: 12),
                        _buildFilters(),
                        const SizedBox(height: 12),
                        _buildTabBar(),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _buildUserList(),
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