// lib/widgets/context_aware_cta.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ContextAwareCTA extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isLoading;
  final String? badge;

  const ContextAwareCTA({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
    this.isLoading = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: isPrimary
              ? const Color(0xFFE5A00D).withOpacity(0.1)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isPrimary
                ? const Color(0xFFE5A00D).withOpacity(0.3)
                : Colors.grey[800]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: isPrimary
                    ? const Color(0xFFE5A00D)
                    : Colors.grey[700],
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isPrimary ? Colors.black : Colors.white,
                        ),
                      ),
                    )
                  : Icon(
                      icon,
                      color: isPrimary ? Colors.black : Colors.white,
                      size: 20.sp,
                    ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5A00D),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
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
              color: isPrimary
                  ? const Color(0xFFE5A00D)
                  : Colors.grey[600],
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}

// Specialized CTA for different contexts
class QuickMatchCTA extends StatelessWidget {
  final String friendName;
  final VoidCallback onPressed;
  final bool isOnline;

  const QuickMatchCTA({
    super.key,
    required this.friendName,
    required this.onPressed,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return ContextAwareCTA(
      title: 'Quick Match with $friendName',
      subtitle: isOnline ? 'Online now' : 'Send invitation',
      icon: Icons.flash_on,
      onPressed: onPressed,
      isPrimary: isOnline,
      badge: isOnline ? 'ONLINE' : null,
    );
  }
}

class GroupSessionCTA extends StatelessWidget {
  final String groupName;
  final int memberCount;
  final VoidCallback onPressed;
  final bool hasActiveSession;

  const GroupSessionCTA({
    super.key,
    required this.groupName,
    required this.memberCount,
    required this.onPressed,
    this.hasActiveSession = false,
  });

  @override
  Widget build(BuildContext context) {
    return ContextAwareCTA(
      title: hasActiveSession ? 'Rejoin $groupName' : 'Start Group Session',
      subtitle: hasActiveSession 
          ? 'Session in progress with $memberCount members'
          : '$memberCount members available',
      icon: hasActiveSession ? Icons.play_arrow : Icons.group,
      onPressed: onPressed,
      isPrimary: hasActiveSession,
      badge: hasActiveSession ? 'ACTIVE' : null,
    );
  }
}

class MoodBasedCTA extends StatelessWidget {
  final String moodName;
  final String moodEmoji;
  final VoidCallback onPressed;

  const MoodBasedCTA({
    super.key,
    required this.moodName,
    required this.moodEmoji,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ContextAwareCTA(
      title: 'Match Your Mood',
      subtitle: '$moodEmoji $moodName vibes',
      icon: Icons.mood,
      onPressed: onPressed,
      isPrimary: true,
    );
  }
}

class ContinueSessionCTA extends StatelessWidget {
  final String sessionTitle;
  final String timeAgo;
  final VoidCallback onPressed;
  final VoidCallback onEnd;

  const ContinueSessionCTA({
    super.key,
    required this.sessionTitle,
    required this.timeAgo,
    required this.onPressed,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFE5A00D).withOpacity(0.15),
              const Color(0xFFE5A00D).withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: const Color(0xFFE5A00D).withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5A00D),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.black,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue Session',
                        style: TextStyle(
                          color: const Color(0xFFE5A00D),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        sessionTitle,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
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
              ],
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5A00D),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                OutlinedButton(
                  onPressed: onEnd,
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
      ),
    );
  }
}