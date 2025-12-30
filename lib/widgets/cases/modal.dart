import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lawdesk/widgets/delightful_toast.dart';
import 'client_modal.dart'; // Import the client modal
import 'package:lawdesk/services/notification_service.dart';

class AddCaseModal extends StatefulWidget {
  final VoidCallback? onCaseAdded;

  const AddCaseModal({Key? key, this.onCaseAdded}) : super(key: key);

  @override
  State<AddCaseModal> createState() => _AddCaseModalState();

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

  final _caseNumberController = TextEditingController();
  final _courtNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedClientId;
  List<Map<String, dynamic>> _clients = [];
  List<String> _courts = [];

  DateTime? _selectedCourtDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _caseNumberController.dispose();
    _courtNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Load clients for current user
      final clientsData = await _supabase
          .from('clients')
          .select('id, name')
          .eq('user', user.id)
          .order('name');

      // Load all courts (shared across users)
      final courtsData = await _supabase
          .from('court')
          .select('name')
          .order('name');

      setState(() {
        _clients = List<Map<String, dynamic>>.from(clientsData);
        _courts = courtsData.map((c) => c['name'] as String).toList();
        _isLoadingData = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load data. Please try again.',
        );
      }
    }
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

  Future<void> _openAddClientModal() async {
    await AddClientModal.show(
      context,
      onClientAdded: () {
        _loadData(); // Reload clients after adding new one
      },
    );
  }

  Future<void> _submitCase() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedClientId == null) {
      AppToast.showError(
        context: context,
        title: 'Client Required',
        message: 'Please select a client.',
      );
      return;
    }

    if (_selectedCourtDate == null) {
      AppToast.showError(
        context: context,
        title: 'Date Required',
        message: 'Please select a court date.',
      );
      return;
    }

    if (_courtNameController.text.trim().isEmpty) {
      AppToast.showError(
        context: context,
        title: 'Court Required',
        message: 'Please select or enter a court name.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) throw Exception('No user logged in');

      final courtName = _courtNameController.text.trim();

      // Format time as HH:mm:ss for the time column
      String? timeString;
      if (_selectedTime != null) {
        final hour = _selectedTime!.hour.toString().padLeft(2, '0');
        final minute = _selectedTime!.minute.toString().padLeft(2, '0');
        timeString = '$hour:$minute:00';
      }

      // Insert the case and get the returned data (including the new case ID)
      final response = await _supabase
          .from('cases')
          .insert({
            'name': _selectedClientId,
            'number': _caseNumberController.text.trim(),
            'court_name': courtName,
            'description': _descriptionController.text.trim(),
            'courtDate': _selectedCourtDate!.toIso8601String().split('T')[0],
            'time': timeString,
            'user': user.id,
          })
          .select()
          .single(); // Add .select().single() to get the created case back

      final newCaseId = response['id'] as int;

      // Schedule notifications for the new case
      await notificationService.scheduleCourtDateNotifications(
        caseId: newCaseId,
        courtDate: _selectedCourtDate!,
        caseName: _selectedClientId ?? 'New Case',
        courtTime: _selectedTime,
      );

      if (mounted) {
        Navigator.pop(context);
        AppToast.showSuccess(
          context: context,
          title: 'Case Added',
          message: 'Your new case has been added successfully.',
        );
        widget.onCaseAdded?.call();
      }
    } catch (e) {
      print('Error adding case: $e');
      if (mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to add case. Please try again.',
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
          child: _isLoadingData
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : Form(
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
                      const SizedBox(height: 16),

                      // Client Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Client',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF374151),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _openAddClientModal,
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Client'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF1E3A8A),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Autocomplete<String>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) {
                                  final names = _clients
                                      .map((c) => c['name'] as String)
                                      .toList();
                                  final input = textEditingValue.text
                                      .toLowerCase();

                                  // Filtered results
                                  final filtered = input.isEmpty
                                      ? names
                                      : names
                                            .where(
                                              (name) => name
                                                  .toLowerCase()
                                                  .contains(input),
                                            )
                                            .toList();

                                  // Add "not found" message if no match
                                  if (filtered.isEmpty && input.isNotEmpty) {
                                    return ['__not_found__'];
                                  }

                                  return filtered;
                                },

                            displayStringForOption: (option) {
                              return option == '__not_found__' ? '' : option;
                            },

                            onSelected: (String selection) {
                              if (selection == '__not_found__') return;

                              setState(() {
                                _selectedClientId = selection;
                              });
                            },

                            fieldViewBuilder:
                                (
                                  context,
                                  controller,
                                  focusNode,
                                  onFieldSubmitted,
                                ) {
                                  // DO NOT override controller.text — allows normal typing

                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Client',
                                      hintText: _clients.isEmpty
                                          ? 'No clients available - Add one first'
                                          : 'Select or type client name',
                                      prefixIcon: const Icon(
                                        Icons.person,
                                        color: Color(0xFF6B7280),
                                      ),
                                      suffixIcon: const Icon(
                                        Icons.arrow_drop_down,
                                        color: Color(0xFF6B7280),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF1E3A8A),
                                          width: 2,
                                        ),
                                      ),
                                    ),

                                    onChanged: (value) {
                                      final names = _clients
                                          .map((c) => c['name'] as String)
                                          .toList();

                                      if (names.contains(value)) {
                                        setState(
                                          () => _selectedClientId = value,
                                        );
                                      } else {
                                        setState(
                                          () => _selectedClientId = null,
                                        );
                                      }
                                    },

                                    validator: (value) {
                                      final names = _clients
                                          .map((c) => c['name'] as String)
                                          .toList();

                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please select a client';
                                      }
                                      if (!names.contains(value.trim())) {
                                        return 'Client not registered — add the client first';
                                      }
                                      return null;
                                    },
                                  );
                                },

                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 240,
                                      minWidth: 300,
                                    ),
                                    child: Scrollbar(
                                      thumbVisibility: true,
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        itemCount: options.length,
                                        itemBuilder: (context, index) {
                                          final option = options.elementAt(
                                            index,
                                          );

                                          // Special not-found tile
                                          if (option == '__not_found__') {
                                            return ListTile(
                                              title: const Text(
                                                'Client not registered. Please add the client first',
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                              onTap: () {}, // disabled
                                            );
                                          }

                                          return ListTile(
                                            title: Text(option),
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Case Number
                      TextFormField(
                        controller: _caseNumberController,
                        decoration: InputDecoration(
                          labelText: 'Case Number',
                          hintText: 'e.g., CR 123/2024',
                          prefixIcon: const Icon(
                            Icons.numbers,
                            color: Color(0xFF6B7280),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E3A8A),
                              width: 2,
                            ),
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

                      // Court Name (Autocomplete Combobox)
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return _courts;
                          }
                          return _courts.where((String option) {
                            return option.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                          });
                        },
                        onSelected: (String selection) {
                          _courtNameController.text = selection;
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                              _courtNameController.text = controller.text;
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'Court Name',
                                  hintText: 'Select or type court name',
                                  prefixIcon: const Icon(
                                    Icons.location_city,
                                    color: Color(0xFF6B7280),
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Color(0xFF6B7280),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1E3A8A),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onChanged: (value) {
                                  _courtNameController.text = value;
                                },
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter court name';
                                  }
                                  return null;
                                },
                              );
                            },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final option = options.elementAt(index);
                                    return ListTile(
                                      title: Text(option),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
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
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Color(0xFF6B7280),
                                      size: 20,
                                    ),
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
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      color: Color(0xFF6B7280),
                                      size: 20,
                                    ),
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
                          prefixIcon: const Icon(
                            Icons.note_alt_outlined,
                            color: Color(0xFF6B7280),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1E3A8A),
                              width: 2,
                            ),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
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
