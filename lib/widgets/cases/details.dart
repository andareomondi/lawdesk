import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lawdesk/screens/documents/upload.dart';
import 'package:lawdesk/config/supabase_config.dart';

class CaseDetailsPage extends StatefulWidget {
  final String caseId;

  const CaseDetailsPage({Key? key, required this.caseId}) : super(key: key);

  @override
  State<CaseDetailsPage> createState() => _CaseDetailsPageState();
}

class _CaseDetailsPageState extends State<CaseDetailsPage> {
  final _supabase = SupabaseConfig.client;
  Map<String, dynamic>? _caseData;
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isDeleting = false;
  bool _isLoadingDocuments = false;

  // Controllers for editing
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _courtNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _loadCaseDetails();
    _loadDocuments();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _courtNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCaseDetails() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await _supabase
          .from('cases')
          .select()
          .eq('id', widget.caseId)
          .single();
      
      setState(() {
        _caseData = response;
        _initializeControllers();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading case details: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error loading case details'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoadingDocuments = true);
    try {
      final response = await _supabase
          .from('documents')
          .select()
          .eq('case_id', int.parse(widget.caseId))
          .order('created_at', ascending: false)
          .limit(3);

      setState(() {
        _documents = List<Map<String, dynamic>>.from(response);
        _isLoadingDocuments = false;
      });
    } catch (e) {
      print('Error loading documents: $e');
      setState(() => _isLoadingDocuments = false);
    }
  }

  void _initializeControllers() {
    if (_caseData != null) {
      _nameController.text = _caseData!['name'] ?? '';
      _numberController.text = _caseData!['number'] ?? '';
      _courtNameController.text = _caseData!['court_name'] ?? '';
      _descriptionController.text = _caseData!['description'] ?? '';
      
      if (_caseData!['courtDate'] != null) {
        _selectedDate = DateTime.parse(_caseData!['courtDate']);
      }
      
      if (_caseData!['time'] != null) {
        final timeParts = _caseData!['time'].toString().split(':');
        if (timeParts.length >= 2) {
          _selectedTime = TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1]),
          );
        }
      }
    }
  }

  String _getStatus() {
    if (_caseData == null || _caseData!['courtDate'] == null) {
      return 'unknown';
    }
    
    try {
      final courtDate = DateTime.parse(_caseData!['courtDate']);
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
    } catch (e) {
      return 'unknown';
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
    if (time == null || time.toString().isEmpty) return 'Not set';
    
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
      return 'Not set';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _getFileExtension(String fileName) {
    return fileName.split('.').last.toUpperCase();
  }

  IconData _getDocumentIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'evidence':
        return Icons.verified_outlined;
      case 'contract':
        return Icons.description_outlined;
      case 'report':
        return Icons.assignment_outlined;
      case 'affidavit':
        return Icons.gavel;
      case 'pleading':
        return Icons.article_outlined;
      case 'judgment':
        return Icons.account_balance_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _getDocumentColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'evidence':
        return const Color(0xFF10B981);
      case 'contract':
        return const Color(0xFF1E3A8A);
      case 'report':
        return const Color(0xFF8B5CF6);
      case 'affidavit':
        return const Color(0xFFF59E0B);
      case 'pleading':
        return const Color(0xFF3B82F6);
      case 'judgment':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF10B981),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF10B981),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Case name cannot be empty'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? timeString;
      if (_selectedTime != null) {
        timeString = '${_selectedTime!.hour.toString().padLeft(2, '0')}:'
                    '${_selectedTime!.minute.toString().padLeft(2, '0')}:00';
      }

      await _supabase.from('cases').update({
        'name': _nameController.text.trim(),
        'number': _numberController.text.trim(),
        'court_name': _courtNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'courtDate': _selectedDate?.toIso8601String(),
        'time': timeString,
      }).eq('id', widget.caseId);

      await _loadCaseDetails();
      
      setState(() {
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Case updated successfully'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error updating case: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating case: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _deleteCase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Case'),
        content: const Text('Are you sure you want to delete this case? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await _supabase
          .from('cases')
          .delete()
          .eq('id', widget.caseId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Case deleted successfully'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error deleting case: $e');
      setState(() => _isDeleting = false);
      
      if (mounted) {
        String errorMessage = 'Failed to delete case';
        
        if (e.toString().contains('permission')) {
          errorMessage = 'You don\'t have permission to delete this case';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection';
        } else if (e.toString().contains('not found')) {
          errorMessage = 'Case not found';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _deleteCase,
            ),
          ),
        );
      }
    }
  }

  void _navigateToDocuments() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CaseDocumentsPage(
          caseId: int.parse(widget.caseId),
          caseName: _caseData!['name'] ?? 'Case',
        ),
      ),
    );
    
    // Refresh documents when returning from documents page
    if (result != null || mounted) {
      _loadDocuments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Case' : 'Case Details',
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!_isEditing && !_isLoading && !_isDeleting)
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF10B981)),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _initializeControllers();
                });
              },
            ),
          if (_isEditing)
            TextButton(
              onPressed: _isLoading ? null : _saveChanges,
              child: Text(
                'Save',
                style: TextStyle(
                  color: _isLoading ? Colors.grey : const Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isDeleting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Deleting case...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _caseData == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Color(0xFF6B7280),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Case not found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This case may have been deleted',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Go Back'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Card
                          _buildStatusCard(),
                          const SizedBox(height: 16),
                          
                          // Case Information Card
                          _buildInfoCard(),
                          const SizedBox(height: 16),
                          
                          // Court Details Card
                          _buildCourtDetailsCard(),
                          
                          if (_caseData!['description'] != null && 
                              _caseData!['description'].toString().trim().isNotEmpty &&
                              !_isEditing) ...[
                            const SizedBox(height: 16),
                            _buildDescriptionCard(),
                          ],

                          // Documents Section
                          if (!_isEditing) ...[
                            const SizedBox(height: 16),
                            _buildDocumentsSection(),
                          ],
                          
                          // Delete Button
                          if (!_isEditing) ...[
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _deleteCase,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete Case'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          
                          if (_isEditing) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _isEditing = false;
                                    _initializeControllers();
                                  });
                                },
                                child: const Text('Cancel'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildDocumentsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.folder_outlined,
                      color: Color(0xFF1E3A8A),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Documents',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: _navigateToDocuments,
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Color(0xFF1E3A8A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (_isLoadingDocuments)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_documents.isEmpty)
            _buildEmptyDocumentsState()
          else
            Column(
              children: [
                for (int i = 0; i < _documents.length; i++) ...[
                  _buildDocumentPreviewCard(_documents[i]),
                  if (i < _documents.length - 1) const SizedBox(height: 8),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _navigateToDocuments,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Upload Document'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E3A8A),
                      side: const BorderSide(color: Color(0xFF1E3A8A)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyDocumentsState() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.folder_open_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No documents yet',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Upload case documents to get started',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _navigateToDocuments,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload First Document'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentPreviewCard(Map<String, dynamic> doc) {
    return InkWell(
      onTap: _navigateToDocuments,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getDocumentColor(doc['document_type']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _getFileExtension(doc['file_name']),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getDocumentColor(doc['document_type']),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc['file_name'],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        _getDocumentIcon(doc['document_type']),
                        size: 12,
                        color: const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        doc['document_type'] ?? 'Document',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const Text(
                        ' • ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      Text(
                        _formatFileSize(doc['file_size'] ?? 0),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _getStatus();
    final isUrgent = status == 'urgent';
    final isUpcoming = status == 'upcoming';
    final isExpired = status == 'expired';
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    if (isUrgent) {
      statusColor = const Color(0xFFF59E0B);
      statusText = 'URGENT';
      statusIcon = Icons.warning_amber_rounded;
    } else if (isUpcoming) {
      statusColor = const Color.fromARGB(255, 55, 218, 49);
      statusText = 'Upcoming';
      statusIcon = Icons.event_available;
    } else if (isExpired) {
      statusColor = const Color(0xFF6B7280);
      statusText = 'Expired';
      statusIcon = Icons.event_busy;
    } else {
      statusColor = const Color(0xFF10B981);
      statusText = 'No Worries';
      statusIcon = Icons.check_circle_outline;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCourtDate(_caseData!['courtDate']),
                  style: TextStyle(
                    fontSize: 14,
                    color: statusColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Text(
            'Case Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          
          if (_isEditing) ...[
            _buildTextField(
              label: 'Case Name',
              controller: _nameController,
              icon: Icons.folder_outlined,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Case Number',
              controller: _numberController,
              icon: Icons.numbers,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Description (Optional)',
              controller: _descriptionController,
              icon: Icons.note_outlined,
              maxLines: 3,
            ),
          ] else ...[
            _buildInfoRow(
              icon: Icons.folder_outlined,
              label: 'Case Name',
              value: _caseData!['name'] ?? 'N/A',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.numbers,
              label: 'Case Number',
              value: _caseData!['number'] ?? 'N/A',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourtDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Text(
            'Court Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 16),
          
          if (_isEditing) ...[
            _buildDateTimePicker(),
            const SizedBox(height: 12),
            _buildTimePicker(),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Court Name',
              controller: _courtNameController,
              icon: Icons.location_on_outlined,
            ),
          ] else ...[
            _buildInfoRow(
              icon: Icons.calendar_today,
              label: 'Court Date',
              value: _formatCourtDate(_caseData!['courtDate']),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.access_time,
              label: 'Time',
              value: _formatTime(_caseData!['time']),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.location_on_outlined,
              label: 'Court Name',
              value: _caseData!['court_name'] ?? 'Not specified',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Row(
            children: [
              Icon(Icons.note_outlined, size: 18, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _caseData!['description'] ?? '',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Court Date',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Color(0xFF6B7280)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDate != null
                        ? _formatCourtDate(_selectedDate!.toIso8601String())
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedDate != null
                          ? const Color(0xFF1F2937)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Time',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 20, color: Color(0xFF6B7280)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedTime != null
                        ? _selectedTime!.format(context)
                        : 'Select time',
                    style: TextStyle(
                      fontSize: 14,
                      color: _selectedTime != null
                          ? const Color(0xFF1F2937)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
