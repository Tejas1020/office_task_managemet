import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:office_task_managemet/notifications/notifications.dart';
import 'package:office_task_managemet/pages/attendance/attendance_page.dart';
import 'package:office_task_managemet/pages/leads/create_leads.dart';
import 'package:office_task_managemet/pages/leads/view_leads.dart';
import 'package:office_task_managemet/utils/back_button.dart';
import 'package:office_task_managemet/utils/splash_screen.dart';
import 'package:office_task_managemet/pages/accounts/create_accounts_page.dart';
import 'package:office_task_managemet/pages/accounts/view_accounts_page.dart';
import 'package:office_task_managemet/pages/daily_tasks/create_daily_task.dart';
import 'package:office_task_managemet/pages/daily_tasks/view_daily_task.dart';
import 'package:office_task_managemet/pages/target/dashboard.dart';
import 'package:office_task_managemet/pages/task/view_tasks_page.dart';
import 'package:office_task_managemet/pages/home_pages/admin_home_page.dart';
import 'package:office_task_managemet/pages/link_storage/create_links_storage.dart';
import 'package:office_task_managemet/pages/target/create_target_page.dart';
import 'package:office_task_managemet/pages/task/create_task_page.dart';
import 'package:office_task_managemet/pages/team/create_team_page.dart';
import 'package:office_task_managemet/pages/todo/create_todo_page.dart';
import 'package:office_task_managemet/pages/home_pages/employee_home_page.dart';
import 'package:office_task_managemet/pages/home_pages/manager_home_page.dart';
import 'package:office_task_managemet/pages/messages/message_page.dart';
import 'package:office_task_managemet/pages/home_pages/profile_page.dart';
import 'package:office_task_managemet/pages/link_storage/view_links_page.dart';
import 'package:office_task_managemet/pages/target/view_targets_page.dart';
import 'package:office_task_managemet/pages/team/view_teams_page.dart';
import 'package:office_task_managemet/pages/todo/view_todo_page.dart';
import 'auth/login_page.dart';
import 'auth/registration_page.dart';
import 'utils/theme.dart';
import 'firebase_options.dart'; // generated via FlutterFire CLI

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notifications with better error handling
  print('🚀 Starting app initialization...');
  await NotificationService.initialize();
  print('🚀 App initialization complete!');

  // Set web-specific configurations
  if (kIsWeb) {
    // Disable right-click context menu on web for better UX
    // You can add other web-specific configurations here
    print('🌐 Running on web platform');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 👈 ADD THIS SECTION - Start notification listener when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FirebaseAuth.instance.currentUser != null) {
        FirebaseService.startNotificationListener();
      }
    });

    final router = GoRouter(
      // Show splash screen first on app launch
      initialLocation: '/splash',

      // Redirect logic, but allow splash always
      redirect: (BuildContext context, GoRouterState state) {
        final loc = state.uri.toString();
        // Do not redirect away from splash
        if (loc == '/splash') return null;

        final user = FirebaseAuth.instance.currentUser;

        // Handle root path
        if (loc == '/') {
          return user == null ? '/login' : _homePathFor(user.email);
        }

        final onAuthPage = loc == '/login' || loc == '/register';
        if (user == null) {
          return onAuthPage ? null : '/login';
        }

        if (onAuthPage) {
          return _homePathFor(user.email);
        }

        // Otherwise no redirect
        return null;
      },

      routes: [
        GoRoute(path: '/splash', builder: (_, __) => SplashScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
        GoRoute(
          path: '/register',
          builder: (_, __) => const RegistrationPage(),
        ),

        // Home routes with shell route for better navigation
        ShellRoute(
          builder: (context, state, child) {
            // Enhanced shell for responsive handling
            return ResponsiveShell(child: BackButtonHandler(child: child));
          },
          routes: [
            GoRoute(
              path: '/employee',
              builder: (_, __) => const EmployeeHomePage(),
            ),
            GoRoute(
              path: '/manager',
              builder: (_, __) => const ManagerHomePage(),
            ),
            GoRoute(path: '/admin', builder: (_, __) => const AdminHomePage()),

            // Feature routes as children of home routes
            GoRoute(path: '/attendance', builder: (_, __) => AttendancePage()),
            GoRoute(path: '/create_team', builder: (_, __) => CreateTeamPage()),
            GoRoute(path: '/view_team_page', builder: (_, __) => TeamsPage()),
            GoRoute(path: '/create_task', builder: (_, __) => CreateTaskPage()),
            GoRoute(
              path: '/admin_view_task',
              builder: (_, __) => AdminViewTasksPage(),
            ),
            GoRoute(
              path: '/create_todo_list',
              builder: (_, __) => CreateTodoPage(),
            ),
            GoRoute(
              path: '/view_todo_list',
              builder: (_, __) => ViewTodosPage(),
            ),
            GoRoute(
              path: '/create_works_link_page',
              builder: (_, __) => WorkLinksPage(),
            ),
            GoRoute(
              path: '/view_works_link_page',
              builder: (_, __) => ViewWorkLinksPage(),
            ),
            GoRoute(
              path: '/create_target',
              builder: (_, __) => CreateTargetPage(),
            ),
            GoRoute(
              path: '/view_target',
              builder: (_, __) => ViewTargetsPage(),
            ),
            GoRoute(path: '/profile', builder: (_, __) => ProfilePage()),
            GoRoute(path: '/message_page', builder: (_, __) => MessagesPage()),
            GoRoute(
              path: '/target_dashboard',
              builder: (_, __) => TargetsDashboard(),
            ),
            GoRoute(
              path: '/create_daily_task',
              builder: (_, __) => CreateDailyTaskPage(),
            ),
            GoRoute(
              path: '/view_daily_task',
              builder: (_, __) => ViewDailyTasksPage(),
            ),
            GoRoute(
              path: '/create_accounts',
              builder: (_, __) => CreateAccountsPage(),
            ),
            GoRoute(
              path: '/view_accounts',
              builder: (_, __) => ViewAccountsPage(),
            ),
            GoRoute(
              path: '/create_leads',
              builder: (_, __) => CreateLeadPage(),
            ),
            GoRoute(path: '/view_leads', builder: (_, __) => ViewLeadsPage()),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Office Task Management',
      theme: _getThemeForPlatform(),
      routerConfig: router,
      // Add web-specific configurations
      builder: kIsWeb ? _webAppBuilder : null,
    );
  }

  // Platform-specific theme handling
  ThemeData _getThemeForPlatform() {
    if (kIsWeb) {
      // Web-optimized theme with better contrast and larger touch targets
      return appTheme.copyWith(
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Add any web-specific theme modifications here
      );
    }
    return appTheme;
  }

  // Web app builder for additional web optimizations
  Widget _webAppBuilder(BuildContext context, Widget? child) {
    return ScrollConfiguration(
      behavior: const MaterialScrollBehavior().copyWith(
        scrollbars: true, // Always show scrollbars on web
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  String _homePathFor(String? email) {
    final e = email?.toLowerCase() ?? '';
    if (e.endsWith('@admin.com')) return '/admin';
    if (e.endsWith('@manager.com')) return '/manager';
    return '/employee';
  }
}

// Enhanced responsive shell wrapper
class ResponsiveShell extends StatelessWidget {
  final Widget child;

  const ResponsiveShell({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Web-specific shell enhancements
      return FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: child,
      );
    }
    return child;
  }
}

// Utility class for responsive breakpoints (optional)
class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
  static const double widescreen = 1800;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobile;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobile &&
      MediaQuery.of(context).size.width < desktop;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktop;

  static bool isWidescreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= widescreen;
}
