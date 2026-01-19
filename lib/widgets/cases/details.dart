import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lawdesk/screens/documents/upload.dart';
import 'package:lawdesk/config/supabase_config.dart';
import 'package:lawdesk/widgets/delightful_toast.dart';
import 'package:lawdesk/services/connectivity_service.dart';
import 'package:lawdesk/services/offline_storage_service.dart';
import 'package:lawdesk/utils/offline_action_helper.dart';

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
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isDeleting = false;
  bool _isLoadingDocuments = false;
  bool _isLoadingNotes = false;
  bool _isLoadingEvents = false;
  bool _isOfflineMode = false;
  // Controllers for editing
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _courtNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool get _isCompleted =>
      _caseData != null && _caseData!['progress_status'] == true;

  // Controllers for notes
  final _noteNameController = TextEditingController();
  final _noteDescriptionController = TextEditingController();
  String _selectedNoteType = 'Quick Note';

  // Controllers for events
  final _eventAgendaController = TextEditingController();
  DateTime? _eventSelectedDate;
  TimeOfDay? _eventSelectedTime;
  String _selectedAgendaType = 'Client Meeting';
  bool _isCustomAgenda = false;
  int? _editingEventId;

  final List<String> _agendaOptions = [
    'Client Meeting',
    'Court Hearing',
    'Brief Hearing',
    'Case Review',
    'Document Submission',
    'Consultation',
    'Settlement Discussion',
    'Evidence Collection',
    'Witness Interview',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    _loadCaseDetails();
    _loadDocuments();
    _loadNotes();
    _loadEvents();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _courtNameController.dispose();
    _descriptionController.dispose();
    _noteNameController.dispose();
    _noteDescriptionController.dispose();
    _eventAgendaController.dispose();
    super.dispose();
  }

  Future<void> _toggleCaseCompletion() async {
    if (!OfflineActionHelper.canPerformAction(
      context,
      actionName: 'update case status',
    )) {
      return;
    }

    final newStatus = !_isCompleted;
    setState(() => _isLoading = true);

    try {
      await _supabase
          .from('cases')
          .update({'progress_status': newStatus})
          .eq('id', widget.caseId);

      await _loadCaseDetails();

      if (mounted) {
        AppToast.showSuccess(
          context: context,
          title: newStatus ? 'Case Completed' : 'Case Reopened',
          message: newStatus
              ? 'This case has been marked as complete.'
              : 'This case is now active.',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to update case status.',
        );
      }
    }
  }

  Future<void> _loadCaseDetails() async {
    setState(() => _isLoading = true);

    try {
      // Check if online
      if (connectivityService.isConnected) {
        final response = await _supabase
            .from('cases')
            .select()
            .eq('id', widget.caseId)
            .single();

        setState(() {
          _caseData = response;
          _initializeControllers();
          _isLoading = false;
          _isOfflineMode = false;
        });

        // Cache individual case data
        final cachedCases = await offlineStorage.getCachedCases();
        if (cachedCases != null) {
          // Update the specific case in cache
          final casesList = List<Map<String, dynamic>>.from(cachedCases);
          final index = casesList.indexWhere(
            (c) => c['id'].toString() == widget.caseId,
          );

          if (index != -1) {
            casesList[index] = response;
          } else {
            casesList.add(response);
          }

          await offlineStorage.cacheCases(casesList);
        }
      } else {
        // Load from cache when offline
        final cachedCases = await offlineStorage.getCachedCases();

        if (cachedCases != null) {
          final caseData = cachedCases.firstWhere(
            (c) => c['id'].toString() == widget.caseId,
            orElse: () => {},
          );

          if (caseData.isNotEmpty) {
            setState(() {
              _caseData = caseData;
              _initializeControllers();
              _isLoading = false;
              _isOfflineMode = true;
            });
          } else {
            // Case not found in cache
            setState(() {
              _caseData = null;
              _isLoading = false;
              _isOfflineMode = true;
            });
          }
        } else {
          setState(() {
            _caseData = null;
            _isLoading = false;
            _isOfflineMode = true;
          });
        }
      }
    } catch (e) {
      print('Error loading case details: $e');

      // Try to load from cache on error
      final cachedCases = await offlineStorage.getCachedCases();

      if (cachedCases != null) {
        final caseData = cachedCases.firstWhere(
          (c) => c['id'].toString() == widget.caseId,
          orElse: () => {},
        );

        if (caseData.isNotEmpty && mounted) {
          setState(() {
            _caseData = caseData;
            _initializeControllers();
            _isLoading = false;
            _isOfflineMode = true;
          });
        } else {
          setState(() => _isLoading = false);
          if (mounted) {
            AppToast.showError(
              context: context,
              title: 'Error',
              message: 'Failed to load case details. Please try again later.',
            );
          }
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          AppToast.showError(
            context: context,
            title: 'Error',
            message: 'Failed to load case details. Please try again later.',
          );
        }
      }
    }
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoadingDocuments = true);
    try {
      if (connectivityService.isConnected) {
        final response = await _supabase
            .from('documents')
            .select()
            .eq('case_id', int.parse(widget.caseId))
            .order('created_at', ascending: false)
            .limit(3);
        await offlineStorage.cacheDocuments(response);

        setState(() {
          _documents = List<Map<String, dynamic>>.from(response);
          _isLoadingDocuments = false;
        });
      } else {
        final cachedDocuments = await offlineStorage.getCachedDocuments();

        if (cachedDocuments != null) {
          final caseDocuments = cachedDocuments
              .where((d) => d['case_id'].toString() == widget.caseId)
              .take(3);

          setState(() {
            _documents = List<Map<String, dynamic>>.from(caseDocuments);
            _isLoadingDocuments = false;
          });
        } else {
          setState(() {
            _documents = [];
            _isLoadingDocuments = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoadingDocuments = false);
    }
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoadingNotes = true);
    try {
      // Implementing offline caching for notes can be done similarly to cases
      if (connectivityService.isConnected) {
        final notes = await _supabase
            .from('notes')
            .select()
            .eq('case', int.parse(widget.caseId))
            .order('created_at', ascending: false);

        await offlineStorage.cacheNotes(notes);

        setState(() {
          _notes = List<Map<String, dynamic>>.from(notes);
          _isLoadingNotes = false;
        });
      } else {
        final cachedNotes = await offlineStorage.getCachedNotes();

        if (cachedNotes != null) {
          final caseNotes = cachedNotes.where(
            (n) => n['case'].toString() == widget.caseId,
          );

          setState(() {
            _notes = List<Map<String, dynamic>>.from(caseNotes);
            _isLoadingNotes = false;
          });
        } else {
          setState(() {
            _notes = [];
            _isLoadingNotes = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoadingNotes = false);
      if (mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load notes. Please try again later.',
        );
      }
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoadingEvents = true);
    try {
      if (connectivityService.isConnected) {
        final response = await _supabase
            .from('events')
            .select()
            .eq('case', int.parse(widget.caseId))
            .order('date', ascending: true);

        await offlineStorage.cacheEvents(response);

        setState(() {
          _events = List<Map<String, dynamic>>.from(response);
          _isLoadingEvents = false;
        });
      } else {
        final cachedEvents = await offlineStorage.getCachedEvents();

        if (cachedEvents != null) {
          final caseEvents = cachedEvents
              .where((e) => e['case'].toString() == widget.caseId)
              .toList();

          setState(() {
            _events = List<Map<String, dynamic>>.from(caseEvents);
            _isLoadingEvents = false;
          });
        } else {
          setState(() {
            _events = [];
            _isLoadingEvents = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoadingEvents = false);
      if (mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load events. Please try again later.',
        );
      }
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

      // Create full DateTime with time if available
      DateTime fullCourtDateTime;
      if (_caseData!['time'] != null &&
          _caseData!['time'].toString().isNotEmpty) {
        final timeParts = _caseData!['time'].toString().split(':');
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
          // If time parsing fails, default to end of day
          fullCourtDateTime = DateTime(
            courtDate.year,
            courtDate.month,
            courtDate.day,
            23,
            59,
          );
        }
      } else {
        // If no time, default to end of day to be safe
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
        // 2 days
        return 'urgent';
      } else if (difference.inHours > 48 && difference.inHours < 120) {
        // 2-5 days
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

  Color _getNoteColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'quick note':
        return const Color(0xFF3B82F6); // Blue
      case 'longer note':
        return const Color(0xFF8B5CF6); // Purple
      case 'case update':
        return const Color(0xFF10B981); // Green
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  IconData _getNoteIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'quick note':
        return Icons.sticky_note_2_outlined;
      case 'longer note':
        return Icons.description_outlined;
      case 'case update':
        return Icons.update_outlined;
      default:
        return Icons.note_outlined;
    }
  }

  Color _getAgendaColor(String? agenda) {
    switch (agenda?.toLowerCase()) {
      case 'client meeting':
        return const Color(0xFF3B82F6); // Blue
      case 'court hearing':
        return const Color(0xFFEF4444); // Red
      case 'brief hearing':
        return const Color(0xFFF59E0B); // Amber
      case 'case review':
        return const Color(0xFF8B5CF6); // Purple
      case 'document submission':
        return const Color(0xFF10B981); // Green
      case 'consultation':
        return const Color(0xFF06B6D4); // Cyan
      case 'settlement discussion':
        return const Color(0xFF14B8A6); // Teal
      case 'evidence collection':
        return const Color(0xFFA855F7); // Purple
      case 'witness interview':
        return const Color(0xFFEC4899); // Pink
      default:
        return const Color(0xFF6B7280); // Gray
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF10B981)),
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
            colorScheme: const ColorScheme.light(primary: Color(0xFF10B981)),
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
    if (!OfflineActionHelper.canPerformAction(
      context,
      actionName: 'save changes',
    )) {
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      AppToast.showError(
        context: context,
        title: 'Validation Error',
        message: 'Case name cannot be empty',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? timeString;
      if (_selectedTime != null) {
        timeString =
            '${_selectedTime!.hour.toString().padLeft(2, '0')}:'
            '${_selectedTime!.minute.toString().padLeft(2, '0')}:00';
      }

      await _supabase
          .from('cases')
          .update({
            'name': _nameController.text.trim(),
            'number': _numberController.text.trim(),
            'court_name': _courtNameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'courtDate': _selectedDate?.toIso8601String(),
            'time': timeString,
          })
          .eq('id', widget.caseId);

      await _loadCaseDetails();

      setState(() {
        _isEditing = false;
      });

      if (mounted) {
        AppToast.showSuccess(
          context: context,
          title: 'Success',
          message: 'Case updated successfully',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to update case. Please try again later.',
        );
      }
    }
  }

  Future<void> _deleteCase() async {
    if (!OfflineActionHelper.canPerformAction(
      context,
      actionName: 'delete case',
    )) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Case'),
        content: const Text(
          'Are you sure you want to delete this case? This action cannot be undone. All events and notifications associated with this case will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);

    try {
      await _supabase.from('cases').delete().eq('id', widget.caseId);

      if (mounted) {
        AppToast.showSuccess(
          context: context,
          title: 'Success',
          message: 'Case deleted successfully',
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
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

        AppToast.showError(
          context: context,
          title: 'Error occurred',
          message: errorMessage,
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

    if (result != null || mounted) {
      _loadDocuments();
    }
  }

  Future<void> _showAddNoteModal() async {
    _noteNameController.clear();
    _noteDescriptionController.clear();
    _selectedNoteType = 'Quick Note';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Note',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: const Color(0xFF6B7280),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Note Name
                const Text(
                  'Note Title',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteNameController,
                  decoration: InputDecoration(
                    hintText: 'Enter note title',
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
                      borderSide: const BorderSide(
                        color: Color(0xFF10B981),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Note Type
                const Text(
                  'Note Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedNoteType,
                      isExpanded: true,
                      items: ['Quick Note', 'Longer Note', 'Case Update']
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  Icon(
                                    _getNoteIcon(type),
                                    size: 20,
                                    color: _getNoteColor(type),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(type),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          _selectedNoteType = value!;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                const Text(
                  'Description (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteDescriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Enter description',
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
                      borderSide: const BorderSide(
                        color: Color(0xFF10B981),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _saveNote();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Save Note',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveNote() async {
    if (!OfflineActionHelper.canPerformAction(
      context,
      actionName: 'save note',
    )) {
      return;
    }
    if (_noteNameController.text.trim().isEmpty) {
      AppToast.showError(
        context: context,
        title: 'Validation Error',
        message: 'Note title cannot be empty',
      );
      return;
    }

    try {
      await _supabase.from('notes').insert({
        'note': _noteNameController.text.trim(),
        'type': _selectedNoteType,
        'description': _noteDescriptionController.text.trim().isEmpty
            ? null
            : _noteDescriptionController.text.trim(),
        'case': int.parse(widget.caseId),
      });

      await _loadNotes();

      if (mounted) {
        //app toast success
        AppToast.showSuccess(
          context: context,
          title: 'Success',
          message: 'Note added successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to add note. Please try again later.',
        );
      }
    }
  }

  Future<void> _deleteNote(int noteId, String noteName) async {
    if (!OfflineActionHelper.canPerformAction(
      context,
      actionName: 'delete note',
    )) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text(
          'Are you sure you want to delete "$noteName"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase.from('notes').delete().eq('id', noteId);

      await _loadNotes();

      if (mounted) {
        // app toast success
        AppToast.showSuccess(
          context: context,
          title: 'Success',
          message: 'Note deleted successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to delete note. Please try again later.',
        );
      }
    }
  }

  // EVENT METHODS
  Future<void> _showAddEventModal({Map<String, dynamic>? event}) async {
    _editingEventId = event?['id'];
    _eventAgendaController.clear();
    _eventSelectedDate = null;
    _eventSelectedTime = null;
    _isCustomAgenda = false;

    if (event != null) {
      // Editing existing event
      if (event['date'] != null) {
        _eventSelectedDate = DateTime.parse(event['date']);
      }
      if (event['time'] != null) {
        final timeParts = event['time'].toString().split(':');
        if (timeParts.length >= 2) {
          _eventSelectedTime = TimeOfDay(
            hour: int.parse(timeParts[0]),
            minute: int.parse(timeParts[1]),
          );
        }
      }

      final agenda = event['agenda'];
      if (_agendaOptions.contains(agenda)) {
        _selectedAgendaType = agenda;
        _isCustomAgenda = false;
      } else {
        _selectedAgendaType = 'Custom';
        _isCustomAgenda = true;
        _eventAgendaController.text = agenda ?? '';
      }
    } else {
      _selectedAgendaType = 'Client Meeting';
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _editingEventId == null ? 'Add Event' : 'Edit Event',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: const Color(0xFF6B7280),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Date Picker
                const Text(
                  'Event Date',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _eventSelectedDate ?? DateTime.now(),
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
                      setModalState(() {
                        _eventSelectedDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _eventSelectedDate != null
                              ? _formatCourtDate(
                                  _eventSelectedDate!.toIso8601String(),
                                )
                              : 'Select date',
                          style: TextStyle(
                            fontSize: 14,
                            color: _eventSelectedDate != null
                                ? const Color(0xFF1F2937)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Time Picker
                const Text(
                  'Event Time',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final TimeOfDay? picked = await showTimePicker(
                      context: context,
                      initialTime: _eventSelectedTime ?? TimeOfDay.now(),
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
                      setModalState(() {
                        _eventSelectedTime = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 20,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _eventSelectedTime != null
                              ? _eventSelectedTime!.format(context)
                              : 'Select time',
                          style: TextStyle(
                            fontSize: 14,
                            color: _eventSelectedTime != null
                                ? const Color(0xFF1F2937)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Agenda Type
                const Text(
                  'Agenda',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedAgendaType,
                      isExpanded: true,
                      items: _agendaOptions
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  Icon(
                                    _getAgendaIcon(type),
                                    size: 20,
                                    color: _getAgendaColor(type),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(type),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setModalState(() {
                          _selectedAgendaType = value!;
                          _isCustomAgenda = value == 'Custom';
                          if (!_isCustomAgenda) {
                            _eventAgendaController.clear();
                          }
                        });
                      },
                    ),
                  ),
                ),

                // Custom Agenda Input
                if (_isCustomAgenda) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Custom Agenda',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _eventAgendaController,
                    decoration: InputDecoration(
                      hintText: 'Enter custom agenda',
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
                        borderSide: const BorderSide(
                          color: Color(0xFF10B981),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      if (_editingEventId == null) {
                        _saveEvent();
                      } else {
                        _updateEvent();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _editingEventId == null ? 'Save Event' : 'Update Event',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveEvent() async {
    if (!OfflineActionHelper.canPerformAction(
      context,
      actionName: 'save event',
    )) {
      return;
    }

    if (_eventSelectedDate == null) {
      AppToast.showError(
        context: context,
        title: 'Validation Error',
        message: 'Please select an event date',
      );
      return;
    }

    if (_isCustomAgenda && _eventAgendaController.text.trim().isEmpty) {
      AppToast.showError(
        context: context,
        title: 'Validation Error',
        message: 'Please enter custom agenda',
      );
      return;
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      String? timeString;
      if (_eventSelectedTime != null) {
        timeString =
            '${_eventSelectedTime!.hour.toString().padLeft(2, '0')}:'
            '${_eventSelectedTime!.minute.toString().padLeft(2, '0')}:00';
      }

      final agendaValue = _isCustomAgenda
          ? _eventAgendaController.text.trim()
          : _selectedAgendaType;

      // Insert event and get the ID back
      final response = await _supabase
          .from('events')
          .insert({
            'date': _eventSelectedDate!.toIso8601String(),
            'time': timeString,
            'agenda': agendaValue,
            'case': int.parse(widget.caseId),
            'profile': userId,
          })
          .select()
          .single();

      final eventId = response['id'] as int;

      await _loadEvents();

      if (mounted) {
        AppToast.showSuccess(
          context: context,
          title: 'Success',
          message: 'Event added successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to add event. Please try again later.',
        );
      }
    }
  }

  Future<void> _updateEvent() async {
    if (!OfflineActionHelper.canPerformAction(
      context,
      actionName: 'update event',
    )) {
      return;
    }

    if (_eventSelectedDate == null) {
      AppToast.showError(
        context: context,
        title: 'Validation Error',
        message: 'Please select an event date',
      );
      return;
    }

    if (_isCustomAgenda && _eventAgendaController.text.trim().isEmpty) {
      AppToast.showError(
        context: context,
        title: 'Validation Error',
        message: 'Please enter custom agenda',
      );
      return;
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      String? timeString;
      if (_eventSelectedTime != null) {
        timeString =
            '${_eventSelectedTime!.hour.toString().padLeft(2, '0')}:'
            '${_eventSelectedTime!.minute.toString().padLeft(2, '0')}:00';
      }

      final agendaValue = _isCustomAgenda
          ? _eventAgendaController.text.trim()
          : _selectedAgendaType;

      await _supabase
          .from('events')
          .update({
            'date': _eventSelectedDate!.toIso8601String(),
            'time': timeString,
            'agenda': agendaValue,
            'profile': userId,
          })
          .eq('id', _editingEventId!);

      await _loadEvents();

      if (mounted) {
        AppToast.showSuccess(
          context: context,
          title: 'Success',
          message: 'Event updated successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to update event. Please try again later.',
        );
      }
    }
  }

  Future<void> _deleteEvent(int eventId, String agenda) async {
    if (!OfflineActionHelper.canPerformAction(
      context,
      actionName: 'delete event',
    )) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
          'Are you sure you want to delete "$agenda"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase.from('events').delete().eq('id', eventId);

      await _loadEvents();

      if (mounted) {
        AppToast.showSuccess(
          context: context,
          title: 'Success',
          message: 'Event deleted successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to delete event. Please try again later.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
            // Add Checkmark icon in AppBar for quick toggle
            if (_caseData != null &&
                !_isEditing &&
                !_isDeleting &&
                !_isOfflineMode)
              IconButton(
                tooltip: _isCompleted ? 'Reopen Case' : 'Mark as Complete',
                icon: Icon(
                  _isCompleted
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: _isCompleted
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6B7280),
                ),
                onPressed: _toggleCaseCompletion,
              ),
          ],

          bottom: _caseData != null && !_isDeleting && !_isLoading
              ? TabBar(
                  labelColor: const Color(0xFF10B981),
                  unselectedLabelColor: const Color(0xFF6B7280),
                  indicatorColor: const Color(0xFF10B981),
                  tabs: const [
                    Tab(icon: Icon(Icons.info_outline), text: 'Details'),
                    Tab(icon: Icon(Icons.event), text: 'Events'),
                    Tab(icon: Icon(Icons.note), text: 'Notes'),
                  ],
                )
              : null,
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
                      style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
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
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
            : Column(
                children: [
                  if (_isCompleted) _buildCompletionBanner(),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildDetailsTab(),
                        _buildEventsTab(),
                        _buildNotesTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCompletionBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF10B981).withOpacity(0.1),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'This case is marked as complete. Editing is disabled.',
              style: TextStyle(
                color: Color(0xFF065F46),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      floatingActionButton: (_isOfflineMode || _isCompleted)
          ? null // Hide FAB when offline
          : FloatingActionButton(
              onPressed: _isEditing
                  ? _saveChanges
                  : () {
                      setState(() {
                        _isEditing = true;
                        _initializeControllers();
                      });
                    },
              backgroundColor: const Color(0xFF10B981),
              child: Icon(
                _isEditing ? Icons.save : Icons.edit,
                color: Colors.white,
              ),
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add offline indicator at the top
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
                        Icons.cloud_off_rounded,
                        color: Color(0xFFF59E0B),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Viewing Offline',
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Connect to internet to edit',
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

            if (!_isCompleted) ...[
              _buildStatusCard(),
              const SizedBox(height: 16),
            ],
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildCourtDetailsCard(),

            if (_caseData!['description'] != null &&
                _caseData!['description'].toString().trim().isNotEmpty &&
                !_isEditing) ...[
              const SizedBox(height: 16),
              _buildDescriptionCard(),
            ],

            if (!_isEditing) ...[
              const SizedBox(height: 16),
              _buildDocumentsSection(),
            ],

            // Only show delete button when online
            if (!_isEditing && !_isOfflineMode) ...[
              const SizedBox(height: 24),

              if (!_isCompleted)
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

  Widget _buildEventsTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      floatingActionButton: (_isOfflineMode || _isCompleted)
          ? null // Hide FAB when offline and when case is completed
          : FloatingActionButton(
              onPressed: () => _showAddEventModal(),
              backgroundColor: const Color(0xFF10B981),
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: Column(
        children: [
          // Add offline indicator
          if (_isOfflineMode)
            Container(
              margin: const EdgeInsets.all(16),
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
                      Icons.cloud_off_rounded,
                      color: Color(0xFFF59E0B),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Viewing Offline',
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Connect to internet to add/edit events',
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

          // Rest of events tab content
          Expanded(
            child: _isLoadingEvents
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No events yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first event to get started',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      return _buildEventCard(event);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final agendaColor = _getAgendaColor(event['agenda']);
    final agendaIcon = _getAgendaIcon(event['agenda']);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: agendaColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: agendaColor.withOpacity(0.2),
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: agendaColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(event['date']),
                            style: TextStyle(
                              fontSize: 12,
                              color: agendaColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (event['time'] != null) ...[
                            const Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: agendaColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(event['time']),
                              style: TextStyle(
                                fontSize: 12,
                                color: agendaColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Only show buttons when online
                if (!_isOfflineMode) ...[
                  IconButton(
                    onPressed: () => _showAddEventModal(event: event),
                    icon: const Icon(Icons.edit_outlined),
                    color: agendaColor,
                    iconSize: 20,
                  ),
                  IconButton(
                    onPressed: () => _deleteEvent(
                      event['id'],
                      event['agenda'] ?? 'this event',
                    ),
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red[400],
                    iconSize: 20,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      floatingActionButton: (_isOfflineMode || _isCompleted)
          ? null // Hide FAB when offline and when case is completed
          : FloatingActionButton(
              onPressed: _showAddNoteModal,
              backgroundColor: const Color(0xFF10B981),
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: Column(
        children: [
          // Add offline indicator
          if (_isOfflineMode)
            Container(
              margin: const EdgeInsets.all(16),
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
                      Icons.cloud_off_rounded,
                      color: Color(0xFFF59E0B),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Viewing Offline',
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Connect to internet to add/delete notes',
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

          // Rest of notes tab content
          Expanded(
            child: _isLoadingNotes
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notes yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first note to get started',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notes.length,
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      return _buildNoteCard(note);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final noteColor = _getNoteColor(note['type']);
    final noteIcon = _getNoteIcon(note['type']);
    final hasDescription =
        note['description'] != null &&
        note['description'].toString().trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: noteColor.withOpacity(0.3), width: 2),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: noteColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: noteColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(noteIcon, color: noteColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note['note'] ?? 'Untitled',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        note['type'] ?? 'Note',
                        style: TextStyle(
                          fontSize: 12,
                          color: noteColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Only show delete button when online
                if (!_isOfflineMode)
                  IconButton(
                    onPressed: () =>
                        _deleteNote(note['id'], note['note'] ?? 'this note'),
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red[400],
                  ),
              ],
            ),
          ),

          if (hasDescription)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                note['description'],
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4B5563),
                  height: 1.5,
                ),
              ),
            ),

          if (note['created_at'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(note['created_at']),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
        ],
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
            border: Border.all(color: const Color(0xFFE5E7EB)),
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
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
          border: Border.all(color: const Color(0xFFE5E7EB)),
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
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF6B7280)),
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
        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
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
              enabled: false,
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
                style: const TextStyle(fontSize: 14, color: Color(0xFF1F2937)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    bool enabled = true,
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
          enabled: enabled,
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
            disabledBorder: OutlineInputBorder(
              // Added for disabled state
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
                const Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Color(0xFF6B7280),
                ),
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
                const Icon(
                  Icons.access_time,
                  size: 20,
                  color: Color(0xFF6B7280),
                ),
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
