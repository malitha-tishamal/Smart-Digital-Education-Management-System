import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../auth/login_screen.dart';
import 'teacher_drawer.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _imagePicker = ImagePicker();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final String _cloudName = "dqeptzlsb";
  final String _uploadPreset = "flutter_mediq_upload";

  static const String _defaultProfileImageUrl =
      'https://res.cloudinary.com/dqeptzlsb/image/upload/v1782734371/default_il19eg.png';

  // Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nicController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  // Stream & Subjects (selection-based)
  String _selectedStream = '';
  List<String> _selectedSubjects = [];

  final Map<String, List<String>> _subjectsByStream = {
    'Science': [
      'Biology / Combined Maths',
      'Physics',
      'Chemistry / Agriculture / ICT',
    ],
    'Commerce': [
      'Accounting',
      'Business Studies',
      'Economics / ICT',
    ],
    'Arts': [
      'Sinhala / Tamil / English',
      'Geography',
      'History',
      'Political Science',
      'Economics',
      'Logic',
      'Media Studies',
      'Music / Dancing / Drama / Art',
      'Languages (French, Japanese, etc.)',
    ],
    'Technology': [
      'Science for Technology (compulsory)',
      'Engineering Technology',
      'Bio Systems Technology',
      'ICT',
    ],
  };

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _profileImageUrl;
  DateTime? _createdAt;
  String _role = '';

  User? _currentUser;
  late StreamSubscription<User?> _authStateSubscription;
  bool _showEmailChangePopup = false;
  bool _showVerificationSuccessPopup = false;

  XFile? _pickedImageFile;
  bool _uploadingImage = false;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _initializeAuthListener();
    _loadTeacherProfile();
  }

  @override
  void dispose() {
    _authStateSubscription.cancel();
    _fullNameController.dispose();
    _emailController.dispose();
    _nicController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  // ---------- Auth & Data Loading ----------
  void _initializeAuthListener() {
    _authStateSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        user.reload().then((_) {
          if (!mounted) return;
          final reloadedUser = _auth.currentUser;
          _handleAuthStateChange(reloadedUser);
        });
      }
    });
  }

  void _handleAuthStateChange(User? reloadedUser) {
    final justVerified = reloadedUser != null &&
        reloadedUser.emailVerified &&
        _currentUser?.emailVerified == false;

    setState(() {
      _currentUser = reloadedUser;
    });

    if (justVerified) {
      setState(() => _showVerificationSuccessPopup = true);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showVerificationSuccessPopup = false);
      });
      _loadTeacherProfile();
    }
  }

  Future<void> _loadTeacherProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = _auth.currentUser;
    if (user == null) {
      _setError('No authenticated user found.');
      return;
    }

    try {
      await user.reload();
      _currentUser = _auth.currentUser;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        _setError('Teacher profile not found in Firestore.');
        return;
      }

      await _updateLocalStateFromDocument(doc);
    } catch (e) {
      _setError('Failed to load profile: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setError(String error) {
    if (mounted) {
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _updateLocalStateFromDocument(DocumentSnapshot doc) async {
    final data = doc.data()! as Map<String, dynamic>;

    _fullNameController.text = (data['name'] ?? '') as String;
    _emailController.text = (_currentUser?.email ?? data['email'] ?? '') as String;
    _nicController.text = (data['nic'] ?? '') as String;
    _mobileController.text = (data['mobile'] ?? '') as String;

    _selectedStream = (data['stream'] ?? '') as String;
    _selectedSubjects = List<String>.from(data['subjects'] ?? []);

    final imageUrl = (data['profileImageUrl'] ?? '') as String?;
    _profileImageUrl = (imageUrl != null && imageUrl.isNotEmpty)
        ? imageUrl
        : _defaultProfileImageUrl;

    _role = (data['role'] ?? '') as String;

    final ts = data['createdAt'];
    if (ts is Timestamp) {
      _createdAt = ts.toDate();
    } else if (ts is DateTime) {
      _createdAt = ts;
    } else {
      _createdAt = null;
    }

    _initializeChangeTracking();
  }

  void _initializeChangeTracking() {
    _fullNameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _nicController.addListener(_onFieldChanged);
    _mobileController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  // ---------- Logout (for drawer) ----------
  Future<void> _logout(BuildContext context) async {
    await _auth.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  // ---------- Header ----------
  Widget _buildHeader() {
    final String displayName = _fullNameController.text.isNotEmpty
        ? _fullNameController.text
        : (_currentUser?.displayName ?? 'Teacher');

    final String imageUrl = _profileImageUrl ?? _defaultProfileImageUrl;

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
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Logged in as: Teacher',
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
                child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Teacher Profile',
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

  // ---------- Drawer ----------
  Widget _buildDrawer() {
    final String userName = _fullNameController.text.isNotEmpty
        ? _fullNameController.text
        : 'Teacher';
    final String userEmail = _currentUser?.email ?? 'teacher@example.com';
    return TeacherDrawer(
      userName: userName,
      userEmail: userEmail,
      profileImageUrl: _profileImageUrl,
      onLogout: () => _logout(context),
    );
  }

  // ---------- Image Handling ----------
  void _openImageOptions() {
    if (_isVerificationPending) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              _buildImageOptionTile(
                icon: Icons.photo_camera,
                title: 'Take Photo',
                onTap: () => _pickImage(ImageSource.camera),
              ),
              _buildImageOptionTile(
                icon: Icons.photo_library,
                title: 'Choose from Gallery',
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              if (_hasExistingImage)
                _buildImageOptionTile(
                  icon: Icons.delete_outline,
                  title: 'Remove Current Photo',
                  isDestructive: true,
                  onTap: _confirmRemoveImage,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon,
          color: isDestructive ? Colors.red : AppColors.primaryPurple),
      title: Text(title,
          style: TextStyle(color: isDestructive ? Colors.red : null)),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (picked == null) return;

      setState(() {
        _pickedImageFile = picked;
        _hasUnsavedChanges = true;
      });
    } catch (e) {
      debugPrint('Image pick error: $e');
      _showSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _confirmRemoveImage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Profile Photo'),
        content: const Text('Are you sure you want to remove your profile photo?'),
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

    if (confirmed == true) {
      await _removeProfileImage();
    }
  }

  Future<void> _removeProfileImage() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _uploadingImage = true);

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'profileImageUrl': _defaultProfileImageUrl,
      });

      setState(() {
        _profileImageUrl = _defaultProfileImageUrl;
        _pickedImageFile = null;
        _uploadingImage = false;
        _hasUnsavedChanges = true;
      });

      _showSnackBar('Profile photo removed. Default photo set.');
    } catch (e) {
      setState(() => _uploadingImage = false);
      _showSnackBar('Failed to remove photo: ${e.toString()}');
    }
  }

  Future<String?> _uploadImageToCloudinary(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      if (bytes.length > 1000000) {
        _showSnackBar('Image is too large. Max 1MB allowed.');
        return null;
      }

      final url =
          Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Upload timed out'),
      );

      final response = await http.Response.fromStream(streamedResponse);
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseData['secure_url'];
      } else {
        final errorMsg = responseData['error']?['message'] ?? 'Upload failed';
        _showSnackBar('Upload failed: $errorMsg');
        return null;
      }
    } catch (e) {
      _showSnackBar('Upload failed. Please try again.');
      return null;
    }
  }

  // ---------- Save Profile ----------
  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      _setError('No authenticated user found.');
      return;
    }

    final fullName = _fullNameController.text.trim();
    final newEmail = _emailController.text.trim();
    final nic = _nicController.text.trim();
    final mobile = _mobileController.text.trim();

    if (_selectedStream.isEmpty) {
      _setError('Please select a teaching stream');
      return;
    }
    if (_selectedSubjects.isEmpty) {
      _setError('Please select at least one teaching subject');
      return;
    }

    if (fullName.isEmpty || newEmail.isEmpty) {
      _setError('Full name and email are required.');
      return;
    }

    setState(() {
      _saving = true;
      _uploadingImage = true;
      _error = null;
    });

    try {
      String? finalProfileImageUrl = _profileImageUrl;
      bool imageUpdated = false;

      if (_pickedImageFile != null) {
        final cloudinaryUrl = await _uploadImageToCloudinary(_pickedImageFile!);
        if (cloudinaryUrl != null) {
          finalProfileImageUrl = cloudinaryUrl;
          imageUpdated = true;
        } else {
          setState(() {
            _saving = false;
            _uploadingImage = false;
          });
          return;
        }
      }

      final updateData = <String, dynamic>{
        'name': fullName,
        'email': newEmail,
        'nic': nic,
        'mobile': mobile,
        'stream': _selectedStream,
        'subjects': _selectedSubjects,
        'updatedAt': FieldValue.serverTimestamp(),
        'profileImageUrl': finalProfileImageUrl ?? _defaultProfileImageUrl,
      };

      await _firestore.collection('users').doc(user.uid).update(updateData);

      if (newEmail != user.email) {
        await _handleEmailChange(user, newEmail);
      } else {
        if (imageUpdated) {
          _showSnackBar('Profile updated with new photo!');
        } else {
          _showSnackBar('Profile updated successfully');
        }
      }

      setState(() {
        _pickedImageFile = null;
        _hasUnsavedChanges = false;
        _profileImageUrl = finalProfileImageUrl ?? _defaultProfileImageUrl;
      });
    } catch (e) {
      _setError('Failed to save profile: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadingImage = false;
        });
      }
    }
  }

  Future<void> _handleEmailChange(User user, String newEmail) async {
    try {
      await user.verifyBeforeUpdateEmail(newEmail);
      setState(() => _showEmailChangePopup = true);
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) setState(() => _showEmailChangePopup = false);
      });
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Email change failed: ${e.code}');
    }
  }

  Future<void> _resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.sendEmailVerification();
      _showSnackBar('Verification email sent to ${user.email}');
    } catch (e) {
      _showSnackBar('Failed to send verification email');
    }
  }

  // ---------- Popups ----------
  Widget _buildEmailChangePopup() {
    if (!_showEmailChangePopup) return const SizedBox.shrink();

    return Container(
      color: Colors.black54,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.email_outlined,
                  size: 50, color: AppColors.primaryPurple),
              const SizedBox(height: 16),
              const Text(
                'Email Change Initiated',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please check your inbox to verify the new email. All profile actions are temporarily disabled until verification is complete.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => setState(() => _showEmailChangePopup = false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationSuccessPopup() {
    if (!_showVerificationSuccessPopup) return const SizedBox.shrink();

    return Container(
      color: Colors.black54,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, size: 50, color: Colors.green),
              SizedBox(height: 16),
              Text(
                'Email Verified Successfully!',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green),
              ),
              SizedBox(height: 12),
              Text(
                'Your email has been verified successfully. All profile actions are now re-enabled.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Verification Status ----------
  Widget _buildVerificationStatusWidget(bool isPending) {
    if (!isPending) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Action Disabled: Email Verification Pending',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Please check your inbox for the verification link.',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _resendVerificationEmail,
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Resend Verification Email',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- UI Widgets ----------
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.darkText,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            enabled: enabled,
            style: TextStyle(
                color: enabled ? Colors.black : Colors.grey.shade600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: AppColors.inputBorder.withOpacity(0.8), fontSize: 14),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 16.0, horizontal: 20.0),
              prefixIcon: Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  border: Border(
                      right: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(icon, color: AppColors.primaryPurple, size: 20),
                ),
              ),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppColors.primaryPurple.withOpacity(0.1), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreamDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Teaching Stream',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedStream.isEmpty ? null : _selectedStream,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
              prefixIcon: const Icon(Icons.school_outlined, color: AppColors.primaryPurple),
              border: InputBorder.none,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryPurple.withOpacity(0.1), width: 1),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.primaryPurple, width: 2),
              ),
            ),
            items: _subjectsByStream.keys.map((stream) {
              return DropdownMenuItem<String>(
                value: stream,
                child: Text(stream),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedStream = value ?? '';
                _selectedSubjects.clear();
                _hasUnsavedChanges = true;
              });
            },
            style: const TextStyle(color: AppColors.darkText),
            dropdownColor: Colors.white,
            icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryPurple),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectSelection() {
    if (_selectedStream.isEmpty) return const SizedBox.shrink();
    final subjects = _subjectsByStream[_selectedStream] ?? [];
    if (subjects.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Teaching Subjects',
          style: TextStyle(
            color: AppColors.darkText,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: subjects.map((subject) {
              return CheckboxListTile(
                title: Text(subject),
                value: _selectedSubjects.contains(subject),
                onChanged: (bool? checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedSubjects.add(subject);
                    } else {
                      _selectedSubjects.remove(subject);
                    }
                    _hasUnsavedChanges = true;
                  });
                },
                activeColor: AppColors.primaryPurple,
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isDisabled) {
    return SizedBox(
      width: 140,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          backgroundColor:
              isDisabled ? Colors.grey.shade400 : AppColors.primaryPurple,
          elevation: 4,
          shadowColor: AppColors.primaryPurple.withOpacity(0.3),
        ),
        onPressed: isDisabled ? null : _saveProfile,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_hasUnsavedChanges)
                        const Icon(Icons.save, size: 18, color: Colors.white),
                      if (_hasUnsavedChanges) const SizedBox(width: 6),
                      Text(
                        _hasUnsavedChanges ? 'Save' : 'Update',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: _isVerificationPending ? null : _openImageOptions,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isVerificationPending
                ? Colors.grey.shade300
                : AppColors.inputBorder,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: _getProfileImage() != null
                        ? DecorationImage(
                            image: _getProfileImage()!,
                            fit: BoxFit.cover,
                          )
                        : null,
                    gradient: _getProfileImage() == null
                        ? const LinearGradient(
                            colors: [Color(0xFF2764E7), Color(0xFF457AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: Border.all(
                      color: _getProfileImage() == null
                          ? Colors.transparent
                          : AppColors.primaryPurple,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _getProfileImage() == null
                      ? const Icon(Icons.person, size: 60, color: Colors.white)
                      : null,
                ),
                if (_uploadingImage)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _uploadingImage
                  ? 'Uploading to Cloudinary...'
                  : _isVerificationPending
                      ? 'Image Change Disabled (Verification Pending)'
                      : (_pickedImageFile != null
                          ? 'Tap to Change Image'
                          : (_hasExistingImage
                              ? 'Tap to Change Image'
                              : 'Tap to Add Image')),
              style: TextStyle(
                fontSize: 14,
                color: _uploadingImage
                    ? AppColors.primaryPurple
                    : (_isVerificationPending
                        ? Colors.grey.shade500
                        : AppColors.primaryPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ImageProvider? _getProfileImage() {
    if (_pickedImageFile != null) {
      return FileImage(File(_pickedImageFile!.path));
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }

  void _showSnackBar(String message,
      {Duration duration = const Duration(seconds: 3)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatCreatedAt() {
    if (_createdAt == null) return '-';
    return DateFormat('yyyy-MM-dd • hh:mm a').format(_createdAt!);
  }

  // ---- Getters ----
  bool get _isVerificationPending =>
      _currentUser?.emailVerified == false && _currentUser != null;
  bool get _hasExistingImage =>
      _profileImageUrl != null && _profileImageUrl!.isNotEmpty ||
      _pickedImageFile != null;
  bool get _disableFieldsAndButton => _isVerificationPending || _saving;

  // ---- Build ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightBackground,
      drawer: _buildDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : Stack(
              children: [
                Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadTeacherProfile,
                        color: AppColors.primaryPurple,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildVerificationStatusWidget(_isVerificationPending),
                              const Text(
                                'Manage Profile Details',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Profile Picture',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryPurple),
                              ),
                              const SizedBox(height: 8),
                              _buildImagePreview(),
                              const SizedBox(height: 18),
                              _buildTextField(
                                controller: _fullNameController,
                                label: 'Full Name',
                                hint: 'Enter your full name',
                                icon: Icons.person_outline,
                                enabled: !_isVerificationPending,
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email',
                                hint: 'example@email.com',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                enabled: !_isVerificationPending,
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _nicController,
                                label: 'NIC',
                                hint: 'NIC number',
                                icon: Icons.badge_outlined,
                                enabled: !_isVerificationPending,
                              ),
                              const SizedBox(height: 12),
                              _buildTextField(
                                controller: _mobileController,
                                label: 'Mobile Number',
                                hint: 'Mobile number',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                enabled: !_isVerificationPending,
                              ),
                              const SizedBox(height: 12),
                              _buildStreamDropdown(),
                              const SizedBox(height: 12),
                              _buildSubjectSelection(),
                              const SizedBox(height: 24),
                              Center(
                                  child: _buildSaveButton(_disableFieldsAndButton)),
                              const SizedBox(height: 18),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text(
                                    'Error: $_error',
                                    style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              // Extra padding for fixed footer
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // FIXED BOTTOM FOOTER - Non-scrollable
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.lightBackground,
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey.shade200,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Developed By Devlk',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black45,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showEmailChangePopup) _buildEmailChangePopup(),
                if (_showVerificationSuccessPopup) _buildVerificationSuccessPopup(),
              ],
            ),
    );
  }
}