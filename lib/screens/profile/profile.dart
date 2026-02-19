import 'package:flutter/material.dart';
import 'package:lawdesk/config/supabase_config.dart';
import 'package:lawdesk/providers/auth_provider.dart';
import 'update_profile.dart';
import 'package:lawdesk/widgets/delightful_toast.dart';
import 'package:lawdesk/services/connectivity_service.dart';
import 'package:lawdesk/services/offline_storage_service.dart';
import 'package:lawdesk/widgets/offline_indicator.dart';
import 'package:lawdesk/screens/auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = SupabaseConfig.client;

  String _fullName = '';
  String _username = '';
  String _email = '';
  String _gender = '';
  String _lskNumber = '';
  String _userId = '';
  String _memberSince = '';
  bool _isLoading = true;
  bool _isOfflineMode = false;

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _setupShimmerAnimation();
    _isOfflineMode = !connectivityService.isConnected;

    // Listen to connectivity changes
    connectivityService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isOfflineMode = !isConnected;
        });

        if (isConnected) {
          _loadUserProfile();
        }
      }
    });
    _loadUserProfile();
  }

  void _setupShimmerAnimation() {
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;

      if (user != null) {
        setState(() {
          _userId = user.id;
          _email = user.email ?? '';
          _memberSince = _formatDate(user.createdAt);
        });

        // Check if offline
        if (_isOfflineMode) {
          final cachedProfile = await offlineStorage.getCachedProfile();
          if (cachedProfile != null) {
            if (mounted) {
              setState(() {
                _fullName = cachedProfile['full_name'] ?? '';
                _username = cachedProfile['username'] ?? '';
                _gender = cachedProfile['gender'] ?? '';
                _lskNumber = cachedProfile['lsk_number'] ?? '';
                _isLoading = false;
              });
            }
          } else {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          }
          return;
        }

        try {
          final profile = await _supabase
              .from('profiles')
              .select()
              .eq('id', user.id)
              .single();

          // Cache the profile data
          await offlineStorage.cacheProfile(profile);

          if (mounted) {
            setState(() {
              _fullName = profile['full_name'] ?? '';
              _username = profile['username'] ?? '';
              _gender = profile['gender'] ?? '';
              _lskNumber = profile['lsk_number'] ?? '';
              _isLoading = false;
            });
          }
        } catch (e) {
          // Try to load from cache on error
          final cachedProfile = await offlineStorage.getCachedProfile();
          if (cachedProfile != null && mounted) {
            setState(() {
              _fullName = cachedProfile['full_name'] ?? '';
              _username = cachedProfile['username'] ?? '';
              _gender = cachedProfile['gender'] ?? '';
              _lskNumber = cachedProfile['lsk_number'] ?? '';
              _isLoading = false;
            });
          } else if (mounted) {
            setState(() {
              _fullName = user.userMetadata?['full_name'] ?? '';
              _username = user.userMetadata?['username'] ?? '';
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
      'December',
    ];
    return months[month - 1];
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      final authProvider = AuthProvider();

      try {
        await authProvider.signOut();

        if (mounted) {
          AppToast.showSuccess(
            context: context,
            title: "Operation sucessful",
            message: "Logged out successfully",
          );
          // Navigator.pop(context);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Error'),
              content: const Text('Error occurred during logging out'),
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

  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileUpdateScreen()),
    );
    if (result == true) {
      _loadUserProfile();
    }
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
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _isLoading ? _buildShimmerLoading() : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      key: const ValueKey('content'),
      child: Column(
        children: [
          _buildProfileHeader(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isOfflineMode) const OfflineDataIndicator(),
                if (_isOfflineMode) const SizedBox(height: 16),
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
                if (!_isOfflineMode) const SizedBox(height: 32),
                if (!_isOfflineMode)
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shadowColor: const Color(0xFF1E3A8A).withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (!_isOfflineMode) const SizedBox(height: 16),
                if (!_isOfflineMode)
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      key: const ValueKey('shimmer'),
      child: Column(
        children: [
          // Shimmer Profile Header
          Container(
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
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.5),
                            Colors.white.withOpacity(0.3),
                          ],
                          stops: [
                            0.0,
                            _shimmerAnimation.value.clamp(0.0, 1.0),
                            1.0,
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return Container(
                      height: 24,
                      width: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.5),
                            Colors.white.withOpacity(0.3),
                          ],
                          stops: [
                            0.0,
                            (_shimmerAnimation.value + 0.1).clamp(0.0, 1.0),
                            1.0,
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return Container(
                      height: 16,
                      width: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.5),
                            Colors.white.withOpacity(0.3),
                          ],
                          stops: [
                            0.0,
                            (_shimmerAnimation.value + 0.2).clamp(0.0, 1.0),
                            1.0,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Shimmer Content Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(3, (sectionIndex) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sectionIndex > 0) const SizedBox(height: 20),
                    AnimatedBuilder(
                      animation: _shimmerAnimation,
                      builder: (context, child) {
                        return Container(
                          height: 18,
                          width: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFE5E7EB),
                                const Color(0xFFF3F4F6),
                                const Color(0xFFE5E7EB),
                              ],
                              stops: [
                                0.0,
                                (_shimmerAnimation.value + sectionIndex * 0.1)
                                    .clamp(0.0, 1.0),
                                1.0,
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
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
                        children: List.generate(
                          sectionIndex == 0 ? 3 : (sectionIndex == 1 ? 1 : 3),
                          (rowIndex) {
                            return Column(
                              children: [
                                if (rowIndex > 0) const Divider(height: 24),
                                Row(
                                  children: [
                                    AnimatedBuilder(
                                      animation: _shimmerAnimation,
                                      builder: (context, child) {
                                        return Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                const Color(0xFFE5E7EB),
                                                const Color(0xFFF3F4F6),
                                                const Color(0xFFE5E7EB),
                                              ],
                                              stops: [
                                                0.0,
                                                (_shimmerAnimation.value +
                                                        sectionIndex * 0.1 +
                                                        rowIndex * 0.05)
                                                    .clamp(0.0, 1.0),
                                                1.0,
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AnimatedBuilder(
                                            animation: _shimmerAnimation,
                                            builder: (context, child) {
                                              return Container(
                                                height: 12,
                                                width: 80,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      const Color(0xFFE5E7EB),
                                                      const Color(0xFFF3F4F6),
                                                      const Color(0xFFE5E7EB),
                                                    ],
                                                    stops: [
                                                      0.0,
                                                      (_shimmerAnimation.value +
                                                              sectionIndex *
                                                                  0.1 +
                                                              rowIndex * 0.05 +
                                                              0.1)
                                                          .clamp(0.0, 1.0),
                                                      1.0,
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 6),
                                          AnimatedBuilder(
                                            animation: _shimmerAnimation,
                                            builder: (context, child) {
                                              return Container(
                                                height: 16,
                                                width: double.infinity,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      const Color(0xFFE5E7EB),
                                                      const Color(0xFFF3F4F6),
                                                      const Color(0xFFE5E7EB),
                                                    ],
                                                    stops: [
                                                      0.0,
                                                      (_shimmerAnimation.value +
                                                              sectionIndex *
                                                                  0.1 +
                                                              rowIndex * 0.05 +
                                                              0.2)
                                                          .clamp(0.0, 1.0),
                                                      1.0,
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
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
              border: Border.all(color: Colors.white, width: 4),
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
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, color: Colors.white, size: 16),
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
      child: Column(children: children),
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
          child: Icon(icon, color: const Color(0xFF1E3A8A), size: 22),
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
