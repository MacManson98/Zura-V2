import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/user_profile.dart';
import '../utils/matcher_integration.dart';
import 'context_aware_cta.dart';

/// Enhanced CTA widgets specifically for matcher integration
class MatcherCTAWidget extends StatelessWidget {
  final UserProfile userProfile;
  final String? contextMessage;

  const MatcherCTAWidget({
    super.key,
    required this.userProfile,
    this.contextMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ContextAwareCTA(
      title: 'Start Discovering',
      subtitle: contextMessage ?? 'Find your next favorite movie',
      icon: Icons.movie,
      onPressed: () => MatcherIntegration.startSoloMatching(
        context: context,
        userProfile: userProfile,
      ),
      isPrimary: true,
    );
  }
}

class FriendMatchCTAWidget extends StatelessWidget {
  final UserProfile userProfile;
  final UserProfile friend;
  final bool isOnline;

  const FriendMatchCTAWidget({
    super.key,
    required this.userProfile,
    required this.friend,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return ContextAwareCTA(
      title: 'Match with ${friend.name}',
      subtitle: isOnline ? 'Online now' : 'Send invitation',
      icon: Icons.people,
      onPressed: () => MatcherIntegration.startFriendMatching(
        context: context,
        userProfile: userProfile,
        friend: friend,
      ),
      isPrimary: isOnline,
      badge: isOnline ? 'ONLINE' : null,
    );
  }
}

class GroupMatchCTAWidget extends StatelessWidget {
  final UserProfile userProfile;
  final List<UserProfile> group;
  final String? groupName;

  const GroupMatchCTAWidget({
    super.key,
    required this.userProfile,
    required this.group,
    this.groupName,
  });

  @override
  Widget build(BuildContext context) {
    return ContextAwareCTA(
      title: 'Start Group Session',
      subtitle: groupName ?? '${group.length} members',
      icon: Icons.group,
      onPressed: () => MatcherIntegration.startGroupMatching(
        context: context,
        userProfile: userProfile,
        group: group,
      ),
    );
  }
}

class ContinueSessionCTAWidget extends StatelessWidget {
  final UserProfile userProfile;

  const ContinueSessionCTAWidget({
    super.key,
    required this.userProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ContextAwareCTA(
      title: 'Continue Session',
      subtitle: 'Pick up where you left off',
      icon: Icons.play_arrow,
      onPressed: () => MatcherIntegration.continueActiveSession(
        context: context,
        userProfile: userProfile,
      ),
      isPrimary: true,
      badge: 'ACTIVE',
    );
  }
}
