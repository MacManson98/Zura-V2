// lib/widgets/inline_notification_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum InlineNotificationType {
  sessionInvite,
  friendRequest,
  groupInvite,
  matchFound,
  info,
  warning,
  success,
}

class InlineNotificationCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final InlineNotificationType type;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onTap;
  final bool showActions;
  final bool isExpanded;
  final Widget? customContent;
  final String? timeAgo;

  const InlineNotificationCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.type,
    this.onAccept,
    this.onDecline,
    this.onTap,
    this.showActions = true,
    this.isExpanded = false,
    this.customContent,
    this.timeAgo,
  });

  @override
  State<InlineNotificationCard> createState() => _InlineNotificationCardState();
}

class _InlineNotificationCardState extends State<InlineNotificationCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: Opacity(
          opacity: _opacityAnimation.value,
          child: _buildCard(),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final config = _getTypeConfig(widget.type);
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: config.backgroundColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: config.borderColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(config),
            if (widget.customContent != null) ...[
              SizedBox(height: 12.h),
              widget.customContent!,
            ],
            if (widget.showActions && _shouldShowActions()) ...[
              SizedBox(height: 16.h),
              _buildActions(config),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(NotificationConfig config) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: config.iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(
            config.icon,
            color: config.iconColor,
            size: 16.sp,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.subtitle.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.timeAgo != null) ...[
          SizedBox(width: 8.w),
          Text(
            widget.timeAgo!,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 10.sp,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(NotificationConfig config) {
    if (widget.type == InlineNotificationType.info ||
        widget.type == InlineNotificationType.warning ||
        widget.type == InlineNotificationType.success) {
      return _buildSingleAction(config);
    }
    
    return _buildDualActions(config);
  }

  Widget _buildSingleAction(NotificationConfig config) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isProcessing ? null : widget.onTap,
          style: TextButton.styleFrom(
            foregroundColor: config.iconColor,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: Text(
            _getSingleActionText(),
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDualActions(NotificationConfig config) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isProcessing ? null : _handleDecline,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[600]!),
              padding: EdgeInsets.symmetric(vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              _getDeclineText(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: config.iconColor,
              foregroundColor: config.iconColor == const Color(0xFFE5A00D) ? Colors.black : Colors.white,
              padding: EdgeInsets.symmetric(vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: _isProcessing
                ? SizedBox(
                    height: 16.h,
                    width: 16.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        config.iconColor == const Color(0xFFE5A00D) ? Colors.black : Colors.white,
                      ),
                    ),
                  )
                : Text(
                    _getAcceptText(),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleAccept() async {
    if (_isProcessing || widget.onAccept == null) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      await Future.delayed(const Duration(milliseconds: 100)); // Small delay for UX
      widget.onAccept!();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleDecline() async {
    if (_isProcessing || widget.onDecline == null) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      await Future.delayed(const Duration(milliseconds: 100)); // Small delay for UX
      widget.onDecline!();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  bool _shouldShowActions() {
    return widget.onAccept != null || widget.onDecline != null || widget.onTap != null;
  }

  String _getAcceptText() {
    switch (widget.type) {
      case InlineNotificationType.sessionInvite:
        return 'Join';
      case InlineNotificationType.friendRequest:
        return 'Accept';
      case InlineNotificationType.groupInvite:
        return 'Join';
      case InlineNotificationType.matchFound:
        return 'View';
      default:
        return 'Accept';
    }
  }

  String _getDeclineText() {
    switch (widget.type) {
      case InlineNotificationType.sessionInvite:
        return 'Decline';
      case InlineNotificationType.friendRequest:
        return 'Decline';
      case InlineNotificationType.groupInvite:
        return 'Decline';
      case InlineNotificationType.matchFound:
        return 'Dismiss';
      default:
        return 'Decline';
    }
  }

  String _getSingleActionText() {
    switch (widget.type) {
      case InlineNotificationType.info:
        return 'Got it';
      case InlineNotificationType.warning:
        return 'Understood';
      case InlineNotificationType.success:
        return 'Great!';
      default:
        return 'OK';
    }
  }

  NotificationConfig _getTypeConfig(InlineNotificationType type) {
    switch (type) {
      case InlineNotificationType.sessionInvite:
        return NotificationConfig(
          icon: Icons.movie,
          iconColor: const Color(0xFFE5A00D),
          backgroundColor: const Color(0xFFE5A00D).withOpacity(0.1),
          borderColor: const Color(0xFFE5A00D).withOpacity(0.3),
        );
      case InlineNotificationType.friendRequest:
        return NotificationConfig(
          icon: Icons.person_add,
          iconColor: const Color(0xFF4CAF50),
          backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
          borderColor: const Color(0xFF4CAF50).withOpacity(0.3),
        );
      case InlineNotificationType.groupInvite:
        return NotificationConfig(
          icon: Icons.group_add,
          iconColor: const Color(0xFF2196F3),
          backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
          borderColor: const Color(0xFF2196F3).withOpacity(0.3),
        );
      case InlineNotificationType.matchFound:
        return NotificationConfig(
          icon: Icons.favorite,
          iconColor: const Color(0xFFE91E63),
          backgroundColor: const Color(0xFFE91E63).withOpacity(0.1),
          borderColor: const Color(0xFFE91E63).withOpacity(0.3),
        );
      case InlineNotificationType.info:
        return NotificationConfig(
          icon: Icons.info,
          iconColor: const Color(0xFF2196F3),
          backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
          borderColor: const Color(0xFF2196F3).withOpacity(0.3),
        );
      case InlineNotificationType.warning:
        return NotificationConfig(
          icon: Icons.warning,
          iconColor: const Color(0xFFFF9800),
          backgroundColor: const Color(0xFFFF9800).withOpacity(0.1),
          borderColor: const Color(0xFFFF9800).withOpacity(0.3),
        );
      case InlineNotificationType.success:
        return NotificationConfig(
          icon: Icons.check_circle,
          iconColor: const Color(0xFF4CAF50),
          backgroundColor: const Color(0xFF4CAF50).withOpacity(0.1),
          borderColor: const Color(0xFF4CAF50).withOpacity(0.3),
        );
    }
  }
}

class NotificationConfig {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;

  NotificationConfig({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
  });
}

// Specialized notification cards for common use cases
class SessionInviteCard extends StatelessWidget {
  final String fromUserName;
  final String? moodName;
  final String? moodEmoji;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final String? timeAgo;

  const SessionInviteCard({
    super.key,
    required this.fromUserName,
    required this.onAccept,
    required this.onDecline,
    this.moodName,
    this.moodEmoji,
    this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return InlineNotificationCard(
      title: '$fromUserName invited you to match',
      subtitle: moodName != null && moodEmoji != null
          ? 'Mood: $moodName $moodEmoji'
          : 'Choose movies together',
      type: InlineNotificationType.sessionInvite,
      onAccept: onAccept,
      onDecline: onDecline,
      timeAgo: timeAgo,
    );
  }
}

class FriendRequestCard extends StatelessWidget {
  final String fromUserName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final String? timeAgo;
  final String? mutualFriends;

  const FriendRequestCard({
    super.key,
    required this.fromUserName,
    required this.onAccept,
    required this.onDecline,
    this.timeAgo,
    this.mutualFriends,
  });

  @override
  Widget build(BuildContext context) {
    return InlineNotificationCard(
      title: '$fromUserName wants to be friends',
      subtitle: mutualFriends != null
          ? 'Mutual friends: $mutualFriends'
          : 'Match movies together',
      type: InlineNotificationType.friendRequest,
      onAccept: onAccept,
      onDecline: onDecline,
      timeAgo: timeAgo,
    );
  }
}

class GroupInviteCard extends StatelessWidget {
  final String groupName;
  final String fromUserName;
  final int memberCount;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final String? timeAgo;

  const GroupInviteCard({
    super.key,
    required this.groupName,
    required this.fromUserName,
    required this.memberCount,
    required this.onAccept,
    required this.onDecline,
    this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return InlineNotificationCard(
      title: '$fromUserName invited you to $groupName',
      subtitle: '$memberCount members • Group movie matching',
      type: InlineNotificationType.groupInvite,
      onAccept: onAccept,
      onDecline: onDecline,
      timeAgo: timeAgo,
    );
  }
}

class MatchFoundCard extends StatelessWidget {
  final String movieTitle;
  final String matchedWith;
  final VoidCallback onView;
  final VoidCallback? onDismiss;
  final String? timeAgo;

  const MatchFoundCard({
    super.key,
    required this.movieTitle,
    required this.matchedWith,
    required this.onView,
    this.onDismiss,
    this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return InlineNotificationCard(
      title: 'You matched on $movieTitle!',
      subtitle: 'With $matchedWith',
      type: InlineNotificationType.matchFound,
      onAccept: onView,
      onDecline: onDismiss,
      timeAgo: timeAgo,
    );
  }
}