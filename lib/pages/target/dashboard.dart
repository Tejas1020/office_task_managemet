import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:office_task_managemet/utils/colors.dart';
import 'package:fl_chart/fl_chart.dart';

class TargetsDashboard extends StatefulWidget {
  const TargetsDashboard({Key? key}) : super(key: key);

  @override
  State<TargetsDashboard> createState() => _TargetsDashboardState();
}

class _TargetsDashboardState extends State<TargetsDashboard>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late TabController _tabController;
  String _selectedPeriod = '30'; // days
  String _selectedTargetType = 'all';
  bool _isLoading = true;

  List<Map<String, dynamic>> _targets = [];
  Map<String, double> _targetTypeData = {};
  List<Map<String, dynamic>> _progressData = [];
  Map<String, dynamic> _summaryStats = {};

  final List<String> _periods = ['7', '30', '90', '365'];
  final List<String> _targetTypes = [
    'all',
    'Revenue',
    'Bookings',
    'EOI',
    'Agreement Value',
    'Invoice',
  ];

  final Map<String, Color> _targetTypeColors = {
    'Revenue': Colors.green,
    'Bookings': Colors.blue,
    'EOI': Colors.orange,
    'Agreement Value': Colors.purple,
    'Invoice': Colors.teal,
  };

  User? get currentUser => _auth.currentUser;

  bool get isAdmin {
    if (currentUser?.email == null) return false;
    return currentUser!.email!.toLowerCase().endsWith('@admin.com');
  }

  bool get isManager {
    if (currentUser?.email == null) return false;
    return currentUser!.email!.toLowerCase().endsWith('@manager.com');
  }

  bool get canViewAllData => isAdmin || isManager;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDashboardData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Load targets data
      final QuerySnapshot targetsSnapshot = await _firestore
          .collection('targets')
          .get();

      List<Map<String, dynamic>> targets = [];

      for (final doc in targetsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        targets.add({'id': doc.id, ...data});
      }

      // Filter targets based on user role and selected period
      final DateTime cutoffDate = DateTime.now().subtract(
        Duration(days: int.parse(_selectedPeriod)),
      );

      List<Map<String, dynamic>> filteredTargets = targets.where((target) {
        final createdAt = target['createdAt'] as Timestamp?;
        if (createdAt == null) return false;

        // Time filter
        if (createdAt.toDate().isBefore(cutoffDate)) return false;

        // Target type filter
        if (_selectedTargetType != 'all' &&
            target['targetType'] != _selectedTargetType)
          return false;

        return true;
      }).toList();

      // Calculate summary statistics
      _calculateSummaryStats(filteredTargets);

      // Process data for charts
      _processTargetTypeData(filteredTargets);
      _processProgressData(filteredTargets);

      setState(() {
        _targets = filteredTargets;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
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
      final value = target['targetValue'] ?? 0.0;
      typeData[type] = (typeData[type] ?? 0.0) + value;
    }

    _targetTypeData = typeData;
  }

  void _processProgressData(List<Map<String, dynamic>> targets) {
    // Group targets by week for progress tracking
    Map<String, List<double>> weeklyProgress = {};

    for (final target in targets) {
      final createdAt = target['createdAt'] as Timestamp?;
      if (createdAt == null) continue;

      final date = createdAt.toDate();
      final weekKey = '${date.year}-W${_getWeekOfYear(date)}';

      if (!weeklyProgress.containsKey(weekKey)) {
        weeklyProgress[weekKey] = [];
      }

      weeklyProgress[weekKey]!.add(target['progress'] ?? 0.0);
    }

    // Calculate average progress per week
    List<Map<String, dynamic>> progressData = [];
    final sortedWeeks = weeklyProgress.keys.toList()..sort();

    for (final week in sortedWeeks) {
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
      // 1 crore
      return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    } else if (value >= 100000) {
      // 1 lakh
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      // 1 thousand
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '₹${value.toStringAsFixed(0)}';
    }
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top row - main metrics
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Targets',
                  _summaryStats['totalTargets']?.toString() ?? '0',
                  Icons.flag,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Active',
                  _summaryStats['activeTargets']?.toString() ?? '0',
                  Icons.play_arrow,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Completed',
                  _summaryStats['completedTargets']?.toString() ?? '0',
                  Icons.check_circle,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Overdue',
                  _summaryStats['overdueTargets']?.toString() ?? '0',
                  Icons.warning,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Bottom row - value metrics
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Target Value',
                  _formatCurrency(_summaryStats['totalValue'] ?? 0.0),
                  Icons.monetization_on,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Achieved',
                  _formatCurrency(_summaryStats['achievedValue'] ?? 0.0),
                  Icons.trending_up,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Avg Progress',
                  '${(_summaryStats['avgProgress'] ?? 0.0).toStringAsFixed(1)}%',
                  Icons.analytics,
                  Colors.indigo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSummaryCard(
                  'Success Rate',
                  '${(_summaryStats['completionRate'] ?? 0.0).toStringAsFixed(1)}%',
                  Icons.star,
                  Colors.amber,
                ),
              ),
            ],
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
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 9,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressChart() {
    if (_progressData.isEmpty) {
      return _buildEmptyChart('No progress data available');
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress Trend',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.gray800,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
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
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < _progressData.length) {
                          final period = _progressData[value.toInt()]['period'];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              period.split('-W')[1] ?? '',
                              style: GoogleFonts.montserrat(
                                color: Colors.grey[600],
                                fontSize: 10,
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
                      interval: 20,
                      reservedSize: 40,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: GoogleFonts.montserrat(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                minX: 0,
                maxX: (_progressData.length - 1).toDouble(),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: _progressData.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value['progress'].toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.blue,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetTypeChart() {
    if (_targetTypeData.isEmpty) {
      return _buildEmptyChart('No target type data available');
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target Value by Type',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.gray800,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _targetTypeData.entries.map((entry) {
                        final color =
                            _targetTypeColors[entry.key] ?? Colors.grey;
                        final total = _targetTypeData.values.fold(
                          0.0,
                          (sum, value) => sum + value,
                        );
                        final percentage = (entry.value / total * 100);

                        return PieChartSectionData(
                          color: color,
                          value: entry.value,
                          title: '${percentage.toStringAsFixed(1)}%',
                          radius: 60,
                          titleStyle: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _targetTypeData.entries.map((entry) {
                    final color = _targetTypeColors[entry.key] ?? Colors.grey;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _formatCurrency(entry.value),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    if (_targets.isEmpty) {
      return _buildEmptyChart('No performance data available');
    }

    // Group targets by achievement level
    Map<String, int> performanceData = {
      '0-25%': 0,
      '26-50%': 0,
      '51-75%': 0,
      '76-99%': 0,
      '100%+': 0,
    };

    for (final target in _targets) {
      final progress = target['progress'] ?? 0.0;
      if (progress <= 25) {
        performanceData['0-25%'] = performanceData['0-25%']! + 1;
      } else if (progress <= 50) {
        performanceData['26-50%'] = performanceData['26-50%']! + 1;
      } else if (progress <= 75) {
        performanceData['51-75%'] = performanceData['51-75%']! + 1;
      } else if (progress < 100) {
        performanceData['76-99%'] = performanceData['76-99%']! + 1;
      } else {
        performanceData['100%+'] = performanceData['100%+']! + 1;
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Distribution',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.gray800,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    performanceData.values
                        .fold(0, (max, value) => value > max ? value : max)
                        .toDouble() +
                    2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final categories = performanceData.keys.toList();
                        if (value.toInt() >= 0 &&
                            value.toInt() < categories.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              categories[value.toInt()],
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
                      reservedSize: 30,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          value.toInt().toString(),
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                barGroups: performanceData.entries.map((entry) {
                  final index = performanceData.keys.toList().indexOf(
                    entry.key,
                  );
                  Color barColor;
                  switch (entry.key) {
                    case '0-25%':
                      barColor = Colors.red;
                      break;
                    case '26-50%':
                      barColor = Colors.orange;
                      break;
                    case '51-75%':
                      barColor = Colors.yellow;
                      break;
                    case '76-99%':
                      barColor = Colors.lightGreen;
                      break;
                    case '100%+':
                      barColor = Colors.green;
                      break;
                    default:
                      barColor = Colors.grey;
                  }

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.toDouble(),
                        color: barColor,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final recentTargets = _targets.take(5).toList();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Targets',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray800,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/view_target'),
                child: Text(
                  'View All',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentTargets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No recent targets',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            )
          else
            ...recentTargets.map((target) => _buildActivityItem(target)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> target) {
    final targetName = target['targetName'] ?? 'Unknown Target';
    final targetType = target['targetType'] ?? 'Unknown';
    final progress = target['progress'] ?? 0.0;
    final status = target['status'] ?? 'active';
    final assignmentType = target['assignmentType'] ?? 'individual';
    final assignedTo = assignmentType == 'individual'
        ? target['assignedToUserName'] ?? 'Unknown'
        : 'Team ${target['assignedToTeamName'] ?? 'Unknown'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (_targetTypeColors[targetType] ?? Colors.grey).withOpacity(
                0.1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.flag,
              size: 16,
              color: _targetTypeColors[targetType] ?? Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  targetName,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Assigned to $assignedTo',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${progress.toStringAsFixed(1)}%',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: progress >= 100 ? Colors.green : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'completed'
                      ? Colors.green[100]
                      : status == 'active'
                      ? Colors.blue[100]
                      : Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: status == 'completed'
                        ? Colors.green[700]
                        : status == 'active'
                        ? Colors.blue[700]
                        : Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(String message) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.analytics_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Time Period',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButton<String>(
                  value: _selectedPeriod,
                  isExpanded: true,
                  underline: Container(),
                  items: _periods.map((period) {
                    String label;
                    switch (period) {
                      case '7':
                        label = 'Last 7 days';
                        break;
                      case '30':
                        label = 'Last 30 days';
                        break;
                      case '90':
                        label = 'Last 3 months';
                        break;
                      case '365':
                        label = 'Last year';
                        break;
                      default:
                        label = period;
                    }
                    return DropdownMenuItem(
                      value: period,
                      child: Text(
                        label,
                        style: GoogleFonts.montserrat(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPeriod = value!;
                    });
                    _loadDashboardData();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Target Type',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                DropdownButton<String>(
                  value: _selectedTargetType,
                  isExpanded: true,
                  underline: Container(),
                  items: _targetTypes.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(
                        type == 'all' ? 'All Types' : type,
                        style: GoogleFonts.montserrat(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedTargetType = value!;
                    });
                    _loadDashboardData();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Targets Dashboard',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppColors.gray800,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.login, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Please log in to view dashboard',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Targets Dashboard',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.gray800,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadDashboardData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 14),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Progress'),
            Tab(text: 'Types'),
            Tab(text: 'Performance'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilters(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Overview Tab
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildSummaryCards(),
                            _buildRecentActivity(),
                          ],
                        ),
                      ),
                      // Progress Tab
                      SingleChildScrollView(child: _buildProgressChart()),
                      // Types Tab
                      SingleChildScrollView(child: _buildTargetTypeChart()),
                      // Performance Tab
                      SingleChildScrollView(child: _buildPerformanceChart()),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/create_target'),
        backgroundColor: AppColors.gray800,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
