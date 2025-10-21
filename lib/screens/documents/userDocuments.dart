import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lawdesk/screens/documents/upload.dart';

class AllDocumentsPage extends StatefulWidget {
  const AllDocumentsPage({Key? key}) : super(key: key);

  @override
  State<AllDocumentsPage> createState() => _AllDocumentsPageState();
}

class _AllDocumentsPageState extends State<AllDocumentsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _documents = [];
  Map<int, Map<String, dynamic>> _casesMap = {};
  bool _isLoading = true;
  String _selectedFilter = 'All';
  String _searchQuery = '';

  final List<String> _documentTypes = [
    'All',
    'Evidence',
    'Contract',
    'Report',
    'Affidavit',
    'Pleading',
    'Judgment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadAllDocuments();
  }

  Future<void> _loadAllDocuments() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // First, get all user's cases
      final casesResponse = await _supabase
          .from('cases')
          .select()
          .eq('user', user.id);

      // Create a map of case IDs to case data
      _casesMap = {};
      for (var caseData in casesResponse) {
        _casesMap[caseData['id']] = caseData;
      }

      // Get all case IDs
      final caseIds = _casesMap.keys.toList();

      if (caseIds.isEmpty) {
        setState(() {
          _documents = [];
          _isLoading = false;
        });
        return;
      }

      // Get all documents for these cases
      final documentsResponse = await _supabase
          .from('documents')
          .select()
          .inFilter('case_id', caseIds)
          .order('created_at', ascending: false);

      setState(() {
        _documents = List<Map<String, dynamic>>.from(documentsResponse);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading documents: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading documents: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredDocuments() {
    var filtered = _documents;

    // Apply type filter
    if (_selectedFilter != 'All') {
      filtered = filtered.where((doc) {
        return doc['document_type']?.toLowerCase() == _selectedFilter.toLowerCase();
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((doc) {
        final fileName = doc['file_name']?.toString().toLowerCase() ?? '';
        final caseName = _casesMap[doc['case_id']]?['name']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return fileName.contains(query) || caseName.contains(query);
      }).toList();
    }

    return filtered;
  }

  Map<String, List<Map<String, dynamic>>> _groupDocumentsByCase() {
    final filtered = _getFilteredDocuments();
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (var doc in filtered) {
      final caseId = doc['case_id'].toString();
      final caseName = _casesMap[doc['case_id']]?['name'] ?? 'Unknown Case';
      
      grouped.putIfAbsent(caseName, () => []);
      grouped[caseName]!.add(doc);
    }

    return grouped;
  }

  Map<String, int> _getDocumentTypeStats() {
    final stats = <String, int>{};
    for (var doc in _documents) {
      final type = doc['document_type'] ?? 'Other';
      stats[type] = (stats[type] ?? 0) + 1;
    }
    return stats;
  }

  int _getTotalFileSize() {
    return _documents.fold<int>(
      0,
      (sum, doc) => sum + (doc['file_size'] as int? ?? 0),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

  void _navigateToCaseDocuments(int caseId, String caseName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CaseDocumentsPage(
          caseId: caseId,
          caseName: caseName,
        ),
      ),
    ).then((_) => _loadAllDocuments());
  }

  Future<void> _deleteDocument(Map<String, dynamic> doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Delete Document',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        content: Text('Are you sure you want to delete "${doc['file_name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.storage
            .from('case-documents')
            .remove([doc['file_path']]);

        await _supabase.from('documents').delete().eq('id', doc['id']);

        await _loadAllDocuments();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document deleted successfully'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
        elevation: 0,
        title: const Text(
          'All Documents',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllDocuments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildStatsCard(),
                    _buildSearchBar(),
                    _buildFilterChips(),
                    Expanded(child: _buildDocumentsList()),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
              Icons.folder_open_outlined,
              size: 80,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Documents Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload documents to your cases to see them here',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go to Cases'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final totalSize = _getTotalFileSize();
    final stats = _getDocumentTypeStats();
    final uniqueCases = _documents.map((d) => d['case_id']).toSet().length;

    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.folder_outlined,
                label: 'Total Documents',
                value: '${_documents.length}',
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white24,
              ),
              _buildStatItem(
                icon: Icons.cases_outlined,
                label: 'Cases',
                value: '$uniqueCases',
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white24,
              ),
              _buildStatItem(
                icon: Icons.storage_outlined,
                label: 'Total Size',
                value: _formatFileSize(totalSize),
              ),
            ],
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
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search documents or cases...',
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

  Widget _buildFilterChips() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _documentTypes.length,
        itemBuilder: (context, index) {
          final type = _documentTypes[index];
          final isSelected = _selectedFilter == type;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = type;
                });
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF1E3A8A).withOpacity(0.2),
              checkmarkColor: const Color(0xFF1E3A8A),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF6B7280),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE5E7EB),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentsList() {
    final groupedDocs = _groupDocumentsByCase();
    
    if (groupedDocs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No documents found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedDocs.length,
      itemBuilder: (context, index) {
        final caseName = groupedDocs.keys.elementAt(index);
        final docs = groupedDocs[caseName]!;
        final caseId = docs.first['case_id'];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _navigateToCaseDocuments(caseId, caseName),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder,
                      color: Color(0xFF1E3A8A),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        caseName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${docs.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Color(0xFF1E3A8A),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...docs.map((doc) => _buildDocumentCard(doc, caseName)),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc, String caseName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
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
            color: _getDocumentColor(doc['document_type']).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              _getFileExtension(doc['file_name']),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _getDocumentColor(doc['document_type']),
              ),
            ),
          ),
        ),
        title: Text(
          doc['file_name'],
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1F2937),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _getDocumentIcon(doc['document_type']),
                  size: 14,
                  color: _getDocumentColor(doc['document_type']),
                ),
                const SizedBox(width: 4),
                Text(
                  doc['document_type'] ?? 'Other',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getDocumentColor(doc['document_type']),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${_formatFileSize(doc['file_size'] ?? 0)} • ${_formatDate(doc['created_at'])}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            if (value == 'view') {
              _navigateToCaseDocuments(doc['case_id'], caseName);
            } else if (value == 'delete') {
              _deleteDocument(doc);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.folder_open, size: 20, color: Color(0xFF6B7280)),
                  SizedBox(width: 12),
                  Text('View in Case'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
