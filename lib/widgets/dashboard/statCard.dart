import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lawdesk/screens/cases/casepage.dart';
import 'package:lawdesk/screens/calender/calender.dart';
import 'package:lawdesk/services/connectivity_service.dart';
import 'package:lawdesk/services/offline_storage_service.dart';

// Model class for stats data
class StatsData {
  final int totalCases;
  final int monthlyIncrease;
  final int dueThisWeek;
  final int urgentCases;

  StatsData({
    required this.totalCases,
    required this.monthlyIncrease,
    required this.dueThisWeek,
    required this.urgentCases,
  });
}

// Stateful Widget for Stats Section
class StatsSection extends StatefulWidget {
  const StatsSection({Key? key}) : super(key: key);

  @override
  State<StatsSection> createState() => StatsSectionState();
}

class StatsSectionState extends State<StatsSection> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;
  StatsData? _statsData;

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  String _calculateStatus(DateTime courtDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final courtDateOnly = DateTime(
      courtDate.year,
      courtDate.month,
      courtDate.day,
    );
    final daysDifference = courtDateOnly.difference(today).inDays;

    if (daysDifference < 0) {
      return 'expired';
    } else if (daysDifference <= 2) {
      return 'urgent';
    } else if (daysDifference > 2 && daysDifference < 5) {
      return 'upcoming';
    } else {
      return 'no worries';
    }
  }

  Future<void> loadStats() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if online
      if (connectivityService.isConnected) {
        // Fetch all cases for the user from server
        final response = await _supabase
            .from('cases')
            .select()
            .eq('user', user.id);

        if (response is List) {
          final cases = List<Map<String, dynamic>>.from(response);
          final statsData = _processStatsData(cases);

          setState(() {
            _statsData = statsData;
            _isLoading = false;
          });

          // Cache the stats
          await offlineStorage.cacheStats({
            'totalCases': statsData.totalCases,
            'monthlyIncrease': statsData.monthlyIncrease,
            'dueThisWeek': statsData.dueThisWeek,
            'urgentCases': statsData.urgentCases,
          });

          // Also cache the cases data for consistency
          await offlineStorage.cacheCases(cases);
        }
      } else {
        // Load from cache when offline
        final cachedStats = await offlineStorage.getCachedStats();

        if (cachedStats != null) {
          setState(() {
            _statsData = StatsData(
              totalCases: cachedStats['totalCases'] ?? 0,
              monthlyIncrease: cachedStats['monthlyIncrease'] ?? 0,
              dueThisWeek: cachedStats['dueThisWeek'] ?? 0,
              urgentCases: cachedStats['urgentCases'] ?? 0,
            );
            _isLoading = false;
          });
        } else {
          // No cached data available
          setState(() {
            _errorMessage = 'No offline data available';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading stats: $e');

      // Try to load from cache on error
      final cachedStats = await offlineStorage.getCachedStats();

      if (cachedStats != null && mounted) {
        setState(() {
          _statsData = StatsData(
            totalCases: cachedStats['totalCases'] ?? 0,
            monthlyIncrease: cachedStats['monthlyIncrease'] ?? 0,
            dueThisWeek: cachedStats['dueThisWeek'] ?? 0,
            urgentCases: cachedStats['urgentCases'] ?? 0,
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load stats';
          _isLoading = false;
        });
      }
    }
  }

  StatsData _processStatsData(List<Map<String, dynamic>> cases) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    int totalCases = cases.length;
    int monthlyIncrease = 0;
    int dueThisWeek = 0;
    int urgentCases = 0;

    // Process each case
    for (var case_ in cases) {
      if (case_['courtDate'] != null) {
        try {
          final courtDate = DateTime.parse(case_['courtDate']);
          final courtDateOnly = DateTime(
            courtDate.year,
            courtDate.month,
            courtDate.day,
          );

          // Calculate status
          final status = _calculateStatus(courtDate);

          // Count urgent cases
          if (status == 'urgent') {
            urgentCases++;
          }

          // Count cases due this week
          if (courtDateOnly.isAfter(
                startOfWeek.subtract(const Duration(days: 1)),
              ) &&
              courtDateOnly.isBefore(endOfWeek.add(const Duration(days: 1)))) {
            dueThisWeek++;
          }

          // Count monthly increase (cases with court date this month)
          if (courtDateOnly.isAfter(
                firstDayOfMonth.subtract(const Duration(days: 1)),
              ) &&
              courtDateOnly.isBefore(DateTime(now.year, now.month + 1, 1))) {
            monthlyIncrease++;
          }
        } catch (e) {
          // Skip cases with invalid dates
          continue;
        }
      }
    }

    return StatsData(
      totalCases: totalCases,
      monthlyIncrease: monthlyIncrease,
      dueThisWeek: dueThisWeek,
      urgentCases: urgentCases,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return _buildStatsSection();
  }

  Widget _buildLoadingState() {
    return Row(
      children: [
        Expanded(child: _buildLoadingCard()),
        const SizedBox(width: 16),
        Expanded(child: _buildLoadingCard()),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_card, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No stats available',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CasesPage()),
              );
            },
            child: _StatCard(
              title: 'Total Cases',
              value: '${_statsData!.totalCases}',
              icon: Icons.folder_outlined,
              color: const Color(0xFF1E3A8A),
              trend: '+${_statsData!.monthlyIncrease} this month',
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarPage()),
              );
            },
            child: _StatCard(
              title: 'Due This Week',
              value: '${_statsData!.dueThisWeek}',
              icon: Icons.event_outlined,
              color: const Color(0xFFF59E0B),
              trend: '${_statsData!.urgentCases} urgent',
            ),
          ),
        ),
      ],
    );
  }
}

// Your existing StatCard widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(trend, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
