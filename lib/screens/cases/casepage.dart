import 'package:flutter/material.dart';
import 'package:lawdesk/screens/cases/case_list.dart';
import 'package:lawdesk/widgets/cases/modal.dart';

class CasesPage extends StatefulWidget {
  const CasesPage({Key? key}) : super(key: key);

  @override
  State<CasesPage> createState() => _CasesPageState();
}

class _CasesPageState extends State<CasesPage> {
  // Key to force rebuild of CasesList
  Key _casesListKey = UniqueKey();

  void _refreshCases() {
    setState(() {
      _casesListKey = UniqueKey(); // Force CasesList to rebuild
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Cases',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFF6B7280)),
            onPressed: () {
              // TODO: Implement filter functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Filter coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF6B7280)),
            onPressed: () {
              // TODO: Implement search functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search coming soon')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _refreshCases();
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.gavel,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Court Cases',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Stay updated on all your cases',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'All Cases',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          AddCaseModal.show(
                            context,
                            onCaseAdded: _refreshCases,
                          );
                        },
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Add Case'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Cases List with key to force rebuild
                  CasesListWidget(key: _casesListKey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
