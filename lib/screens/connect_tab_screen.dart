// lib/screens/connect_tab_screen.dart - FIXED VERSION
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/user_profile.dart';
import '../models/friend_group.dart';
import '../services/friendship_service.dart';
import '../services/group_service.dart';
import '../utils/completed_session.dart';
import '../utils/unified_session_manager.dart';
import '../utils/debug_loader.dart';
import '../widgets/inline_notification_card.dart';
import '../widgets/context_aware_cta.dart';
import '../screens/friend_search_screen.dart';

class ConnectTabScreen extends StatefulWidget {
  final UserProfile userProfile;
  
  const ConnectTabScreen({
    super.key,
    required this.userProfile,
  });

  @override
  State<ConnectTabScreen> createState() => _ConnectTabScreenState();
}

class _ConnectTabScreenState extends State<ConnectTabScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<UserProfile> _friends = [];
  List<FriendGroup> _groups = [];
  List<CompletedSession> _sessions = [];
  List<Map<String, dynamic>> _friendRequests = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadConnectData();
  }

  Future<void> _loadConnectData() async {
    try {
      // Load all social data in parallel
      final results = await Future.wait([
        FriendshipService.getFriends(widget.userProfile.uid),
        GroupService().getUserGroups(widget.userProfile.uid),
        UnifiedSessionManager.getAllSessionsForDisplay(widget.userProfile),
        FriendshipService.getPendingFriendRequestsList(widget.userProfile.uid),
      ]);
      
      if (mounted) {
        setState(() {
          _friends = results[0] as List<UserProfile>;
          _groups = results[1] as List<FriendGroup>;
          _sessions = results[2] as List<CompletedSession>;
          _friendRequests = results[3] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      DebugLogger.log("❌ Error loading connect data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: _isLoading ? _buildLoadingState() : _buildMainContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              const Color(0xFFE5A00D),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Loading your connections...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _loadConnectData,
      color: const Color(0xFFE5A00D),
      backgroundColor: const Color(0xFF2A2A2A),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 24.h),
            if (_friendRequests.isNotEmpty) ...[
              _buildFriendRequests(),
              SizedBox(height: 24.h),
            ],
            _buildConnectionActions(),
            SizedBox(height: 24.h),
            _buildFriendsSection(),
            SizedBox(height: 24.h),
            _buildGroupsSection(),
            SizedBox(height: 24.h),
            _buildSessionHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          _getConnectionSummary(),
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14.sp,
          ),
        ),
      ],
    );
  }

  String _getConnectionSummary() {
    final totalConnections = _friends.length + _groups.length;
    
    if (totalConnections == 0) {
      return 'Build your movie matching network';
    }
    
    final friendsText = _friends.length == 1 ? '1 friend' : '${_friends.length} friends';
    final groupsText = _groups.length == 1 ? '1 group' : '${_groups.length} groups';
    
    if (_friends.isNotEmpty && _groups.isNotEmpty) {
      return '$friendsText • $groupsText';
    } else if (_friends.isNotEmpty) {
      return friendsText;
    } else {
      return groupsText;
    }
  }

  Widget _buildFriendRequests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Friend Requests',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        ...(_friendRequests.take(3).map((request) => 
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: InlineNotificationCard(
              title: '${request['fromUserName']} wants to be friends',
              subtitle: 'Match movies together',
              type: InlineNotificationType.friendRequest,
              onAccept: () => _acceptFriendRequest(request),
              onDecline: () => _declineFriendRequest(request),
            ),
          ),
        )),
        if (_friendRequests.length > 3) ...[
          SizedBox(height: 8.h),
          Text(
            '+${_friendRequests.length - 3} more requests',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12.sp,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConnectionActions() {
    return Column(
      children: [
        ContextAwareCTA(
          title: 'Add Friends',
          subtitle: 'Find people to match movies with',
          icon: Icons.person_add,
          onPressed: _navigateToFriendSearch,
          isPrimary: _friends.isEmpty,
        ),
        SizedBox(height: 12.h),
        ContextAwareCTA(
          title: 'Create Group',
          subtitle: 'Match with multiple friends at once',
          icon: Icons.group_add,
          onPressed: _navigateToCreateGroup,
          isPrimary: false,
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
              'Friends (${_friends.length})',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_friends.isNotEmpty)
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
        _friends.isEmpty ? _buildEmptyFriendsState() : _buildFriendsList(),
      ],
    );
  }

  Widget _buildEmptyFriendsState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline,
            color: Colors.grey[600],
            size: 48.sp,
          ),
          SizedBox(height: 16.h),
          Text(
            'No friends yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Add friends to start matching movies together',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14.sp,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _navigateToFriendSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5A00D),
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'Add Friends',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    return SizedBox(
      height: 120.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _friends.length,
        separatorBuilder: (context, index) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          final friend = _friends[index];
          return _buildFriendCard(friend);
        },
      ),
    );
  }

  Widget _buildFriendCard(UserProfile friend) {
    return GestureDetector(
      onTap: () => _navigateToFriendProfile(friend),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24.r,
              backgroundColor: const Color(0xFFE5A00D),
              child: Text(
                friend.name.isNotEmpty ? friend.name[0].toUpperCase() : 'U',
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
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            Text(
              '${friend.totalSessions} sessions',
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
              'Groups (${_groups.length})',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_groups.isNotEmpty)
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
        _groups.isEmpty ? _buildEmptyGroupsState() : _buildGroupsList(),
      ],
    );
  }

  Widget _buildEmptyGroupsState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.grey[800]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_outlined,
            color: Colors.grey[600],
            size: 48.sp,
          ),
          SizedBox(height: 16.h),
          Text(
            'No groups yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Create or join groups to match with multiple friends',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14.sp,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: _navigateToCreateGroup,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5A00D),
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'Create Group',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _groups.take(3).length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final group = _groups[index];
        return _buildGroupCard(group);
      },
    );
  }

  Widget _buildGroupCard(FriendGroup group) {
    return GestureDetector(
      onTap: () => _navigateToGroupDetail(group),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: Colors.grey[800]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24.r,
              backgroundColor: const Color(0xFFE5A00D),
              child: Text(
                group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${group.members.length} members',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Sessions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_sessions.isNotEmpty)
              TextButton(
                onPressed: _viewAllSessions,
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
        _sessions.isEmpty ? _buildEmptySessionsState() : _buildSessionsList(),
      ],
    );
  }

  Widget _buildEmptySessionsState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16.r),
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
            size: 48.sp,
          ),
          SizedBox(height: 16.h),
          Text(
            'No session history',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Your completed matching sessions will appear here',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _sessions.take(3).length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(CompletedSession session) {
    return GestureDetector(
      onTap: () => _navigateToSessionDetail(session),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: Colors.grey[800]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                _getSessionIcon(session.type),
                color: const Color(0xFFE5A00D),
                size: 24.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getSessionTitle(session),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Text(
                        _formatSessionDate(session.startTime),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '•',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '${session.matchedMovieIds.length} matches',
                        style: TextStyle(
                          color: const Color(0xFFE5A00D),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  String _getSessionTitle(CompletedSession session) {
    switch (session.type) {
      case SessionType.solo:
        return 'Solo Session';
      case SessionType.friend:
        final otherParticipants = session.participantNames
            .where((name) => name != widget.userProfile.name)
            .toList();
        return otherParticipants.isNotEmpty 
            ? 'With ${otherParticipants.first}'
            : 'Friend Session';
      case SessionType.group:
        return 'Group Session';
    }
  }

  IconData _getSessionIcon(SessionType type) {
    switch (type) {
      case SessionType.solo:
        return Icons.person;
      case SessionType.friend:
        return Icons.people;
      case SessionType.group:
        return Icons.group;
    }
  }

  String _formatSessionDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Fixed navigation methods with proper BuildContext checks
  void _navigateToFriendSearch() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendSearchScreen(userProfile: widget.userProfile),
      ),
    ).then((_) {
      if (mounted) _loadConnectData();
    });
  }

  void _navigateToCreateGroup() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateGroupScreen(userProfile: widget.userProfile),
      ),
    ).then((_) {
      if (mounted) _loadConnectData();
    });
  }

  void _navigateToFriendProfile(UserProfile friend) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendProfileScreen(
          userProfile: widget.userProfile,
          friend: friend,
        ),
      ),
    );
  }

  void _navigateToGroupDetail(FriendGroup group) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailScreen(
          userProfile: widget.userProfile,
          group: group,
        ),
      ),
    ).then((_) {
      if (mounted) _loadConnectData();
    });
  }

  void _navigateToSessionDetail(CompletedSession session) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SessionDetailScreen(
          userProfile: widget.userProfile,
          session: session,
        ),
      ),
    );
  }

  void _viewAllFriends() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Full friends list coming soon!'),
        backgroundColor: Color(0xFFE5A00D),
      ),
    );
  }

  void _viewAllGroups() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Full groups list coming soon!'),
        backgroundColor: Color(0xFFE5A00D),
      ),
    );
  }

  void _viewAllSessions() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Full session history coming soon!'),
        backgroundColor: Color(0xFFE5A00D),
      ),
    );
  }

  // Friend request handling
  Future<void> _acceptFriendRequest(Map<String, dynamic> request) async {
    try {
      await FriendshipService.acceptFriendRequestById(
        requestDocumentId: request['id'],
        fromUserId: request['fromUserId'],
        toUserId: request['toUserId'],
      );
      
      if (mounted) {
        _loadConnectData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You are now friends with ${request['fromUserName']}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      DebugLogger.log("❌ Error accepting friend request: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to accept friend request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineFriendRequest(Map<String, dynamic> request) async {
    try {
      await FriendshipService.declineFriendRequestById(request['id']);
      
      if (mounted) {
        _loadConnectData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request declined'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      DebugLogger.log("❌ Error declining friend request: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to decline friend request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ========================================
// PLACEHOLDER SCREEN IMPLEMENTATIONS
// ========================================

class CreateGroupScreen extends StatelessWidget {
  final UserProfile userProfile;

  const CreateGroupScreen({
    super.key,
    required this.userProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: const Text('Create Group'),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.group_add,
                size: 80.sp,
                color: const Color(0xFFE5A00D),
              ),
              SizedBox(height: 24.h),
              Text(
                'Create Group',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Group creation feature coming soon!\nYou\'ll be able to create groups and invite friends.',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16.sp,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32.h),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5A00D),
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FriendProfileScreen extends StatelessWidget {
  final UserProfile userProfile;
  final UserProfile friend;

  const FriendProfileScreen({
    super.key,
    required this.userProfile,
    required this.friend,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: Text(friend.name),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60.r,
                backgroundColor: const Color(0xFFE5A00D),
                child: Text(
                  friend.name.isNotEmpty ? friend.name[0].toUpperCase() : 'U',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 48.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                friend.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Friend Profile',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16.sp,
                ),
              ),
              SizedBox(height: 32.h),
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Column(
                  children: [
                    _buildStatRow('Total Sessions', '${friend.totalSessions}'),
                    SizedBox(height: 12.h),
                    _buildStatRow('Movies Liked', '${friend.likedMovies.length}'),
                    SizedBox(height: 12.h),
                    _buildStatRow('Friend Since', 'Recently'),
                  ],
                ),
              ),
              SizedBox(height: 32.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Start matching with friend
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Starting session with friend coming soon!'),
                            backgroundColor: Color(0xFFE5A00D),
                          ),
                        );
                      },
                      icon: const Icon(Icons.movie),
                      label: const Text('Start Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5A00D),
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
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

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14.sp,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class GroupDetailScreen extends StatelessWidget {
  final UserProfile userProfile;
  final FriendGroup group;

  const GroupDetailScreen({
    super.key,
    required this.userProfile,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: Text(group.name),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Info
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40.r,
                    backgroundColor: const Color(0xFFE5A00D),
                    child: Text(
                      group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 32.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    group.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '${group.members.length} members',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16.sp,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // Members Section
            Text(
              'Members',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12.h),
            
            ...group.members.map((memberId) => Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20.r,
                    backgroundColor: const Color(0xFFE5A00D),
                    child: Text(
                      'M',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Text(
                      'Member ${userProfile.name.substring(0, math.min(10, userProfile.name.length))}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                  if (memberId == userProfile.uid)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5A00D).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        'You',
                        style: TextStyle(
                          color: const Color(0xFFE5A00D),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            )),
            
            SizedBox(height: 32.h),
            
            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Start group session
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Starting group session coming soon!'),
                      backgroundColor: Color(0xFFE5A00D),
                    ),
                  );
                },
                icon: const Icon(Icons.movie),
                label: const Text('Start Group Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5A00D),
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SessionDetailScreen extends StatelessWidget {
  final UserProfile userProfile;
  final CompletedSession session;

  const SessionDetailScreen({
    super.key,
    required this.userProfile,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        title: Text(_getSessionTitle()),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session Info Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5A00D).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          _getSessionIcon(),
                          color: const Color(0xFFE5A00D),
                          size: 24.sp,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getSessionTitle(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              _formatDate(session.startTime),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 20.h),
                  
                  // Session Stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Duration',
                          _formatDuration(),
                          Icons.timer,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatCard(
                          'Matches',
                          '${session.matchedMovieIds.length}',
                          Icons.favorite,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatCard(
                          'Liked',
                          '${session.likedMovieIds.length}',
                          Icons.thumb_up,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24.h),
            
            // Participants
            if (session.participantNames.length > 1) ...[
              Text(
                'Participants',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12.h),
              
              ...session.participantNames.map((name) => Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20.r,
                      backgroundColor: name == userProfile.name 
                          ? const Color(0xFFE5A00D)
                          : Colors.grey[600],
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: name == userProfile.name ? Colors.black : Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                    if (name == userProfile.name)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5A00D).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          'You',
                          style: TextStyle(
                            color: const Color(0xFFE5A00D),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              )),
              
              SizedBox(height: 24.h),
            ],
            
            // Matched Movies
            if (session.matchedMovieIds.isNotEmpty) ...[
              Text(
                'Matched Movies',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 12.h),
              
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  children: session.matchedMovieIds.map((movieId) => 
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Row(
                        children: [
                          Icon(
                            Icons.movie,
                            color: const Color(0xFFE5A00D),
                            size: 20.sp,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              'Movie ${movieId.substring(0, 8)}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 16.sp,
                          ),
                        ],
                      ),
                    ),
                  ).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFFE5A00D),
            size: 20.sp,
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  String _getSessionTitle() {
    switch (session.type) {
      case SessionType.solo:
        return 'Solo Session';
      case SessionType.friend:
        final otherParticipants = session.participantNames
            .where((name) => name != userProfile.name)
            .toList();
        return otherParticipants.isNotEmpty 
            ? 'Session with ${otherParticipants.first}'
            : 'Friend Session';
      case SessionType.group:
        return 'Group Session';
    }
  }

  IconData _getSessionIcon() {
    switch (session.type) {
      case SessionType.solo:
        return Icons.person;
      case SessionType.friend:
        return Icons.people;
      case SessionType.group:
        return Icons.group;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration() {
    final duration = session.endTime.difference(session.startTime);
    final minutes = duration.inMinutes;
    
    if (minutes < 60) {
      return '${minutes}m';
    } else {
      final hours = duration.inHours;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}m';
    }
  }
}