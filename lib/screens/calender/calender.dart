import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lawdesk/widgets/cases/details.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final _supabase = Supabase.instance.client;
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _casesMap = {};
  List<Map<String, dynamic>> _allCases = [];
  bool _isLoading = true;
  
  // View mode: 'month' or 'list'
  String _viewMode = 'month';

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadCases();
  }

  Future<void> _loadCases() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      final response = await _supabase
          .from('cases')
          .select()
          .eq('user', user.id)
          .order('courtDate', ascending: true);

      if (response is List) {
        _allCases = List<Map<String, dynamic>>.from(response);
        _organizeCasesByDate();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading cases: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading cases: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _organizeCasesByDate() {
    _casesMap.clear();
    
    for (var case_ in _allCases) {
      if (case_['courtDate'] != null) {
        try {
          final courtDate = DateTime.parse(case_['courtDate']);
          final dateKey = DateTime(courtDate.year, courtDate.month, courtDate.day);
          
          if (!_casesMap.containsKey(dateKey)) {
            _casesMap[dateKey] = [];
          }
          _casesMap[dateKey]!.add(case_);
        } catch (e) {
          print('Error parsing date: $e');
        }
      }
    }
  }

  List<Map<String, dynamic>> _getCasesForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _casesMap[dateKey] ?? [];
  }

  bool _hasEventsOnDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _casesMap.containsKey(dateKey);
  }

  String _getStatus(DateTime courtDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final courtDateOnly = DateTime(courtDate.year, courtDate.month, courtDate.day);
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'urgent':
        return const Color(0xFFF59E0B);
      case 'upcoming':
        return const Color.fromARGB(255, 55, 218, 49);
      case 'expired':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF10B981);
    }
  }

  String _formatTime(dynamic time) {
    if (time == null || time.toString().isEmpty) return '';
    
    try {
      final timeParts = time.toString().split(':');
      if (timeParts.length >= 2) {
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        
        final period = hour >= 12 ? 'PM' : 'AM';
        final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final minuteStr = minute.toString().padLeft(2, '0');
        
        return '$hour12:$minuteStr $period';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  void _navigateToCaseDetails(String caseId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CaseDetailsPage(caseId: caseId),
      ),
    ).then((_) => _loadCases());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Cases Calendar',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_viewMode == 'month' ? Icons.list : Icons.calendar_month),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == 'month' ? 'list' : 'month';
              });
            },
            tooltip: _viewMode == 'month' ? 'List View' : 'Calendar View',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCases,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allCases.isEmpty
              ? _buildEmptyState()
              : _viewMode == 'month'
                  ? _buildCalendarView()
                  : _buildListView(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_outlined,
              size: 80,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Cases Scheduled',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add cases with court dates to see them here',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        _buildCalendarHeader(),
        _buildCalendarGrid(),
        const SizedBox(height: 16),
        Expanded(
          child: _buildSelectedDayCases(),
        ),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1);
              });
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(_focusedDay),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          
          // Calendar days
          ...List.generate(6, (weekIndex) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (dayIndex) {
                final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 1;
                
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 50));
                }
                
                final date = DateTime(_focusedDay.year, _focusedDay.month, dayNumber);
                final isSelected = _selectedDay != null &&
                    date.year == _selectedDay!.year &&
                    date.month == _selectedDay!.month &&
                    date.day == _selectedDay!.day;
                final isToday = date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;
                final hasEvents = _hasEventsOnDay(date);
                
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDay = date;
                      });
                    },
                    child: Container(
                      height: 50,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1E3A8A)
                            : isToday
                                ? const Color(0xFF1E3A8A).withOpacity(0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isToday && !isSelected
                              ? const Color(0xFF1E3A8A)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '$dayNumber',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : isToday
                                        ? const Color(0xFF1E3A8A)
                                        : const Color(0xFF1F2937),
                                fontWeight: isSelected || isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (hasEvents)
                            Positioned(
                              bottom: 4,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF1E3A8A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSelectedDayCases() {
    if (_selectedDay == null) {
      return const Center(
        child: Text(
          'Select a day to view cases',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
          ),
        ),
      );
    }

    final cases = _getCasesForDay(_selectedDay!);

    if (cases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No cases on ${DateFormat('MMMM d, yyyy').format(_selectedDay!)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cases.length,
            itemBuilder: (context, index) {
              return _buildCaseCard(cases[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    // Group cases by month
    final groupedCases = <String, List<Map<String, dynamic>>>{};
    
    for (var case_ in _allCases) {
      if (case_['courtDate'] != null) {
        try {
          final courtDate = DateTime.parse(case_['courtDate']);
          final monthKey = DateFormat('MMMM yyyy').format(courtDate);
          
          groupedCases.putIfAbsent(monthKey, () => []);
          groupedCases[monthKey]!.add(case_);
        } catch (e) {
          print('Error parsing date: $e');
        }
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedCases.length,
      itemBuilder: (context, index) {
        final monthKey = groupedCases.keys.elementAt(index);
        final cases = groupedCases[monthKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                monthKey,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            ...cases.map((case_) => _buildCaseCard(case_)),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildCaseCard(Map<String, dynamic> case_) {
    final courtDate = DateTime.parse(case_['courtDate']);
    final status = _getStatus(courtDate);
    final statusColor = _getStatusColor(status);
    final time = _formatTime(case_['time']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToCaseDetails(case_['id'].toString()),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          case_['name'] ?? 'Unnamed Case',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          case_['number'] ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      status == 'urgent'
                          ? 'URGENT'
                          : status == 'upcoming'
                              ? 'Upcoming'
                              : status == 'expired'
                                  ? 'Expired'
                                  : 'Scheduled',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    time.isNotEmpty ? time : 'Time not set',
                    style: TextStyle(
                      fontSize: 14,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (case_['court_name'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        case_['court_name'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
