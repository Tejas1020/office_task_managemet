import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CompactProjectCard extends StatelessWidget {
  /// The card’s title (e.g. “Ongoing”)
  final String title;

  /// Number of tasks (e.g. 10)
  final int count;

  /// The icon to show in the top‑left
  final IconData icon;

  /// Background color of this card
  final Color backgroundColor;

  /// Color to use for icon, title & arrow
  final Color foregroundColor;

  /// Where to navigate when tapped
  final String route;

  const CompactProjectCard({
    Key? key,
    required this.title,
    required this.count,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.route,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => GoRouter.of(context).go(route),
      child: Container(
        height: 145, // fixed height avoids overflow

        decoration: BoxDecoration(       
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            // Top‑left block
            Positioned(
              top: 0,
              left: 0,
              right: 32, // leave room for arrow
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 25, color: foregroundColor),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                ],
              ),
            ),

            // Bottom‑right arrow
            Positioned(
              bottom: 0,
              right: 0,
              child: Icon(
                Icons.arrow_forward,
                size: 18,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

