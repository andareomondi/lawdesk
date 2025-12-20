import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:lawdesk/widgets/delightful_toast.dart';

class CaseDocumentsPage extends StatefulWidget {
  final int caseId;
  final String caseName;

  const CaseDocumentsPage({
    Key? key,
    required this.caseId,
    required this.caseName,
  }) : super(key: key);

  @override
  State<CaseDocumentsPage> createState() => _CaseDocumentsPageState();
}

class _CaseDocumentsPageState extends State<CaseDocumentsPage> {
  final _supabase = Supabase.instance.client;
  
  // FIXED: Consistent bucket name throughout
  static const String BUCKET_NAME = 'case_documents';
  
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _selectedDocumentType;

  final List<String> _documentTypes = [
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
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('documents')
          .select()
          .eq('case_id', widget.caseId)
          .order('created_at', ascending: false);

      setState(() {
        _documents = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
       AppToast.showError(context: context, title: "Error occurred", message: "Failed to load documents: ${e.toString()}"); 
      }
    }
  }

  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        await _showDocumentTypeDialog(result.files.single);
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context: context, title: "Error occurred", message: "Failed to pick the document: ${e.toString()}");
      }
    }
  }

  Future<void> _showDocumentTypeDialog(PlatformFile file) async {
    String? selectedType = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Select Document Type',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _documentTypes.map((type) {
              return ListTile(
                title: Text(type),
                leading: Icon(
                  _getDocumentIcon(type),
                  color: const Color(0xFF1E3A8A),
                ),
                onTap: () => Navigator.pop(context, type),
              );
            }).toList(),
          ),
        );
      },
    );

    if (selectedType != null) {
      await _uploadDocument(file, selectedType);
    }
  }

  Future<void> _uploadDocument(PlatformFile file, String documentType) async {
    setState(() => _isUploading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No user logged in');

      // FIXED: Create flat file path without folder structure
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = file.name;
      // Use case_id as prefix in filename instead of folder
      final filePath = 'case_${widget.caseId}_${timestamp}_$fileName';

      print('Uploading to path: $filePath'); // Debug logging

      // Upload to Supabase Storage
      final fileBytes = await File(file.path!).readAsBytes();
      
      // FIXED: Added proper upload options
      final uploadResponse = await _supabase.storage
          .from(BUCKET_NAME)
          .uploadBinary(
            filePath, 
            fileBytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      print('Upload response: $uploadResponse'); // Debug logging

      // FIXED: Get public URL for the uploaded file
      final publicUrl = _supabase.storage
          .from(BUCKET_NAME)
          .getPublicUrl(filePath);

      print('Public URL: $publicUrl'); // Debug logging

      // Insert record into documents table
      final insertResponse = await _supabase.from('documents').insert({
        'case_id': widget.caseId,
        'uploaded_by': user.id,
        'file_name': fileName,
        'file_path': filePath,
        'file_size': file.size,
        'mime_type': file.extension,
        'document_type': documentType,
        'bucket_name': BUCKET_NAME,
        'public_url': publicUrl, // Store the public URL
      }).select();

      print('Insert response: $insertResponse'); // Debug logging

      // Reload documents
      await _loadDocuments();

      if (mounted) {
        AppToast.showSuccess(context: context, title: "Upload Successful", message: "Document uploaded successfully.");
      }
    } catch (e) {
      print('Upload error: $e'); // Debug logging
      if (mounted) {
        AppToast.showError(context: context, title: "Error occurred", message: "Failed to upload: ${e.toString()}");
      }
    } finally {
      setState(() => _isUploading = false);
    }
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
        // FIXED: Use consistent bucket name
        await _supabase.storage
            .from(BUCKET_NAME)
            .remove([doc['file_path']]);

        // Delete from database
        await _supabase.from('documents').delete().eq('id', doc['id']);

        await _loadDocuments();

        if (mounted) {
          AppToast.showSuccess(context: context, title: "Deletion Successful", message: "Document deleted successfully.");
        }
      } catch (e) {
        print('Delete error: $e'); // Debug logging
        if (mounted) {
          AppToast.showError(context: context, title: "Error occurred", message: "Failed to delete: ${e.toString()}");
        }
      }
    }
  }

  Future<void> _downloadDocument(Map<String, dynamic> doc) async {
    try {
      AppToast.showSuccess(context: context, title: "Download Started", message: "Downloading document...");

      // FIXED: Use consistent bucket name
      final response = await _supabase.storage
          .from(BUCKET_NAME)
          .download(doc['file_path']);

      // In a real app, you'd save this to the device
      // For now, just show success
      if (mounted) {
        AppToast.showSuccess(context: context, title: "Download Successful", message: "Document downloaded successfully (${response.length} bytes).");
      }
    } catch (e) {
      print('Download error: $e'); // Debug logging
      if (mounted) {
        AppToast.showError(context: context, title: "Error occurred", message: "Failed to download: ${e.toString()}");
      }
    }
  }

  String _getFileExtension(String fileName) {
    return fileName.split('.').last.toUpperCase();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Documents',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            Text(
              widget.caseName,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _documents.isEmpty
              ? _buildEmptyState()
              : _buildDocumentsList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickAndUploadFile,
        backgroundColor: const Color(0xFF1E3A8A),
        icon: _isUploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.add, color: Colors.white),
        label: Text(_isUploading ? 'Uploading...' : 'Upload Document', style: const TextStyle(color: Colors.white,),),
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
            'Upload your first document to get started',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickAndUploadFile,
            icon: const Icon(Icons.upload_file, color: Colors.white,),
            label: const Text('Upload Document'),
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

  Widget _buildDocumentsList() {
    // TODO: Add on click function which previews it if it's a viewable file. Viewable file include images and pdfs only
    // Group documents by type
    final groupedDocs = <String, List<Map<String, dynamic>>>{};
    for (var doc in _documents) {
      final type = doc['document_type'] ?? 'Other';
      groupedDocs.putIfAbsent(type, () => []);
      groupedDocs[type]!.add(doc);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Card
        _buildSummaryCard(),
        const SizedBox(height: 24),

        // Documents by type
        ...groupedDocs.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      _getDocumentIcon(entry.key),
                      size: 20,
                      color: _getDocumentColor(entry.key),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getDocumentColor(entry.key).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${entry.value.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getDocumentColor(entry.key),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...entry.value.map((doc) => _buildDocumentCard(doc)),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  Widget _buildSummaryCard() {
    final totalSize = _documents.fold<int>(
      0,
      (sum, doc) => sum + (doc['file_size'] as int? ?? 0),
    );

    return Container(
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
                  'Total Documents',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_documents.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total size: ${_formatFileSize(totalSize)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.folder_outlined,
            size: 80,
            color: Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Map<String, dynamic> doc) {
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
      child: Column(
        children: [
          ListTile(
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
                if (value == 'download') {
                  _downloadDocument(doc);
                } else if (value == 'delete') {
                  _deleteDocument(doc);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download, size: 20, color: Color(0xFF6B7280)),
                      SizedBox(width: 12),
                      Text('Download'),
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
        ],
      ),
    );
  }
}
