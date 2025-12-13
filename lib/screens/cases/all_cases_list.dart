import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lawdesk/widgets/cases/details.dart';

class AllCasesListWidget extends StatefulWidget {
  const AllCasesListWidget({Key? key}) : super(key: key);

  @override
  State<AllCasesListWidget> createState() => AllCasesListWidgetState();
}

class AllCasesListWidgetState extends State<AllCasesListWidget> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _cases = [];
  List<Map<String, dynamic>> _filteredCases = [];
  bool _isLoading = true;

  // Filter and Search variables
  String _searchQuery = '';
  String _selectedFilter = 'All'; // All, Urgent, Upcoming, Expired, No Worries
  String _selectedSort = 'Date'; // Date, Name, Court

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
    
    _shimmerAnimation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOutSine,
    ));
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
              final courtDateOnly = DateTime(courtDate.year, courtDate.month, courtDate.day);
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
        
        return name.contains(query) || number.contains(query) || court.contains(query);
      }).toList();
    }

    // Apply sorting
    if (_selectedSort == 'Date') {
      filtered.sort((a, b) {
        if (a['courtDate'] == null && b['courtDate'] == null) return 0;
        if (a['courtDate'] == null) return 1;
        if (b['courtDate'] == null) return -1;
        return DateTime.parse(a['courtDate']).compareTo(DateTime.parse(b['courtDate']));
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
          case 1: return 'st';
          case 2: return 'nd';
          case 3: return 'rd';
          default: return 'th';
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CaseDetailsPage(caseId: caseId),
      ),
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
        // Search Bar
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
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
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
                    items: ['All', 'Urgent', 'Upcoming', 'Expired', 'No Worries']
                        .map((filter) => DropdownMenuItem(
                              value: filter,
                              child: Text(filter, style: const TextStyle(fontSize: 14)),
                            ))
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
                        .map((sort) => DropdownMenuItem(
                              value: sort,
                              child: Text('Sort: $sort', style: const TextStyle(fontSize: 14)),
                            ))
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
              padding: EdgeInsets.only(bottom: index < _filteredCases.length - 1 ? 12 : 0),
              child: _CourtDateCard(
                caseName: case_['name'] ?? 'Unnamed Case',
                caseNumber: case_['number'] ?? 'N/A',
                courtDate: _formatCourtDate(case_['courtDate']),
                courtTime: _formatTime(case_['time']),
                courtName: case_['court_name'] ?? 'Court not specified',
                description: case_['description'],
                status: case_['status'] ?? 'Unknown status',
                onTap: () => _navigateToCaseDetails(case_['id'].toString()),
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
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
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
                                      (_shimmerAnimation.value + index * 0.2).clamp(0.0, 1.0),
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
                                      (_shimmerAnimation.value + index * 0.2 + 0.1).clamp(0.0, 1.0),
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
                                (_shimmerAnimation.value + index * 0.2 + 0.2).clamp(0.0, 1.0),
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
                            (_shimmerAnimation.value + index * 0.2 + 0.3).clamp(0.0, 1.0),
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

// Reuse the same _CourtDateCard from list.dart (copy it here or extract to a shared widget)
// ... paste the entire _CourtDateCard class here ...
