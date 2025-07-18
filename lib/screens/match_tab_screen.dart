// lib/screens/match_tab_screen.dart - UPDATED VERSION
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/user_profile.dart';
import '../models/friend_group.dart';
import '../services/friendship_service.dart';
import '../services/group_service.dart';
import '../services/session_service.dart';
import '../utils/completed_session.dart';
import '../utils/unified_session_manager.dart';
import '../utils/debug_loader.dart';
import '../widgets/context_aware_cta.dart';
import '../widgets/inline_notification_card.dart';
import '../widgets/enhanced_context_cta.dart';
import '../utils/matcher_integration.dart';

class MatchTabScreen extends StatefulWidget {
  final UserProfile userProfile;
  
  const MatchTabScreen({
    super.key,
    required this.userProfile,
  });

  @override
  State<MatchTabScreen> createState() => _MatchTabScreenState();
}

class _MatchTabScreenState extends State<MatchTabScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<UserProfile> _friends = [];
  List<FriendGroup> _groups = [];
  List<Map<String, dynamic>> _sessionInvites = [];
  bool _isLoading = true;
  String _contextMessage = '';
  
  @override
  void initState() {
    super.initState();
    _loadUserContext();
  }

  Future<void> _loadUserContext() async {
    try {
      final results = await Future.wait([
        FriendshipService.getFriends(widget.userProfile.uid),
        GroupService().getUserGroups(widget.userProfile.uid),
        SessionService.watchPendingInvitations().first,
      ]);
      
      if (mounted) {
        setState(() {
          _friends = results[0] as List<UserProfile>;
          _groups = results[1] as List<FriendGroup>;
          _sessionInvites = results[2] as List<Map<String, dynamic>>;
          _isLoading = false;
          _contextMessage = _generateContextMessage();
        });
      }
    } catch (e) {
      DebugLogger.log("❌ Error loading user context: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _contextMessage = 'Ready to discover movies!';
        });
      }
    }
  }

  String _generateContextMessage() {
    final activeSession = UnifiedSessionManager.getActiveSessionForDisplay();
    
    if (activeSession != null) {
      if (activeSession.type == SessionType.solo) {
        return 'Continue your movie discovery session';
      } else {
        final otherParticipants = activeSession.getOtherParticipantsDisplay(widget.userProfile.name);
        return 'Continue matching with $otherParticipants';
      }
    }
    
    if (_sessionInvites.isNotEmpty) {
      return 'You have ${_sessionInvites.length} pending session invite${_sessionInvites.length == 1 ? '' : 's'}';
    }
    
    if (_friends.isNotEmpty) {
      return 'Start matching with friends or discover solo';
    }
    
    return 'Ready to discover movies!';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: _isLoading 
            ? _buildLoadingState()
            : _buildMainContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFFE5A00D)),
          ),
          SizedBox(height: 16.h),
          Text(
            'Loading your movie matching experience...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Context message
          if (_contextMessage.isNotEmpty) ...[
            Text(
              _contextMessage,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 20.h),
          ],
          
          // Pending invitations
          if (_sessionInvites.isNotEmpty) ...[
            _buildPendingInvitations(),
            SizedBox(height: 20.h),
          ],
          
          // Primary action
          _buildPrimaryAction(),
          SizedBox(height: 16.h),
          
          // Quick actions
          _buildQuickActions(),
          SizedBox(height: 24.h),
          
          // Friends section
          if (_friends.isNotEmpty) ...[
            _buildFriendsSection(),
            SizedBox(height: 24.h),
          ],
          
          // Groups section
          if (_groups.isNotEmpty) ...[
            _buildGroupsSection(),
            SizedBox(height: 24.h),
          ],
          
          // Recent activity
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildPendingInvitations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session Invitations',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        ...(_sessionInvites.take(3).map((invite) => Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: InlineNotificationCard(
            type: InlineNotificationType.sessionInvite,
            title: '${invite['hostName']} invited you to match',
            subtitle: 'Tap to join their session',
            onAccept: () => _acceptSessionInvite(invite),
            onDecline: () => _declineSessionInvite(invite),
          ),
        )).toList()),
      ],
    );
  }

  Widget _buildPrimaryAction() {
    final activeSession = UnifiedSessionManager.getActiveSessionForDisplay();
    
    if (activeSession != null) {
      // Continue active session
      return ContinueSessionCTAWidget(userProfile: widget.userProfile);
    } else {
      // Start new matching
      return MatcherCTAWidget(
        userProfile: widget.userProfile,
        contextMessage: _contextMessage,
      );
    }
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: ContextAwareCTA(
                title: 'Mood Match',
                subtitle: 'Choose your vibe',
                icon: Icons.mood,
                onPressed: _startMoodMatching,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: ContextAwareCTA(
                title: 'Popular',
                subtitle: 'Trending now',
                icon: Icons.trending_up,
                onPressed: _startPopularMatching,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFriendsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Friends',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: _viewAllFriends,
              child: Text(
                'View All',
                style: TextStyle(
                  color: const Color(0xFFE5A00D),
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 120.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _friends.take(5).length,
            separatorBuilder: (context, index) => SizedBox(width: 12.w),
            itemBuilder: (context, index) {
              final friend = _friends[index];
              return _buildFriendCard(friend);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFriendCard(UserProfile friend) {
    return GestureDetector(
      onTap: () => MatcherIntegration.startFriendMatching(
        context: context,
        userProfile: widget.userProfile,
        friend: friend,
      ),
      child: Container(
        width: 100.w,
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: Colors.grey[800]!,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24.r,
              backgroundColor: const Color(0xFFE5A00D),
              child: Text(
                friend.name.isNotEmpty ? friend.name[0].toUpperCase() : 'F',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              friend.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Tap to match',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Groups',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: _viewAllGroups,
              child: Text(
                'View All',
                style: TextStyle(
                  color: const Color(0xFFE5A00D),
                  fontSize: 14.sp,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        ..._groups.take(3).map((group) => Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: GroupMatchCTAWidget(
            userProfile: widget.userProfile,
            group: [], // You'll need to load group members
            groupName: group.name,
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: Colors.grey[800]!,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.history,
                color: Colors.grey[600],
                size: 32.sp,
              ),
              SizedBox(height: 12.h),
              Text(
                'No recent activity',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Start matching to see your activity',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Action methods
  void _startMoodMatching() {
    // This will be handled by the new MatcherScreenV2
    MatcherIntegration.startSoloMatching(
      context: context,
      userProfile: widget.userProfile,
    );
  }

  void _startPopularMatching() {
    // This will be handled by the new MatcherScreenV2
    MatcherIntegration.startSoloMatching(
      context: context,
      userProfile: widget.userProfile,
    );
  }

  void _viewAllFriends() {
    // Navigate to friends screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Friends list integration coming soon!'),
        backgroundColor: const Color(0xFFE5A00D),
      ),
    );
  }

  void _viewAllGroups() {
    // Navigate to groups screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Groups list integration coming soon!'),
        backgroundColor: const Color(0xFFE5A00D),
      ),
    );
  }

  Future<void> _acceptSessionInvite(Map<String, dynamic> invite) async {
    try {
      await MatcherIntegration.joinSession(
        context: context,
        userProfile: widget.userProfile,
        sessionId: invite['sessionId'],
      );
      
      // Refresh the UI
      await _loadUserContext();
      
    } catch (e) {
      DebugLogger.log("❌ Error accepting session invite: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept invitation'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _declineSessionInvite(Map<String, dynamic> invite) async {
    try {
      final inviteId = invite['id'];
      final sessionId = invite['sessionId'];
      
      await SessionService.declineInvitation(inviteId, sessionId);
      await _loadUserContext();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invitation declined'),
          backgroundColor: Colors.grey[600],
        ),
      );
    } catch (e) {
      DebugLogger.log("❌ Error declining session invite: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to decline invitation'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}