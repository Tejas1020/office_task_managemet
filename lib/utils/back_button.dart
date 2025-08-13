import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class BackButtonHandler extends StatelessWidget {
  final Widget child;

  const BackButtonHandler({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackButton(context);
        }
      },
      child: child,
    );
  }

  void _handleBackButton(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();

    // Define navigation hierarchy
    final navigationMap = {
      '/attendance': _getHomeRoute(),
      '/create_team': _getHomeRoute(),
      '/view_team_page': _getHomeRoute(),
      '/create_task': _getHomeRoute(),
      '/admin_view_task': _getHomeRoute(),
      '/create_todo_list': _getHomeRoute(),
      '/view_todo_list': _getHomeRoute(),
      '/create_works_link_page': _getHomeRoute(),
      '/view_works_link_page': _getHomeRoute(),
      '/create_target': _getHomeRoute(),
      '/view_target': _getHomeRoute(),
      '/profile': _getHomeRoute(),
      '/message_page': _getHomeRoute(),
      '/target_dashboard': _getHomeRoute(),
      '/create_daily_task': _getHomeRoute(),
      '/view_daily_task': _getHomeRoute(),
      '/create_accounts': _getHomeRoute(),
      '/view_accounts': _getHomeRoute(),
    };

    final backRoute = navigationMap[currentRoute];
    if (backRoute != null) {
      context.go(backRoute);
    } else {
      // If we're at home routes, show exit confirmation
      _showExitConfirmation(context);
    }
  }

  String _getHomeRoute() {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.toLowerCase() ?? '';

    if (email.endsWith('@admin.com')) return '/admin';
    if (email.endsWith('@manager.com')) return '/manager';
    return '/employee';
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.exit_to_app, color: Colors.red.shade400),
              SizedBox(width: 12),
              Text('Exit App?'),
            ],
          ),
          content: Text('Are you sure you want to exit the application?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                SystemNavigator.pop(); // This will exit the app
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
              ),
              child: Text('Exit'),
            ),
          ],
        );
      },
    );
  }
}
