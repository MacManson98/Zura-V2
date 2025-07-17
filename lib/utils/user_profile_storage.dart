import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_profile.dart';

class UserProfileStorage {
  static final _usersCollection = FirebaseFirestore.instance.collection('users');

  // ✅ ADD: Check if username already exists
  static Future<bool> isUsernameAvailable(String username) async {
    final query = await _usersCollection
        .where('name', isEqualTo: username)
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  // ✅ ADD: Get email by username
  static Future<String?> getEmailByUsername(String username) async {
    final query = await _usersCollection
        .where('name', isEqualTo: username)
        .limit(1)
        .get();
    
    if (query.docs.isEmpty) return null;
    
    final userData = query.docs.first.data();
    return userData['email'] as String?;
  }

  // ✅ EXISTING methods stay the same
  static Future<void> saveProfile(UserProfile profile) async {
    if (profile.uid.isEmpty) return;
    await _usersCollection.doc(profile.uid).set(profile.toJson(), SetOptions(merge: true));
  }


  // Load profile from Firestore
  static Future<UserProfile> loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists) {
      final newProfile = UserProfile.empty().copyWith(uid: uid);
      await _usersCollection.doc(uid).set(newProfile.toJson());
      return newProfile;
    }

    return UserProfile.fromJson(doc.data()!);
  }

  // Listen to changes in current profile
  static Stream<UserProfile?> streamProfile() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromJson(doc.data()!);
    });
  }



  // Optional: delete profile
  static Future<void> clearProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _usersCollection.doc(uid).delete();
  }
}
