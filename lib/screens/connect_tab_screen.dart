// lib/screens/connect_tab_screen.dart
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
import '../utils/matcher_integration.dart';

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
        )).toList(),
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
            SizedBox(width: 12.w),
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
                    '${group.memberCount} members • ${group.totalMatches} matches',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[600],
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
            'No sessions yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Start matching to see your session history',
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
      itemCount: _sessions.take(5).length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return _buildSessionCard(session);
      },
    );
  }

  Widget _buildSessionCard(CompletedSession session) {
    final isActive = session.id.startsWith('active_');
    
    return GestureDetector(
      onTap: () => _navigateToSessionDetail(session),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isActive 
              ? const Color(0xFFE5A00D).withOpacity(0.1)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isActive 
                ? const Color(0xFFE5A00D).withOpacity(0.3)
                : Colors.grey[800]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: isActive 
                    ? const Color(0xFFE5A00D)
                    : Colors.grey[700],
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                _getSessionIcon(session.type),
                color: isActive ? Colors.black : Colors.white,
                size: 20.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.funTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    isActive ? 'Active now' : _formatSessionDate(session.startTime),
                    style: TextStyle(
                      color: isActive 
                          ? const Color(0xFFE5A00D)
                          : Colors.grey[400],
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5A00D),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[600],
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
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

  // Navigation methods
  void _navigateToFriendSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendSearchScreen(userProfile: widget.userProfile),
      ),
    ).then((_) => _loadConnectData());
  }

  void _navigateToCreateGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateGroupScreen(userProfile: widget.userProfile),
      ),
    ).then((_) => _loadConnectData());
  }

  void _navigateToFriendProfile(UserProfile friend) {
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailScreen(
          userProfile: widget.userProfile,
          group: group,
        ),
      ),
    ).then((_) => _loadConnectData());
  }

  void _navigateToSessionDetail(CompletedSession session) {
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
    // Navigate to full friends list
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Full friends list coming soon!'),
        backgroundColor: const Color(0xFFE5A00D),
      ),
    );
  }

  void _viewAllGroups() {
    // Navigate to full groups list
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Full groups list coming soon!'),
        backgroundColor: const Color(0xFFE5A00D),
      ),
    );
  }

  void _viewAllSessions() {
    // Navigate to full sessions list
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Full session history coming soon!'),
        backgroundColor: const Color(0xFFE5A00D),
      ),
    );
  }

  // Action handlers
  Future<void> _acceptFriendRequest(Map<String, dynamic> request) async {
    try {
      await FriendshipService.acceptFriendRequestById(
        requestDocumentId: request['id'],
        fromUserId: request['fromUserId'],
        toUserId: request['toUserId'],
      );
      
      await _loadConnectData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${request['fromUserName']} is now your friend!'),
          backgroundColor: const Color(0xFFE5A00D),
        ),
      );
    } catch (e) {
      DebugLogger.log("❌ Error accepting friend request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept friend request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _declineFriendRequest(Map<String, dynamic> request) async {
    try {
      await FriendshipService.declineFriendRequestById(request['id']);
      
      await _loadConnectData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Friend request declined'),
          backgroundColor: Colors.grey[600],
        ),
      );
    } catch (e) {
      DebugLogger.log("❌ Error declining friend request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to decline friend request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}