import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lawdesk/widgets/delightful_toast.dart';
import 'package:lawdesk/services/connectivity_service.dart';
import 'package:lawdesk/services/offline_storage_service.dart'; // Import offline storage
import 'package:lawdesk/widgets/offline_indicator.dart'; // Added offline indicator
import 'package:lawdesk/utils/offline_action_helper.dart';
import 'package:lawdesk/widgets/cases/details.dart';

class ClientDetailsPage extends StatefulWidget {
  final Map<String, dynamic> clientData;

  const ClientDetailsPage({Key? key, required this.clientData})
    : super(key: key);

  @override
  State<ClientDetailsPage> createState() => _ClientDetailsPageState();
}

class _ClientDetailsPageState extends State<ClientDetailsPage> {
  final _supabase = Supabase.instance.client;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _notesController;

  List<Map<String, dynamic>> _linkedCases = [];
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isLoadingCases = true;
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _isOfflineMode = !connectivityService.isConnected;
    _initializeControllers();
    _loadLinkedCases();

    connectivityService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isOfflineMode = !isConnected;
        });

        // Retry loading cases if we just came online
        if (isConnected && _linkedCases.isEmpty) {
          _loadLinkedCases();
        }
      }
    });
  }

  // Helper to format phone number with leading 0
  String _formatPhoneNumber(dynamic phone) {
    if (phone == null) return '';
    String p = phone.toString();
    // If it's a 9 digit number (e.g. 712345678), add the leading 0
    if (p.length == 9 && !p.startsWith('0')) {
      return '0$p';
    }
    return p;
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.clientData['name']);
    _emailController = TextEditingController(text: widget.clientData['email']);
    // Apply formatting to initial text so "0" appears in UI
    _phoneController = TextEditingController(
      text: _formatPhoneNumber(widget.clientData['phone']),
    );
    _notesController = TextEditingController(text: widget.clientData['notes']);
  }

  Future<void> _loadLinkedCases() async {
    setState(() => _isLoadingCases = true);
    try {
      if (connectivityService.isConnected) {
        // Online: Fetch from Supabase
        final response = await _supabase
            .from('cases')
            .select()
            .eq('name', widget.clientData['name']);

        if (mounted) {
          setState(() {
            _linkedCases = List<Map<String, dynamic>>.from(response);
            _isLoadingCases = false;
          });
        }
      } else {
        // Offline: Fetch from local cache and filter by client name
        final cachedCases = await offlineStorage.getCachedCases();
        if (mounted) {
          if (cachedCases != null) {
            // Filter locally
            final clientName = widget.clientData['name'];
            _linkedCases = List<Map<String, dynamic>>.from(
              cachedCases,
            ).where((c) => c['name'] == clientName).toList();
          }
          setState(() => _isLoadingCases = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading linked cases: $e');
      // Fallback to cache on error
      final cachedCases = await offlineStorage.getCachedCases();
      if (mounted) {
        if (cachedCases != null) {
          final clientName = widget.clientData['name'];
          _linkedCases = List<Map<String, dynamic>>.from(
            cachedCases,
          ).where((c) => c['name'] == clientName).toList();
        }
        setState(() => _isLoadingCases = false);
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;

    // Ensure we send the number with the leading zero to the dialer
    String formattedNumber = phoneNumber;
    if (formattedNumber.length == 9 && !formattedNumber.startsWith('0')) {
      formattedNumber = '0$formattedNumber';
    }

    final Uri launchUri = Uri(scheme: 'tel', path: formattedNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Could not launch dialer',
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    if (email.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'mailto', path: email);

    try {
      // Attempt launch directly; avoid canLaunchUrl check which can be unreliable
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'No email app found on this device.',
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!OfflineActionHelper.canPerformAction(
      context,
      actionName: 'update client',
    )) {
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      AppToast.showError(
        context: context,
        title: 'Error',
        message: 'Name cannot be empty',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Parse phone back to int for DB if needed, or keep as int if DB is int
      // NOTE: If DB is int, leading zero is lost. UI re-adds it on load.
      final phoneInput = _phoneController.text.trim();
      final phoneInt = int.tryParse(phoneInput);

      await _supabase
          .from('clients')
          .update({
            'name': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': phoneInt, // Storing as int
            'notes': _notesController.text.trim(),
          })
          .eq('id', widget.clientData['id']);

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
          // Update local widget data to reflect changes immediately
          widget.clientData['name'] = _nameController.text.trim();
          widget.clientData['email'] = _emailController.text.trim();
          widget.clientData['phone'] = phoneInt;
          widget.clientData['notes'] = _notesController.text.trim();
        });
        AppToast.showSuccess(
          context: context,
          title: 'Success',
          message: 'Client updated successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to update client',
        );
      }
    }
  }

  Future<void> _deleteClient() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Client'),
        content: const Text(
          'Are you sure you want to delete this client? This action cannot be undone.',
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

    setState(() => _isLoading = true);

    try {
      await _supabase
          .from('clients')
          .delete()
          .eq('id', widget.clientData['id']);
      if (mounted) {
        AppToast.showSuccess(
          context: context,
          title: 'Success',
          message: 'Client deleted successfully',
        );
        Navigator.pop(context, true); // Return true to indicate deletion
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to delete client',
        );
      }
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Client Profile',
          style: TextStyle(color: Color(0xFF1F2937)),
        ),
        actions: [
          // TODO: Enable editing in future release and fix the save flow logic first and offline handling
          // IconButton(
          //   icon: Icon(
          //     _isEditing ? Icons.check : Icons.edit,
          //     color: _isEditing ? Colors.green : const Color(0xFF3B82F6),
          //   ),
          //   onPressed: _isLoading || _isOfflineMode
          //       ? null
          //       : () {
          //           if (_isEditing) {
          //             _saveChanges();
          //           } else {
          //             setState(() => _isEditing = true);
          //           }
          //         },
          //   tooltip: _isEditing ? 'Save Changes' : 'Edit Client',
          // ),
          if (!_isOfflineMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Color(0xFFEF4444)),
              onPressed: _isLoading || _isOfflineMode ? null : _deleteClient,
              tooltip: 'Delete Client',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLinkedCases,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isOfflineMode)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: OfflineDataIndicator(),
                ),
              _buildProfileHeader(),
              const SizedBox(height: 24),
              _buildInfoCard(),
              const SizedBox(height: 16),

              // Linked Cases Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Associated Cases',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
              _buildCasesList(),

              const SizedBox(height: 16),
              _buildNotesCard(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCasesList() {
    if (_isLoadingCases) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_linkedCases.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Icon(Icons.folder_open, color: Colors.grey[400], size: 40),
            const SizedBox(height: 8),
            Text(
              'No cases found for this client',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _linkedCases.length,
      itemBuilder: (context, index) {
        final caseItem = _linkedCases[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          child: ListTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CaseDetailsPage(caseId: caseItem['id'].toString()),
                ),
              );
            },
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEFF6FF),
              child: Icon(Icons.gavel, color: Color(0xFF1E3A8A), size: 20),
            ),
            title: Text(
              caseItem['number'] ?? 'Untitled Case',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Status: ${caseItem['progress_status'] == null ? 'N/A' : (caseItem['progress_status'] == true ? 'Completed' : 'Ongoing')}',
              style: TextStyle(
                color: caseItem['progress_status'] == true
                    ? Colors.green
                    : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),

            trailing: const Icon(Icons.chevron_right, size: 20),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader() {
    final String initial = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : '?';

    // Get current phone from controller (which has formatting applied in init)
    final String displayPhone = _phoneController.text;

    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_isEditing) ...[
            Text(
              _nameController.text,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Call email functionality
                InkWell(
                  onTap: () => _sendEmail(_emailController.text),
                  borderRadius: BorderRadius.circular(20),
                  child: _buildActionChip(Icons.email, 'Email', Colors.blue),
                ),
                const SizedBox(width: 12),
                // Call phone functionality
                InkWell(
                  onTap: () => _makePhoneCall(displayPhone),
                  borderRadius: BorderRadius.circular(20),
                  child: _buildActionChip(Icons.phone, 'Call', Colors.green),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            'Contact Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'Full Name',
            controller: _nameController,
            icon: Icons.person_outline,
            enabled: _isEditing,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Email Address',
            controller: _emailController,
            icon: Icons.email_outlined,
            enabled: _isEditing,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Phone Number',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            enabled: _isEditing,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Icon(Icons.note_alt_outlined, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text(
                'Notes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Additional Information',
            controller: _notesController,
            icon: Icons.notes,
            enabled: _isEditing,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    if (!enabled) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
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
                const SizedBox(height: 4),
                Text(
                  controller.text.isEmpty ? 'Not provided' : controller.text,
                  style: TextStyle(
                    fontSize: 15,
                    color: controller.text.isEmpty
                        ? Colors.grey[400]
                        : const Color(0xFF1F2937),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6B7280)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}
