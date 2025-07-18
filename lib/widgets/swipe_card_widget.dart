// lib/widgets/swipe_card_widget.dart - Enhanced Swipe Card Component
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


import '../movie.dart';

typedef SwipeCallback = void Function(Movie movie, SwipeDirection direction);

enum SwipeDirection { left, right, up }

class SwipeCardWidget extends StatefulWidget {
  final Movie movie;
  final SwipeCallback onSwipe;
  final bool isBackCard;
  final bool enableSwipe;
  final Widget? child;

  const SwipeCardWidget({
    super.key,
    required this.movie,
    required this.onSwipe,
    this.isBackCard = false,
    this.enableSwipe = true,
    this.child,
  });

  @override
  State<SwipeCardWidget> createState() => _SwipeCardWidgetState();
}

class _SwipeCardWidgetState extends State<SwipeCardWidget>
    with TickerProviderStateMixin {
  
  late AnimationController _animationController;
  late AnimationController _slideOutController;
  late Animation<double> _rotationAnimation;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  Offset _position = Offset.zero;
  bool _isDragging = false;
  double _rotation = 0.0;
  SwipeDirection? _swipeDirection;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _slideOutController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideOutController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _positionAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideOutController,
      curve: Curves.easeInBack,
    ));

    _scaleAnimation = Tween<double>(
      begin: widget.isBackCard ? 0.95 : 1.0,
      end: widget.isBackCard ? 1.0 : 0.8,
    ).animate(CurvedAnimation(
      parent: _slideOutController,
      curve: Curves.easeOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: widget.isBackCard ? 0.5 : 1.0,
      end: widget.isBackCard ? 1.0 : 0.0,
    ).animate(_slideOutController);

    if (!widget.isBackCard) {
      _animationController.forward();
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.enableSwipe) return;
    
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.enableSwipe) return;

    setState(() {
      _position += details.delta;
      _rotation = _position.dx / 300.0;
      
      // Determine swipe direction
      if (_position.dx.abs() > 50) {
        _swipeDirection = _position.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
      } else if (_position.dy < -50) {
        _swipeDirection = SwipeDirection.up;
      } else {
        _swipeDirection = null;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.enableSwipe) return;

    final swipeThreshold = 100.0;
    final velocity = details.velocity.pixelsPerSecond;

    bool shouldSwipe = false;
    SwipeDirection? finalDirection;

    // Check if swipe threshold is met by position or velocity
    if (_position.dx.abs() > swipeThreshold || velocity.dx.abs() > 500) {
      shouldSwipe = true;
      finalDirection = _position.dx > 0 ? SwipeDirection.right : SwipeDirection.left;
    } else if (_position.dy < -swipeThreshold || velocity.dy < -500) {
      shouldSwipe = true;
      finalDirection = SwipeDirection.up;
    }

    if (shouldSwipe && finalDirection != null) {
      _performSwipe(finalDirection);
    } else {
      _resetPosition();
    }
  }

  void _performSwipe(SwipeDirection direction) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    Offset endPosition;
    double endRotation;

    switch (direction) {
      case SwipeDirection.left:
        endPosition = Offset(-screenWidth * 1.5, _position.dy);
        endRotation = -0.5;
        break;
      case SwipeDirection.right:
        endPosition = Offset(screenWidth * 1.5, _position.dy);
        endRotation = 0.5;
        break;
      case SwipeDirection.up:
        endPosition = Offset(_position.dx, -screenHeight);
        endRotation = _rotation;
        break;
    }

    _positionAnimation = Tween<Offset>(
      begin: _position,
      end: endPosition,
    ).animate(CurvedAnimation(
      parent: _slideOutController,
      curve: Curves.easeInBack,
    ));

    _rotationAnimation = Tween<double>(
      begin: _rotation,
      end: endRotation,
    ).animate(_slideOutController);

    _slideOutController.forward().then((_) {
      widget.onSwipe(widget.movie, direction);
    });
  }

  void _resetPosition() {
    _animationController.reset();
    _animationController.forward();
    
    setState(() {
      _position = Offset.zero;
      _rotation = 0.0;
      _isDragging = false;
      _swipeDirection = null;
    });
  }

  // Public method to trigger programmatic swipe
  void swipeCard(SwipeDirection direction) {
    _performSwipe(direction);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _animationController,
        _slideOutController,
      ]),
      builder: (context, child) {
        final position = _slideOutController.isAnimating 
            ? _positionAnimation.value 
            : _position;
        
        final rotation = _slideOutController.isAnimating 
            ? _rotationAnimation.value 
            : _rotation;

        final scale = _slideOutController.isAnimating 
            ? _scaleAnimation.value 
            : (widget.isBackCard ? 0.95 : 1.0);

        final opacity = _slideOutController.isAnimating 
            ? _opacityAnimation.value 
            : (widget.isBackCard ? 0.5 : 1.0);

        return Transform.translate(
          offset: position,
          child: Transform.rotate(
            angle: rotation,
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Stack(
                    children: [
                      widget.child ?? _buildDefaultCard(),
                      if (_isDragging && !widget.isBackCard)
                        _buildSwipeIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultCard() {
    return Container(
      width: 320.w,
      height: 500.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: widget.isBackCard ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20.r,
            offset: Offset(0, 10.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Movie poster
            widget.movie.posterUrl.isNotEmpty
                ? Image.network(
                    widget.movie.posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
            
            // Gradient overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 200.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
            
            // Movie info
            Positioned(
              bottom: 20.h,
              left: 20.w,
              right: 20.w,
              child: _buildMovieInfo(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: Center(
        child: Icon(
          Icons.movie,
          size: 80.sp,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildMovieInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.movie.title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Icon(
              Icons.star,
              color: const Color(0xFFE5A00D),
              size: 16.sp,
            ),
            SizedBox(width: 4.w),
            Text(
              '${widget.movie.rating}/10',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 16.w),
            Text(
              widget.movie.releaseYear?.toString() ?? '',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
        if (widget.movie.overview.isNotEmpty) ...[
          SizedBox(height: 12.h),
          Text(
            widget.movie.overview,
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13.sp,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildSwipeIndicator() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          color: _getSwipeIndicatorColor(),
        ),
        child: Center(
          child: _getSwipeIndicatorIcon(),
        ),
      ),
    );
  }

  Color _getSwipeIndicatorColor() {
    if (_swipeDirection == null) return Colors.transparent;
    
    switch (_swipeDirection!) {
      case SwipeDirection.right:
        return Colors.green.withOpacity(0.3);
      case SwipeDirection.left:
        return Colors.red.withOpacity(0.3);
      case SwipeDirection.up:
        return Colors.blue.withOpacity(0.3);
    }
  }

  Widget? _getSwipeIndicatorIcon() {
    if (_swipeDirection == null) return null;
    
    IconData iconData;
    Color iconColor;
    
    switch (_swipeDirection!) {
      case SwipeDirection.right:
        iconData = Icons.favorite;
        iconColor = Colors.green;
        break;
      case SwipeDirection.left:
        iconData = Icons.close;
        iconColor = Colors.red;
        break;
      case SwipeDirection.up:
        iconData = Icons.info;
        iconColor = Colors.blue;
        break;
    }
    
    return Icon(
      iconData,
      color: iconColor,
      size: 80.sp,
    );
  }
}

// Helper widget for programmatic swiping
class SwipeController {
  _SwipeCardWidgetState? _state;
  
  void _attach(_SwipeCardWidgetState state) {
    _state = state;
  }
  
  void _detach() {
    _state = null;
  }
  
  void swipeLeft() {
    _state?.swipeCard(SwipeDirection.left);
  }
  
  void swipeRight() {
    _state?.swipeCard(SwipeDirection.right);
  }
  
  void swipeUp() {
    _state?.swipeCard(SwipeDirection.up);
  }
}

// Enhanced version with controller support
class ControllableSwipeCard extends StatefulWidget {
  final Movie movie;
  final SwipeCallback onSwipe;
  final SwipeController? controller;
  final bool isBackCard;
  final bool enableSwipe;
  final Widget? child;

  const ControllableSwipeCard({
    super.key,
    required this.movie,
    required this.onSwipe,
    this.controller,
    this.isBackCard = false,
    this.enableSwipe = true,
    this.child,
  });

  @override
  State<ControllableSwipeCard> createState() => _ControllableSwipeCardState();
}

class _ControllableSwipeCardState extends State<ControllableSwipeCard> {
  @override
  void initState() {
    super.initState();
    widget.controller?._attach(_swipeCardState!);
  }

  @override
  void dispose() {
    widget.controller?._detach();
    super.dispose();
  }

  _SwipeCardWidgetState? _swipeCardState;

  @override
  Widget build(BuildContext context) {
    return SwipeCardWidget(
      key: GlobalKey<_SwipeCardWidgetState>(),
      movie: widget.movie,
      onSwipe: widget.onSwipe,
      isBackCard: widget.isBackCard,
      enableSwipe: widget.enableSwipe,
      child: widget.child,
    );
  }
}