import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';
import '../utils/completed_session.dart';
import '../utils/debug_loader.dart';

class UserService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<UserProfile> loadOrCreateUserProfile() async {
    final uid = _auth.currentUser!.uid;
    final docRef = _firestore.collection('users').doc(uid);
    final snapshot = await docRef.get();

    late UserProfile userProfile;

    if (snapshot.exists) {
      userProfile = UserProfile.fromJson(snapshot.data()!);
    } else {
      userProfile = UserProfile.empty();
      userProfile.name = 'New User'; // Or prompt user later
      await docRef.set(userProfile.toJson());
    }

    // 🧹 REMOVED: The problematic Firestore session merging
    // This was causing duplicates. Solo sessions stay local,
    // collaborative sessions are handled separately in the UI.

    // 🆕 ONE-TIME CLEANUP: Remove any duplicate sessions
    userProfile.removeDuplicateSessions();

    return userProfile;
  }

  // 🆕 NEW: Separate method to load collaborative sessions for UI display only
  Future<List<CompletedSession>> loadCollaborativeSessionsForDisplay(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('swipeSessions')
          .where('participantIds', arrayContains: uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(20) // Limit to recent sessions
          .get();

      return snapshot.docs.map((doc) {
        return CompletedSession.fromFirestore(doc.id, doc.data());
      }).toList();
    } catch (e) {
      DebugLogger.log("Error loading collaborative sessions: $e");
      return [];
    }
  }
}