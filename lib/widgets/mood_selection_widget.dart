// File: lib/widgets/mood_selection_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/mood_engine.dart';

class MoodSelectionWidget extends StatefulWidget {
  final Function(List<CurrentMood>) onMoodsSelected;
  final bool isGroupMode;
  final int groupSize;
  final MoodSelectionContext moodContext; // ✅ RENAMED to avoid BuildContext conflict

  const MoodSelectionWidget({
    super.key,
    required this.onMoodsSelected,
    this.isGroupMode = false,
    this.groupSize = 1,
    this.moodContext = MoodSelectionContext.solo, // ✅ RENAMED parameter
  });

  @override
  State<MoodSelectionWidget> createState() => _MoodSelectionWidgetState();
}

// Enum for different contexts
enum MoodSelectionContext {
  solo,           // "Start Swiping"
  friendInvite,   // "Send Invite"
  groupInvite,    // "Send Invites"
  collaborative,  // "Start Swiping" (when already in session)
}

class MoodCategory {
  final String icon;
  final List<CurrentMood> moods;

  MoodCategory({
    required this.icon,
    required this.moods,
  });
}

class _MoodSelectionWidgetState extends State<MoodSelectionWidget>
    with TickerProviderStateMixin {
  Set<CurrentMood> selectedMoods = {};
  late TabController _tabController;
  late AnimationController _fadeController;
  late AnimationController _headerController; // Header animation
  late AnimationController _buttonController; // Button animation
  late Animation<double> _fadeAnimation;
  late Animation<double> _headerAnimation; 
  late Animation<double> _buttonAnimation; // Button slide animation

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _moodCategories.length, vsync: this);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Header animation controller
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Button animation controller
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Header animation (1.0 = visible, 0.0 = hidden)
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeInOut,
    );

    // Button slide animation (0.0 = hidden below, 1.0 = visible)
    _buttonAnimation = CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOutBack, // Nice bouncy effect
    );

    _fadeController.forward();
    _headerController.forward(); // Start with header visible
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _headerController.dispose();
    _buttonController.dispose();

    super.dispose();
  }

  // Organized mood categories with balanced distribution
  Map<String, MoodCategory> get _moodCategories => {
  'Feel Good': MoodCategory(
    icon: '💖',
    moods: [
      CurrentMood.pureComedy,
      CurrentMood.romantic,
      CurrentMood.familyFun,
      CurrentMood.musicalDance,
    ],
  ),
  'Intense': MoodCategory(
    icon: '🔥',
    moods: [
      CurrentMood.scaryAndSuspenseful,
      CurrentMood.mindBending,
      CurrentMood.emotionalDrama,
      CurrentMood.highStakes,
    ],
  ),
  'Adventure': MoodCategory(
    icon: '⚡',
    moods: [
      CurrentMood.epicAction,
      CurrentMood.adventureFantasy,
      CurrentMood.sciFiFuture,
      CurrentMood.mysteryCrime,
    ],
  ),
  'Wildcard': MoodCategory(
    icon: '🌀',
    moods: [
      CurrentMood.cultClassic,   // 🎞️ iconic oddball cinema
      CurrentMood.trueStories,   // 📰 real-world narratives
      CurrentMood.twistEnding,   // 🔄 shocking finales
      CurrentMood.worldCinema,   // 🌍 global voices
    ],
  ),
};

  void _toggleMood(CurrentMood mood) {
    setState(() {
      if (selectedMoods.contains(mood)) {
        selectedMoods.remove(mood);
      } else {
        selectedMoods.add(mood);
      }
    });

    // Animate header and button based on selection state
    if (selectedMoods.isNotEmpty) {
      _headerController.reverse(); // Hide category headers
      _buttonController.forward(); // Show button
    } else {
      _headerController.forward(); // Show category headers
      _buttonController.reverse(); // Hide button
    }
  }

  // Get button text based on context
  String get _buttonText {
    switch (widget.moodContext) { // ✅ UPDATED to use new parameter name
      case MoodSelectionContext.solo:
      case MoodSelectionContext.collaborative:
        return "Start Swiping";
      case MoodSelectionContext.friendInvite:
        return "Send Invite";
      case MoodSelectionContext.groupInvite:
        return "Send Invites";
    }
  }

  // Get subtitle text based on context
  String get _subtitleText {
    switch (widget.moodContext) { // ✅ UPDATED to use new parameter name
      case MoodSelectionContext.solo:
        return "Browse categories and mix moods for perfect recommendations";
      case MoodSelectionContext.friendInvite:
        return "Choose the vibe for your friend session";
      case MoodSelectionContext.groupInvite:
        return "Choose the vibe for your group session";
      case MoodSelectionContext.collaborative:
        return "Browse categories and mix moods for perfect recommendations";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A1A1A),
            const Color(0xFF0F0F0F),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            Column(
              children: [
                // Add a drag handle at the top
                Container(
                  margin: EdgeInsets.only(top: 12.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _moodCategories.entries.map((entry) {
                      return _buildTabContent(entry.key, entry.value);
                    }).toList(),
                  ),
                ),
              ],
            ),
            _buildAnimatedContinueButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 0.h, 24.w, 12.h), // Reduced top padding for modal
      child: Column(
        children: [
          Text(
            widget.isGroupMode 
                ? "What's the group vibe?" 
                : widget.moodContext == MoodSelectionContext.friendInvite // ✅ UPDATED to use new parameter name
                    ? "What's your vibe?"
                    : "What's your mood?",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26.sp, // Slightly smaller for modal
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFFE5A00D).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: const Color(0xFFE5A00D).withValues(alpha: 0.3),
                width: 1.w,
              ),
            ),
            child: Text(
              _subtitleText, // Use dynamic subtitle
              style: TextStyle(
                color: const Color(0xFFE5A00D),
                fontSize: 13.sp, // Slightly smaller for modal
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFE5A00D).withValues(alpha: 0.2),
          width: 1.w,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFE5A00D), Colors.orange.shade600],
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: EdgeInsets.all(4.r),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
        labelStyle: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w500,
        ),
        tabs: _moodCategories.entries.map((entry) {
          final MoodCategory category = entry.value;
          return Tab(
            child: SizedBox(
              height: 48.h, // Force tab height
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    category.icon,
                    style: TextStyle(fontSize: 16.sp),
                  ),
                  SizedBox(height: 2.h), // tighter spacing
                  Text(
                    entry.key,
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(String categoryName, MoodCategory categoryData) {
    final List<CurrentMood> moods = categoryData.moods;
    final int moodCount = moods.length;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 120.h), // Adjusted for modal
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Animated category header that slides up/down based on selections
          SizeTransition(
            sizeFactor: _headerAnimation,
            axisAlignment: -1.0, // Align to top
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(categoryData.icon, style: TextStyle(fontSize: 24.sp)),
                    SizedBox(width: 12.w),
                    Text(
                      categoryName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5A00D).withAlpha(51),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFFE5A00D).withAlpha(102),
                        ),
                      ),
                      child: Text(
                        '$moodCount',
                        style: TextStyle(
                          color: const Color(0xFFE5A00D),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32.h),
              ],
            ),
          ),
          _buildMoodGrid(moods),
        ],
      ),
    );
  }

  Widget _buildMoodGrid(List<CurrentMood> moods) {
    // Dynamic grid layout based on mood count
    if (moods.length == 3) {
      return Column(
        children: [
          // Top row
          SizedBox(
            height: 160.h,
            child: Row(
              children: [
                Expanded(child: _buildMoodCard(moods[0], selectedMoods.contains(moods[0]))),
                SizedBox(width: 16.w),
                Expanded(child: _buildMoodCard(moods[1], selectedMoods.contains(moods[1]))),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          // Bottom row
          SizedBox(
            height: 160.h,
            child: Row(
              children: [
                const Spacer(),
                Expanded(flex: 2, child: _buildMoodCard(moods[2], selectedMoods.contains(moods[2]))),
                const Spacer(),
              ],
            ),
          ),
        ],
      );
    }
 else {
      // 4 moods: 2x2 grid
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 16.w,
          childAspectRatio: 1.0,
        ),
        itemCount: moods.length,
        itemBuilder: (context, index) {
          final mood = moods[index];
          final isSelected = selectedMoods.contains(mood);
          
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 400 + (index * 100)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 30 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: _buildMoodCard(mood, isSelected),
                ),
              );
            },
          );
        },
      );
    }
  }

  Widget _buildMoodCard(CurrentMood mood, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleMood(mood),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFE5A00D),
                    Colors.orange.shade600,
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2A2A2A),
                    const Color(0xFF1F1F1F),
                  ],
                ),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected 
                ? Colors.transparent 
                : Colors.grey.withValues(alpha: 0.2),
            width: 1.5.w,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFE5A00D).withValues(alpha: 0.4),
                    blurRadius: 16.r,
                    spreadRadius: 2.r,
                    offset: Offset(0, 8.h),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 8.r,
                    offset: Offset(0, 4.h),
                  ),
                ],
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: EdgeInsets.all(16.r),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Emoji with background
                  Container(
                    width: 50.w,
                    height: 50.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected 
                          ? Colors.white.withValues(alpha: 0.2)
                          : const Color(0xFFE5A00D).withValues(alpha: 0.1),
                    ),
                    child: Center(
                      child: Text(
                        mood.emoji,
                        style: TextStyle(fontSize: 24.sp),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 12.h),
                  
                  // Mood name
                  Text(
                    mood.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  SizedBox(height: 6.h),
                  
                  // Description
                  Text(
                    _getMoodDescription(mood),
                    style: TextStyle(
                      color: isSelected 
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.grey[400],
                      fontSize: 11.sp,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Selection indicator
            if (isSelected)
              Positioned(
                top: 12.r,
                right: 12.r,
                child: Container(
                  width: 24.w,
                  height: 24.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4.r,
                        offset: Offset(0, 2.h),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check,
                    color: const Color(0xFFE5A00D),
                    size: 16.sp,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // New animated continue button with selected moods display
  Widget _buildAnimatedContinueButton() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(_buttonAnimation),
        child: FadeTransition(
          opacity: _buttonAnimation,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF0F0F0F),
                  const Color(0xFF0F0F0F),
                ],
                stops: [0.0, 0.3, 1.0],
              ),
            ),
            padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 24.h), // Increased top padding
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact selected moods header (always visible when moods selected)
                if (selectedMoods.isNotEmpty) _buildCompactSelectedHeader(),
                if (selectedMoods.isNotEmpty) SizedBox(height: 12.h),
                
                // Main button
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: selectedMoods.isNotEmpty 
                        ? () => widget.onMoodsSelected(selectedMoods.toList())
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5A00D),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28.r),
                      ),
                      elevation: 8,
                      shadowColor: const Color(0xFFE5A00D).withValues(alpha: 0.4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.moodContext == MoodSelectionContext.friendInvite || widget.moodContext == MoodSelectionContext.groupInvite // ✅ UPDATED to use new parameter name
                              ? Icons.send
                              : Icons.movie_filter, 
                          color: Colors.white, 
                          size: 24.sp
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          _buttonText, // Use dynamic button text
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (selectedMoods.isNotEmpty) ...[
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              '${selectedMoods.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Compact header that shows selected moods without taking much space
  Widget _buildCompactSelectedHeader() {
    final moodsList = selectedMoods.toList();
    final showCount = moodsList.length;
    final displayMoods = moodsList.take(2).toList(); // Show max 2 moods
    final hasMore = showCount > 2;

    return GestureDetector(
      onTap: _showExpandedSelection, // Tap to see full list
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: const Color(0xFFE5A00D).withValues(alpha: 0.3),
            width: 1.w,
          ),
        ),
        child: Row(
          children: [
            // Selection count badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFE5A00D), Colors.orange.shade600],
                ),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                showCount.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            SizedBox(width: 12.w),
            
            // First two mood chips
            Expanded(
              child: Row(
                children: [
                  ...displayMoods.map((mood) => Padding(
                    padding: EdgeInsets.only(right: 6.w),
                    child: _buildCompactMoodChip(mood),
                  )),
                  
                  // "+X more" indicator
                  if (hasMore)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: const Color(0xFFE5A00D).withValues(alpha: 0.3),
                          width: 1.w,
                        ),
                      ),
                      child: Text(
                        '+${showCount - 2}',
                        style: TextStyle(
                          color: const Color(0xFFE5A00D),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Tap to expand indicator
            Icon(
              Icons.keyboard_arrow_up,
              color: Colors.white.withValues(alpha: 0.6),
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }

  // Compact mood chip for the header
  Widget _buildCompactMoodChip(CurrentMood mood) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFE5A00D), Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mood.emoji,
            style: TextStyle(fontSize: 12.sp),
          ),
          SizedBox(width: 4.w),
          Text(
            mood.displayName.split(' ').first, // Just first word to save space
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Method to show expanded selection in a dialog
  void _showExpandedSelection() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            Text(
              "Selected Moods",
              style: TextStyle(color: Colors.white, fontSize: 18.sp),
            ),
            Spacer(),
            Text(
              "(${selectedMoods.length})",
              style: TextStyle(
                color: const Color(0xFFE5A00D),
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: selectedMoods.map((mood) => _buildFullMoodChip(mood)).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                selectedMoods.clear();
                _headerController.forward();
                _buttonController.reverse();
              });
              Navigator.of(context).pop();
            },
            child: Text(
              "Clear All",
              style: TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "Done",
              style: TextStyle(color: const Color(0xFFE5A00D)),
            ),
          ),
        ],
      ),
    );
  }

  // Full mood chip with remove option
  Widget _buildFullMoodChip(CurrentMood mood) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedMoods.remove(mood);
          if (selectedMoods.isEmpty) {
            _headerController.forward();
            _buttonController.reverse();
          }
        });
        Navigator.of(context).pop(); // Close dialog
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFFE5A00D), Colors.orange.shade600],
          ),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mood.emoji,
              style: TextStyle(fontSize: 16.sp),
            ),
            SizedBox(width: 8.w),
            Text(
              mood.displayName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 6.w),
            Icon(
              Icons.close,
              color: Colors.white,
              size: 14.sp,
            ),
          ],
        ),
      ),
    );
  }

  String _getMoodDescription(CurrentMood mood) {
    final description = mood.preferredVibes.isNotEmpty
        ? mood.preferredVibes.take(2).join(" • ")
        : mood.preferredGenres.take(2).join(" • ");
    return description;
  }
}

// Enhanced Quick mood selector for returning users
class QuickMoodSelector extends StatelessWidget {
  final Function(List<CurrentMood>) onMoodsSelected;
  final List<CurrentMood> recentMoods;
  final bool isGroupMode;

  const QuickMoodSelector({
    super.key,
    required this.onMoodsSelected,
    this.recentMoods = const [],
    this.isGroupMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final moodsToShow = recentMoods.isNotEmpty 
        ? recentMoods.take(4).toList()
        : _getDefaultMoods();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Quick mood pick:",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          
          Row(
            children: moodsToShow.map((mood) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: _buildQuickMoodChip(mood),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  List<CurrentMood> _getDefaultMoods() {
    return [CurrentMood.pureComedy, CurrentMood.epicAction, CurrentMood.romantic, CurrentMood.familyFun];
  }

  Widget _buildQuickMoodChip(CurrentMood mood) {
    return GestureDetector(
      onTap: () => onMoodsSelected([mood]),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              mood.emoji,
              style: TextStyle(fontSize: 20.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              mood.displayName.split(' ').first, // First word only
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}