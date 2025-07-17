// lib/screens/match_tab_screen.dart
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
import '../screens/matcher_screen.dart';
import '../screens/mood_selection_screen.dart';

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
      // Load friends and groups in parallel
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
    
    if (_friends.isEmpty && _groups.isEmpty) {
      return 'Start by discovering movies solo or add friends to match together';
    }
    
    if (_friends.isNotEmpty && _groups.isNotEmpty) {
      return 'Match with ${_friends.length} friend${_friends.length == 1 ? '' : 's'} or ${_groups.length} group${_groups.length == 1 ? '' : 's'}';
    }
    
    if (_friends.isNotEmpty) {
      return 'Match with your ${_friends.length} friend${_friends.length == 1 ? '' : 's'}';
    }
    
    if (_groups.isNotEmpty) {
      return 'Match with your ${_groups.length} group${_groups.length == 1 ? '' : 's'}';
    }
    
    return 'Discover your next favorite movie';
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
            'Loading your movie world...',
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
      onRefresh: _loadUserContext,
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
            if (_sessionInvites.isNotEmpty) ...[
              _buildSessionInvites(),
              SizedBox(height: 24.h),
            ],
            _buildPrimaryActions(),
            SizedBox(height: 32.h),
            _buildQuickActions(),
            SizedBox(height: 32.h),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final greeting = _getGreeting();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, ${widget.userProfile.name}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          _contextMessage,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14.sp,
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildSessionInvites() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending Invitations',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        ...(_sessionInvites.take(2).map((invite) => 
          InlineNotificationCard(
            title: '${invite['fromUserName']} invited you to match',
            subtitle: invite['hasMood'] == true 
                ? 'Mood: ${invite['selectedMoodName']} ${invite['selectedMoodEmoji']}'
                : 'Choose movies together',
            type: InlineNotificationType.sessionInvite,
            onAccept: () => _acceptSessionInvite(invite),
            onDecline: () => _declineSessionInvite(invite),
          ),
        )).toList(),
        if (_sessionInvites.length > 2) ...[
          SizedBox(height: 8.h),
          Text(
            '+${_sessionInvites.length - 2} more invitations',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12.sp,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPrimaryActions() {
    final activeSession = UnifiedSessionManager.getActiveSessionForDisplay();
    
    if (activeSession != null) {
      return _buildActiveSessionCard(activeSession);
    }
    
    return Column(
      children: [
        ContextAwareCTA(
          title: 'Start Matching',
          subtitle: _getPrimaryActionSubtitle(),
          icon: Icons.play_arrow,
          onPressed: _handlePrimaryAction,
          isPrimary: true,
        ),
        SizedBox(height: 16.h),
        ContextAwareCTA(
          title: 'Solo Discovery',
          subtitle: 'Discover movies at your own pace',
          icon: Icons.explore,
          onPressed: _startSoloMatching,
          isPrimary: false,
        ),
      ],
    );
  }

  String _getPrimaryActionSubtitle() {
    if (_friends.isEmpty && _groups.isEmpty) {
      return 'Start with solo discovery or add friends';
    }
    
    if (_friends.isNotEmpty && _groups.isNotEmpty) {
      return 'Choose friends or groups to match with';
    }
    
    if (_friends.isNotEmpty) {
      return 'Match with ${_friends.length} friend${_friends.length == 1 ? '' : 's'}';
    }
    
    if (_groups.isNotEmpty) {
      return 'Match with ${_groups.length} group${_groups.length == 1 ? '' : 's'}';
    }
    
    return 'Start collaborative matching';
  }

  Widget _buildActiveSessionCard(activeSession) {
    final isCollaborative = activeSession.type != SessionType.solo;
    
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE5A00D).withOpacity(0.1),
            const Color(0xFFE5A00D).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFE5A00D).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCollaborative ? Icons.people : Icons.person,
                color: const Color(0xFFE5A00D),
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Session',
                      style: TextStyle(
                        color: const Color(0xFFE5A00D),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      activeSession.displayTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _continueActiveSession,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5A00D),
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Continue Matching',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              OutlinedButton(
                onPressed: _endActiveSession,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[600]!),
                  padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'End',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.mood,
                title: 'Mood Match',
                subtitle: 'Based on how you feel',
                onPressed: _startMoodMatching,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.trending_up,
                title: 'Trending',
                subtitle: 'What\'s popular now',
                onPressed: _viewTrending,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: const Color(0xFFE5A00D),
              size: 24.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    // This would show recent matches, sessions, etc.
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
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            children: [
              Icon(
                Icons.history,
                color: Colors.grey[600],
                size: 32.sp,
              ),
              SizedBox(height: 8.h),
              Text(
                'No recent activity',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14.sp,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Start matching to see your activity here',
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

  // Action handlers
  void _handlePrimaryAction() {
    if (_friends.isEmpty && _groups.isEmpty) {
      _startSoloMatching();
    } else {
      _showCollaborativeOptions();
    }
  }

  void _startSoloMatching() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatcherScreen(
          userProfile: widget.userProfile,
          sessionType: SessionType.solo,
        ),
      ),
    );
  }

  void _showCollaborativeOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => _buildCollaborativeOptionsSheet(),
    );
  }

  Widget _buildCollaborativeOptionsSheet() {
    return Container(
      padding: EdgeInsets.all(20.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Match with Others',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 20.h),
          if (_friends.isNotEmpty) ...[
            _buildCollaborativeOption(
              icon: Icons.person,
              title: 'Friends',
              subtitle: '${_friends.length} friend${_friends.length == 1 ? '' : 's'} available',
              onPressed: _showFriendSelection,
            ),
            SizedBox(height: 12.h),
          ],
          if (_groups.isNotEmpty) ...[
            _buildCollaborativeOption(
              icon: Icons.group,
              title: 'Groups',
              subtitle: '${_groups.length} group${_groups.length == 1 ? '' : 's'} available',
              onPressed: _showGroupSelection,
            ),
            SizedBox(height: 12.h),
          ],
          _buildCollaborativeOption(
            icon: Icons.qr_code,
            title: 'Session Code',
            subtitle: 'Join someone else\'s session',
            onPressed: _showCodeInput,
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _buildCollaborativeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFE5A00D)),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 14.sp,
        ),
      ),
      onTap: onPressed,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
      ),
      tileColor: const Color(0xFF1E1E1E),
    );
  }

  void _startMoodMatching() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoodSelectionScreen(
          userProfile: widget.userProfile,
        ),
      ),
    );
  }

  void _viewTrending() {
    // Navigate to trending screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Trending movies coming soon!'),
        backgroundColor: const Color(0xFFE5A00D),
      ),
    );
  }

  void _showFriendSelection() {
    Navigator.pop(context);
    // Navigate to friend selection
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Friend selection coming soon!'),
        backgroundColor: const Color(0xFFE5A00D),
      ),
    );
  }

  void _showGroupSelection() {
    Navigator.pop(context);
    // Navigate to group selection
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Group selection coming soon!'),
        backgroundColor: const Color(0xFFE5A00D),
      ),
    );
  }

  void _showCodeInput() {
    Navigator.pop(context);
    // Show code input dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Session code input coming soon!'),
        backgroundColor: const Color(0xFFE5A00D),
      ),
    );
  }

  void _continueActiveSession() {
    final activeSession = UnifiedSessionManager.getActiveSessionForDisplay();
    if (activeSession != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MatcherScreen(
            userProfile: widget.userProfile,
            sessionType: activeSession.type,
          ),
        ),
      );
    }
  }

  void _endActiveSession() {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text('End Session?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to end your current session?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // End the session
              UnifiedSessionManager.clearActiveCollaborativeSession();
              setState(() {
                _contextMessage = _generateContextMessage();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5A00D),
              foregroundColor: Colors.black,
            ),
            child: Text('End Session'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptSessionInvite(Map<String, dynamic> invite) async {
    try {
      final sessionId = invite['sessionId'];
      final session = await SessionService.acceptInvitation(sessionId, widget.userProfile.name);
      
      if (session != null) {
        UnifiedSessionManager.setActiveCollaborativeSession(session);
        await _loadUserContext(); // Refresh the UI
        
        // Navigate to matcher screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatcherScreen(
              userProfile: widget.userProfile,
              sessionType: SessionType.friend,
              collaborativeSession: session,
            ),
          ),
        );
      }
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
      await _loadUserContext(); // Refresh the UI
      
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