import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser?> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String nic,
    required String mobile,
    required String role,
    required String stream,
    required List<String> subjects,
    String alYear = '', 
    String studentId = '', 
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;
      if (user != null) {
        AppUser appUser = AppUser(
          uid: user.uid,
          email: email,
          name: name,
          nic: nic,
          mobile: mobile,
          role: role,
          stream: stream,
          subjects: subjects,
          status: 'pending',
          alYear: alYear, 
          studentId: studentId,
        );
        await _firestore.collection('users').doc(user.uid).set(appUser.toMap());
        return appUser;
      }
      return null;
    } catch (e) {
      print('SignUp error: $e');
      rethrow;
    }
  }



  Future<AppUser?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(uid, doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('GetUserProfile error: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Forgot password
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}