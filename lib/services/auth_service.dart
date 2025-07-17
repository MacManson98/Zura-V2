import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/debug_loader.dart';
import '../utils/user_profile_storage.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ✅ ADD: Login with username or email
  Future<User?> loginWithUsernameOrEmail(String usernameOrEmail, String password) async {
    String email;
    
    // Check if input contains @ (email) or not (username)
    if (usernameOrEmail.contains('@')) {
      // It's an email, use directly
      email = usernameOrEmail;
    } else {
      // It's a username, lookup email
      final foundEmail = await UserProfileStorage.getEmailByUsername(usernameOrEmail);
      if (foundEmail == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found with that username.',
        );
      }
      email = foundEmail;
    }
    
    // Login with email
    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return result.user;
  }

  Future<User?> registerWithEmail(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    return result.user;
  }

  // Login with email & password
  Future<User?> loginWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return result.user;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<User?> signInAsTestUser() async {
  try {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'connor@maclusky.com',
      password: 'Dudl@ymac1',
    );
    return credential.user;
  } catch (e) {
    DebugLogger.log('🚫 Dev sign-in failed: $e');
    return null;
  }
}


  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled the sign-in

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
