import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:chatbee/config/theme/app_theme.dart';
import 'package:chatbee/features/feed/screens/home_feed_screen.dart';
import 'package:chatbee/features/chat/screens/chat_list_screen.dart';
import 'package:chatbee/features/feed/screens/explore_screen.dart';
import 'package:chatbee/features/profile/screens/profile_screen.dart';
import 'package:chatbee/core/services/notification_service.dart';

/// Home screen shell — text-only bottom navigation with dot indicator.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<AnimationController> _animationControllers;

  final List<String> _labels = const ['HOME', 'CHATS', 'EXPLORE', 'PROFILE'];

  final List<Widget> _screens = const [
    HomeFeedScreen(),
    ChatListScreen(),
    ExploreScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animationControllers = List.generate(
      _labels.length,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _animationControllers[_currentIndex].value = 1.0;

    // Consume pending notification from terminated-state launch (fix #2)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(notificationServiceProvider).handlePendingNotification(context);
    });
  }

  @override
  void dispose() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _animationControllers[_currentIndex].reverse();
      _currentIndex = index;
      _animationControllers[_currentIndex].forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          context.push('/editor');
        },
        backgroundColor: AppTheme.primaryColor,
        child: Icon(Icons.edit_outlined, color: Colors.white, size: 24.r),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      color: AppTheme.surfaceColor,
      child: SafeArea(
        top: false,
        child: Container(
          height: 60.h,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(
              top: BorderSide(color: AppTheme.borderColor, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_labels.length, (index) {
              return _NavItem(
                label: _labels[index],
                isSelected: _currentIndex == index,
                animation: _animationControllers[index],
                onTap: () => _onItemTapped(index),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final AnimationController animation;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.isSelected,
    required this.animation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final progress = animation.value;

          return SizedBox(
            width: 80.w,
            height: 60.h,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Label with fade animation
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Color.lerp(
                      AppTheme.textLightColor,
                      AppTheme.textDarkColor,
                      progress,
                    ),
                    letterSpacing: 1.2,
                  ),
                  child: Text(label),
                ),
                SizedBox(height: 8.h),
                // Small dot indicator (like in reference image)
                Container(
                  width: 6.r,
                  height: 6.r,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      Colors.transparent,
                      Colors.white,
                      progress,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
