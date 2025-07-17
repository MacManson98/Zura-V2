// lib/screens/friend_search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';

import '../models/user_profile.dart';
import '../services/friendship_service.dart';
import '../utils/debug_loader.dart';
import '../utils/themed_notifications.dart';

class FriendSearchScreen extends StatefulWidget {
  final UserProfile userProfile;

  const FriendSearchScreen({
    super.key,
    required this.userProfile,
  });

  @override
  State<FriendSearchScreen> createState() => _FriendSearchScreenState();
}

class _FriendSearchScreenState extends State<FriendSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounceTimer;
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    
    // Cancel previous search
    _debounceTimer?.cancel();
    
    if (query.length < 2) {
      setState(() {
        _searchResults.clear();
        _hasSearched = false;
      });
      return;
    }
    
    // Debounce search
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await FriendshipService.searchUsersByName(
        query,
        widget.userProfile.uid,
      );
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      DebugLogger.log("❌ Error searching users: $e");
      if (mounted) {
        setState(() {
          _searchResults.clear();
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          'Add Friends',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.sp,
        ),
        decoration: InputDecoration(
          hintText: 'Search by username...',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 16.sp,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey[400],
            size: 20.sp,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: Colors.grey[400],
                    size: 20.sp,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _searchFocusNode.requestFocus();
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (!_hasSearched) {
      return _buildSearchPrompt();
    }
    
    if (_isSearching) {
      return _buildLoadingState();
    }
    
    if (_searchResults.isEmpty) {
      return _buildEmptyState();
    }
    
    return _buildResultsList();
  }

  Widget _buildSearchPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64.sp,
            color: Colors.grey[600],
          ),
          SizedBox(height: 16.h),
          Text(
            'Search for friends',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Enter a username to find people to match movies with',
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
            'Searching...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search,
            size: 64.sp,
            color: Colors.grey[600],
          ),
          SizedBox(height: 16.h),
          Text(
            'No users found',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Try searching for a different username',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.separated(
      padding: EdgeInsets.all(20.w),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(UserProfile user) {
    return Container(
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
              user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
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
                  user.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${user.totalSessions} sessions • ${user.totalMatches} matches',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _sendFriendRequest(user),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE5A00D),
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            child: Text(
              'Add',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFriendRequest(UserProfile user) async {
    try {
      await FriendshipService.sendFriendRequest(
        fromUserId: widget.userProfile.uid,
        toUserId: user.uid,
        fromUserName: widget.userProfile.name,
        toUserName: user.name,
      );
      
      if (mounted) {
        ThemedNotifications.showSuccess(
          context,
          'Friend request sent to ${user.name}',
          icon: "👥",
        );
        
        // Remove user from search results
        setState(() {
          _searchResults.removeWhere((u) => u.uid == user.uid);
        });
      }
    } catch (e) {
      DebugLogger.log("❌ Error sending friend request: $e");
      
      if (mounted) {
        String errorMessage = 'Failed to send friend request';
        if (e.toString().contains('already sent')) {
          errorMessage = 'Friend request already sent';
        }
        
        ThemedNotifications.showError(context, errorMessage);
      }
    }
  }
}