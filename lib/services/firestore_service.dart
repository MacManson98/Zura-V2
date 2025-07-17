import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../movie.dart';
import '../utils/user_profile_storage.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> updateUserFavouriteIds(String uid, Set<String> favouriteMovieIds) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'favouriteMovieIds': favouriteMovieIds.toList(),
    });
  }

  Future<List<UserProfile>> getFriends(String currentUserId) async {
    final snapshot = await _db
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return UserProfile.fromJson(data);
    }).toList();
  }
  Future<void> saveMatchToFirestore(String userId, Movie movie) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('matches')
        .doc(movie.id);

    await docRef.set(movie.toJson());
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    await UserProfileStorage.saveProfile(profile);
  }
  Future<void> sendNotification({
  required String toUserId,
  required String type,
  required String title,
  required String message,
  String? movieId,
  String? fromUserId,
}) async {
  final ref = FirebaseFirestore.instance
      .collection('users')
      .doc(toUserId)
      .collection('notifications')
      .doc();

  await ref.set({
    'type': type,
    'title': title,
    'message': message,
    'movieId': movieId,
    'fromUserId': fromUserId,
    'timestamp': DateTime.now(),
    'read': false,
  });
}

}
