import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lawdesk/widgets/delightful_toast.dart'; // Ensuring we use your toast widget

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client; // Using the client from your config
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // State
  bool _isLoading = false;
  String _feedbackType = 'bug'; // Options: 'bug' or 'improvement'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to submit feedback.');
      }

      // Determine table name based on selection
      final tableName = _feedbackType == 'bug' ? 'bugs' : 'improves';

      final data = {
        'user_id': user.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'status': 'pending', // Default status
      };

      await _supabase.from(tableName).insert(data);

      if (mounted) {
        // Clear form and show success
        _titleController.clear();
        _descriptionController.clear();
        
        AppToast.showSuccess(
          context: context,
          title: 'Received',
          message: _feedbackType == 'bug' 
              ? 'Bug report submitted. Thank you!' 
              : 'Suggestion received. We appreciate it!',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Failed to submit. Please check your connection.',
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        title: const Text(
          'Help & Support',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF3B82F6),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Guides & Tips'),
            Tab(text: 'Report Issue'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGuidesTab(),
          _buildFeedbackTab(),
        ],
      ),
    );
  }

  // --- Tab 1: Guides ---
  Widget _buildGuidesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildGuideCard(
          icon: Icons.refresh,
          title: 'Refreshing Your Data',
          content: 'To verify you have the latest cases and documents, go to the Dashboard and pull down from the top. You will see a liquid animation confirming the refresh.',
        ),
        _buildGuideCard(
          icon: Icons.wifi_off_outlined,
          title: 'Offline Access',
          content: 'LawDesk stores your data locally. You can view your calendar, cases, and documents even without an internet connection. Changes will sync once you are back online.',
        ),
        _buildGuideCard(
          icon: Icons.grid_view_rounded,
          title: 'Quick Actions Menu',
          content: 'Tap the Floating Action Button (bottom right of Dashboard) to reveal quick shortcuts for adding new Clients, Cases, or accessing the Calendar.',
        ),
        _buildGuideCard(
          icon: Icons.person_add_outlined,
          title: 'Managing Clients',
          content: 'You must add a Client to the system before you can assign a Case to them. Use the "New Client" button in the Quick Actions menu.',
        ),
      ],
    );
  }

  Widget _buildGuideCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Tab 2: Feedback Form ---
  Widget _buildFeedbackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report a Bug or Suggest Improvement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select the type of feedback you want to send.',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),

            // Type Selector (Bug vs Improvement)
            Row(
              children: [
                Expanded(child: _buildTypeButton('Report Bug', 'bug', Icons.bug_report)),
                const SizedBox(width: 12),
                Expanded(child: _buildTypeButton('Suggestion', 'improvement', Icons.lightbulb)),
              ],
            ),
            const SizedBox(height: 24),

            // Title Input
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                hintText: _feedbackType == 'bug' ? 'e.g., App crashes on login' : 'e.g., Add Dark Mode',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.title, color: Color(0xFF9CA3AF)),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Please enter a title' : null,
            ),
            const SizedBox(height: 16),

            // Description Input
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Provide as much detail as possible...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
              validator: (val) => val == null || val.isEmpty ? 'Please enter a description' : null,
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitFeedback,
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
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Submit Feedback',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(String label, String value, IconData icon) {
    final isSelected = _feedbackType == value;
    return InkWell(
      onTap: () => setState(() => _feedbackType = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
