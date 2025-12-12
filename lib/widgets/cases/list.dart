import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lawdesk/widgets/cases/details.dart';

class CasesListWidget extends StatefulWidget {
  const CasesListWidget({Key? key}) : super(key: key);

  @override
  State<CasesListWidget> createState() => _CasesListWidgetState();
}

class _CasesListWidgetState extends State<CasesListWidget> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _cases = [];
  bool _isLoading = true;

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _setupShimmerAnimation();
    _loadCases();
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

  Future<void> _loadCases() async {
    setState(() => _isLoading = true);
    
    final cases = await _fetchCases();
    
    // Add small delay for smooth transition
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (mounted) {
      setState(() {
        _cases = cases;
        _isLoading = false;
      });
    }
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

  void _navigateToCaseDetails(String caseId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CaseDetailsPage(caseId: caseId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _isLoading
          ? _buildShimmerLoading()
          : _cases.isEmpty
              ? _buildEmptyState()
              : _buildCasesList(),
    );
  }

  Widget _buildCasesList() {
    return Column(
      key: const ValueKey('cases_list'),
      children: [
        for (int i = 0; i < _cases.length; i++) ...[
          _CourtDateCard(
            caseName: _cases[i]['name'] ?? 'Unnamed Case',
            caseNumber: _cases[i]['number'] ?? 'N/A',
            courtDate: _formatCourtDate(_cases[i]['courtDate']),
            courtTime: _formatTime(_cases[i]['time']),
            courtName: _cases[i]['court_name'] ?? 'Court not specified',
            description: _cases[i]['description'],
            status: _cases[i]['status'] ?? 'Unknown status',
            onTap: () => _navigateToCaseDetails(_cases[i]['id'].toString()),
          ),
          if (i < _cases.length - 1) const SizedBox(height: 12),
        ],
      ],
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
              Icons.folder_open,
              size: 80,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Cases Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add cases to see them here',
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

  Widget _buildShimmerLoading() {
    return Column(
      key: const ValueKey('shimmer_loading'),
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
                    const SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: 180,
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
                            (_shimmerAnimation.value + index * 0.2 + 0.4).clamp(0.0, 1.0),
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

  const _CourtDateCard({
    required this.caseName,
    required this.caseNumber,
    required this.courtDate,
    required this.courtTime,
    required this.courtName,
    this.description,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = status == 'urgent';
    final isUpcoming = status == 'upcoming';
    final isNoWorries = status == 'no worries';
    final isExpired = status == 'expired';
    final hasDescription = description != null && description!.trim().isNotEmpty;
    
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 55, 218, 49).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color.fromARGB(255, 55, 218, 49).withOpacity(0.1)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B7280).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF6B7280).withOpacity(0.2)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
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
                  color: isUrgent ? const Color(0xFFF59E0B) : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    courtDate,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUrgent ? const Color(0xFFF59E0B) : const Color(0xFF1F2937),
                      fontWeight: isUrgent ? FontWeight.w600 : FontWeight.normal,
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
                    color: isUrgent ? const Color(0xFFF59E0B) : const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    courtTime,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUrgent ? const Color(0xFFF59E0B) : const Color(0xFF1F2937),
                      fontWeight: isUrgent ? FontWeight.w600 : FontWeight.normal,
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
          ],
        ),
      ),
    );
  }
}
