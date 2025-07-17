// lib/screens/mood_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/user_profile.dart';
import '../utils/mood_engine.dart';
import '../utils/debug_loader.dart';
import '../screens/matcher_screen.dart';
import '../utils/completed_session.dart';

class MoodSelectionScreen extends StatefulWidget {
  final UserProfile userProfile;
  final List<UserProfile>? collaborators;
  final String? sessionType;

  const MoodSelectionScreen({
    super.key,
    required this.userProfile,
    this.collaborators,
    this.sessionType,
  });

  @override
  State<MoodSelectionScreen> createState() => _MoodSelectionScreenState();
}

class _MoodSelectionScreenState extends State<MoodSelectionScreen> {
  CurrentMood? _selectedMood;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          'How are you feeling?',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMoodGrid(),
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildMoodGrid() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pick a mood to find movies that match your vibe',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16.sp,
            ),
          ),
          SizedBox(height: 24.h),
          _buildMoodSection('Popular Moods', [
            CurrentMood.pureComedy,
            CurrentMood.epicAction,
            CurrentMood.romantic,
            CurrentMood.scaryAndSuspenseful,
          ]),
          SizedBox(height: 24.h),
          _buildMoodSection('Story Types', [
            CurrentMood.emotionalDrama,
            CurrentMood.mysteryCrime,
            CurrentMood.trueStories,
            CurrentMood.mindBending,
          ]),
          SizedBox(height: 24.h),
          _buildMoodSection('Genres & Worlds', [
            CurrentMood.sciFiFuture,
            CurrentMood.adventureFantasy,
            CurrentMood.worldCinema,
            CurrentMood.familyFun,
          ]),
          SizedBox(height: 24.h),
          _buildMoodSection('Special Collections', [
            CurrentMood.cultClassic,
            CurrentMood.twistEnding,
            CurrentMood.highStakes,
            CurrentMood.musicalDance,
          ]),
        ],
      ),
    );
  }

  Widget _buildMoodSection(String title, List<CurrentMood> moods) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
          ),
          itemCount: moods.length,
          itemBuilder: (context, index) {
            final mood = moods[index];
            return _buildMoodCard(mood);
          },
        ),
      ],
    );
  }

  Widget _buildMoodCard(CurrentMood mood) {
    final isSelected = _selectedMood == mood;
    
    return GestureDetector(
      onTap: () => _selectMood(mood),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE5A00D).withOpacity(0.1)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE5A00D)
                : Colors.grey[800]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              mood.emoji,
              style: TextStyle(fontSize: 32.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              mood.displayName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedMood != null) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5A00D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: const Color(0xFFE5A00D).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '${_selectedMood!.emoji} ${_selectedMood!.displayName}',
                      style: TextStyle(
                        color: const Color(0xFFE5A00D),
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _getMoodDescription(_selectedMood!),
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 12.sp,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[600]!),
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _selectedMood == null || _isLoading
                        ? null
                        : _startMoodMatching,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5A00D),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      disabledBackgroundColor: Colors.grey[700],
                      disabledForegroundColor: Colors.grey[500],
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20.h,
                            width: 20.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : Text(
                            'Start Matching',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
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

  void _selectMood(CurrentMood mood) {
    setState(() {
      _selectedMood = mood;
    });
  }

  String _getMoodDescription(CurrentMood mood) {
    switch (mood) {
      case CurrentMood.pureComedy:
        return 'Laugh-out-loud funny movies';
      case CurrentMood.epicAction:
        return 'High-octane thrills and adventure';
      case CurrentMood.romantic:
        return 'Love stories and heartwarming romance';
      case CurrentMood.scaryAndSuspenseful:
        return 'Horror and spine-chilling thrillers';
      case CurrentMood.emotionalDrama:
        return 'Deep, meaningful storytelling';
      case CurrentMood.mysteryCrime:
        return 'Puzzles, investigations, and crime';
      case CurrentMood.trueStories:
        return 'Based on real events and people';
      case CurrentMood.mindBending:
        return 'Complex narratives that challenge thinking';
      case CurrentMood.sciFiFuture:
        return 'Science fiction and futuristic worlds';
      case CurrentMood.adventureFantasy:
        return 'Epic journeys and magical worlds';
      case CurrentMood.worldCinema:
        return 'International films and cultures';
      case CurrentMood.familyFun:
        return 'Perfect for all ages';
      case CurrentMood.cultClassic:
        return 'Underground favorites and unique films';
      case CurrentMood.twistEnding:
        return 'Surprising plot twists and reveals';
      case CurrentMood.highStakes:
        return 'Intense pressure and urgent situations';
      case CurrentMood.musicalDance:
        return 'Song, dance, and musical storytelling';
    }
  }

  Future<void> _startMoodMatching() async {
    if (_selectedMood == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      DebugLogger.log("🎭 Starting mood-based matching: ${_selectedMood!.displayName}");

      // Determine session type
      SessionType sessionType;
      if (widget.collaborators == null || widget.collaborators!.isEmpty) {
        sessionType = SessionType.solo;
      } else if (widget.collaborators!.length == 1) {
        sessionType = SessionType.friend;
      } else {
        sessionType = SessionType.group;
      }

      // Navigate to matcher screen with selected mood
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MatcherScreen(
            userProfile: widget.userProfile,
            sessionType: sessionType,
            selectedMood: _selectedMood,
            collaborators: widget.collaborators,
          ),
        ),
      );
    } catch (e) {
      DebugLogger.log("❌ Error starting mood matching: $e");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start mood matching'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}