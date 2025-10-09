import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class CasesListWidget extends StatefulWidget {
  const CasesListWidget({Key? key}) : super(key: key);

  @override
  State<CasesListWidget> createState() => _CasesListWidgetState();
}

class _CasesListWidgetState extends State<CasesListWidget> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _cases = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    setState(() => _isLoading = true);
    final cases = await _fetchCases();
    setState(() {
      _cases = cases;
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
          .select();

      
      if (response is List) {
        final cases = List<Map<String, dynamic>>.from(response);
        
        // Calculate status based on court date
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
      
    } catch (e, stackTrace) {
      print(stackTrace);
      return [];
    }
  }

  String _formatCourtDate(dynamic courtDate) {
    if (courtDate == null) return 'Date not set';
    
    try {
      final date = DateTime.parse(courtDate.toString());
      // Format: Monday, 13th July 2025
      final dayName = DateFormat('EEEE').format(date);
      final day = date.day;
      final monthName = DateFormat('MMMM').format(date);
      final year = date.year;
      
      // Add ordinal suffix (st, nd, rd, th)
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
  void _navigateToCaseDetails(String caseId) {
    // TODO: Implement navigation to case details page
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => CaseDetailsPage(caseId: caseId),
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_cases.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No upcoming court dates',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < _cases.length; i++) ...[
          _CourtDateCard(
            caseName: _cases[i]['name'] ?? 'Unnamed Case',
            caseNumber: _cases[i]['number'] ?? 'N/A',
            courtDate: _formatCourtDate(_cases[i]['courtDate']),
            courtName: _cases[i]['court_name'] ?? 'Court not specified',
            status: _cases[i]['status'] ?? 'Unknown status',
            onTap: () => _navigateToCaseDetails(_cases[i]['id'].toString()),
          ),
          if (i < _cases.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CourtDateCard extends StatelessWidget {
  final String caseName;
  final String caseNumber;
  final String courtDate;
  final String courtName;
  final String status;
  final VoidCallback onTap;

  const _CourtDateCard({
    required this.caseName,
    required this.caseNumber,
    required this.courtDate,
    required this.courtName,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = status == 'urgent';
    final isUpcoming = status == 'upcoming';
    final isNoWorries = status == 'no worries';
    final isExpired = status == 'expired';
    
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
                    color: const Color.fromARGB(255, 55, 218, 49).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color.fromARGB(255, 55, 218, 49).withOpacity(0.1),
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
                  Icons.access_time,
                  size: 16,
                  color: isUrgent 
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Text(
                  courtDate,
                  style: TextStyle(
                    fontSize: 14,
                    color: isUrgent 
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF1F2937),
                    fontWeight: isUrgent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
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
          ],
        ),
      ),
    );
  }
}

