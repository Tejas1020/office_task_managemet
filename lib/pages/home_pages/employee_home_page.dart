import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:office_task_managemet/notifications/test_widget.dart';
import 'package:office_task_managemet/widgets/app_drawer.dart';
import 'package:office_task_managemet/widgets/header_module.dart';
import 'package:office_task_managemet/widgets/project_card.dart';
import 'package:office_task_managemet/widgets/simple_nav_bar.dart';
import 'package:office_task_managemet/utils/colors.dart';
import 'package:office_task_managemet/utils/theme.dart';

class EmployeeHomePage extends StatefulWidget {
  const EmployeeHomePage({super.key});

  @override
  State<EmployeeHomePage> createState() => _EmployeeHomePageState();
}

class _EmployeeHomePageState extends State<EmployeeHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get isWeb => kIsWeb;
  bool get isMobile => !kIsWeb;

  bool _isScreenWide(BuildContext context) {
    return MediaQuery.of(context).size.width > 800;
  }

  List<CompactProjectCard> get _projectCards => [
    CompactProjectCard(
      title: 'Tasks',
      count: 10,
      icon: Icons.assignment_outlined,
      backgroundColor: const Color(0xFF2E3440),
      foregroundColor: Colors.white,
      route: '/admin_view_task',
    ),
    CompactProjectCard(
      title: 'Todos',
      count: 26,
      icon: Icons.checklist_outlined,
      backgroundColor: const Color(0xFF434C5E),
      foregroundColor: Colors.white,
      route: '/view_todo_list',
    ),
    CompactProjectCard(
      title: 'Create Links',
      count: 10,
      icon: Icons.add_link_outlined,
      backgroundColor: const Color(0xFF5E81AC),
      foregroundColor: Colors.white,
      route: '/create_works_link_page',
    ),
    CompactProjectCard(
      title: 'View Links',
      count: 10,
      icon: Icons.link_outlined,
      backgroundColor: const Color(0xFF81A1C1),
      foregroundColor: Colors.white,
      route: '/view_works_link_page',
    ),
    CompactProjectCard(
      title: 'Create Daily Task',
      count: 20,
      icon: Icons.task_outlined,
      backgroundColor: const Color.fromARGB(255, 122, 95, 95),
      foregroundColor: Colors.white,
      route: '/create_daily_task',
    ),
    CompactProjectCard(
      title: 'View Daily Task',
      count: 20,
      icon: Icons.task_sharp,
      backgroundColor: const Color.fromARGB(255, 142, 107, 107),
      foregroundColor: Colors.white,
      route: '/view_daily_task',
    ),
    CompactProjectCard(
      title: 'Create Accounts',
      count: 20,
      icon: Icons.account_balance,
      backgroundColor: const Color.fromARGB(255, 95, 121, 122),
      foregroundColor: Colors.white,
      route: '/create_accounts',
    ),
    CompactProjectCard(
      title: 'View Accounts',
      count: 20,
      icon: Icons.account_balance_sharp,
      backgroundColor: const Color.fromARGB(255, 107, 142, 142),
      foregroundColor: Colors.white,
      route: '/view_accounts',
    ),
    CompactProjectCard(
      title: 'View Targets',
      count: 20,
      icon: Icons.analytics_outlined,
      backgroundColor: const Color(0xFF6B8E6B),
      foregroundColor: Colors.white,
      route: '/view_target',
    ),
    CompactProjectCard(
      title: 'Attendance',
      count: 20,
      icon: Icons.analytics_outlined,
      backgroundColor: const Color.fromARGB(255, 70, 90, 220),
      foregroundColor: Colors.white,
      route: '/attendance',
    ),
        CompactProjectCard(
      title: 'View Leads',
      count: 20,
      icon: Icons.addchart_rounded,
      backgroundColor: const Color.fromARGB(185, 155, 70, 220),
      foregroundColor: Colors.white,
      route: '/view_leads',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _isScreenWide(context) ? _buildWebLayout() : _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? '';

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      backgroundColor: appTheme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          children: <Widget>[
            SafeArea(
              bottom: false,
              child: HeaderModule(
                userName: displayName,
                bgcolor: const Color.fromARGB(255, 0, 118, 182),
                onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: _projectCards,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: SimpleNavBar(
        currentIndex: 0,
        route1: '/employee',
        route2: '/message_page',
        route3: '/create_task',
        route4: '/profile',
        icon1: Icons.home_outlined,
        icon2: Icons.send_rounded,
        icon3: Icons.add_task_outlined,
        icon4: Icons.person_outline,
        fabIcon: Icons.add_rounded,
        fabRoute: '/create_todo_list',
        activeColor: Colors.blue,
        inactiveColor: Colors.grey,
        fabColor: Colors.blue,
      ),
    );
  }

  Widget _buildWebLayout() {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Employee';

    return Scaffold(
      backgroundColor: appTheme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Sidebar for web
          Container(
            width: 280,
            color: const Color.fromARGB(255, 0, 118, 182),
            child: Column(
              children: [
                // Header section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 0, 118, 182),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          color: const Color.fromARGB(255, 0, 118, 182),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName.isNotEmpty ? displayName : 'Employee',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Employee Dashboard',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Navigation menu
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      _buildSidebarItem(
                        Icons.home_outlined,
                        'Home',
                        '/employee',
                      ),
                      _buildSidebarItem(
                        Icons.send_rounded,
                        'Messages',
                        '/message_page',
                      ),
                      _buildSidebarItem(
                        Icons.add_task_outlined,
                        'Create Task',
                        '/create_task',
                      ),
                      _buildSidebarItem(
                        Icons.person_outline,
                        'Profile',
                        '/profile',
                      ),
                      _buildSidebarItem(
                        Icons.add_rounded,
                        'Create Todo',
                        '/create_todo_list',
                      ),
                      const Divider(color: Colors.white24, height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Quick Actions',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      _buildSidebarItem(
                        Icons.task_outlined,
                        'Daily Tasks',
                        '/create_daily_task',
                      ),
                      _buildSidebarItem(
                        Icons.analytics_outlined,
                        'Attendance',
                        '/attendance',
                      ),
                      _buildSidebarItem(
                        Icons.link_outlined,
                        'Work Links',
                        '/view_works_link_page',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main content area
          Expanded(
            child: Column(
              children: [
                // Top bar for web
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Text(
                          'Employee Dashboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color.fromARGB(255, 0, 118, 182),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.notifications_outlined,
                            color: const Color.fromARGB(255, 0, 118, 182),
                          ),
                          onPressed: () {},
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.settings_outlined,
                            color: const Color.fromARGB(255, 0, 118, 182),
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),

                // Main grid content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _getCrossAxisCount(context),
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: _projectCards.length,
                      itemBuilder: (context, index) {
                        return _projectCards[index];
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, String route) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    final isActive = currentRoute == route;

    return InkWell(
      onTap: () => context.go(route),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1400) return 4;
    if (width > 1100) return 3;
    return 2;
  }
}
