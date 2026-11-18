import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'reminders.dart';

const sage = Color(0xFF5E7F5C),
    sageLight = Color(0xFFDDE8DA),
    smoky = Color(0xFFF5F5F0),
    ink = Color(0xFF2E3A2D),
    danger = Color(0xFFC0504D);
SupabaseClient get db => Supabase.instance.client;
Map<String, dynamic>? me;

Future<void> loadMe() async {
  final u = db.auth.currentUser;
  me = u == null
      ? null
      : await db.from('profiles').select().eq('id', u.id).single();
}

String homeFor(Map p) {
  switch (p['role']) {
    case 'DOCTOR':
      return p['verification_status'] == 'APPROVED'
          ? '/doctor/dashboard'
          : '/doctor/pending';
    case 'ADMIN':
      return '/admin/dashboard';
    default:
      return '/dashboard';
  }
}

Widget brandLogo(double size) => Image.asset(
      'assets/images/steady_recovery_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(Icons.spa, size: size, color: sage),
    );

AppBar brandAppBar({
  Widget? title,
  List<Widget>? actions,
  VoidCallback? onBack,
  bool showDrawerMenu = false,
}) =>
    AppBar(
      automaticallyImplyLeading: false,
      leading: onBack == null
          ? (showDrawerMenu ? drawerMenuButton() : null)
          : IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          brandLogo(38),
          if (title != null) ...[
            const SizedBox(width: 10),
            Flexible(child: title),
          ],
        ],
      ),
      actions: [
        ...?actions,
        if (showDrawerMenu && onBack != null) drawerMenuButton(),
      ],
    );

Widget drawerMenuButton() => Builder(
      builder: (context) => IconButton(
        tooltip: 'Open menu',
        icon: const Icon(Icons.menu),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
    );

ThemeData theme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8BA888), primary: sage, surface: smoky),
      scaffoldBackgroundColor: smoky,
      textTheme: GoogleFonts.nunitoTextTheme()
          .apply(bodyColor: ink, displayColor: ink),
      appBarTheme: const AppBarTheme(backgroundColor: smoky, elevation: 0),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: sage, minimumSize: const Size.fromHeight(52))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none)),
    );

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<void> signOut(BuildContext c) async {
  await ReminderService.cancelForSignOut();
  await db.auth.signOut();
  me = null;
  if (c.mounted) c.go('/');
}

Widget logoutBtn(BuildContext c) =>
    IconButton(icon: const Icon(Icons.logout), onPressed: () => signOut(c));
