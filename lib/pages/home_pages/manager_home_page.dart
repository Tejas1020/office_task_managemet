import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:office_task_managemet/widgets/app_drawer.dart';
import 'package:office_task_managemet/widgets/header_module.dart';
import 'package:office_task_managemet/widgets/project_card.dart';
import 'package:office_task_managemet/widgets/simple_nav_bar.dart';

class ManagerHomePage extends StatefulWidget {
  const ManagerHomePage({super.key});

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? '';

    final cards = [
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
        title: 'Create Target',
        count: 20,
        icon: Icons.flag_outlined,
        backgroundColor: const Color(0xFF5F7A61),
        foregroundColor: Colors.white,
        route: '/create_target',
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
        title: 'Create Team',
        count: 20,
        icon: Icons.person_add_sharp,
        backgroundColor: const Color.fromARGB(255, 122, 121, 95),
        foregroundColor: Colors.white,
        route: '/create_team',
      ),
      CompactProjectCard(
        title: 'View Teams',
        count: 20,
        icon: Icons.people_rounded,
        backgroundColor: const Color.fromARGB(255, 142, 141, 107),
        foregroundColor: Colors.white,
        route: '/view_team_page',
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
    ];

    return Scaffold(
      // appBar: AppBar(title: const Text('Employee Home')),
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      body: Center(
        child: Column(
          // mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SafeArea(
              bottom: false,
              child: HeaderModule(
                userName: displayName,
                bgcolor: const Color.fromARGB(255, 43, 42, 38),
                onMenuTap: () {},
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
                  children: cards,
                ),
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: SimpleNavBar(
        currentIndex: 0,
        route1: '/',
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
}
