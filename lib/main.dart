import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reminders.dart';
import 'common.dart';
import 'auth.dart';
import 'patient.dart';
import 'doctor.dart';
import 'admin.dart';
import 'blueprint.dart';

const supabaseUrl = 'https://ompxchtwmptemnywubjf.supabase.co';
const supabaseKey = 'sb_publishable_YZwLzBMo20wOVdW3wUD7ug_KSJwTjtQ';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  ReminderService.setNotificationTapHandler(router.go);
  try {
    await ReminderService.initialize();
  } catch (e) {
    debugPrint('Local reminders could not be initialized: $e');
  }
  runApp(const App());
}

final router = GoRouter(
  initialLocation: '/splash',
  redirect: (c, s) {
    final p = s.matchedLocation;
    if (['/splash', '/', '/login', '/register'].contains(p)) return null;
    if (me == null) return '/';
    final h = homeFor(me!);
    final role = me!['role'];
    final ok = role == 'PATIENT'
        ? [
            '/dashboard',
            '/check-in',
            '/sos',
            '/groups',
            '/tools',
            '/settings',
            '/blueprint'
          ].contains(p)
        : role == 'DOCTOR'
            ? p == h
            : p.startsWith('/admin');
    return ok ? null : h; // route isolation (FR2)
  },
  routes: [
    GoRoute(path: '/splash', builder: (c, s) => const Splash()),
    GoRoute(path: '/', builder: (c, s) => const Landing()),
    GoRoute(path: '/login', builder: (c, s) => const Login()),
    GoRoute(path: '/register', builder: (c, s) => const Register()),
    GoRoute(path: '/dashboard', builder: (c, s) => const Shell(0)),
    GoRoute(path: '/check-in', builder: (c, s) => const Shell(1)),
    GoRoute(path: '/sos', builder: (c, s) => const Shell(2)),
    GoRoute(path: '/groups', builder: (c, s) => const Shell(3)),
    GoRoute(path: '/tools', builder: (c, s) => const ToolsPage()),
    GoRoute(path: '/settings', builder: (c, s) => const SettingsPage()),
    GoRoute(
      path: '/blueprint',
      builder: (c, s) => CopingPlanScreen(
        returnRoute: s.extra is String ? s.extra! as String : '/sos',
      ),
    ),
    GoRoute(path: '/doctor/dashboard', builder: (c, s) => const DoctorDash()),
    GoRoute(path: '/doctor/pending', builder: (c, s) => const Pending()),
    GoRoute(path: '/admin/dashboard', builder: (c, s) => const AdminDash()),
  ],
);

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp.router(
      title: 'SteadyRecovery',
      theme: theme(),
      routerConfig: router,
      debugShowCheckedModeBanner: false);
}
