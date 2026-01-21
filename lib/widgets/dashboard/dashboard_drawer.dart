import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:lawdesk/screens/profile/profile.dart';
import 'package:lawdesk/screens/cases/casepage.dart';
import 'package:lawdesk/screens/documents/userDocuments.dart';
import 'package:lawdesk/screens/calender/calender.dart';
import 'package:lawdesk/widgets/delightful_toast.dart';
import 'package:lawdesk/providers/auth_provider.dart';
import 'package:lawdesk/screens/help/help_support.dart';
import 'package:lawdesk/screens/clients/clients_page.dart';

class DashboardDrawer extends StatelessWidget {
  final String userName;
  final String userEmail;
  final VoidCallback onProfileUpdate;

  const DashboardDrawer({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.onProfileUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Drawer Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.of(context).padding.top + 24,
                24,
                24,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Logo/Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.gavel,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userName.isNotEmpty
                        ? userName.toUpperCase()
                        : 'LAWDESK USER',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userEmail,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.account_circle_outlined,
                    title: 'Profile',
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                      if (result == true) {
                        onProfileUpdate();
                      }
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.cases_outlined,
                    title: 'Cases',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CasesPage(),
                        ),
                      );
                    },
                  ),
                  // Added Clients Item
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.people_alt_outlined,
                    title: 'Clients',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ClientsPage(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.description_outlined,
                    title: 'Documents',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AllDocumentsPage(),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.calendar_month_outlined,
                    title: 'Calendar',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CalendarPage(),
                        ),
                      );
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      AppToast.showInfo(
                        context: context,
                        title: "Coming Soon",
                        message: "Settings page is under development",
                      );
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? const Color(0xFF6B7280),
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? const Color(0xFF1F2937),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
