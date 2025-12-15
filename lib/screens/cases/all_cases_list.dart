import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lawdesk/widgets/cases/details.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AllCasesListWidget extends StatefulWidget {
  const AllCasesListWidget({Key? key}) : super(key: key);

  @override
  State<AllCasesListWidget> createState() => AllCasesListWidgetState();
}

class AllCasesListWidgetState extends State<AllCasesListWidget>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _cases = [];
  List<Map<String, dynamic>> _filteredCases = [];
  List<Map<String, dynamic>> _displayedCases = [];
  bool _isLoading = true;

  // Filter and Search variables
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedDateRange = 'All';
  String _selectedSort = 'Date';
  bool _sortAscending = true;

  // Pagination
  static const int _batchSize = 30;

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _setupShimmerAnimation();
    loadCases();
  }

  void _setupShimmerAnimation() {
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  // Public method for parent to call
  Future<void> loadCases() async {
    setState(() => _isLoading = true);
    final cases = await _fetchCases();
    setState(() {
      _cases = cases;
      _applyFilters();
      _isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchCases() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return [];
    }

    try {
      final response = await _supabase
          .from('cases')
          .select()
          .eq('user', user.id)
          .order('courtDate', ascending: true);

      if (response is List) {
        final cases = List<Map<String, dynamic>>.from(response);

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        for (var case_ in cases) {
          if (case_['courtDate'] != null) {
            try {
              final courtDate = DateTime.parse(case_['courtDate']);
              final courtDateOnly = DateTime(
                courtDate.year,
                courtDate.month,
                courtDate.day,
              );
              final daysDifference = courtDateOnly.difference(today).inDays;

              if (daysDifference < 0) {
                case_['status'] = 'expired';
              } else if (daysDifference <= 2) {
                case_['status'] = 'urgent';
              } else if (daysDifference > 2 && daysDifference < 5) {
                case_['status'] = 'upcoming';
              } else {
                case_['status'] = 'no worries';
              }
            } catch (e) {
              case_['status'] = 'unknown';
            }
          }
        }

        return cases;
      }

      return [];
    } catch (e, stackTrace) {
      return [];
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_cases);

    // Apply status filter
    if (_selectedStatus != 'All') {
      filtered = filtered.where((case_) {
        return case_['status']?.toLowerCase() == _selectedStatus.toLowerCase();
      }).toList();
    }

    // Apply date range filter
    filtered = _applyDateRangeFilter(filtered);

    // Apply search query (enhanced)
    if (_searchQuery.isNotEmpty) {
      filtered = _applyEnhancedSearch(filtered);
    }

    // Apply sorting
    filtered = _applySorting(filtered);

    setState(() {
      _filteredCases = filtered;
      _displayedCases = filtered.take(_batchSize).toList();
    });
  }

  List<Map<String, dynamic>> _applyDateRangeFilter(
    List<Map<String, dynamic>> cases,
  ) {
    if (_selectedDateRange == 'All') return cases;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return cases.where((case_) {
      if (case_['courtDate'] == null) return false;

      try {
        final courtDate = DateTime.parse(case_['courtDate']);
        final courtDateOnly = DateTime(
          courtDate.year,
          courtDate.month,
          courtDate.day,
        );

        switch (_selectedDateRange) {
          case 'Today':
            return courtDateOnly == today;
          case 'Tomorrow':
            return courtDateOnly == today.add(const Duration(days: 1));
          case 'This Week':
            final endOfWeek = today.add(Duration(days: 7 - today.weekday));
            return courtDateOnly.isAfter(
                  today.subtract(const Duration(days: 1)),
                ) &&
                courtDateOnly.isBefore(endOfWeek.add(const Duration(days: 1)));
          case 'Next Week':
            final startOfNextWeek = today.add(
              Duration(days: 7 - today.weekday + 1),
            );
            final endOfNextWeek = startOfNextWeek.add(const Duration(days: 6));
            return courtDateOnly.isAfter(
                  startOfNextWeek.subtract(const Duration(days: 1)),
                ) &&
                courtDateOnly.isBefore(
                  endOfNextWeek.add(const Duration(days: 1)),
                );
          case 'This Month':
            return courtDateOnly.year == today.year &&
                courtDateOnly.month == today.month;
          default:
            return true;
        }
      } catch (e) {
        return false;
      }
    }).toList();
  }

  List<Map<String, dynamic>> _applyEnhancedSearch(
    List<Map<String, dynamic>> cases,
  ) {
    return cases.where((case_) {
      final query = _searchQuery.toLowerCase();

      // Search in basic fields
      final name = (case_['name'] ?? '').toString().toLowerCase();
      final number = (case_['number'] ?? '').toString().toLowerCase();
      final court = (case_['court_name'] ?? '').toString().toLowerCase();
      final description = (case_['description'] ?? '').toString().toLowerCase();

      // Search in formatted date parts
      final formattedDate = _formatCourtDate(case_['courtDate']).toLowerCase();

      // Extract date parts for granular search
      String monthName = '', dayName = '', dayWithSuffix = '', year = '';
      if (case_['courtDate'] != null) {
        try {
          final date = DateTime.parse(case_['courtDate']);
          monthName = DateFormat('MMMM').format(date).toLowerCase();
          dayName = DateFormat('EEEE').format(date).toLowerCase();
          dayWithSuffix = '${date.day}${_getOrdinalSuffix(date.day)}'
              .toLowerCase();
          year = date.year.toString();
        } catch (e) {}
      }

      return name.contains(query) ||
          number.contains(query) ||
          court.contains(query) ||
          description.contains(query) ||
          formattedDate.contains(query) ||
          monthName.contains(query) ||
          dayName.contains(query) ||
          dayWithSuffix.contains(query) ||
          year.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _applySorting(List<Map<String, dynamic>> cases) {
    final sorted = List<Map<String, dynamic>>.from(cases);

    if (_selectedSort == 'Date') {
      sorted.sort((a, b) {
        if (a['courtDate'] == null && b['courtDate'] == null) return 0;
        if (a['courtDate'] == null) return 1;
        if (b['courtDate'] == null) return -1;
        final comparison = DateTime.parse(
          a['courtDate'],
        ).compareTo(DateTime.parse(b['courtDate']));
        return _sortAscending ? comparison : -comparison;
      });
    } else if (_selectedSort == 'Name') {
      sorted.sort((a, b) {
        final nameA = (a['name'] ?? '').toString().toLowerCase();
        final nameB = (b['name'] ?? '').toString().toLowerCase();
        final comparison = nameA.compareTo(nameB);
        return _sortAscending ? comparison : -comparison;
      });
    } else if (_selectedSort == 'Court') {
      sorted.sort((a, b) {
        final courtA = (a['court_name'] ?? '').toString().toLowerCase();
        final courtB = (b['court_name'] ?? '').toString().toLowerCase();
        final comparison = courtA.compareTo(courtB);
        return _sortAscending ? comparison : -comparison;
      });
    }

    return sorted;
  }

  void _updateSearch(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _updateStatus(String status) {
    setState(() {
      _selectedStatus = status;
      _applyFilters();
    });
  }

  void _updateDateRange(String dateRange) {
    setState(() {
      _selectedDateRange = dateRange;
      _applyFilters();
    });
  }

  void _updateSort(String sort) {
    setState(() {
      _selectedSort = sort;
      _applyFilters();
    });
  }

  void _toggleSortOrder() {
    setState(() {
      _sortAscending = !_sortAscending;
      _applyFilters();
    });
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _selectedStatus = 'All';
      _selectedDateRange = 'All';
      _applyFilters();
    });
  }

  void _loadMoreCases() {
    setState(() {
      final currentLength = _displayedCases.length;
      final remainingCases = _filteredCases
          .skip(currentLength)
          .take(_batchSize)
          .toList();
      _displayedCases.addAll(remainingCases);
    });
  }

  bool get _hasActiveFilters {
    return _selectedStatus != 'All' ||
        _selectedDateRange != 'All' ||
        _searchQuery.isNotEmpty;
  }

  String _formatCourtDate(dynamic courtDate) {
    if (courtDate == null) return 'Date not set';

    try {
      final date = DateTime.parse(courtDate.toString());
      final dayName = DateFormat('EEEE').format(date);
      final day = date.day;
      final monthName = DateFormat('MMMM').format(date);
      final year = date.year;

      return '$dayName, $day${_getOrdinalSuffix(day)} $monthName $year';
    } catch (e) {
      return courtDate.toString();
    }
  }

  String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
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
      return time.toString();
    } catch (e) {
      return '';
    }
  }

  Future<void> _navigateToCaseDetails(String caseId) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CaseDetailsPage(caseId: caseId)),
    );

    if (result == true && mounted) {
      loadCases();
    }
  }

  Future<void> _showPostponeModal(String caseId) async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Postpone Court Date',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.calendar_today,
                      color: Color(0xFF1E3A8A),
                    ),
                    title: Text(
                      selectedDate == null
                          ? 'Select New Date'
                          : DateFormat(
                              'EEEE, MMMM d, yyyy',
                            ).format(selectedDate!),
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedDate == null
                            ? const Color(0xFF6B7280)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 1),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 2),
                        ),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(
                      Icons.access_time,
                      color: Color(0xFF1E3A8A),
                    ),
                    title: Text(
                      selectedTime == null
                          ? 'Select New Time'
                          : selectedTime!.format(context),
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedTime == null
                            ? const Color(0xFF6B7280)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedTime = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedDate == null || selectedTime == null
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await _postponeCase(
                            caseId,
                            selectedDate!,
                            selectedTime!,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _postponeCase(
    String caseId,
    DateTime newDate,
    TimeOfDay newTime,
  ) async {
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(newDate);
      final formattedTime =
          '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}:00';

      await _supabase
          .from('cases')
          .update({'courtDate': formattedDate, 'time': formattedTime})
          .eq('id', caseId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Court date postponed successfully'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );

        await loadCases();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to postpone court date'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _exportCasesToFile() async {
    try {
      if (await Permission.storage.request().isGranted) {
        final buffer = StringBuffer();
        buffer.writeln('LAWDESK CASES EXPORT');
        buffer.writeln(
          'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
        );
        buffer.writeln('Total Cases: ${_cases.length}');
        buffer.writeln('=' * 60);
        buffer.writeln();

        for (var case_ in _cases) {
          buffer.writeln('CASE: ${case_['name'] ?? 'Unnamed'}');
          buffer.writeln('Number: ${case_['number'] ?? 'N/A'}');
          buffer.writeln('Court: ${case_['court_name'] ?? 'Not specified'}');
          buffer.writeln('Date: ${_formatCourtDate(case_['courtDate'])}');
          buffer.writeln('Time: ${_formatTime(case_['time'])}');
          buffer.writeln('Status: ${case_['status'] ?? 'Unknown'}');
          if (case_['description'] != null &&
              case_['description'].toString().isNotEmpty) {
            buffer.writeln('Description: ${case_['description']}');
          }
          buffer.writeln('-' * 60);
          buffer.writeln();
        }

        final directory = await getExternalStorageDirectory();
        final fileName =
            'lawdesk_cases_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.txt';
        final file = File('${directory!.path}/$fileName');
        await file.writeAsString(buffer.toString());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cases exported successfully'),
              backgroundColor: const Color(0xFF10B981),
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission required to export'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to export cases'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        const SizedBox(height: 12),
        _buildStatusFilterChips(),
        const SizedBox(height: 8),
        _buildDateRangeChips(),
        const SizedBox(height: 8),
        _buildSortChips(),
        const SizedBox(height: 12),
        _buildResultsCount(),
        const SizedBox(height: 12),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _isLoading
                ? _buildShimmerLoading()
                : _filteredCases.isEmpty
                ? _buildEmptyState()
                : _buildCasesList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: _updateSearch,
              decoration: const InputDecoration(
                hintText: 'Search by name, number, court, date...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
            ),
          ),
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(
                Icons.clear_all,
                color: Color(0xFF6B7280),
                size: 20,
              ),
              onPressed: _clearAllFilters,
              tooltip: 'Clear all filters',
            ),
          IconButton(
            icon: const Icon(
              Icons.download,
              color: Color(0xFF1E3A8A),
              size: 20,
            ),
            onPressed: _exportCasesToFile,
            tooltip: 'Export cases',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChips() {
    final statuses = ['All', 'Urgent', 'Upcoming', 'No Worries', 'Expired'];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          final status = statuses[index];
          final isSelected = _selectedStatus == status;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(status),
              selected: isSelected,
              onSelected: (selected) => _updateStatus(status),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF1E3A8A).withOpacity(0.15),
              checkmarkColor: const Color(0xFF1E3A8A),
              labelStyle: TextStyle(
                color: isSelected
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFF6B7280),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF1E3A8A)
                    : const Color(0xFFE5E7EB),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateRangeChips() {
    final dateRanges = [
      'All',
      'Today',
      'Tomorrow',
      'This Week',
      'Next Week',
      'This Month',
    ];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: dateRanges.length,
        itemBuilder: (context, index) {
          final dateRange = dateRanges[index];
          final isSelected = _selectedDateRange == dateRange;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(dateRange),
              selected: isSelected,
              onSelected: (selected) => _updateDateRange(dateRange),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF10B981).withOpacity(0.15),
              checkmarkColor: const Color(0xFF10B981),
              labelStyle: TextStyle(
                color: isSelected
                    ? const Color(0xFF10B981)
                    : const Color(0xFF6B7280),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF10B981)
                    : const Color(0xFFE5E7EB),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortChips() {
    final sortOptions = ['Date', 'Name', 'Court'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            'Sort by:',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...sortOptions.map((sort) {
                    final isSelected = _selectedSort == sort;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(sort),
                        selected: isSelected,
                        onSelected: (selected) => _updateSort(sort),
                        backgroundColor: Colors.white,
                        selectedColor: const Color(
                          0xFF3B82F6,
                        ).withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF6B7280),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFFE5E7EB),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _sortAscending ? 0 : 0.5,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      color: const Color(0xFF1E3A8A),
                      onPressed: _toggleSortOrder,
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF1E3A8A,
                        ).withOpacity(0.1),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(8),
                      ),
                      tooltip: _sortAscending
                          ? 'Sort Ascending'
                          : 'Sort Descending',
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

  Widget _buildResultsCount() {
    final showing = _displayedCases.length;
    final total = _filteredCases.length;
    final allCases = _cases.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        _hasActiveFilters
            ? 'Showing $showing of $total cases • $allCases total'
            : '$total case${total == 1 ? '' : 's'}',
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCasesList() {
    return ListView(
      key: const ValueKey('cases_list'),
      padding: const EdgeInsets.all(16),
      children: [
        ..._displayedCases.asMap().entries.map((entry) {
          final index = entry.key;
          final case_ = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < _displayedCases.length - 1 ? 12 : 0,
            ),
            child: _CourtDateCard(
              caseName: case_['name'] ?? 'Unnamed Case',
              caseNumber: case_['number'] ?? 'N/A',
              courtDate: _formatCourtDate(case_['courtDate']),
              courtTime: _formatTime(case_['time']),
              courtName: case_['court_name'] ?? 'Court not specified',
              description: case_['description'],
              status: case_['status'] ?? 'Unknown status',
              caseId: case_['id'].toString(),
              onTap: () => _navigateToCaseDetails(case_['id'].toString()),
              onPostpone: _showPostponeModal,
            ),
          );
        }).toList(),

        if (_displayedCases.length < _filteredCases.length)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _loadMoreCases,
                icon: const Icon(Icons.expand_more, size: 20),
                label: Text(
                  'Load More (${_filteredCases.length - _displayedCases.length} remaining)',
                  style: const TextStyle(fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const ValueKey('empty'),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _hasActiveFilters ? Icons.filter_list_off : Icons.folder_open,
                size: 64,
                color: const Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Cases Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hasActiveFilters
                  ? 'No cases match your current filters'
                  : 'Add cases to see them here',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _clearAllFilters,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView(
      key: const ValueKey('shimmer_loading'),
      padding: const EdgeInsets.all(16),
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index < 2 ? 12 : 0),
          child: AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 16,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFFE5E7EB),
                                      const Color(0xFFF3F4F6),
                                      const Color(0xFFE5E7EB),
                                    ],
                                    stops: [
                                      0.0,
                                      (_shimmerAnimation.value + index * 0.2)
                                          .clamp(0.0, 1.0),
                                      1.0,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 12,
                                width: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFFE5E7EB),
                                      const Color(0xFFF3F4F6),
                                      const Color(0xFFE5E7EB),
                                    ],
                                    stops: [
                                      0.0,
                                      (_shimmerAnimation.value +
                                              index * 0.2 +
                                              0.1)
                                          .clamp(0.0, 1.0),
                                      1.0,
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 24,
                          width: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFE5E7EB),
                                const Color(0xFFF3F4F6),
                                const Color(0xFFE5E7EB),
                              ],
                              stops: [
                                0.0,
                                (_shimmerAnimation.value + index * 0.2 + 0.2)
                                    .clamp(0.0, 1.0),
                                1.0,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFE5E7EB),
                            const Color(0xFFF3F4F6),
                            const Color(0xFFE5E7EB),
                          ],
                          stops: [
                            0.0,
                            (_shimmerAnimation.value + index * 0.2 + 0.3).clamp(
                              0.0,
                              1.0,
                            ),
                            1.0,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

class _CourtDateCard extends StatelessWidget {
  final String caseName;
  final String caseNumber;
  final String courtDate;
  final String courtTime;
  final String courtName;
  final String? description;
  final String status;
  final String caseId;
  final VoidCallback onTap;
  final Function(String)? onPostpone;
  const _CourtDateCard({
    required this.caseName,
    required this.caseNumber,
    required this.courtDate,
    required this.courtTime,
    required this.courtName,
    this.description,
    required this.status,
    required this.caseId,
    required this.onTap,
    this.onPostpone,
  });
  @override
  Widget build(BuildContext context) {
    final isUrgent = status == 'urgent';
    final isUpcoming = status == 'upcoming';
    final isNoWorries = status == 'no worries';
    final isExpired = status == 'expired';
    final hasDescription =
        description != null && description!.trim().isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUrgent
                ? const Color(0xFFF59E0B)
                : isUpcoming
                ? const Color.fromARGB(255, 91, 204, 129)
                : isExpired
                ? const Color(0xFF6B7280)
                : const Color(0xFF10B981),
            width: isUrgent ? 2 : 1,
          ),
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        caseName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        caseNumber,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUrgent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.3),
                      ),
                    ),
                    child: const Text(
                      'URGENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF59E0B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else if (isUpcoming)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(
                        255,
                        55,
                        218,
                        49,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color.fromARGB(
                          255,
                          55,
                          218,
                          49,
                        ).withOpacity(0.1),
                      ),
                    ),
                    child: const Text(
                      'Upcoming',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 55, 218, 49),
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else if (isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B7280).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF6B7280).withOpacity(0.2),
                      ),
                    ),
                    child: const Text(
                      'Expired',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                      ),
                    ),
                    child: const Text(
                      'No Worries',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
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
                  Icons.calendar_today,
                  size: 16,
                  color: isUrgent
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    courtDate,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUrgent
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF1F2937),
                      fontWeight: isUrgent
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            if (courtTime.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: isUrgent
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    courtTime,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUrgent
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF1F2937),
                      fontWeight: isUrgent
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
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
                    courtName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
            if (hasDescription) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.note_outlined,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4B5563),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!isExpired && onPostpone != null) ...[
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE5E7EB), height: 1),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => onPostpone!(caseId),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.schedule, size: 16, color: Color(0xFF1E3A8A)),
                      SizedBox(width: 8),
                      Text(
                        'Postpone Court Date',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

