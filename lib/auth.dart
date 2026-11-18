import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'common.dart';
import 'reminders.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    try {
      await loadMe().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('Unable to restore session during startup: $e');
      me = null;
    }
    if (me != null && me!['role'] == 'PATIENT') {
      unawaited(ReminderService.refreshOnAppOpen('${me!['id']}'));
    }
    if (mounted) {
      final notificationRoute = ReminderService.takePendingRoute();
      context.go(me == null ? '/' : notificationRoute ?? homeFor(me!));
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      backgroundColor: sage,
      body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        brandLogo(80),
        SizedBox(height: 16),
        Text('SteadyRecovery',
            style: TextStyle(
                fontSize: 30,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
      ])));
}

class Landing extends StatelessWidget {
  const Landing({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: brandAppBar(title: const Text('SteadyRecovery')),
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('SteadyRecovery',
                        style: TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                        'One steady day at a time. Daily check-ins, urge support and clinical care in one place.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 40),
                    FilledButton(
                        onPressed: () => c.go('/login'),
                        child: const Text('Sign in')),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52)),
                        onPressed: () => c.go('/register'),
                        child: const Text('Create account')),
                  ]))));
}

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final email = TextEditingController(), pass = TextEditingController();
  bool busy = false;
  bool showPassword = false;

  Future<void> _submit() async {
    setState(() => busy = true);
    try {
      await db.auth
          .signInWithPassword(email: email.text.trim(), password: pass.text);
      await loadMe();
      if (me!['role'] == 'PATIENT') {
        unawaited(ReminderService.refreshOnAppOpen('${me!['id']}'));
      }
      if (mounted) context.go(homeFor(me!));
    } catch (e) {
      if (mounted) snack(context, 'Sign-in failed: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: brandAppBar(onBack: () => c.go('/')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Welcome back',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 12),
        TextField(
            controller: pass,
            obscureText: !showPassword,
            decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: sage,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(88, 48)),
                    onPressed: () =>
                        setState(() => showPassword = !showPassword),
                    icon: Icon(
                        showPassword ? Icons.visibility_off : Icons.visibility,
                        size: 22,
                        color: sage),
                    label: Text(showPassword ? 'Hide' : 'Show')))),
        const SizedBox(height: 24),
        FilledButton(
            onPressed: busy ? null : _submit,
            child: Text(busy ? 'Please wait...' : 'Sign in')),
        TextButton(
            onPressed: () => c.go('/register'),
            child: const Text('No account? Register')),
      ]));
}

class Register extends StatefulWidget {
  const Register({super.key});
  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final name = TextEditingController(),
      email = TextEditingController(),
      pass = TextEditingController();
  String role = 'PATIENT';
  String? doc;
  List docs = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _docs();
  }

  Future<void> _docs() async {
    try {
      final v = await db
          .from('profiles')
          .select('id,full_name')
          .eq('role', 'DOCTOR')
          .eq('verification_status', 'APPROVED');
      if (mounted) setState(() => docs = v);
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (name.text.trim().isEmpty || pass.text.length < 6) {
      snack(context, 'Enter your name and a password of 6+ characters');
      return;
    }
    setState(() => busy = true);
    try {
      final r = await db.auth.signUp(
          email: email.text.trim(),
          password: pass.text,
          data: {'role': role, 'full_name': name.text.trim()});
      if (r.session == null) {
        if (mounted) {
          snack(context, 'Check your email to confirm, then sign in.');
          context.go('/login');
        }
        return;
      }
      if (role == 'PATIENT') {
        await db
            .from('profiles')
            .update({'assigned_doctor_id': doc}).eq('id', r.user!.id);
      }
      await loadMe();
      if (me!['role'] == 'PATIENT') {
        unawaited(ReminderService.refreshOnAppOpen('${me!['id']}'));
      }
      if (mounted) context.go(homeFor(me!));
    } catch (e) {
      if (mounted) snack(context, '$e');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: brandAppBar(onBack: () => c.go('/')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Create account',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        SegmentedButton<String>(segments: const [
          ButtonSegment(value: 'PATIENT', label: Text('Patient')),
          ButtonSegment(value: 'DOCTOR', label: Text('Doctor'))
        ], selected: {
          role
        }, onSelectionChanged: (s) => setState(() => role = s.first)),
        const SizedBox(height: 16),
        TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Full name')),
        const SizedBox(height: 12),
        TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 12),
        TextField(
            controller: pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password')),
        const SizedBox(height: 12),
        if (role == 'PATIENT')
          DropdownButtonFormField<String>(
              value: doc,
              hint: const Text('Choose your doctor (optional)'),
              items: docs
                  .map((d) => DropdownMenuItem(
                      value: d['id'] as String, child: Text(d['full_name'])))
                  .toList(),
              onChanged: (v) => setState(() => doc = v),
              decoration: const InputDecoration())
        else
          const Text(
              'Doctor accounts stay PENDING until an administrator verifies your credentials.'),
        const SizedBox(height: 24),
        FilledButton(
            onPressed: busy ? null : _submit,
            child: Text(busy ? 'Please wait...' : 'Register')),
      ]));
}

class Pending extends StatelessWidget {
  const Pending({super.key});
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: brandAppBar(actions: [logoutBtn(c)]),
      body: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.hourglass_top, size: 80, color: sage),
            const SizedBox(height: 16),
            const Text('Verification pending',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                me?['verification_status'] == 'REJECTED'
                    ? 'Your application was not approved.'
                    : 'An administrator is reviewing your credentials. Clinical tools unlock once approved.',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: () async {
                  await loadMe();
                  if (c.mounted) c.go(homeFor(me!));
                },
                child: const Text('Check status')),
          ])));
}
