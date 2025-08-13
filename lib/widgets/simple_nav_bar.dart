// lib/src/widgets/simple_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:office_task_managemet/utils/colors.dart';

class SimpleNavBar extends StatelessWidget {
  final int currentIndex;
  final String route1;
  final String route2;
  final String route3;
  final String route4;
  final IconData icon1;
  final IconData icon2;
  final IconData icon3;
  final IconData icon4;
  final String? label1;
  final String? label2;
  final String? label3;
  final String? label4;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? backgroundColor;

  // FAB properties
  final VoidCallback? onFabPressed;
  final IconData? fabIcon;
  final Color? fabColor;
  final Color? fabIconColor;
  final String? fabRoute;

  const SimpleNavBar({
    Key? key,
    required this.currentIndex,
    required this.route1,
    required this.route2,
    required this.route3,
    required this.route4,
    required this.icon1,
    required this.icon2,
    required this.icon3,
    required this.icon4,
    this.label1,
    this.label2,
    this.label3,
    this.label4,
    this.activeColor,
    this.inactiveColor,
    this.backgroundColor,
    this.onFabPressed,
    this.fabIcon,
    this.fabColor,
    this.fabIconColor,
    this.fabRoute,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? Theme.of(context).primaryColor;
    final inactive = inactiveColor ?? Colors.grey[600]!;
    final bgColor = backgroundColor ?? const Color.fromARGB(255, 255, 255, 255);
    final fabBgColor = AppColors.gray800;
    final fabIconCol = fabIconColor ?? Colors.white;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Navigation Bar
        Container(
          margin: const EdgeInsets.all(16),
          height: 65,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Row(
              children: [
                _buildNavItem(
                  context,
                  0,
                  icon1,
                  route1,
                  label1,
                  active,
                  inactive,
                ),
                _buildNavItem(
                  context,
                  1,
                  icon2,
                  route2,
                  label2,
                  active,
                  inactive,
                ),
                const SizedBox(width: 60), // Space for FAB
                _buildNavItem(
                  context,
                  2,
                  icon3,
                  route3,
                  label3,
                  active,
                  inactive,
                ),
                _buildNavItem(
                  context,
                  3,
                  icon4,
                  route4,
                  label4,
                  active,
                  inactive,
                ),
              ],
            ),
          ),
        ),

        // Floating Action Button
        Positioned(
          bottom: 40,
          child: Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fabBgColor,
              boxShadow: [
                BoxShadow(
                  color: fabBgColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  if (onFabPressed != null) {
                    onFabPressed!();
                  } else if (fabRoute != null) {
                    context.go(fabRoute!);
                  }
                },
                child: Icon(fabIcon ?? Icons.add, color: fabIconCol, size: 28),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    String route,
    String? label,
    Color active,
    Color inactive,
  ) {
    final isActive = currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(route),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: isActive ? active : inactive, size: 24),
                if (label != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: isActive ? active : inactive,
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
