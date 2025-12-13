import 'package:flutter/material.dart';
import 'package:lawdesk/screens/cases/all_cases_list.dart'; // CHANGED IMPORT
import 'package:lawdesk/widgets/cases/modal.dart';

class CasesPage extends StatefulWidget {
  const CasesPage({Key? key}) : super(key: key);

  @override
  State<CasesPage> createState() => _CasesPageState();
}

class _CasesPageState extends State<CasesPage> {
  // Use GlobalKey for the all cases list
  final GlobalKey<AllCasesListWidgetState> _allCasesListKey = GlobalKey<AllCasesListWidgetState>();

  void _refreshCases() {
    _allCasesListKey.currentState?.loadCases();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Color(0xFF1E3A8A),
        elevation: 0,
        title: const Text(
          'My Cases',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                  
                  // All Cases List with filtering
                  AllCasesListWidget(key: _allCasesListKey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
