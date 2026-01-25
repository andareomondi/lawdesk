import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lawdesk/providers/auth_provider.dart';
import 'package:lawdesk/widgets/delightful_toast.dart';
import 'package:intl/intl.dart';

class SubscriptionEndedScreen extends StatelessWidget {
  const SubscriptionEndedScreen({super.key});

  static const String _adminPhoneNumber = '0741716609';

  Future<void> _makePhoneCall(BuildContext context) async {
    final Uri launchUri = Uri(scheme: 'tel', path: _adminPhoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (context.mounted) {
        AppToast.showError(
          context: context,
          title: 'Error',
          message: 'Could not launch dialer',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final profile = authProvider.profile;

    // Determine if blocked (is_activated = false) or just expired
    final bool isBlocked = profile != null && profile['is_activated'] == false;
    final String dateStr = profile?['subscription_end_date'] ?? '';
    String formattedDate = 'Unknown';

    if (dateStr.isNotEmpty) {
      final date = DateTime.parse(dateStr).toLocal();
      formattedDate = DateFormat('dd MMM yyyy').format(date);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isBlocked ? Colors.red[50] : Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBlocked ? Icons.block : Icons.timer_off_outlined,
                  size: 64,
                  color: isBlocked ? Colors.red : Colors.orange,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                isBlocked ? 'Account Suspended' : 'Subscription Ended',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Explanation
              Text(
                isBlocked
                    ? 'Your account has been deactivated due to policy violations or administrative action. Please contact support.'
                    : 'Your subscription expired on $formattedDate. You cannot access the dashboard until you renew your plan.',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              // -----------------------------------------------------
              // Payment Instructions & "I've Paid" Button
              // ONLY visible if NOT blocked
              // -----------------------------------------------------
              if (!isBlocked) ...[
                const SizedBox(height: 32),
                // Payment Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'To Reactivate Your Account:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.payment,
                              size: 20,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Send Ksh 1,000',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('MPESA to $_adminPhoneNumber'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        'After payment, please wait for account reopening.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Refresh Button (Primary Action for Expired Users)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : () async {
                            await authProvider.refreshProfile();
                            if (context.mounted) {
                              if (authProvider.status ==
                                  AuthStatus.authenticated) {
                                AppToast.showSuccess(
                                  context: context,
                                  title: "Welcome Back",
                                  message: "Your subscription is active.",
                                );
                              } else {
                                AppToast.showError(
                                  context: context,
                                  title: "Still Inactive",
                                  message: "Status has not changed yet.",
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('I Have Paid (Refresh Status)'),
                  ),
                ),
              ],

              // -----------------------------------------------------
              const SizedBox(height: 24),

              // Call Button (Available to both blocked and expired users)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _makePhoneCall(context),
                  icon: const Icon(Icons.call),
                  label: const Text('Call Admin Support'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFF1E3A8A)),
                    foregroundColor: const Color(0xFF1E3A8A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Logout Button (Bottom)
              TextButton.icon(
                onPressed: () => authProvider.signOut(),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Logout'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
