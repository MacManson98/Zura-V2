// File: lib/utils/themed_notifications.dart
// Custom notification system that matches your app's theme

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ThemedNotifications {
  // Your app's color scheme
  static const Color primaryGold = Color(0xFFE5A00D);
  static const Color darkBackground = Color(0xFF1A1A1A);
  static const Color cardBackground = Color(0xFF2A2A2A);
  
  // Success notification (for joins, accepts, etc.)
  static void showSuccess(BuildContext context, String message, {String? icon}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: primaryGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  icon ?? "✅",
                  style: TextStyle(fontSize: 16.sp),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: cardBackground,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 100.h), // Above nav bar
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: primaryGold.withValues(alpha: 0.3), width: 1),
        ),
        duration: Duration(seconds: 3),
        elevation: 8,
      ),
    );
  }

  // Waiting notification (for invitations sent, etc.)
  static void showWaiting(BuildContext context, String message, {String? icon}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: primaryGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  icon ?? "⏳",
                  style: TextStyle(fontSize: 16.sp),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      height: 2.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1.r),
                        gradient: LinearGradient(
                          colors: [
                            primaryGold.withValues(alpha: 0.3),
                            primaryGold,
                            primaryGold.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: cardBackground,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 100.h), // Above nav bar
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: primaryGold.withValues(alpha: 0.5), width: 1),
        ),
        duration: Duration(seconds: 4),
        elevation: 8,
      ),
    );
  }

  // Error notification (for failures, declines)
  static void showError(BuildContext context, String message, {String? icon}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  icon ?? "❌",
                  style: TextStyle(fontSize: 16.sp),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: cardBackground,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 100.h), // Above nav bar
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 1),
        ),
        duration: Duration(seconds: 3),
        elevation: 8,
      ),
    );
  }

  // Info notification (for cancellations, updates)
  static void showInfo(BuildContext context, String message, {String? icon}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  icon ?? "ℹ️",
                  style: TextStyle(fontSize: 16.sp),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: cardBackground,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 100.h), // Above nav bar
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: Colors.blue.withValues(alpha: 0.3), width: 1),
        ),
        duration: Duration(seconds: 4),
        elevation: 8,
      ),
    );
  }

  // Decline notification (neutral gray)
  static void showDecline(BuildContext context, String message, {String? icon}) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  icon ?? "🚫",
                  style: TextStyle(fontSize: 16.sp),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: cardBackground,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 100.h), // Above nav bar
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.3), width: 1),
        ),
        duration: Duration(seconds: 3),
        elevation: 8,
      ),
    );
  }

  static void showLike(BuildContext context, String s, {required String icon}) {}
}