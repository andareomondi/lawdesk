import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddCaseModal extends StatefulWidget {
  final VoidCallback? onCaseAdded;

  const AddCaseModal({Key? key, this.onCaseAdded}) : super(key: key);

  @override
  State<AddCaseModal> createState() => _AddCaseModalState();

  // Static method to show the modal
  static void show(BuildContext context, {VoidCallback? onCaseAdded}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddCaseModal(onCaseAdded: onCaseAdded),
    );
  }
}

class _AddCaseModalState extends State<AddCaseModal> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  
  final _caseNameController = TextEditingController();
  final _caseNumberController = TextEditingController();
  final _courtNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime? _selectedCourtDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;

  @override
  void dispose() {
    _caseNameController.dispose();
    _caseNumberController.dispose();
    _courtNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() => _selectedCourtDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Select time';
    return time.format(context);
  }

  Future<void> _submitCase() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedCourtDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a court date')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Combine date and time
      DateTime courtDateTime = _selectedCourtDate!;
      if (_selectedTime != null) {
        courtDateTime = DateTime(
          _selectedCourtDate!.year,
          _selectedCourtDate!.month,
          _selectedCourtDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      }

      // Format time as HH:mm:ss for the time column
      String? timeString;
      if (_selectedTime != null) {
        final hour = _selectedTime!.hour.toString().padLeft(2, '0');
        final minute = _selectedTime!.minute.toString().padLeft(2, '0');
        timeString = '$hour:$minute:00';
      }

      await _supabase.from('cases').insert({
        'name': _caseNameController.text.trim(),
        'number': _caseNumberController.text.trim(),
        'court_name': _courtNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'courtDate': _selectedCourtDate!.toIso8601String().split('T')[0], // Just the date part
        'time': timeString,
        'user': user.id,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Case added successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onCaseAdded?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error occured during Case creation. Please try again'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add New Case',
                      style: TextStyle(
                        fontSize: 24,
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
                const SizedBox(height: 8),
                const Text(
                  'Fill in the details of your new case',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 24),

                // Case Name
                TextFormField(
                  controller: _caseNameController,
                  decoration: InputDecoration(
                    labelText: 'Case Name',
                    hintText: 'e.g., Kamau v. Republic',
                    prefixIcon: const Icon(Icons.gavel, color: Color(0xFF6B7280)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter case name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Case Number
                TextFormField(
                  controller: _caseNumberController,
                  decoration: InputDecoration(
                    labelText: 'Case Number',
                    hintText: 'e.g., CR 123/2024',
                    prefixIcon: const Icon(Icons.numbers, color: Color(0xFF6B7280)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter case number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Court Name
                TextFormField(
                  controller: _courtNameController,
                  decoration: InputDecoration(
                    labelText: 'Court Name',
                    hintText: 'e.g., Milimani Law Courts',
                    prefixIcon: const Icon(Icons.location_city, color: Color(0xFF6B7280)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter court name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Date and Time Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, 
                                color: Color(0xFF6B7280), size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _formatDate(_selectedCourtDate),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _selectedCourtDate == null 
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectTime(context),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, 
                                color: Color(0xFF6B7280), size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _formatTime(_selectedTime),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _selectedTime == null 
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description (Optional)
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Add any additional notes...',
                    prefixIcon: const Icon(Icons.note_alt_outlined, 
                      color: Color(0xFF6B7280)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitCase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Add Case',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
