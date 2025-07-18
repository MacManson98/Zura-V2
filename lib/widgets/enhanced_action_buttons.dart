// lib/widgets/enhanced_action_buttons.dart - Modern Action Button Bar
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;

typedef ActionCallback = void Function();

class EnhancedActionButtons extends StatefulWidget {
  final ActionCallback onLike;
  final ActionCallback onPass;
  final ActionCallback? onSuperLike;
  final bool showSuperLike;
  final bool isEnabled;
  final int? swipeCount;

  const EnhancedActionButtons({
    super.key,
    required this.onLike,
    required this.onPass,
    this.onSuperLike,
    this.showSuperLike = false,
    this.isEnabled = true,
    this.swipeCount,
  });

  @override
  State<EnhancedActionButtons> createState() => _EnhancedActionButtonsState();
}

class _EnhancedActionButtonsState extends State<EnhancedActionButtons>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late AnimationController _tapController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  
  String? _lastPressed;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _tapController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(
      parent: _tapController,
      curve: Curves.easeOut,
    ));

    // Start subtle pulse animation
    _pulseController.repeat(reverse: true);
  }

  void _handleAction(String action, ActionCallback callback) {
    if (!widget.isEnabled) return;

    setState(() {
      _lastPressed = action;
    });

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Animate button press
    _tapController.forward().then((_) {
      _tapController.reverse();
    });

    // Execute callback
    callback();

    // Clear pressed state after animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _lastPressed = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Pass Button
          _buildActionButton(
            icon: Icons.close,
            color: Colors.red,
            onPressed: () => _handleAction('pass', widget.onPass),
            isPressed: _lastPressed == 'pass',
            size: ActionButtonSize.medium,
          ),
          
          // Super Like Button (if enabled)
          if (widget.showSuperLike) ...[
            _buildActionButton(
              icon: Icons.star,
              color: Colors.blue,
              onPressed: widget.onSuperLike != null 
                  ? () => _handleAction('super', widget.onSuperLike!)
                  : null,
              isPressed: _lastPressed == 'super',
              size: ActionButtonSize.small,
              isPremium: true,
            ),
          ],
          
          // Like Button
          _buildActionButton(
            icon: Icons.favorite,
            color: Colors.green,
            onPressed: () => _handleAction('like', widget.onLike),
            isPressed: _lastPressed == 'like',
            size: ActionButtonSize.large,
            showPulse: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required bool isPressed,
    required ActionButtonSize size,
    bool showPulse = false,
    bool isPremium = false,
  }) {
    final buttonSize = _getButtonSize(size);
    final iconSize = _getIconSize(size);
    
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
      builder: (context, child) {
        final scale = isPressed ? _scaleAnimation.value : 1.0;
        final pulseScale = showPulse ? _pulseAnimation.value : 1.0;
        final combinedScale = scale * pulseScale;
        
        return Transform.scale(
          scale: combinedScale,
          child: GestureDetector(
            onTapDown: onPressed != null ? (_) => HapticFeedback.selectionClick() : null,
            onTap: onPressed,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isEnabled 
                    ? color.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                border: Border.all(
                  color: widget.isEnabled ? color : Colors.grey,
                  width: 2.w,
                ),
                boxShadow: widget.isEnabled ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: isPressed ? 15.r : 8.r,
                    offset: Offset(0, isPressed ? 6.h : 3.h),
                  ),
                ] : [],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Premium gradient overlay
                  if (isPremium)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.2),
                            Colors.purple.withOpacity(0.2),
                          ],
                        ),
                      ),
                    ),
                  
                  // Main icon
                  Icon(
                    icon,
                    color: widget.isEnabled ? color : Colors.grey,
                    size: iconSize,
                  ),
                  
                  // Premium sparkle effect
                  if (isPremium && widget.isEnabled)
                    Positioned(
                      top: 8.h,
                      right: 8.w,
                      child: Icon(
                        Icons.auto_awesome,
                        color: Colors.amber,
                        size: 12.sp,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _getButtonSize(ActionButtonSize size) {
    switch (size) {
      case ActionButtonSize.small:
        return 50.w;
      case ActionButtonSize.medium:
        return 60.w;
      case ActionButtonSize.large:
        return 70.w;
    }
  }

  double _getIconSize(ActionButtonSize size) {
    switch (size) {
      case ActionButtonSize.small:
        return 20.sp;
      case ActionButtonSize.medium:
        return 24.sp;
      case ActionButtonSize.large:
        return 28.sp;
    }
  }
}

enum ActionButtonSize { small, medium, large }

// Floating Action Button variant
class FloatingActionButtons extends StatefulWidget {
  final ActionCallback onLike;
  final ActionCallback onPass;
  final bool isEnabled;
  final Alignment alignment;

  const FloatingActionButtons({
    super.key,
    required this.onLike,
    required this.onPass,
    this.isEnabled = true,
    this.alignment = Alignment.bottomCenter,
  });

  @override
  State<FloatingActionButtons> createState() => _FloatingActionButtonsState();
}

class _FloatingActionButtonsState extends State<FloatingActionButtons>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 100.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Align(
              alignment: widget.alignment,
              child: Padding(
                padding: EdgeInsets.only(bottom: 40.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFloatingButton(
                      icon: Icons.close,
                      color: Colors.red,
                      onPressed: widget.onPass,
                    ),
                    SizedBox(width: 80.w),
                    _buildFloatingButton(
                      icon: Icons.favorite,
                      color: Colors.green,
                      onPressed: widget.onLike,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: widget.isEnabled ? onPressed : null,
      child: Container(
        width: 56.w,
        height: 56.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isEnabled ? color : Colors.grey,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10.r,
              offset: Offset(0, 5.h),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24.sp,
        ),
      ),
    );
  }
}

// Progress indicator for swipe count
class SwipeProgressIndicator extends StatelessWidget {
  final int currentCount;
  final int targetCount;
  final Color progressColor;

  const SwipeProgressIndicator({
    super.key,
    required this.currentCount,
    required this.targetCount,
    this.progressColor = const Color(0xFFE5A00D),
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentCount / targetCount).clamp(0.0, 1.0);
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$currentCount/$targetCount',
                style: TextStyle(
                  color: progressColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 4.h,
            ),
          ),
        ],
      ),
    );
  }
}