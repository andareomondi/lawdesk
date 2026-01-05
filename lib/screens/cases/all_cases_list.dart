import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lawdesk/widgets/cases/details.dart';
import 'package:lawdesk/widgets/delightful_toast.dart';
import 'package:lawdesk/services/connectivity_service.dart';
import 'package:lawdesk/services/offline_storage_service.dart';
import 'package:lawdesk/utils/offline_action_helper.dart';

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
  bool _isLoading = true;
  bool _isOfflineMode = false;
  // Filter and Search variables
  String _searchQuery = '';
  String _selectedFilter = 'All'; // All, Urgent, Upcoming, Expired, No Worries
  String _selectedSort = 'Date'; // Date, Name, Court

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  @override
  void initState() {
    super.initState();
    _setupShimmerAnimation();

    // Listen to connectivity changes
    connectivityService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isOfflineMode = !isConnected;
        });

        if (isConnected) {
          // Refresh data when connection is restored
          loadCases();
        }
      }
    });

    _isOfflineMode = !connectivityService.isConnected;
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

  Future<void> _showPostponeModal(String caseId) async {
    // Check if online before allowing postponement
    if (!OfflineActionHelper.canPerformAction(
      context,
      actionName: 'postpone case',
    )) {
      return;
    }

    DateTime? selectedDate;
    TimeOfDay? selectedTime;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Postpone Court Date'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      selectedDate == null
                          ? 'Select New Date'
                          : DateFormat(
                              'EEEE, MMMM d, yyyy',
                            ).format(selectedDate!),
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
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: Text(
                      selectedTime == null
                          ? 'Select New Time'
                          : selectedTime!.format(context),
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
                  child: const Text('Cancel'),
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
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white),
                  ),
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
      // Format the date and time
      final formattedDate = DateFormat('yyyy-MM-dd').format(newDate);
      final formattedTime =
          '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}:00';

      // Update in Supabase
      await _supabase
          .from('cases')
          .update({'courtDate': formattedDate, 'time': formattedTime})
          .eq('id', caseId);

      // Show success message
      if (mounted) {
        AppToast.showSuccess(
          context: context,
          title: "Success!",
          message: "Case postpone scheduled successfully.",
        );
        await loadCases();
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context: context,
          title: "Error",
          message: "Failed to postpone case. Please try again.",
        );
      }
    }
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
      // Check if online
      if (connectivityService.isConnected) {
        final response = await _supabase
            .from('cases')
            .select()
            .eq('user', user.id)
            .order('courtDate', ascending: true);

        if (response is List) {
          final cases = List<Map<String, dynamic>>.from(response);

          // Process status for each case
          final processedCases = _processStatusForCases(cases);

          // Cache all cases
          await offlineStorage.cacheCases(processedCases);

          return processedCases;
        }

        return [];
      } else {
        // Load from cache when offline
        final cachedCases = await offlineStorage.getCachedCases();

        if (cachedCases != null) {
          final cases = List<Map<String, dynamic>>.from(cachedCases);

          // Process status with current date
          final processedCases = _processStatusForCases(cases);

          return processedCases;
        }

        return [];
      }
    } catch (e) {
      print('Error loading cases: $e');

      // Try to load from cache on error
      final cachedCases = await offlineStorage.getCachedCases();

      if (cachedCases != null) {
        final cases = List<Map<String, dynamic>>.from(cachedCases);
        final processedCases = _processStatusForCases(cases);
        return processedCases;
      }

      return [];
    }
  }

  List<Map<String, dynamic>> _processStatusForCases(
    List<Map<String, dynamic>> cases,
  ) {
    final now = DateTime.now();

    for (var case_ in cases) {
      if (case_['courtDate'] != null) {
        try {
          final courtDate = DateTime.parse(case_['courtDate']);

          // Create full DateTime with time if available
          DateTime fullCourtDateTime;
          if (case_['time'] != null && case_['time'].toString().isNotEmpty) {
            final timeParts = case_['time'].toString().split(':');
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
          } else {
            fullCourtDateTime = DateTime(
              courtDate.year,
              courtDate.month,
              courtDate.day,
              23,
              59,
            );
          }

          final difference = fullCourtDateTime.difference(now);

          if (difference.isNegative) {
            case_['status'] = 'expired';
          } else if (difference.inHours <= 48) {
            case_['status'] = 'urgent';
          } else if (difference.inHours > 48 && difference.inHours < 120) {
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

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_cases);

    // Apply status filter
    if (_selectedFilter != 'All') {
      filtered = filtered.where((case_) {
        return case_['status']?.toLowerCase() == _selectedFilter.toLowerCase();
      }).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((case_) {
        final name = (case_['name'] ?? '').toString().toLowerCase();
        final number = (case_['number'] ?? '').toString().toLowerCase();
        final court = (case_['court_name'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();

        return name.contains(query) ||
            number.contains(query) ||
            court.contains(query);
      }).toList();
    }

    // Apply sorting
    if (_selectedSort == 'Date') {
      filtered.sort((a, b) {
        if (a['courtDate'] == null && b['courtDate'] == null) return 0;
        if (a['courtDate'] == null) return 1;
        if (b['courtDate'] == null) return -1;
        return DateTime.parse(
          a['courtDate'],
        ).compareTo(DateTime.parse(b['courtDate']));
      });
    } else if (_selectedSort == 'Name') {
      filtered.sort((a, b) {
        final nameA = (a['name'] ?? '').toString().toLowerCase();
        final nameB = (b['name'] ?? '').toString().toLowerCase();
        return nameA.compareTo(nameB);
      });
    } else if (_selectedSort == 'Court') {
      filtered.sort((a, b) {
        final courtA = (a['court_name'] ?? '').toString().toLowerCase();
        final courtB = (b['court_name'] ?? '').toString().toLowerCase();
        return courtA.compareTo(courtB);
      });
    }

    setState(() {
      _filteredCases = filtered;
    });
  }

  void _updateSearch(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _updateFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _applyFilters();
    });
  }

  void _updateSort(String sort) {
    setState(() {
      _selectedSort = sort;
      _applyFilters();
    });
  }

  String _formatCourtDate(dynamic courtDate) {
    if (courtDate == null) return 'Date not set';

    try {
      final date = DateTime.parse(courtDate.toString());
      final dayName = DateFormat('EEEE').format(date);
      final day = date.day;
      final monthName = DateFormat('MMMM').format(date);
      final year = date.year;

      String getOrdinalSuffix(int day) {
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

      return '$dayName, $day${getOrdinalSuffix(day)} $monthName $year';
    } catch (e) {
      return courtDate.toString();
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
    // Allow viewing case details offline, but editing will be blocked inside
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CaseDetailsPage(caseId: caseId)),
    );

    // If case was deleted OR updated, reload
    if (result == true && mounted) {
      loadCases();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Show offline indicator when offline
        if (_isOfflineMode)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFF59E0B).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.cloud_off,
                    color: Color(0xFFF59E0B),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Viewing Offline Data',
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Editing disabled until connection restored',
                        style: TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        Container(
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
                    hintText: 'Search by case name, number, or court...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Filter and Sort Row
        Row(
          children: [
            // Filter Dropdown
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    isExpanded: true,
                    icon: const Icon(Icons.filter_list, size: 20),
                    items:
                        ['All', 'Urgent', 'Upcoming', 'Expired', 'No Worries']
                            .map(
                              (filter) => DropdownMenuItem(
                                value: filter,
                                child: Text(
                                  filter,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => _updateFilter(value!),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Sort Dropdown
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSort,
                    isExpanded: true,
                    icon: const Icon(Icons.sort, size: 20),
                    items: ['Date', 'Name', 'Court']
                        .map(
                          (sort) => DropdownMenuItem(
                            value: sort,
                            child: Text(
                              'Sort: $sort',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => _updateSort(value!),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${_filteredCases.length} case${_filteredCases.length == 1 ? '' : 's'} found',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Cases List
        if (_isLoading)
          _buildShimmerLoading()
        else if (_filteredCases.isEmpty)
          _buildEmptyState()
        else
          ..._filteredCases.asMap().entries.map((entry) {
            final index = entry.key;
            final case_ = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < _filteredCases.length - 1 ? 12 : 0,
              ),
              child: _CourtDateCard(
                caseName: case_['name'] ?? 'Unnamed Case',
                caseNumber: case_['number'] ?? 'N/A',
                courtDate: _formatCourtDate(case_['courtDate']),
                courtTime: _formatTime(case_['time']),
                courtName: case_['court_name'] ?? 'Court not specified',
                description: case_['description'],
                status: case_['status'] ?? 'Unknown status',
                onTap: () => _navigateToCaseDetails(case_['id'].toString()),
                caseId: case_['id'].toString(),
                onPostpone: _showPostponeModal,
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
              child: const Icon(
                Icons.search_off,
                size: 64,
                color: Color(0xFF1E3A8A),
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
              _searchQuery.isNotEmpty
                  ? 'Try adjusting your search or filters'
                  : 'Add cases to see them here',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Column(
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
  final VoidCallback onTap;
  final String caseId;
  final Function(String caseId)? onPostpone;

  const _CourtDateCard({
    required this.caseName,
    required this.caseNumber,
    required this.courtDate,
    required this.courtTime,
    required this.courtName,
    this.description,
    required this.status,
    required this.onTap,
    required this.caseId,
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
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => onPostpone!(caseId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, size: 16, color: Color(0xFF1E3A8A)),
                      const SizedBox(width: 8),
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
