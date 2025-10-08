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
      // Select ALL cases to debug
      final response = await _supabase
          .from('cases')
          .select();
      

      
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      
    } catch (e, stackTrace) {
      return [];
    }
  }

  String _formatCourtDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Date not set';
    
    try {
      // Parse Supabase timestamp format (2025-10-08 09:19:27.557383+00)
      DateTime date = DateTime.parse(dateString).toLocal();
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      if (dateOnly == today) {
        return 'Today, ${DateFormat('h:mm a').format(date)}';
      } else if (dateOnly == tomorrow) {
        return 'Tomorrow, ${DateFormat('h:mm a').format(date)}';
      } else {
        final daysDifference = dateOnly.difference(today).inDays;
        if (daysDifference > 0 && daysDifference <= 7) {
          return '${DateFormat('EEEE').format(date)}, ${DateFormat('h:mm a').format(date)}';
        } else if (daysDifference < 0) {
          // Past date
          return 'Past - ${DateFormat('MMM d, h:mm a').format(date)}';
        }
        return DateFormat('MMM d, h:mm a').format(date);
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _getStatus(String? courtDate) {
    if (courtDate == null) return 'upcoming';
    
    try {
      final date = DateTime.parse(courtDate);
      final now = DateTime.now();
      final difference = date.difference(now).inHours;
      
      if (difference <= 48) return 'urgent';
      return 'upcoming';
    } catch (e) {
      return 'upcoming';
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
            courtDate: _cases[i]['court_date'],
            courtName: _cases[i]['court_name'] ?? 'Court not specified',
            status: _cases[i]['status'] ?? 'Unknown Status',
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
              : const Color.fromARGB(255, 91, 204, 129),
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
              else
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
