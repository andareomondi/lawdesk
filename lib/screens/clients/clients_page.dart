import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lawdesk/widgets/delightful_toast.dart';
import 'package:lawdesk/services/connectivity_service.dart';
import 'package:lawdesk/services/offline_storage_service.dart';
import 'package:lawdesk/widgets/offline_indicator.dart';
import 'package:lawdesk/widgets/cases/client_modal.dart';
import 'package:lawdesk/screens/clients/client_details_page.dart';
import 'package:lawdesk/utils/offline_action_helper.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({Key? key}) : super(key: key);

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;
  String _searchQuery = '';

  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _setupShimmerAnimation();

    _isOfflineMode = !connectivityService.isConnected;

    connectivityService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isOfflineMode = !isConnected;
        });

        if (isConnected) {
          _loadClients();
        }
      }
    });

    _loadClients();
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

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      if (connectivityService.isConnected) {
        // Online: Fetch from Supabase
        final response = await _supabase
            .from('clients')
            .select()
            .eq('user', user.id)
            .order('created_at', ascending: false);

        if (mounted) {
          final clientsList = List<Map<String, dynamic>>.from(response);
          setState(() {
            _clients = clientsList;
            _isLoading = false;
          });

          // Cache the fresh data
          await offlineStorage.cacheClients(clientsList);
        }
      } else {
        // Offline: Load from cache
        final cachedClients = await offlineStorage.getCachedClients();
        if (mounted) {
          setState(() {
            if (cachedClients != null) {
              _clients = List<Map<String, dynamic>>.from(cachedClients);
            } else {
              _clients = [];
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Fallback to cache on error
      final cachedClients = await offlineStorage.getCachedClients();
      if (mounted) {
        setState(() {
          if (cachedClients != null) {
            _clients = List<Map<String, dynamic>>.from(cachedClients);
          }
          _isLoading = false;
        });

        // Only show error toast if we have no data at all
        if (_clients.isEmpty) {
          AppToast.showError(
            context: context,
            title: 'Error',
            message: 'Failed to load clients',
          );
        }
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredClients() {
    if (_searchQuery.isEmpty) return _clients;

    return _clients.where((client) {
      final name = client['name']?.toString().toLowerCase() ?? '';
      final email = client['email']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Clients',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isOfflineMode ? null : _loadClients,
          ),
        ],
      ),
      floatingActionButton: _isOfflineMode
          ? null // Hide FAB if offline (since we can't create clients offline usually)
          : FloatingActionButton(
              onPressed: () {
                if (OfflineActionHelper.canPerformAction(
                  context,
                  actionName: 'add client',
                )) {
                  AddClientModal.show(context, onClientAdded: _loadClients);
                }
              },
              backgroundColor: const Color(0xFF1E3A8A),
              child: const Icon(Icons.person_add, color: Colors.white),
            ),
      body: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            if (_isOfflineMode) const OfflineDataIndicator(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _isLoading
                    ? _buildShimmerLoading()
                    : _clients.isEmpty
                    ? _buildEmptyState()
                    : _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final filteredClients = _getFilteredClients();

    return Column(
      key: const ValueKey('content'),
      children: [
        _buildStatsCard(),
        _buildSearchBar(),
        Expanded(
          child: filteredClients.isEmpty
              ? _buildNoSearchResults()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                  itemCount: filteredClients.length,
                  itemBuilder: (context, index) {
                    return _buildClientCard(filteredClients[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStatItem(
            icon: Icons.people_outline,
            label: 'Total Clients',
            value: '${_clients.length}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search clients by name or email...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
          filled: true,
          fillColor: Colors.white,
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> client) {
    final String initial =
        client['name'] != null && client['name'].toString().isNotEmpty
        ? client['name'].toString()[0].toUpperCase()
        : '?';

    // Format phone number to include leading 0
    final String displayPhone = _formatPhoneNumber(client['phone']);

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClientDetailsPage(clientData: client),
          ),
        );
        // Refresh list if we return from details (in case of edit/delete)
        if (result == true) {
          _loadClients();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          title: Text(
            client['name'] ?? 'Unknown Name',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              if (client['email'] != null)
                Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      size: 14,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        client['email'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              if (displayPhone.isNotEmpty)
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      displayPhone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No clients found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const ValueKey('empty'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline,
              size: 80,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Clients Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first client to get started',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (!_isOfflineMode)
            ElevatedButton.icon(
              onPressed: () {
                if (OfflineActionHelper.canPerformAction(
                  context,
                  actionName: 'add client',
                )) {
                  AddClientModal.show(context, onClientAdded: _loadClients);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Client'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      key: const ValueKey('shimmer'),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(6, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (context, child) {
                return Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
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
                              (_shimmerAnimation.value + index * 0.2).clamp(
                                0.0,
                                1.0,
                              ),
                              1.0,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 16,
                              width: double.infinity,
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
                                    (_shimmerAnimation.value +
                                            index * 0.2 +
                                            0.1)
                                        .clamp(0.0, 1.0),
                                    1.0,
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 12,
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
                                    (_shimmerAnimation.value +
                                            index * 0.2 +
                                            0.2)
                                        .clamp(0.0, 1.0),
                                    1.0,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
