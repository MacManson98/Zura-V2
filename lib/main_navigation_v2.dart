// lib/main_navigation_v2.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/match_tab_screen.dart';
import 'screens/connect_tab_screen.dart';
import 'auth_gate.dart';
import 'models/user_profile.dart';
import 'services/user_service.dart';
import 'utils/debug_loader.dart';

class MainNavigationV2 extends StatefulWidget {
  const MainNavigationV2({super.key});

  @override
  State<MainNavigationV2> createState() => _MainNavigationV2State();
}

class _MainNavigationV2State extends State<MainNavigationV2> with TickerProviderStateMixin {
  int _currentIndex = 0;
  UserProfile? _userProfile;
  bool _isLoading = true;
  
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
    _loadUserProfile();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userService = UserService();
      final profile = await userService.loadOrCreateUserProfile();
      
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      DebugLogger.log("❌ Error loading user profile: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }
        
        if (!snapshot.hasData) {
          return const AuthGate();
        }
        
        if (_isLoading) {
          return const _LoadingScreen();
        }
        
        if (_userProfile == null) {
          return const _ErrorScreen();
        }
        
        return _buildMainInterface();
      },
    );
  }
  
  Widget _buildMainInterface() {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: TabBarView(
        controller: _tabController,
        children: [
          MatchTabScreen(userProfile: _userProfile!),
          ConnectTabScreen(userProfile: _userProfile!),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }
  
  Widget _buildBottomNavigation() {
    return Container(
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
        child: Container(
          height: 70.h,
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.movie_outlined,
                activeIcon: Icons.movie,
                label: 'Match',
                isActive: _currentIndex == 0,
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                label: 'Connect',
                isActive: _currentIndex == 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () {
        _tabController.animateTo(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE5A00D).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? const Color(0xFFE5A00D) : Colors.grey[400],
              size: 24.sp,
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFFE5A00D) : Colors.grey[400],
                fontSize: 12.sp,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie,
              size: 64.sp,
              color: const Color(0xFFE5A00D),
            ),
            SizedBox(height: 24.h),
            Text(
              'Loading Zura...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16.h),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFFE5A00D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.sp,
              color: Colors.red,
            ),
            SizedBox(height: 24.h),
            Text(
              'Something went wrong',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () {
                // Restart the app
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5A00D),
                foregroundColor: Colors.black,
              ),
              child: const Text('Restart'),
            ),
          ],
        ),
      ),
    );
  }
}