import 'package:flutter/material.dart';
import 'common.dart';
import 'widgets/app_drawer.dart';

class AdminDash extends StatefulWidget {
  const AdminDash({super.key});
  @override
  State<AdminDash> createState() => _AdminDashState();
}

class _AdminDashState extends State<AdminDash> {
  late Future f = _load();
  int _selectedIndex = 0;

  Future _load() => db
      .from('profiles')
      .select('id,full_name,email,verification_status')
      .eq('role', 'DOCTOR')
      .order('created_at', ascending: false);

  Future _loadPatients() => db
      .from('profiles')
      .select('id,full_name,email,assigned_doctor_id')
      .eq('role', 'PATIENT')
      .order('full_name');

  Future<void> _set(String id, String st) async {
    try {
      await db
          .rpc('set_doctor_status', params: {'doctor': id, 'new_status': st});
      if (mounted)
        setState(() {
          f = _load();
        });
    } catch (e) {
      if (mounted) snack(context, '$e');
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: brandAppBar(
          title: Text(_selectedIndex == 0
              ? 'Admin - Doctor verification'
              : 'Admin - Patients'),
          showDrawerMenu: true,
          actions: [logoutBtn(c)]),
      drawer: AppDrawer(
        pageContext: c,
        onAdminVerifications: () => setState(() {
          _selectedIndex = 0;
          f = _load();
        }),
        onAdminPatients: () => setState(() {
          _selectedIndex = 1;
          f = _loadPatients();
        }),
      ),
      body: FutureBuilder(
          future: f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData)
              return const Center(child: CircularProgressIndicator());
            final l = s.data as List;
            if (l.isEmpty)
              return Center(
                  child: Text(_selectedIndex == 0
                      ? 'No doctor applications.'
                      : 'No patients registered.'));
            if (_selectedIndex == 1) {
              return ListView(
                  padding: const EdgeInsets.all(16),
                  children: l
                      .map((p) => Card(
                          child: ListTile(
                              leading:
                                  const Icon(Icons.person_outline, color: sage),
                              title: Text(p['full_name'] ?? 'Unnamed patient'),
                              subtitle: Text(p['email'] ?? ''))))
                      .toList());
            }
            return ListView(
                padding: const EdgeInsets.all(16),
                children: l
                    .map((d) => Card(
                        child: ListTile(
                            title: Text(d['full_name']),
                            subtitle: Text(
                                '${d['email']}\nStatus: ${d['verification_status']}'),
                            isThreeLine: true,
                            trailing:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                  icon: const Icon(Icons.check_circle,
                                      color: sage),
                                  onPressed: () => _set(d['id'], 'APPROVED')),
                              IconButton(
                                  icon: const Icon(Icons.cancel, color: danger),
                                  onPressed: () => _set(d['id'], 'REJECTED')),
                            ]))))
                    .toList());
          }),
      bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() {
                _selectedIndex = index;
                f = index == 0 ? _load() : _loadPatients();
              }),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.verified_user_outlined),
                selectedIcon: Icon(Icons.verified_user),
                label: 'Verifications'),
            NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Patients'),
          ]));
}
