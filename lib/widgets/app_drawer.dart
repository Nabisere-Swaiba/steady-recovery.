import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../common.dart';

class AppDrawer extends StatelessWidget {
  final BuildContext pageContext;
  final Future<void> Function()? onGenerateReport;
  final VoidCallback? onRefresh;
  final VoidCallback? onAdminPatients;
  final VoidCallback? onAdminVerifications;

  const AppDrawer({
    super.key,
    required this.pageContext,
    this.onGenerateReport,
    this.onRefresh,
    this.onAdminPatients,
    this.onAdminVerifications,
  });

  @override
  Widget build(BuildContext context) {
    final role = '${me?['role'] ?? ''}';
    final name = '${me?['full_name'] ?? 'User'}';

    void select(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    Widget item(IconData icon, String title, VoidCallback action) => ListTile(
          leading: Icon(icon, color: sage),
          title: Text(title),
          onTap: () => select(action),
        );

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: sage),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          if (role == 'PATIENT') ...[
            item(Icons.grid_view_outlined, 'Today',
                () => pageContext.go('/dashboard')),
            item(Icons.monitor_heart_outlined, 'Check-ins',
                () => pageContext.go('/check-in')),
            item(Icons.shield_outlined, 'Get support',
                () => pageContext.go('/sos')),
            item(Icons.groups_outlined, 'Support Groups',
                () => pageContext.go('/groups')),
            item(Icons.self_improvement, 'When an urge shows up',
                () => pageContext.go('/tools')),
            item(Icons.assignment_outlined, 'Coping plan',
                () => pageContext.go('/blueprint', extra: '/sos')),
            if (onGenerateReport != null)
              item(Icons.description_outlined, 'Generate report',
                  () => onGenerateReport!()),
            item(Icons.settings_outlined, 'Settings',
                () => pageContext.go('/settings')),
          ] else if (role == 'DOCTOR') ...[
            item(Icons.medical_services_outlined, 'Clinical Command Center',
                () => pageContext.go('/doctor/dashboard')),
            if (onRefresh != null) item(Icons.refresh, 'Refresh', onRefresh!),
          ] else if (role == 'ADMIN') ...[
            item(
                Icons.verified_user_outlined,
                'Doctor verification',
                onAdminVerifications ??
                    () => pageContext.go('/admin/dashboard')),
            if (onAdminPatients != null)
              item(Icons.people_outline, 'Patients', onAdminPatients!),
          ],
          const Divider(),
          item(Icons.logout, 'Sign out', () => signOut(pageContext)),
        ],
      ),
    );
  }
}
