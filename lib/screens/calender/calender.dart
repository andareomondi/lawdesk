import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lawdesk/widgets/cases/details.dart';
import 'package:lawdesk/widgets/delightful_toast.dart';
import 'package:lawdesk/services/connectivity_service.dart';
import 'package:lawdesk/services/offline_storage_service.dart';
import 'package:lawdesk/widgets/offline_indicator.dart';

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
  Map<DateTime, List<Map<String, dynamic>>> _eventsMap = {};
  List<Map<String, dynamic>> _allCases = [];
  List<Map<String, dynamic>> _allEvents = [];
  bool _isLoading = true;
  bool _isOfflineMode = false;
  bool _isCalendarExpanded = false;
  double _dragOffset = 0;

  // View mode: 'month' or 'list'
  String _viewMode = 'month';

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;

    _isOfflineMode = !connectivityService.isConnected;

    // Listen to connectivity changes
    connectivityService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isOfflineMode = !isConnected;
        });

        if (isConnected) {
          _loadData();
        }
      }
    });

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Check if online
      if (connectivityService.isConnected) {
        // Load cases from server
        final casesResponse = await _supabase
            .from('cases')
            .select()
            .eq('user', user.id)
            .order('courtDate', ascending: true);

        if (casesResponse is List) {
          _allCases = List<Map<String, dynamic>>.from(casesResponse);
          // Cache cases
          await offlineStorage.cacheCases(_allCases);
        }

        // Load events for user's cases
        final userCasesIds = _allCases.map((c) => c['id']).toList();

        if (userCasesIds.isNotEmpty) {
          final eventsResponse = await _supabase
              .from('events')
              .select('*, cases!inner(user)')
              .inFilter('case', userCasesIds)
              .order('date', ascending: true);

          if (eventsResponse is List) {
            _allEvents = List<Map<String, dynamic>>.from(eventsResponse);
            // Cache events
            await offlineStorage.cacheEvents(_allEvents);
          }
        }

        _organizeDataByDate();
        setState(() => _isLoading = false);
      } else {
        // Load from cache when offline
        final cachedCases = await offlineStorage.getCachedCases();
        final cachedEvents = await offlineStorage.getCachedEvents();

        if (cachedCases != null) {
          _allCases = List<Map<String, dynamic>>.from(cachedCases);
        }

        if (cachedEvents != null) {
          _allEvents = List<Map<String, dynamic>>.from(cachedEvents);
        }

        _organizeDataByDate();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading calendar data: $e');

      // Try cache on error
      final cachedCases = await offlineStorage.getCachedCases();
      final cachedEvents = await offlineStorage.getCachedEvents();

      if (cachedCases != null) {
        _allCases = List<Map<String, dynamic>>.from(cachedCases);
      }

      if (cachedEvents != null) {
        _allEvents = List<Map<String, dynamic>>.from(cachedEvents);
      }

      _organizeDataByDate();
      setState(() => _isLoading = false);

      if (mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load calendar data.',
        );
      }
    }
  }

  void _organizeDataByDate() {
    _casesMap.clear();
    _eventsMap.clear();

    // Organize cases by court date
    for (var case_ in _allCases) {
      if (case_['courtDate'] != null) {
        try {
          final courtDate = DateTime.parse(case_['courtDate']);
          final dateKey = DateTime(
            courtDate.year,
            courtDate.month,
            courtDate.day,
          );

          if (!_casesMap.containsKey(dateKey)) {
            _casesMap[dateKey] = [];
          }
          _casesMap[dateKey]!.add(case_);
        } catch (e) {
          print('Error parsing case date: $e');
        }
      }
    }

    // Organize events by event date
    for (var event in _allEvents) {
      if (event['date'] != null) {
        try {
          final eventDate = DateTime.parse(event['date']);
          final dateKey = DateTime(
            eventDate.year,
            eventDate.month,
            eventDate.day,
          );

          if (!_eventsMap.containsKey(dateKey)) {
            _eventsMap[dateKey] = [];
          }
          _eventsMap[dateKey]!.add(event);
        } catch (e) {
          print('Error parsing event date: $e');
        }
      }
    }
  }

  List<Map<String, dynamic>> _getCasesForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _casesMap[dateKey] ?? [];
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _eventsMap[dateKey] ?? [];
  }

  bool _hasItemsOnDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _casesMap.containsKey(dateKey) || _eventsMap.containsKey(dateKey);
  }

  String _getStatus(
    DateTime courtDate,
    dynamic time, {
    bool isCompleted = false,
  }) {
    if (isCompleted) return 'completed';
    // Create full DateTime with time if available
    DateTime fullCourtDateTime;
    if (time != null && time.toString().isNotEmpty) {
      try {
        final timeParts = time.toString().split(':');
        if (timeParts.length >= 2) {
          final hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          fullCourtDateTime = DateTime(
            courtDate.year,
            courtDate.month,
            courtDate.day,
            hour,
            minute,
          );
        } else {
          fullCourtDateTime = DateTime(
            courtDate.year,
            courtDate.month,
            courtDate.day,
            23,
            59,
          );
        }
      } catch (e) {
        fullCourtDateTime = DateTime(
          courtDate.year,
          courtDate.month,
          courtDate.day,
          23,
          59,
        );
      }
    } else {
      fullCourtDateTime = DateTime(
        courtDate.year,
        courtDate.month,
        courtDate.day,
        23,
        59,
      );
    }

    final now = DateTime.now();
    final difference = fullCourtDateTime.difference(now);

    if (difference.isNegative) {
      return 'expired';
    } else if (difference.inHours <= 48) {
      return 'urgent';
    } else if (difference.inHours > 48 && difference.inHours < 120) {
      return 'upcoming';
    } else {
      return 'no worries';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF10B981);
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

  Color _getAgendaColor(String? agenda) {
    switch (agenda?.toLowerCase()) {
      case 'client meeting':
        return const Color(0xFF3B82F6);
      case 'court hearing':
        return const Color(0xFFEF4444);
      case 'brief hearing':
        return const Color(0xFFF59E0B);
      case 'case review':
        return const Color(0xFF8B5CF6);
      case 'document submission':
        return const Color(0xFF10B981);
      case 'consultation':
        return const Color(0xFF06B6D4);
      case 'settlement discussion':
        return const Color(0xFF14B8A6);
      case 'evidence collection':
        return const Color(0xFFA855F7);
      case 'witness interview':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getAgendaIcon(String? agenda) {
    switch (agenda?.toLowerCase()) {
      case 'client meeting':
        return Icons.people_outline;
      case 'court hearing':
        return Icons.gavel;
      case 'brief hearing':
        return Icons.hearing_outlined;
      case 'case review':
        return Icons.rate_review_outlined;
      case 'document submission':
        return Icons.upload_file_outlined;
      case 'consultation':
        return Icons.chat_bubble_outline;
      case 'settlement discussion':
        return Icons.handshake_outlined;
      case 'evidence collection':
        return Icons.folder_special_outlined;
      case 'witness interview':
        return Icons.record_voice_over_outlined;
      default:
        return Icons.event_outlined;
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
      MaterialPageRoute(builder: (context) => CaseDetailsPage(caseId: caseId)),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) {
          Navigator.of(context).pop(true);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
          elevation: 0,
          title: const Text(
            'Calendar',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _viewMode == 'month' ? Icons.list : Icons.calendar_month,
              ),
              onPressed: () {
                setState(() {
                  _viewMode = _viewMode == 'month' ? 'list' : 'month';
                });
              },
              tooltip: _viewMode == 'month' ? 'List View' : 'Calendar View',
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (_allCases.isEmpty && _allEvents.isEmpty)
            ? _buildEmptyState()
            : _viewMode == 'month'
            ? _buildCalendarView()
            : _buildListView(),
      ),
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
            'No Schedule Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add cases and events to see them here',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        if (_isOfflineMode) const OfflineDataIndicator(),
        GestureDetector(
          onVerticalDragUpdate: (details) {
            // Detect downward swipe to expand, upward to collapse
            if (details.delta.dy > 5 && !_isCalendarExpanded) {
              setState(() => _isCalendarExpanded = true);
            } else if (details.delta.dy < -5 && _isCalendarExpanded) {
              setState(() => _isCalendarExpanded = false);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildCalendarHeader(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return SizeTransition(
                          sizeFactor: animation,
                          axisAlignment: -1.0,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                  child: _isCalendarExpanded
                      ? KeyedSubtree(
                          key: const ValueKey('grid'),
                          child: _buildCalendarGrid(),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('row'),
                          child: _buildWeeklyRow(),
                        ),
                ),
                // Visual "Handle" for better affordance
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Scrollable list area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildSelectedDayItems(),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyRow() {
    final DateTime now = _selectedDay ?? DateTime.now();
    // Calculate the Sunday of the current week
    final DateTime startOfWeek = now.subtract(Duration(days: now.weekday % 7));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (index) {
          final date = startOfWeek.add(Duration(days: index));
          final isSelected =
              _selectedDay != null &&
              date.year == _selectedDay!.year &&
              date.month == _selectedDay!.month &&
              date.day == _selectedDay!.day;
          final hasItems = _hasItemsOnDay(date);

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDay = date),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1E3A8A)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? null
                      : Border.all(color: Colors.transparent),
                ),
                child: Column(
                  children: [
                    Text(
                      ['S', 'M', 'T', 'W', 'T', 'F', 'S'][index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white70 : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Small indicator dot for events
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasItems
                            ? (isSelected
                                  ? Colors.white
                                  : const Color(0xFF1E3A8A))
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
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
    final daysInMonth = DateTime(
      _focusedDay.year,
      _focusedDay.month + 1,
      0,
    ).day;
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7;

    // Calculate how many rows are actually needed (usually 5 or 6)
    final totalItems = firstWeekday + daysInMonth;
    final rowCount = (totalItems / 7).ceil();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (day) => Expanded(
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
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),

          ...List.generate(rowCount, (weekIndex) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (dayIndex) {
                final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 1;

                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 50));
                }

                final date = DateTime(
                  _focusedDay.year,
                  _focusedDay.month,
                  dayNumber,
                );
                final isSelected =
                    _selectedDay != null &&
                    date.year == _selectedDay!.year &&
                    date.month == _selectedDay!.month &&
                    date.day == _selectedDay!.day;
                final isToday =
                    date.year == DateTime.now().year &&
                    date.month == DateTime.now().month &&
                    date.day == DateTime.now().day;
                final hasItems = _hasItemsOnDay(date);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDay = date;
                        _isCalendarExpanded = false;
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
                          if (hasItems)
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

  Widget _buildSelectedDayItems() {
    if (_selectedDay == null) {
      return const Center(
        child: Text(
          'Select a day to view schedule',
          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
        ),
      );
    }

    final cases = _getCasesForDay(_selectedDay!);
    final events = _getEventsForDay(_selectedDay!);

    if (cases.isEmpty && events.isEmpty) {
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
              'Nothing scheduled on ${DateFormat('MMMM d, yyyy').format(_selectedDay!)}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              if (cases.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.gavel, size: 18, color: Color(0xFF1E3A8A)),
                      SizedBox(width: 8),
                      Text(
                        'Court Cases',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ),
                ...cases.map((case_) => _buildCaseCard(case_)),
                const SizedBox(height: 16),
              ],
              if (events.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_note,
                        size: 18,
                        color: Color(0xFF1E3A8A),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Events',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ),
                ...events.map((event) => _buildEventCard(event)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    final groupedData = <String, Map<String, List<Map<String, dynamic>>>>{};

    // Group cases by month
    for (var case_ in _allCases) {
      if (case_['courtDate'] != null) {
        try {
          final courtDate = DateTime.parse(case_['courtDate']);
          final monthKey = DateFormat('MMMM yyyy').format(courtDate);

          groupedData.putIfAbsent(monthKey, () => {'cases': [], 'events': []});
          groupedData[monthKey]!['cases']!.add(case_);
        } catch (e) {
          print('Error parsing case date: $e');
        }
      }
    }

    // Group events by month
    for (var event in _allEvents) {
      if (event['date'] != null) {
        try {
          final eventDate = DateTime.parse(event['date']);
          final monthKey = DateFormat('MMMM yyyy').format(eventDate);

          groupedData.putIfAbsent(monthKey, () => {'cases': [], 'events': []});
          groupedData[monthKey]!['events']!.add(event);
        } catch (e) {
          print('Error parsing event date: $e');
        }
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedData.length,
      itemBuilder: (context, index) {
        final monthKey = groupedData.keys.elementAt(index);
        final cases = groupedData[monthKey]!['cases']!;
        final events = groupedData[monthKey]!['events']!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isOfflineMode) const OfflineDataIndicator(),
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
            if (cases.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 8),
                child: Text(
                  'Court Cases',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              ...cases.map((case_) => _buildCaseCard(case_)),
              const SizedBox(height: 12),
            ],
            if (events.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 8),
                child: Text(
                  'Events',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              ...events.map((event) => _buildEventCard(event)),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCaseCard(Map<String, dynamic> case_) {
    final courtDate = DateTime.parse(case_['courtDate']);

    // Use progress_status from the database to determine if it's completed
    final bool isCompleted = case_['progress_status'] == true;

    // Pass the isCompleted flag to get the correct 'completed' status string
    final status = _getStatus(
      courtDate,
      case_['time'],
      isCompleted: isCompleted,
    );

    final statusColor = _getStatusColor(status);
    final time = _formatTime(case_['time']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          // High-contrast green border for completed cases
          color: isCompleted
              ? const Color(0xFF10B981)
              : statusColor.withOpacity(0.3),
          width: isCompleted ? 2 : 1,
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_circle : Icons.gavel,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          case_['name'] ?? 'Unnamed Case',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            // Subtle strike-through or grey color for completed text
                            color: isCompleted
                                ? const Color(0xFF6B7280)
                                : const Color(0xFF1F2937),
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
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
                  // Badge Logic
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      status == 'completed'
                          ? 'COMPLETED'
                          : status == 'urgent'
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
                  Icon(Icons.access_time, size: 16, color: statusColor),
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

  Widget _buildEventCard(Map<String, dynamic> event) {
    final agendaColor = _getAgendaColor(event['agenda']);
    final agendaIcon = _getAgendaIcon(event['agenda']);
    final time = _formatTime(event['time']);

    // Find the case this event belongs to
    final relatedCase = _allCases.firstWhere(
      (c) => c['id'] == event['case'],
      orElse: () => {},
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: agendaColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: relatedCase.isNotEmpty
            ? () => _navigateToCaseDetails(relatedCase['id'].toString())
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: agendaColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(agendaIcon, color: agendaColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['agenda'] ?? 'Event',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        if (relatedCase.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            relatedCase['name'] ?? 'Case',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (time.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: agendaColor),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 14,
                        color: agendaColor,
                        fontWeight: FontWeight.w500,
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
