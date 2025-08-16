import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:office_task_managemet/widgets/app_drawer.dart';
import 'package:office_task_managemet/widgets/header_module.dart';
import 'package:office_task_managemet/utils/colors.dart';
import 'package:office_task_managemet/utils/theme.dart';
import 'package:office_task_managemet/widgets/project_card.dart';
import 'package:office_task_managemet/widgets/simple_nav_bar.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get isWeb => kIsWeb;
  bool get isMobile => !kIsWeb;

  bool _isScreenWide(BuildContext context) {
    return MediaQuery.of(context).size.width > 800;
  }

  // Dashboard Data
  bool _isDashboardLoading = true;
  List<Map<String, dynamic>> _targets = [];
  Map<String, dynamic> _summaryStats = {};
  Map<String, double> _targetTypeData = {};
  List<Map<String, dynamic>> _progressData = [];

  final Map<String, Color> _targetTypeColors = {
    'Revenue': Colors.green,
    'Bookings': Colors.blue,
    'EOI': Colors.orange,
    'Agreement Value': Colors.purple,
    'Invoice': Colors.teal,
  };

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isDashboardLoading = true);

    try {
      final QuerySnapshot targetsSnapshot = await _firestore
          .collection('targets')
          .limit(50) // Limit for performance on home page
          .get();

      List<Map<String, dynamic>> targets = [];

      for (final doc in targetsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        targets.add({'id': doc.id, ...data});
      }

      // Filter recent targets (last 30 days)
      final DateTime cutoffDate = DateTime.now().subtract(
        const Duration(days: 30),
      );
      targets = targets.where((target) {
        final createdAt = target['createdAt'] as Timestamp?;
        return createdAt != null && createdAt.toDate().isAfter(cutoffDate);
      }).toList();

      _calculateSummaryStats(targets);
      _processTargetTypeData(targets);
      _processProgressData(targets);

      setState(() {
        _targets = targets;
        _isDashboardLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() => _isDashboardLoading = false);
    }
  }

  void _calculateSummaryStats(List<Map<String, dynamic>> targets) {
    final totalTargets = targets.length;
    final activeTargets = targets.where((t) => t['status'] == 'active').length;
    final completedTargets = targets
        .where((t) => t['status'] == 'completed')
        .length;
    final overdue = targets.where((t) {
      final dueDate = t['dueDate'] as Timestamp?;
      return dueDate != null &&
          DateTime.now().isAfter(dueDate.toDate()) &&
          t['status'] != 'completed';
    }).length;

    final totalValue = targets.fold(
      0.0,
      (sum, t) => sum + (t['targetValue'] ?? 0.0),
    );
    final achievedValue = targets.fold(
      0.0,
      (sum, t) => sum + (t['achievedValue'] ?? 0.0),
    );
    final avgProgress = targets.isEmpty
        ? 0.0
        : targets.fold(0.0, (sum, t) => sum + (t['progress'] ?? 0.0)) /
              targets.length;

    _summaryStats = {
      'totalTargets': totalTargets,
      'activeTargets': activeTargets,
      'completedTargets': completedTargets,
      'overdueTargets': overdue,
      'totalValue': totalValue,
      'achievedValue': achievedValue,
      'avgProgress': avgProgress,
      'completionRate': totalTargets > 0
          ? (completedTargets / totalTargets * 100)
          : 0.0,
    };
  }

  void _processTargetTypeData(List<Map<String, dynamic>> targets) {
    Map<String, double> typeData = {};
    for (final target in targets) {
      final type = target['targetType'] ?? 'Unknown';
      final value = (target['targetValue'] ?? 0.0).toDouble();
      typeData[type] = (typeData[type] ?? 0.0) + value;
    }
    _targetTypeData = typeData;
  }

  void _processProgressData(List<Map<String, dynamic>> targets) {
    Map<String, List<double>> weeklyProgress = {};

    for (final target in targets) {
      final createdAt = target['createdAt'] as Timestamp?;
      if (createdAt == null) continue;

      final date = createdAt.toDate();
      final weekKey = 'W${_getWeekOfYear(date)}';

      if (!weeklyProgress.containsKey(weekKey)) {
        weeklyProgress[weekKey] = [];
      }

      weeklyProgress[weekKey]!.add((target['progress'] ?? 0.0).toDouble());
    }

    List<Map<String, dynamic>> progressData = [];
    final sortedWeeks = weeklyProgress.keys.toList()..sort();

    for (final week in sortedWeeks.take(4)) {
      // Last 4 weeks
      final progresses = weeklyProgress[week]!;
      final avgProgress =
          progresses.fold(0.0, (sum, p) => sum + p) / progresses.length;

      progressData.add({
        'period': week,
        'progress': avgProgress,
        'targetCount': progresses.length,
      });
    }

    _progressData = progressData;
  }

  int _getWeekOfYear(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    return (dayOfYear / 7).ceil();
  }

  String _formatCurrency(double value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '₹${value.toStringAsFixed(0)}';
    }
  }

  Widget _buildDashboardSection() {
    if (_isDashboardLoading) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Performance Dashboard',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gray800,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/target_dashboard'),
                child: Text(
                  'View Full Dashboard',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Summary Cards
        _buildSummaryCards(),

        // Charts Row
        if (_isScreenWide(context))
          _buildWebChartsLayout()
        else
          _buildMobileChartsLayout(),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: _isScreenWide(context) ? 4 : 2,
            childAspectRatio: _isScreenWide(context) ? 2.0 : 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildSummaryCard(
                'Total Targets',
                _summaryStats['totalTargets']?.toString() ?? '0',
                Icons.flag,
                Colors.blue,
              ),
              _buildSummaryCard(
                'Active Targets',
                _summaryStats['activeTargets']?.toString() ?? '0',
                Icons.play_arrow,
                Colors.green,
              ),
              _buildSummaryCard(
                'Completed',
                _summaryStats['completedTargets']?.toString() ?? '0',
                Icons.check_circle,
                Colors.orange,
              ),
              _buildSummaryCard(
                'Success Rate',
                '${(_summaryStats['completionRate'] ?? 0.0).toStringAsFixed(1)}%',
                Icons.trending_up,
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Caption for Summary Cards
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Key Performance Indicators: Overview of target status and completion rates for the last 30 days. Success rate indicates the percentage of targets completed successfully.',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontStyle: FontStyle.italic,
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

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Adaptive sizing based on available space
          final isSmall = constraints.maxHeight < 80;
          final iconSize = isSmall ? 18.0 : 24.0;
          final valueSize = isSmall ? 14.0 : 18.0;
          final titleSize = isSmall ? 10.0 : 12.0;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: iconSize),
              SizedBox(height: isSmall ? 4 : 8),
              Flexible(
                child: Text(
                  value,
                  style: GoogleFonts.montserrat(
                    fontSize: valueSize,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: isSmall ? 2 : 4),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: titleSize,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWebChartsLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 800) {
            // Stack charts vertically on smaller screens
            return Column(
              children: [
                _buildProgressChart(),
                const SizedBox(height: 16),
                _buildTargetTypeChart(),
              ],
            );
          } else {
            // Side by side layout for wider screens
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildProgressChart()),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: _buildTargetTypeChart()),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildMobileChartsLayout() {
    return Column(
      children: [
        _buildProgressChart(),
        const SizedBox(height: 16),
        _buildTargetTypeChart(),
      ],
    );
  }

  Widget _buildProgressChart() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartHeight = (constraints.maxWidth * 0.6).clamp(160.0, 220.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Progress Trend',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gray800,
                ),
              ),
              const SizedBox(height: 16),
              ClipRect(
                child: SizedBox(
                  height: chartHeight,
                  child: _progressData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.show_chart,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No data available',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 25,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: Colors.grey[300]!,
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 25,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 &&
                                        value.toInt() < _progressData.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          _progressData[value
                                              .toInt()]['period'],
                                          style: GoogleFonts.montserrat(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 35,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${value.toInt()}%',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 9,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            minX: 0,
                            maxX: (_progressData.length - 1).toDouble(),
                            minY: 0,
                            maxY: 100,
                            lineBarsData: [
                              LineChartBarData(
                                spots: _progressData.asMap().entries.map((
                                  entry,
                                ) {
                                  return FlSpot(
                                    entry.key.toDouble(),
                                    (entry.value['progress'] as num).toDouble(),
                                  );
                                }).toList(),
                                isCurved: true,
                                color: Colors.blue,
                                barWidth: 2,
                                dotData: FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.blue.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Caption for Progress Chart
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.trending_up, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Weekly Performance Trend: Shows average target completion progress over the last 4 weeks. Higher values indicate better team performance and goal achievement.',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.green[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTargetTypeChart() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartHeight = (constraints.maxWidth * 0.6).clamp(160.0, 200.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Target Distribution',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gray800,
                ),
              ),
              const SizedBox(height: 16),
              ClipRect(
                child: SizedBox(
                  height: chartHeight,
                  child: _targetTypeData.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.pie_chart_outline_rounded,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No data available',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: PieChart(
                                PieChartData(
                                  sectionsSpace: 2,
                                  centerSpaceRadius: (chartHeight * 0.15).clamp(
                                    15.0,
                                    25.0,
                                  ),
                                  sections: _targetTypeData.entries.map((
                                    entry,
                                  ) {
                                    final color =
                                        _targetTypeColors[entry.key] ??
                                        Colors.grey;
                                    final total = _targetTypeData.values.fold(
                                      0.0,
                                      (sum, value) => sum + value,
                                    );
                                    final percentage = total == 0
                                        ? 0
                                        : (entry.value / total * 100);

                                    return PieChartSectionData(
                                      color: color,
                                      value: entry.value,
                                      title:
                                          '${percentage.toStringAsFixed(0)}%',
                                      radius: (chartHeight * 0.15).clamp(
                                        20.0,
                                        35.0,
                                      ),
                                      titleStyle: GoogleFonts.montserrat(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 1,
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: _targetTypeData.entries.take(5).map(
                                    (entry) {
                                      final color =
                                          _targetTypeColors[entry.key] ??
                                          Colors.grey;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: color,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                entry.key,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Caption for Target Type Chart
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.withOpacity(0.1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.pie_chart, size: 16, color: Colors.purple[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Target Type Breakdown: Distribution of target values across different categories (Revenue, Bookings, EOI, etc.). Helps identify focus areas and resource allocation.',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.purple[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
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
    CompactProjectCard(
      title: 'Dashboard',
      count: 20,
      icon: Icons.dashboard_outlined,
      backgroundColor: const Color.fromARGB(255, 108, 107, 142),
      foregroundColor: Colors.white,
      route: '/target_dashboard',
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
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      backgroundColor: appTheme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: HeaderModule(
              userName: 'Admin',
              bgcolor: AppColors.gray800,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Dashboard Section
                  _buildDashboardSection(),
                  const SizedBox(height: 24),
                  // Quick Access Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Quick Access',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gray800,
                              ),
                            ),
                            IconButton(
                              onPressed: _loadDashboardData,
                              icon: Icon(
                                Icons.refresh,
                                color: Colors.grey[600],
                              ),
                              tooltip: 'Refresh Data',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Quick Access Caption
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.apps,
                                size: 14,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Management tools and modules for efficient operations. Click any card to access specific features and functionalities.',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: Colors.orange[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Project Cards — **FORCE TWO COLUMNS ON MOBILE**
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2, // 👈 two columns on mobile
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.35, // Good balance for phone screens
                      children: _projectCards,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SimpleNavBar(
        currentIndex: 0,
        route1: '/admin',
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
    return Scaffold(
      backgroundColor: appTheme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Sidebar for web
          Container(
            width: 280,
            color: AppColors.gray800,
            child: Column(
              children: [
                // Header section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.gray800,
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
                        backgroundColor: Colors.blue,
                        child: const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Admin Panel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Dashboard',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Navigation menu
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      _buildSidebarItem(Icons.home_outlined, 'Home', '/admin'),
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
                        Icons.addchart_rounded,
                        'Create leads',
                        '/create_leads',
                      ),
                      _buildSidebarItem(
                        Icons.add_rounded,
                        'Create Todo',
                        '/create_todo_list',
                      ),
                      _buildSidebarItem(
                        Icons.add_link_outlined,
                        'Create links',
                        '/create_works_link_page',
                      ),
                      _buildSidebarItem(
                        Icons.flag_outlined,
                        'Create Targets',
                        '/create_target',
                      ),
                      _buildSidebarItem(
                        Icons.person_add_sharp,
                        'Create Teams',
                        '/create_team',
                      ),
                      _buildSidebarItem(
                        Icons.task_sharp,
                        'Create Daily Tasks',
                        '/create_daily_task',
                      ),
                      _buildSidebarItem(
                        Icons.account_balance,
                        'Create Accounts',
                        '/create_accounts',
                      ),
                      _buildSidebarItem(
                        Icons.person_outline,
                        'Profile',
                        '/profile',
                      ),
                      const Divider(color: Colors.white24, height: 32),
                      const Padding(
                        padding: EdgeInsets.symmetric(
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
                          'Admin Dashboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray800,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Icons.refresh, color: AppColors.gray600),
                          onPressed: _loadDashboardData,
                          tooltip: 'Refresh Dashboard',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.notifications_outlined,
                            color: AppColors.gray600,
                          ),
                          onPressed: () {},
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.settings_outlined,
                            color: AppColors.gray600,
                          ),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),

                // Main content with dashboard and project cards
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Dashboard Section
                        _buildDashboardSection(),
                        const SizedBox(height: 24),

                        // Project Cards Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Management Tools',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.gray800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Management Tools Caption
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.settings,
                                      size: 16,
                                      color: Colors.orange[700],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Comprehensive suite of management tools for tasks, targets, teams, accounts, and leads. Each module provides detailed views and management capabilities.',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          color: Colors.orange[700],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Project Grid
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: _getCrossAxisCount(
                                        context,
                                      ),
                                      crossAxisSpacing: 20,
                                      mainAxisSpacing: 20,
                                      childAspectRatio: 1.6,
                                    ),
                                itemCount: _projectCards.length,
                                itemBuilder: (context, index) {
                                  return ClipRect(child: _projectCards[index]);
                                },
                              );
                            },
                          ),
                        ),
                      ],
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
          color: isActive ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.blue : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.blue : Colors.white70,
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
    if (width > 1600) return 5;
    if (width > 1400) return 4;
    if (width > 1100) return 3;
    if (width > 800) return 2;
    return 1;
  }
}
