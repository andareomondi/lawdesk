import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as dart_ui;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:lawdesk/screens/profile/update_profile.dart';
import 'package:lawdesk/screens/profile/profile.dart';
import 'package:lawdesk/widgets/cases/list.dart';
import 'package:lawdesk/screens/cases/casepage.dart';
import 'package:lawdesk/widgets/cases/modal.dart';
import 'package:lawdesk/screens/documents/userDocuments.dart';
import 'package:lawdesk/widgets/dashboard/statCard.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:lawdesk/widgets/delightful_toast.dart';
import 'package:lawdesk/widgets/cases/client_modal.dart';
import 'package:lawdesk/widgets/dashboard/dashboard_drawer.dart';
import 'package:lawdesk/services/connectivity_service.dart';
import 'package:lawdesk/services/offline_storage_service.dart';
import 'package:lawdesk/widgets/offline_indicator.dart';
import 'package:lawdesk/utils/offline_action_helper.dart';
import 'package:lawdesk/widgets/cases/details.dart';
import 'package:lawdesk/main.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with TickerProviderStateMixin, RouteAware {
  final _supabase = Supabase.instance.client;
  final _updater = ShorebirdUpdater();

  final GlobalKey<CasesListWidgetState> _casesListKey = GlobalKey();
  final GlobalKey<StatsSectionState> _statsKey = GlobalKey<StatsSectionState>();
  // just a comment

  final GlobalKey<CaseDetailsPageState> _caseDetailsKey = GlobalKey();
  // User data variables
  String _userName = '';
  String _userEmail = '';
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _isUpdated = false;
  bool _hasCheckedProfile = false;
  bool _isOfflineMode = false;
  // Shorebird update variables
  bool _isCheckingForUpdate = false;
  bool _isDownloadingUpdate = false;
  int? _currentPatchNumber;

  // FAB expansion state
  bool _isFabExpanded = false;

  // Animation controller for shimmer effect
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  late AnimationController _fabController;
  late Animation<double> _expandAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

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
          // When connection is restored, refresh data
          OfflineStorageService()
              .synchronizeAllData(); // Get all data first if possible
          _loadUserData();
          _casesListKey.currentState?.loadCases();
          _statsKey.currentState?.loadStats();
          _caseDetailsKey.currentState?.loadCaseDetails();

          AppToast.showSuccess(
            context: context,
            title: "Back Online",
            message: "Connection restored. Data synced.",
          );
        }
      }
    });

    if (connectivityService.isConnected) {
      OfflineStorageService().synchronizeAllData();
    }

    _loadUserData();
    _checkCurrentPatch();
    _checkForShorebirdUpdates();

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void didPopNext() {
    // Refresh data when returning to this screen
    _loadUserData();
    _casesListKey.currentState?.loadCases();
    _statsKey.currentState?.loadStats();
    _caseDetailsKey.currentState?.loadCaseDetails();
    super.didPopNext();
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
    routeObserver.unsubscribe(this);
    _shimmerController.dispose();
    _fabController.dispose();
    super.dispose();
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
    // Check if online before refreshing
    if (!OfflineActionHelper.canPerformAction(context, actionName: 'refresh')) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _loadUserData();
      await _checkForShorebirdUpdates();

      _casesListKey.currentState?.loadCases();
      _statsKey.currentState?.loadStats();

      if (mounted) {
        HapticFeedback.mediumImpact();
        AppToast.showSuccess(
          context: context,
          title: "Success!",
          message: "Dashboard refreshed successfully",
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context: context,
          title: "Error",
          message: "Error refreshing. Make sure you are online",
        );
      }
    }
  }

  Future<void> _downloadAndApplyUpdate() async {
    setState(() {
      _isDownloadingUpdate = true;
    });

    try {
      await _updater.update();

      setState(() {
        _isDownloadingUpdate = false;
      });

      if (mounted) {
        _showUpdateSuccessDialog();
      }
    } on UpdateException catch (error) {
      setState(() {
        _isDownloadingUpdate = false;
      });
    } catch (e) {
      setState(() {
        _isDownloadingUpdate = false;
      });
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
                    AppToast.showSuccess(
                      context: context,
                      title: "Hurray!",
                      message:
                          "Please close and reopen the app to complete the update",
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
      final user = _supabase.auth.currentUser;

      if (user != null) {
        setState(() {
          _userEmail = user.email ?? '';
        });

        // Try to fetch from server if online
        if (connectivityService.isConnected) {
          final response = await _supabase
              .from('profiles')
              .select()
              .eq('id', user.id)
              .single();

          if (mounted) {
            setState(() {
              _userProfile = response;
              _userName = response['username'] ?? '';
              _userEmail = response['email'] ?? '';
              _isUpdated = response['is_updated'] == true;
              _isLoading = false;
            });

            // Cache the profile data
            await offlineStorage.cacheProfile(response);

            if (!_isUpdated && !_hasCheckedProfile) {
              _hasCheckedProfile = true;
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _showProfileUpdateToast(context);
                }
              });
            }
          }
        } else {
          // Load from cache when offline
          final cachedProfile = await offlineStorage.getCachedProfile();
          if (cachedProfile != null && mounted) {
            setState(() {
              _userProfile = cachedProfile;
              _userName = cachedProfile['username'] ?? '';
              _userEmail = cachedProfile['email'] ?? '';
              _isUpdated = cachedProfile['is_updated'] == true;
              _isLoading = false;
            });
          } else {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');

      // Try to load from cache on error
      final cachedProfile = await offlineStorage.getCachedProfile();
      if (cachedProfile != null && mounted) {
        setState(() {
          _userProfile = cachedProfile;
          _userName = cachedProfile['username'] ?? '';
          _userEmail = cachedProfile['email'] ?? '';
          _isUpdated = cachedProfile['is_updated'] == true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
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
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
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
                      onPressed: () async {
                        Navigator.of(context).pop();
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileUpdateScreen(),
                          ),
                        );
                        if (result == true) {
                          _hasCheckedProfile = false;
                          _loadUserData();
                        }
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

  void _toggleFab() {
    HapticFeedback.lightImpact();
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  void _closeFab() {
    if (_isFabExpanded) {
      setState(() {
        _isFabExpanded = false;
        _fabController.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // We use PopScope to close the FAB if the user presses the back button
    return PopScope(
      canPop: !_isFabExpanded,
      onPopInvoked: (didPop) {
        if (!didPop && _isFabExpanded) {
          _closeFab();
        }
      },
      child: Scaffold(
        extendBody: true,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Dashboard',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          actions: [
            // Move the menu icon to actions (right side)
            Builder(
              builder: (context) {
                return IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Scaffold.of(
                      context,
                    ).openEndDrawer(); // Use openEndDrawer instead
                  },
                );
              },
            ),
          ],
          // Add connection status indicator in AppBar
        ),
        endDrawer: DashboardDrawer(
          userName: _userName,
          userEmail: _userEmail,
          onProfileUpdate: () {
            _hasCheckedProfile = false;
            _loadUserData();
          },
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Main Content
            LiquidPullToRefresh(
              onRefresh: _refreshDashboard,
              color: const Color(0xFF1E3A8A),
              height: 80,
              backgroundColor: Colors.white,
              animSpeedFactor: 2.0,
              showChildOpacityTransition: true,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Show offline indicator when offline
                    if (_isOfflineMode) const OfflineDataIndicator(),

                    _isLoading
                        ? _buildShimmerWelcomeCard()
                        : _buildWelcomeSection(),
                    const SizedBox(height: 16),
                    _isLoading
                        ? _buildShimmerStatsCards()
                        : StatsSection(key: _statsKey),
                    const SizedBox(height: 16),
                    _buildUpcomingDatesSection(context),
                    const SizedBox(height: 16),
                    // button to trigger the instant notification for testing
                  ],
                ),
              ),
            ),

            // Overlay for expanded FAB
            if (_isFabExpanded)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeFab,
                  child: GestureDetector(
                    onTap: _closeFab,
                    child: ClipRect(
                      // Clips the blur to the widget's bounds
                      child: BackdropFilter(
                        filter: dart_ui.ImageFilter.blur(
                          sigmaX: 3.0,
                          sigmaY: 3.0,
                        ),
                        child: Container(
                          color: Colors.black.withOpacity(0.6),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // FAB and menu items remain the same...
            Positioned(
              right: 16,
              bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildFabMenuItem(
                    label: 'Review Documents',
                    icon: Icons.description_outlined,
                    color: const Color(0xFFF59E0B),
                    delay: 1,
                    onPressed: () {
                      {
                        _closeFab();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AllDocumentsPage(),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFabMenuItem(
                    label: 'Register Client',
                    icon: Icons.person_add_alt_outlined,
                    color: const Color(0xFF8B5CF6),
                    delay: 2,
                    onPressed: () {
                      if (OfflineActionHelper.canPerformAction(
                        context,
                        actionName: 'register a new client',
                      )) {
                        _closeFab();
                        AddClientModal.show(
                          context,
                          onClientAdded: () {
                            _loadUserData();
                          },
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFabMenuItem(
                    label: 'Open Case',
                    icon: Icons.add_circle_outline,
                    color: const Color(0xFF1E3A8A),
                    delay: 3,
                    onPressed: () {
                      if (OfflineActionHelper.canPerformAction(
                        context,
                        actionName: 'open a new case',
                      )) {
                        _closeFab();
                        AddCaseModal.show(
                          context,
                          onCaseAdded: () {
                            _casesListKey.currentState?.loadCases();
                            _statsKey.currentState?.loadStats();
                          },
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  FloatingActionButton.extended(
                    heroTag: 'main_fab',
                    onPressed: _toggleFab,
                    backgroundColor: const Color(0xFF1E3A8A),
                    elevation: 6,
                    label: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                      child: Text(
                        _isFabExpanded ? 'Close' : 'Quick Actions',
                        key: ValueKey<bool>(_isFabExpanded),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    icon: AnimatedRotation(
                      turns: _isFabExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        color: Colors.white,
                        _isFabExpanded ? Icons.close : Icons.apps,
                        key: ValueKey<bool>(_isFabExpanded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFabMenuItem({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required int delay,
  }) {
    // We calculate a staggered animation interval for each item
    final intervalStart = 0.1 * delay;
    final intervalEnd = 0.6 + (0.1 * delay);

    final animation = CurvedAnimation(
      parent: _fabController,
      curve: Interval(
        intervalStart > 1.0 ? 1.0 : intervalStart,
        intervalEnd > 1.0 ? 1.0 : intervalEnd,
        curve: Curves.easeOutBack,
      ),
    );

    return ScaleTransition(
      scale: animation,
      alignment: Alignment.centerRight,
      child: FadeTransition(
        opacity: animation,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Button
            FloatingActionButton(
              heroTag: 'fab_$label', // Unique tag to prevent errors
              onPressed: onPressed,
              backgroundColor: color,
              mini: true,
              elevation: 4,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(
              width: 4,
            ), // Tiny adjustment to align center of mini FAB with main FAB
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerStatsCards() {
    return Row(
      children: List.generate(2, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < 2 ? 12 : 0),
            child: AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (context, child) {
                return Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
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
                        (_shimmerAnimation.value + index * 0.2).clamp(0.0, 1.0),
                        1.0,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWelcomeSection() {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
        if (result == true) {
          _hasCheckedProfile = false;
          _loadUserData();
        }
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
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userName.isNotEmpty
                        ? _userName.toUpperCase()
                        : 'LAWDESK USER',
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
                          _userProfile != null &&
                                  _userProfile!['lsk_number'] != null
                              ? 'LSK No: ${_userProfile!['lsk_number']}'
                              : 'Tap to update profile',
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
            const Icon(Icons.gavel, size: 60, color: Colors.white24),
          ],
        ),
      ),
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
                    builder: (context) =>
                        const CasesPage(), // This navigates to the full cases page
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
        _isLoading
            ? _buildShimmerCasesList() // Show shimmer during loading
            : CasesListWidget(
                key: _casesListKey,
                onCaseChanged: () {
                  _statsKey.currentState?.loadStats();
                },
              ),
      ],
    );
  }

  Widget _buildShimmerWelcomeCard() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFE5E7EB),
                const Color(0xFFF3F4F6),
                const Color(0xFFE5E7EB),
              ],
              stops: [0.0, _shimmerAnimation.value.clamp(0.0, 1.0), 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerCasesList() {
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return Container(
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
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
                      (_shimmerAnimation.value + index * 0.3).clamp(0.0, 1.0),
                      1.0,
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
