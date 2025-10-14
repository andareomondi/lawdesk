import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/supabase_config.dart';
import '../../providers/auth_provider.dart';
import 'package:lawdesk/screens/auth/login_screen.dart';
import 'update_profile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = SupabaseConfig.client;

  String _fullName = '';
  String _username = '';
  String _email = '';
  String _gender = '';
  String _lskNumber = '';
  String _userId = '';
  String _memberSince = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user != null) {
        setState(() {
          _userId = user.id;
          _email = user.email ?? '';
          _memberSince = _formatDate(user.createdAt);
        });

        // Fetch from profiles table
        try {
          final profile = await _supabase
              .from('profiles')
              .select()
              .eq('id', user.id)
              .single();

          setState(() {
            _fullName = profile['full_name'] ?? '';
            _username = profile['username'] ?? '';
            _gender = profile['gender'] ?? '';
            _lskNumber = profile['lsk_number'] ?? '';
            _isLoading = false;
          });
        } catch (e) {
          // If no profile exists, just use auth data
          setState(() {
            _fullName = user.userMetadata?['full_name'] ?? '';
            _username = user.userMetadata?['username'] ?? '';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${_getMonthName(date.month)} ${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Use AuthProvider instead of direct Supabase call
      final authProvider = context.read<AuthProvider>();

      try {
        await authProvider.signOut();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logged out successfully'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 2),
            ),
          );
        }

      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: Text('Error logging out: $e'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileUpdateScreen(),
      ),
    ).then((_) => _loadUserProfile()); // Reload after update
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Header with Profile Picture
                  _buildProfileHeader(),

                  // Profile Details Section
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Personal Information Card
                        _buildSectionTitle('Personal Information'),
                        const SizedBox(height: 12),
                        _buildInfoCard([
                          _buildInfoRow(
                            icon: Icons.person_outline,
                            label: 'Full Name',
                            value: _fullName.isEmpty ? 'Not set' : _fullName,
                            isEmpty: _fullName.isEmpty,
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            icon: Icons.alternate_email,
                            label: 'Username',
                            value: _username.isEmpty ? 'Not set' : _username,
                            isEmpty: _username.isEmpty,
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            icon: Icons.wc_outlined,
                            label: 'Gender',
                            value: _gender.isEmpty ? 'Not set' : _gender,
                            isEmpty: _gender.isEmpty,
                          ),
                        ]),
                        const SizedBox(height: 20),

                        // Professional Information Card
                        _buildSectionTitle('Professional Information'),
                        const SizedBox(height: 12),
                        _buildInfoCard([
                          _buildInfoRow(
                            icon: Icons.badge_outlined,
                            label: 'LSK Number',
                            value: _lskNumber.isEmpty ? 'Not set' : _lskNumber,
                            isEmpty: _lskNumber.isEmpty,
                          ),
                        ]),
                        const SizedBox(height: 20),

                        // Account Information Card
                        _buildSectionTitle('Account Information'),
                        const SizedBox(height: 12),
                        _buildInfoCard([
                          _buildInfoRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: _email,
                            isEmpty: false,
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Member Since',
                            value: _memberSince,
                            isEmpty: false,
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            icon: Icons.fingerprint,
                            label: 'User ID',
                            value: _userId.substring(0, 8) + '...',
                            isEmpty: false,
                            isSmall: true,
                          ),
                        ]),
                        const SizedBox(height: 32),

                        // Edit Profile Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _navigateToEditProfile,
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            label: const Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A8A),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              elevation: 2,
                              shadowColor: const Color(0xFF1E3A8A)
                                  .withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _handleLogout,
                            icon: const Icon(Icons.logout, size: 20),
                            label: const Text(
                              'Logout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(
                                color: Color(0xFFEF4444),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _fullName.isNotEmpty
                    ? _fullName
                        .split(' ')
                        .map((e) => e[0])
                        .take(2)
                        .join()
                        .toUpperCase()
                    : _email.isNotEmpty
                        ? _email[0].toUpperCase()
                        : 'A',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _fullName.isEmpty ? 'Advocate' : _fullName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _username.isNotEmpty ? '@$_username' : _email,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
          if (_lskNumber.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LSK: $_lskNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1F2937),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
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
        children: children,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isEmpty,
    bool isSmall = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A8A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF1E3A8A),
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
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
                value,
                style: TextStyle(
                  fontSize: isSmall ? 14 : 16,
                  color: isEmpty
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF1F2937),
                  fontWeight: isEmpty ? FontWeight.normal : FontWeight.w600,
                  fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
        if (isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Incomplete',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFFF59E0B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}
