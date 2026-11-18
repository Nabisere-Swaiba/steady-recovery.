import 'package:flutter/material.dart';
import 'common.dart';

class DoctorDash extends StatefulWidget {
  const DoctorDash({super.key});
  @override
  State<DoctorDash> createState() => _DoctorDashState();
}

class _DoctorDashState extends State<DoctorDash> {
  late Future<List<Map<String, dynamic>>> f = _load();
  int _selectedIndex = 0;

  Future<List<Map<String, dynamic>>> _load() async {
    final ps = List<Map<String, dynamic>>.from(
        await db.from('profiles').select().eq('assigned_doctor_id', me!['id']));
    if (ps.isEmpty) return ps;
    final ids = ps.map((p) => p['id']).toList();
    final since =
        DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final cs = List<Map<String, dynamic>>.from(await db
        .from('checkins')
        .select()
        .inFilter('user_id', ids)
        .gte('created_at', since));
    final ss = List<Map<String, dynamic>>.from(await db
        .from('sos_events')
        .select()
        .inFilter('user_id', ids)
        .gte('created_at', since));
    for (final p in ps) {
      final cr = cs
          .where((x) => x['user_id'] == p['id'])
          .map((x) => x['craving'] as num)
          .toList();
      p['avg'] = cr.isEmpty ? null : cr.reduce((a, b) => a + b) / cr.length;
      p['sos'] = ss.where((x) => x['user_id'] == p['id']).length;
      p['risk'] = cr.any((v) => v >= 8) || p['sos'] > 0;
      final st = DateTime.tryParse(p['recovery_start_date'] ?? '');
      p['days'] = st == null ? 0 : DateTime.now().difference(st).inDays;
    }
    return ps;
  }

  Future<void> _msg(Map p) async {
    final t = TextEditingController();
    await showDialog(
        context: context,
        builder: (d) => AlertDialog(
                title: Text('Message ${p['full_name']}'),
                content: TextField(controller: t, maxLines: 3),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () async {
                        try {
                          await db.from('doctor_messages').insert({
                            'doctor_id': me!['id'],
                            'patient_id': p['id'],
                            'body': t.text.trim()
                          });
                          if (d.mounted) Navigator.pop(d);
                          if (mounted) snack(context, 'Sent');
                        } catch (e) {
                          if (mounted) snack(context, '$e');
                        }
                      },
                      child: const Text('Send'))
                ]));
  }

  @override
  Widget build(BuildContext c) {
    final selectedIndex =
        _selectedIndex >= 0 && _selectedIndex < 2 ? _selectedIndex : 0;
    return Scaffold(
        appBar: brandAppBar(
            title: Text(selectedIndex == 0
                ? 'Clinical Command Center'
                : 'Pending follow-up'),
            actions: [
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => setState(() {
                        f = _load();
                      })),
              logoutBtn(c)
            ]),
        body: FutureBuilder(
            future: f,
            builder: (_, s) {
              if (s.hasError)
                return Center(
                    child: Text('Could not load patients: ${s.error}'));
              if (!s.hasData)
                return const Center(child: CircularProgressIndicator());
              final ps = s.data!;
              final visiblePatients = selectedIndex == 0
                  ? ps
                  : ps.where((p) => p['risk'] == true).toList();
              if (visiblePatients.isEmpty)
                return const Center(
                    child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                            'No patients are currently flagged for follow-up.',
                            textAlign: TextAlign.center)));
              final risk = ps.where((p) => p['risk'] == true).length;
              return ListView(padding: const EdgeInsets.all(16), children: [
                if (selectedIndex == 0)
                  Row(children: [
                    Expanded(
                        child: Card(
                            color: sageLight,
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(children: [
                                  Text('${ps.length}',
                                      style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold)),
                                  const Text('Patients')
                                ])))),
                    Expanded(
                        child: Card(
                            color: risk > 0 ? danger : sageLight,
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(children: [
                                  Text('$risk',
                                      style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold)),
                                  const Text('High-risk')
                                ])))),
                  ]),
                if (selectedIndex == 1)
                  const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                          'Patients with a high craving score or recent SOS activity.')),
                ...visiblePatients.map((p) => Card(
                    child: ListTile(
                        leading: Icon(
                            p['risk'] == true
                                ? Icons.warning_amber
                                : Icons.check_circle,
                            color: p['risk'] == true ? danger : sage),
                        title: Text(p['full_name']),
                        subtitle: Text(
                            '${p['days']} clean days | avg craving ${p['avg'] == null ? '-' : (p['avg'] as num).toStringAsFixed(1)} | SOS ${p['sos']}'),
                        trailing: IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: () => _msg(p))))),
              ]);
            }),
        bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => setState(() {
                  if (index >= 0 && index < 2) _selectedIndex = index;
                }),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Patients'),
              NavigationDestination(
                  icon: Icon(Icons.pending_actions),
                  selectedIcon: Icon(Icons.pending_actions),
                  label: 'Pending'),
            ]));
  }
}
