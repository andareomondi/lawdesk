import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:lawdesk/screens/profile/update_profile.dart';
import 'package:lawdesk/screens/profile/profile.dart';
import 'package:lawdesk/widgets/cases/list.dart';
import 'package:lawdesk/screens/cases/casepage.dart';
import 'package:lawdesk/widgets/cases/modal.dart';
import 'package:lawdesk/screens/documents/userDocuments.dart';
import 'package:lawdesk/screens/calender/calender.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final _supabase = Supabase.instance.client;
  final _updater = ShorebirdUpdater();
  
  // User data variables
  String _userName = '';
  String _userEmail = '';
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _isUpdated = true;
  
  // Shorebird update variables
  bool _isCheckingForUpdate = false;
  bool _isDownloadingUpdate = false;
  int? _currentPatchNumber;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _checkCurrentPatch();
    _checkForShorebirdUpdates();
  }

  Future<void> _checkCurrentPatch() async {
    try {
      final currentPatch = await _updater.readCurrentPatch();
      setState(() {
        _currentPatchNumber = currentPatch?.number;
      });
      print('Current patch number: $_currentPatchNumber');
    } catch (e) {
      print('Error reading current patch');
    }
  }

  Future<void> _checkForShorebirdUpdates() async {
    if (_isCheckingForUpdate || _isDownloadingUpdate) return;

    setState(() {
      _isCheckingForUpdate = true;
    });

    try {
      // Check for update status
      final status = await _updater.checkForUpdate();
      
      setState(() {
        _isCheckingForUpdate = false;
      });

      if (status == UpdateStatus.outdated) {
        print('Update available! Starting download...');
        _downloadAndApplyUpdate();
      } else if (status == UpdateStatus.upToDate) {
        print('App is up to date');
      } else if (status == UpdateStatus.restartRequired) {
        if (mounted) {
          _showRestartRequiredDialog();
        }
      }
      
    } catch (e) {
      setState(() {
        _isCheckingForUpdate = false;
      });
    }
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Reload user data and profile
      await _loadUserData();
      
      // Check for Shorebird updates
      await _checkForShorebirdUpdates();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dashboard refreshed successfully'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing. Make sure you are online'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadAndApplyUpdate() async {
    setState(() {
      _isDownloadingUpdate = true;
    });

    try {
      // Download and apply the update
      await _updater.update();
      
      setState(() {
        _isDownloadingUpdate = false;
      });

      // Show dialog after successful update
      if (mounted) {
        _showUpdateSuccessDialog();
      }
      
    } on UpdateException catch (error) {
      setState(() {
        _isDownloadingUpdate = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed to initialize. Please Refresh'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloadingUpdate = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed to initialize. Please Refresh'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUpdateSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF10B981),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Update Downloaded',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'The app has been updated successfully. Please restart the app to apply the changes.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please close and reopen the app to complete the update'),
                        duration: Duration(seconds: 5),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRestartRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restart_alt,
                  color: Color(0xFFF59E0B),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Restart Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'An update is ready. Please restart the app to complete the installation.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadUserData() async {
    try {
      // Get current user from auth
      final user = _supabase.auth.currentUser;
      
      if (user != null) {
        setState(() {
          _userEmail = user.email ?? '';
        });

        // Fetch user profile from your profiles table
        final response = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();

        setState(() {
          _userProfile = response;
          _userName = response['username'];
          _userEmail = response['email'];
          _isUpdated = response['is_updated'] ?? false; 
          _isLoading = false;
        });
        
        // Show toast notification if profile is not updated
        if (!_isUpdated) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showProfileUpdateToast(context);
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showProfileUpdateToast(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFFF59E0B),
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Profile Update Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Please update your profile information to continue using the app.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                      ),
                      child: const Text(
                        'Later',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ProfileUpdateScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Update Now',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isCheckingForUpdate || _isDownloadingUpdate || _isLoading
                ? null
                : _refreshDashboard,
            tooltip: 'Refresh Dashboard',
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  _buildWelcomeSection(),
                  const SizedBox(height: 24),
                  
                  // Stats Cards
                  _buildStatsSection(),
                  const SizedBox(height: 24),
                  
                  // Upcoming Court Dates Section
                  _buildUpcomingDatesSection(context),
                  const SizedBox(height: 24),
                  
                  // Quick Actions
                  _buildQuickActionsSection(context),
                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeSection() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back,',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _userProfile != null && _userProfile!['lsk_number'] != null
                              ? 'LSK No: ${_userProfile!['lsk_number']}'
                              : 'You have 5 cases due this week',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.gavel,
              size: 60,
              color: Colors.white24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const CasesPage()), );
          },
            child: _StatCard(
              title: 'Total Cases',
              value: '24',
              icon: Icons.folder_outlined,
              color: const Color(0xFF1E3A8A),
              trend: '+3 this month',
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const CalendarPage()),);
          },
            child: _StatCard(
              title: 'Due This Week',
              value: '5',
              icon: Icons.event_outlined,
              color: const Color(0xFFF59E0B),
              trend: '2 urgent',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingDatesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Upcoming Court Dates',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CalendarPage(),
                  ),
                );
              },
              child: const Text(
                'View All',
                style: TextStyle(color: Color(0xFF1E3A8A)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const CasesListWidget(),
      ],
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'New Case',
                icon: Icons.add_circle_outline,
                color: const Color(0xFF1E3A8A),
                onPressed: () {
                  AddCaseModal.show(context, onCaseAdded: () {
                    setState(() {});
                    },
                    );
                  
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                label: 'View Calendar',
                icon: Icons.calendar_month_outlined,
                color: const Color(0xFF10B981),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CalendarPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: 'All Cases',
                icon: Icons.folder_open_outlined,
                color: const Color(0xFF8B5CF6),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CasesPage()));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                label: 'Documents',
                icon: Icons.description_outlined,
                color: const Color(0xFFF59E0B),
                onPressed: () {
                  Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AllDocumentsPage(),
      ),
    );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            trend,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

// Action Button Widget
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 2,
        shadowColor: color.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
