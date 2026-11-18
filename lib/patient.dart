import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'blueprint.dart';
import 'common.dart';
import 'reminders.dart';

const muted = Color(0xFF6B7D6F);
TextStyle serif([double s = 26]) => GoogleFonts.lora(fontSize: s, color: ink);
Widget card(Widget child, {Color? color}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8E3))),
    child: child);
Widget head(String eyebrow, String title, String sub) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(eyebrow.toUpperCase(),
          style: const TextStyle(
              letterSpacing: 2,
              fontSize: 12,
              color: sage,
              fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(title, style: serif(32)),
      const SizedBox(height: 6),
      Text(sub, style: const TextStyle(color: muted)),
    ]));
Future<void> call(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

// ---------- Reports ----------
Future<void> reportSheet(BuildContext c) => showModalBottomSheet(
    context: c,
    builder: (_) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Generate a report', style: serif(22))),
          for (final p in [
            ['Daily', 1],
            ['Weekly', 7],
            ['Monthly', 30]
          ])
            ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text('${p[0]} report'),
                onTap: () {
                  Navigator.pop(c);
                  _report(c, p[0] as String, p[1] as int);
                }),
        ])));

Future<void> _report(BuildContext c, String label, int days) async {
  try {
    final since = DateTime.now()
        .subtract(Duration(days: days - 1))
        .toIso8601String()
        .substring(0, 10);
    final rows = List<Map<String, dynamic>>.from(await db
        .from('checkins')
        .select()
        .eq('user_id', me!['id'])
        .gte('checkin_date', since)
        .order('checkin_date'));
    String j(x) => (x as List?)?.join(', ') ?? '';
    final avg = rows.isEmpty
        ? 0.0
        : rows.map((r) => (r['craving'] as num?) ?? 0).reduce((a, b) => a + b) /
            rows.length;
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
        build: (_) => [
              pw.Text('SteadyRecovery - $label check-in report',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                  '${me!['full_name']}  |  $since to ${DateTime.now().toIso8601String().substring(0, 10)}'),
              pw.SizedBox(height: 10),
              pw.Text(
                  'Check-ins: ${rows.length}    Average intensity: ${avg.toStringAsFixed(1)}/10'),
              pw.SizedBox(height: 10),
              if (rows.isEmpty)
                pw.Text('No check-ins in this period.')
              else
                pw.TableHelper.fromTextArray(
                    headers: [
                      'Date',
                      'Intensity',
                      'Inside',
                      'Around',
                      'Helped',
                      'HALT',
                      'Note'
                    ],
                    data: rows
                        .map((r) => [
                              r['checkin_date'],
                              '${r['craving']}/10',
                              j(r['inside']),
                              j(r['around']),
                              j(r['helped']),
                              j(r['halt']),
                              r['note'] ?? ''
                            ])
                        .toList(),
                    cellStyle: const pw.TextStyle(fontSize: 8)),
            ]));
    await Printing.layoutPdf(
        name: 'steadyrecovery_${label.toLowerCase()}_report.pdf',
        onLayout: (_) async => doc.save());
  } catch (e) {
    if (c.mounted) snack(c, 'Report failed: $e');
  }
}

// ---------- Shell: bottom nav + drawer ----------
class Shell extends StatelessWidget {
  final int i;
  const Shell(this.i, {super.key});
  static const routes = ['/dashboard', '/check-in', '/sos', '/groups'];
  static const titles = ['Today', 'Check-ins', 'Get support', 'Support Groups'];
  static const pages = [Today(), CheckInPage(), Support(), Groups()];

  @override
  Widget build(BuildContext c) {
    Widget tile(IconData ic, String t, VoidCallback f) => ListTile(
        leading: Icon(ic, color: sage),
        title: Text(t),
        onTap: () {
          Navigator.pop(c);
          f();
        });
    return Scaffold(
        appBar: brandAppBar(title: Text(titles[i], style: serif(22))),
        drawer: Drawer(
            child: ListView(padding: EdgeInsets.zero, children: [
          DrawerHeader(
              decoration: const BoxDecoration(color: sage),
              child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text('Hi, ${me!['full_name']}',
                      style: serif(24).copyWith(color: Colors.white)))),
          tile(Icons.grid_view_outlined, 'Today', () => c.go('/dashboard')),
          tile(Icons.monitor_heart_outlined, 'Check-ins',
              () => c.go('/check-in')),
          tile(Icons.shield_outlined, 'Get support', () => c.go('/sos')),
          tile(Icons.groups_outlined, 'Support Groups', () => c.go('/groups')),
          tile(Icons.self_improvement, 'When an urge shows up',
              () => c.go('/tools')),
          tile(Icons.assignment_outlined, 'Coping plan',
              () => c.go('/blueprint', extra: routes[i])),
          const Divider(),
          tile(Icons.description_outlined, 'Generate report',
              () => reportSheet(c)),
          tile(Icons.settings_outlined, 'Settings', () => c.go('/settings')),
          tile(Icons.logout, 'Sign out', () => signOut(c)),
        ])),
        body: SafeArea(child: pages[i]),
        bottomNavigationBar: NavigationBar(
            backgroundColor: Colors.white,
            indicatorColor: sageLight,
            selectedIndex: i,
            onDestinationSelected: (n) => c.go(routes[n]),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view),
                  label: 'Today'),
              NavigationDestination(
                  icon: Icon(Icons.monitor_heart_outlined),
                  selectedIcon: Icon(Icons.monitor_heart),
                  label: 'Check-ins'),
              NavigationDestination(
                  icon: Icon(Icons.shield_outlined),
                  selectedIcon: Icon(Icons.shield),
                  label: 'Get support'),
              NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups),
                  label: 'Support Groups'),
            ]));
  }
}

// ---------- Today ----------
class Today extends StatelessWidget {
  const Today({super.key});
  @override
  Widget build(BuildContext c) {
    final st = DateTime.tryParse('${me!['recovery_start_date'] ?? ''}');
    final days =
        st == null ? 0 : DateTime.now().difference(st).inDays.clamp(0, 99999);
    final saved = days * ((me!['daily_saving'] as num?) ?? 0);
    return ListView(padding: const EdgeInsets.all(20), children: [
      head('Your recovery space', 'Welcome, ${me!['full_name']}',
          'No need to have it all figured out. Just start where you are.'),
      const RiskyTimeBanner(),
      if (st == null)
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.schedule, color: sage, size: 32),
          const SizedBox(height: 12),
          Text("Whenever you're ready", style: serif(24)),
          const SizedBox(height: 8),
          const Text(
              'Choose a start date for your recovery clock. This is a tool for noticing progress, not measuring your worth.',
              style: TextStyle(color: muted)),
          const SizedBox(height: 16),
          FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => c.go('/settings'),
              child: const Text('Set up your clock  →')),
        ]))
      else
        card(
            color: sage,
            Row(children: [
              Expanded(
                  child: Column(children: [
                Text('$days', style: serif(54).copyWith(color: Colors.white)),
                const Text('clean days',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ])),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(children: [
                Text('UGX ${saved.toStringAsFixed(0)}',
                    textAlign: TextAlign.center,
                    style: serif(26).copyWith(color: Colors.white)),
                const Text('total saved',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ])),
            ])),
      card(InkWell(
          onTap: () => c.go('/tools'),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.explore_outlined, color: sage),
            const SizedBox(height: 10),
            Text('An urge can be a wave', style: serif(22)),
            const SizedBox(height: 6),
            const Text(
                'Try a guided breathing pause. One breath at a time, stop whenever you like.',
                style: TextStyle(color: muted)),
            const SizedBox(height: 10),
            const Text('Explore tools  →',
                style: TextStyle(color: sage, fontWeight: FontWeight.bold)),
          ]))),
      FutureBuilder(
          future: db
              .from('doctor_messages')
              .select()
              .eq('patient_id', me!['id'])
              .order('created_at', ascending: false)
              .limit(2),
          builder: (_, s) => Column(children: [
                ...((s.data as List?) ?? [])
                    .map<Widget>((m) => card(Row(children: [
                          const Icon(Icons.mail_outline, color: sage),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Your doctor: ${m['body']}'))
                        ])))
              ])),
      card(const Row(children: [
        Icon(Icons.shield_outlined, color: sage),
        SizedBox(width: 12),
        Expanded(
            child: Text(
                "A gentle reminder: a difficult moment doesn't erase the care you've put into yourself. There is always a next step.",
                style: TextStyle(color: muted)))
      ])),
    ]);
  }
}

class RiskyTimeBanner extends StatefulWidget {
  const RiskyTimeBanner({super.key});

  @override
  State<RiskyTimeBanner> createState() => _RiskyTimeBannerState();
}

class _RiskyTimeBannerState extends State<RiskyTimeBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<List<RiskyWindow>>(
        valueListenable: ReminderService.riskyWindows,
        builder: (context, windows, _) {
          final now = DateTime.now();
          RiskyWindow? upcoming;
          var minutesUntil = 61;

          for (final window in windows) {
            final daysUntil = (window.weekday - now.weekday) % 7;
            var start = DateTime(
              now.year,
              now.month,
              now.day,
              window.startHour,
            ).add(Duration(days: daysUntil));
            if (!start.isAfter(now)) {
              start = start.add(const Duration(days: 7));
            }
            final minutes = start.difference(now).inMinutes;
            if (minutes >= 0 && minutes <= 60 && minutes < minutesUntil) {
              upcoming = window;
              minutesUntil = minutes;
            }
          }

          if (upcoming == null) return const SizedBox.shrink();
          return card(
            color: sageLight,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.self_improvement, color: sage),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A moment for yourself',
                      style: serif(20),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                  'A familiar time is coming up in about $minutesUntil minutes. Choose what feels useful.',
                  style: const TextStyle(color: muted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.go('/tools'),
                      child: const Text('Take a breath'),
                    ),
                    FilledButton(
                      onPressed: () => context.go('/sos'),
                      child: const Text('Get support'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
}

// ---------- Check-ins ----------
class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});
  @override
  State<CheckInPage> createState() => _CheckInState();
}

class _CheckInState extends State<CheckInPage> {
  double v = 5;
  final inside = <String>{},
      around = <String>{},
      helped = <String>{},
      halt = <String>{};
  final note = TextEditingController();
  List rows = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final since = DateTime.now()
          .subtract(const Duration(days: 6))
          .toIso8601String()
          .substring(0, 10);
      rows = await db
          .from('checkins')
          .select('checkin_date,craving')
          .eq('user_id', me!['id'])
          .gte('checkin_date', since)
          .order('checkin_date');
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Widget group(String t, List<String> o, Set<String> s) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Text(t, style: const TextStyle(fontSize: 16))),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: o
                .map((x) => FilterChip(
                    label: Text(x),
                    selected: s.contains(x),
                    showCheckmark: false,
                    backgroundColor: Colors.white,
                    selectedColor: sageLight,
                    onSelected: (on) =>
                        setState(() => on ? s.add(x) : s.remove(x))))
                .toList()),
      ]);

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      await db.from('checkins').upsert({
        'user_id': me!['id'],
        'checkin_date': DateTime.now().toIso8601String().substring(0, 10),
        'craving': v.round(),
        'inside': inside.toList(),
        'around': around.toList(),
        'helped': helped.toList(),
        'halt': halt.toList(),
        'note': note.text.trim(),
      }, onConflict: 'user_id,checkin_date');
      if (mounted) snack(context, 'Check-in saved');
      await _load();
      try {
        await ReminderService.refreshForUser('${me!['id']}');
      } catch (e) {
        debugPrint('Could not update reminders after check-in: $e');
        if (mounted) {
          snack(
              context, 'Check-in saved. Reminder times could not be updated.');
        }
      }
    } catch (e) {
      if (mounted) snack(context, '$e');
    }
    if (mounted) setState(() => busy = false);
  }

  Widget bars() {
    if (rows.length < 3)
      return Container(
          height: 120,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: smoky, borderRadius: BorderRadius.circular(16)),
          child: const Text(
              'Your check-in patterns will appear here when you have a few entries. There is no right amount to log.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted)));
    final m = {
      for (final r in rows)
        r['checkin_date'] as String: (r['craving'] as num).toDouble()
    };
    final ds =
        List.generate(7, (i) => DateTime.now().subtract(Duration(days: 6 - i)));
    return SizedBox(
        height: 150,
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ds.map((d) {
              final x = m[d.toIso8601String().substring(0, 10)] ?? 0;
              return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(x == 0 ? '' : x.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 12)),
                    Container(
                        width: 22,
                        height: x * 10 + 2,
                        decoration: BoxDecoration(
                            color: sage.withOpacity(x == 0 ? .15 : .8),
                            borderRadius: BorderRadius.circular(6))),
                    Text('MTWTFSS'[d.weekday - 1],
                        style: const TextStyle(color: muted)),
                  ]);
            }).toList()));
  }

  @override
  Widget build(BuildContext c) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        head('Daily', 'Check-ins', 'A moment to notice how you are.'),
        OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48), backgroundColor: Colors.white),
            onPressed: () => reportSheet(c),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Generate a report')),
        const SizedBox(height: 14),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('A check-in, just for you', style: serif(24)),
          const SizedBox(height: 6),
          const Text(
              "There are no wrong answers. You can skip anything you don't want to share.",
              style: TextStyle(color: muted)),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(
                child: Text('How strong does it feel right now?',
                    style: TextStyle(fontSize: 16))),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: sageLight, borderRadius: BorderRadius.circular(12)),
                child: Text('${v.round()} / 10',
                    style: const TextStyle(
                        color: sage, fontWeight: FontWeight.bold))),
          ]),
          Slider(
              value: v,
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: sage,
              onChanged: (x) => setState(() => v = x)),
          const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('A little', style: TextStyle(color: muted)),
                Text('A lot', style: TextStyle(color: muted))
              ]),
          group(
              'What is happening inside?',
              [
                'Stress',
                'Anxiety',
                'Sadness',
                'Boredom',
                'Celebration',
                'Physical discomfort'
              ],
              inside),
          group(
              'What is around you?',
              [
                'People',
                'Place',
                'Time of day',
                'Conflict',
                'Availability',
                'Transition'
              ],
              around),
          group(
              'What helped, or might help?',
              [
                'Reached out',
                'Changed my setting',
                'Moved my body',
                'Took a breath',
                'Ate or drank water',
                'Waited it out'
              ],
              helped),
          const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 8),
              child:
                  Text('A quick body check', style: TextStyle(fontSize: 16))),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Hungry', 'Angry', 'Lonely', 'Tired']
                  .map((h) => SizedBox(
                      width: 150,
                      child: CheckboxListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          controlAffinity: ListTileControlAffinity.leading,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8E3))),
                          title: Text(h),
                          value: halt.contains(h),
                          onChanged: (on) => setState(
                              () => on! ? halt.add(h) : halt.remove(h)))))
                  .toList()),
          const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 8),
              child: Text('Anything else you want to remember?')),
          TextField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Optional - extra words for the day.')),
          const SizedBox(height: 18),
          FilledButton(
              onPressed: busy ? null : _save,
              child: const Text('Save check-in')),
        ])),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Patterns, not judgments', style: serif(22)),
          const SizedBox(height: 6),
          const Text(
              'Average intensity by day, from your last seven days of check-ins.',
              style: TextStyle(color: muted)),
          const SizedBox(height: 14),
          bars(),
          const SizedBox(height: 10),
          const Text(
              'Only your own check-ins are shown. This is for reflection, not diagnosis.',
              style: TextStyle(color: muted, fontSize: 12)),
        ])),
      ]);
}

// ---------- Get support ----------
class Support extends StatefulWidget {
  const Support({super.key});
  @override
  State<Support> createState() => _SupportState();
}

class _SupportState extends State<Support> {
  List contacts = [];
  List<String> copingStrategies = [];
  final n = TextEditingController(), p = TextEditingController();
  String role = 'Sponsor';
  int step = 0;
  static const gs = [
    'Look around gently. Name five things you can see.',
    'Notice four things you can touch or feel.',
    'Listen. Name three things you can hear.',
    'Find two things you can smell.',
    'Notice one thing you can taste.'
  ];
  static const gl = [
    'THINGS YOU CAN SEE',
    'THINGS YOU CAN TOUCH',
    'THINGS YOU CAN HEAR',
    'THINGS YOU CAN SMELL',
    'THING YOU CAN TASTE'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await db
          .from('safety_blueprint')
          .select()
          .eq('user_id', me!['id'])
          .maybeSingle();
      contacts = List.from(r?['contacts'] ?? []);
      copingStrategies = (r?['coping_strategies'] as String? ?? '')
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    } catch (e) {
      if (mounted) snack(context, 'Could not load your support plan: $e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _store() => db
      .from('safety_blueprint')
      .upsert({'user_id': me!['id'], 'contacts': contacts});

  Future<void> _add() async {
    if (n.text.trim().isEmpty ||
        p.text.trim().isEmpty ||
        contacts.length >= 3) {
      snack(context, 'Enter a name and phone (up to 3 contacts)');
      return;
    }
    contacts.add({'name': n.text.trim(), 'phone': p.text.trim(), 'role': role});
    try {
      await _store();
      n.clear();
      p.clear();
    } catch (e) {
      contacts.removeLast();
      if (mounted) snack(context, '$e');
    }
    if (mounted) setState(() {});
  }

  Future<void> _help() async {
    try {
      await db.from('sos_events').insert({'user_id': me!['id']});
    } catch (e) {
      if (mounted) {
        snack(context, 'Could not save your support request: $e');
      }
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your next steps', style: serif(24)),
                const SizedBox(height: 8),
                const Text(
                  'Choose something from your plan or call for support.',
                  style: TextStyle(color: muted),
                ),
                if (copingStrategies.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Your coping strategies',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  ...copingStrategies.map((strategy) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.check_circle_outline, color: sage),
                        title: Text(strategy),
                      )),
                ],
                if (contacts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('People in your corner',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  ...contacts.map((contact) {
                    final phone = '${contact['phone'] ?? ''}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${contact['name'] ?? 'Trusted person'}'),
                      subtitle: phone.isEmpty ? null : Text(phone),
                      trailing: IconButton(
                        tooltip: 'Call trusted person',
                        icon: const Icon(Icons.call, color: sage),
                        onPressed: phone.isEmpty
                            ? null
                            : () async {
                                Navigator.pop(sheetContext);
                                await _dial(phone);
                              },
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _dial('999');
                  },
                  icon: const Icon(Icons.call),
                  label: const Text('Call emergency services (999)'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _dial(String phone) async {
    try {
      final launched = await launchUrl(
        Uri(scheme: 'tel', path: phone),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        snack(context, 'A phone app is not available on this device.');
      }
    } catch (e) {
      if (mounted) snack(context, 'Could not open the phone app: $e');
    }
  }

  @override
  Widget build(BuildContext c) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        head('You are not alone', 'Support, when you need it',
            'Keep trusted people close and find a grounding exercise for a hard moment.'),
        CopingPlanCard(),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("YOU DON'T HAVE TO HANDLE THIS ALONE",
              style: TextStyle(
                  letterSpacing: 1.5,
                  fontSize: 12,
                  color: Color(0xFFC98F8A),
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Need immediate support?', style: serif(24)),
          const SizedBox(height: 8),
          const Text(
              'Connect with a trusted person, or use a crisis resource. In Uganda, call 999 for emergency services; outside Uganda, call your local emergency number.',
              style: TextStyle(color: muted)),
          const SizedBox(height: 14),
          FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC98F8A)),
              onPressed: _help,
              icon: const Icon(Icons.call),
              label: const Text('Get help now')),
        ])),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Add a trusted person', style: serif(22)),
          const SizedBox(height: 6),
          const Text('Their call link will appear in your coping plan.',
              style: TextStyle(color: muted)),
          const Divider(height: 28),
          const Text('Add someone you trust'),
          const SizedBox(height: 10),
          TextField(
              controller: n,
              decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          TextField(
              controller: p,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
              value: role,
              items: ['Sponsor', 'Family', 'Friend', 'Counsellor']
                  .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                  .toList(),
              onChanged: (x) => setState(() => role = x!),
              decoration: const InputDecoration(labelText: 'Their role')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Add contact')),
        ])),
        card(Column(children: [
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('COME BACK TO NOW',
                  style: TextStyle(
                      letterSpacing: 2,
                      fontSize: 12,
                      color: sage,
                      fontWeight: FontWeight.bold))),
          Align(
              alignment: Alignment.centerLeft,
              child: Text('5-4-3-2-1 grounding', style: serif(22))),
          const SizedBox(height: 6),
          const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'Take your time. There is no need to get this exactly right.',
                  style: TextStyle(color: muted))),
          const SizedBox(height: 14),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: smoky, borderRadius: BorderRadius.circular(18)),
              child: step >= 5
                  ? Column(children: [
                      Text('You are back in the room. Well done.',
                          style: serif(20), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                          onPressed: () => setState(() => step = 0),
                          child: const Text('Start again'))
                    ])
                  : Column(children: [
                      CircleAvatar(
                          radius: 38,
                          backgroundColor: sageLight,
                          child: Text('${5 - step}', style: serif(32))),
                      const SizedBox(height: 10),
                      Text('STEP ${step + 1} OF 5 - ${gl[step]}',
                          style: const TextStyle(color: muted, fontSize: 12)),
                      const SizedBox(height: 10),
                      Text(gs[step],
                          style: serif(19), textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      FilledButton(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(140, 46)),
                          onPressed: () => setState(() => step++),
                          child: const Text("I'm ready  →")),
                    ])),
        ])),
      ]);
}

// ---------- When an urge shows up ----------
class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});
  @override
  State<ToolsPage> createState() => _ToolsState();
}

class _ToolsState extends State<ToolsPage> {
  int el = -1; // -1 = not started
  Timer? t;
  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  void _begin() {
    t?.cancel();
    setState(() => el = 0);
    t = Timer.periodic(const Duration(seconds: 1), (x) {
      if (el >= 900) {
        x.cancel();
      } else {
        setState(() => el++);
      }
    });
  }

  void _reset() {
    t?.cancel();
    setState(() => el = -1);
  }

  @override
  Widget build(BuildContext c) {
    final pos = el < 0 ? 0 : el % 12;
    final s = el < 0
        ? 0.0
        : pos < 4
            ? pos / 4
            : pos < 6
                ? 1.0
                : 1 - (pos - 6) / 6;
    final label = el < 0
        ? 'Ready when you are'
        : el >= 900
            ? 'Well done'
            : pos < 4
                ? 'Breathe in'
                : pos < 6
                    ? 'Pause'
                    : 'Breathe out';
    final left = el < 0 ? 900 : 900 - el;
    return Scaffold(
        appBar: brandAppBar(onBack: () => c.go('/dashboard')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          head('', 'When an urge shows up',
              'This moment is temporary. Explore a tool, check in with yourself, or simply take a breath.'),
          OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: Colors.white),
              onPressed: () => reportSheet(c),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Generate a report')),
          const SizedBox(height: 14),
          card(Column(children: [
            Align(
                alignment: Alignment.centerLeft,
                child:
                    Text('A little space for this moment', style: serif(22))),
            const SizedBox(height: 6),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    "Urges rise and fall. You don't have to act on one right now.",
                    style: TextStyle(color: muted))),
            const SizedBox(height: 14),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                    color: smoky, borderRadius: BorderRadius.circular(18)),
                child: Column(children: [
                  SizedBox(
                      height: 220,
                      child: Center(
                          child: AnimatedContainer(
                              duration: const Duration(seconds: 1),
                              width: 120 + 80 * s,
                              height: 120 + 80 * s,
                              decoration: const BoxDecoration(
                                  color: sageLight, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(label,
                                        textAlign: TextAlign.center,
                                        style: serif(18)),
                                    Text(
                                        '${(left ~/ 60).toString().padLeft(2, '0')}:${(left % 60).toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                            fontSize: 20, color: muted))
                                  ])))),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                          'Follow the gentle rhythm: breathe in for four, pause for two, breathe out for six. Stop any time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted))),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(110, 46)),
                        onPressed: _begin,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Begin')),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.replay),
                        label: const Text('Start over')),
                  ]),
                ])),
          ])),
          const CopingPlanCard(compact: true),
        ]));
  }
}

// ---------- Support groups ----------
class Groups extends StatelessWidget {
  const Groups({super.key});
  @override
  Widget build(BuildContext c) => FutureBuilder(
      future: db.from('support_groups').select(),
      builder: (_, s) {
        final l = (s.data as List?) ?? [];
        return ListView(padding: const EdgeInsets.all(20), children: [
          head('Find connection', 'Support Groups',
              'Explore peer-led recovery communities and find a meeting that feels right for you. Availability and schedules vary by location.'),
          card(
              color: const Color(0xFFECF0EC),
              const Text(
                  "These are community directories, not scheduled meetings hosted by this app. Use each organization's meeting finder to confirm current times, format, and access details.",
                  style: TextStyle(color: muted))),
          if (s.hasError) const Text('Could not load groups.'),
          if (!s.hasData && !s.hasError)
            const Center(child: CircularProgressIndicator()),
          if (s.hasData && l.isEmpty) const Text('No groups listed yet.'),
          ...l.map<Widget>((g) => card(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Recovery community',
                              style: TextStyle(color: muted)),
                          Icon(
                              g['is_virtual'] == false
                                  ? Icons.place_outlined
                                  : Icons.videocam_outlined,
                              color: sage)
                        ]),
                    const SizedBox(height: 6),
                    Text(g['name'], style: serif(24)),
                    const SizedBox(height: 12),
                    Row(children: [
                      const SizedBox(
                          width: 90,
                          child: Text('Type', style: TextStyle(color: muted))),
                      Expanded(
                          child: Text('${g['type'] ?? 'Virtual and local'}'))
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const SizedBox(
                          width: 90,
                          child:
                              Text('Schedule', style: TextStyle(color: muted))),
                      Expanded(
                          child:
                              Text('${g['schedule'] ?? 'Times vary by group'}'))
                    ]),
                    const SizedBox(height: 14),
                    FilledButton(
                        onPressed: g['join_link'] == null
                            ? null
                            : () => call(g['join_link']),
                        child: const Text('Join Meeting')),
                  ]))),
        ]);
      });
}

// ---------- Settings ----------
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsPage> {
  DateTime? when =
      DateTime.tryParse('${me!['recovery_start_date'] ?? ''}')?.toLocal();
  String? goal;
  String? doc = me!['assigned_doctor_id'];
  final money = TextEditingController(text: '${me!['daily_saving'] ?? 0}');
  List docs = [];
  bool dailyReminderEnabled = false;
  bool riskyReminderEnabled = false;
  bool reminderSettingsLoading = true;
  bool reminderSettingsSaving = false;
  TimeOfDay dailyReminderTime = const TimeOfDay(hour: 20, minute: 0);
  static const goals = [
    'Recover from alcohol addiction',
    'Recover from drug addiction',
  ];

  @override
  void initState() {
    super.initState();
    _loadReminderSettings();
    goal = switch (me!['recovery_goal']) {
      'Alcohol' => goals[0],
      'Drugs' => goals[1],
      final String existing => existing,
      _ => null,
    };
    () async {
      try {
        final v = await db
            .from('profiles')
            .select('id,full_name')
            .eq('role', 'DOCTOR')
            .eq('verification_status', 'APPROVED');
        if (mounted) setState(() => docs = v);
      } catch (_) {}
    }();
  }

  Future<void> _loadReminderSettings() async {
    try {
      final userId = '${me!['id']}';
      final daily = await ReminderService.dailyEnabled(userId);
      final risky = await ReminderService.riskyEnabled(userId);
      final minute = await ReminderService.dailyMinuteOfDay(userId);
      final permissionGranted = !ReminderService.isSupported ||
          await ReminderService.notificationsEnabled();
      if ((daily || risky) && !permissionGranted) {
        await ReminderService.saveSettings(
          userId: userId,
          dailyReminderEnabled: false,
          riskyReminderEnabled: false,
          dailyReminderMinute: minute,
        );
        if (mounted) {
          snack(context,
              'Notifications are off, so reminders have been turned off.');
        }
      }
      if (!mounted) return;
      setState(() {
        dailyReminderEnabled = permissionGranted && daily;
        riskyReminderEnabled = permissionGranted && risky;
        dailyReminderTime = TimeOfDay(hour: minute ~/ 60, minute: minute % 60);
        reminderSettingsLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => reminderSettingsLoading = false);
        snack(context, 'Could not load reminder settings: $e');
      }
    }
  }

  Future<void> _saveReminderSettings({
    bool? dailyEnabled,
    bool? riskyEnabled,
    TimeOfDay? dailyTime,
  }) async {
    final nextDailyEnabled = dailyEnabled ?? dailyReminderEnabled;
    final nextRiskyEnabled = riskyEnabled ?? riskyReminderEnabled;
    final nextDailyTime = dailyTime ?? dailyReminderTime;

    setState(() => reminderSettingsSaving = true);
    try {
      await ReminderService.saveSettings(
        userId: '${me!['id']}',
        dailyReminderEnabled: nextDailyEnabled,
        riskyReminderEnabled: nextRiskyEnabled,
        dailyReminderMinute: nextDailyTime.hour * 60 + nextDailyTime.minute,
      );
      if (!mounted) return;
      setState(() {
        dailyReminderEnabled = nextDailyEnabled;
        riskyReminderEnabled = nextRiskyEnabled;
        dailyReminderTime = nextDailyTime;
      });
      snack(context, 'Reminder settings saved.');
    } catch (e) {
      if (mounted) {
        await _loadReminderSettings();
        final message =
            e is StateError ? e.message : 'Could not update reminders: $e';
        snack(context, '$message');
      }
    } finally {
      if (mounted) setState(() => reminderSettingsSaving = false);
    }
  }

  Future<void> _pickDailyReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: dailyReminderTime,
    );
    if (picked == null || !mounted) return;
    await _saveReminderSettings(dailyTime: picked);
  }

  Future<void> _pick() async {
    final d = await showDatePicker(
        context: context,
        initialDate: when ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now());
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(when ?? DateTime.now()));
    if (t != null)
      setState(() => when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    try {
      await db.from('profiles').update({
        'recovery_start_date': when?.toUtc().toIso8601String(),
        'recovery_goal': goal,
        'daily_saving': num.tryParse(money.text) ?? 0,
        'assigned_doctor_id': doc
      }).eq('id', me!['id']);
      await loadMe();
      if (mounted) context.go('/dashboard');
    } catch (e) {
      if (mounted) snack(context, '$e');
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: brandAppBar(onBack: () => c.go('/dashboard')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        head('Your space', 'Settings',
            'Make this feel right for you. You can change these whenever you like.'),
        OutlinedButton.icon(
          onPressed: () => c.go('/blueprint', extra: '/settings'),
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Edit your coping plan'),
        ),
        const SizedBox(height: 14),
        card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.notifications_outlined, color: sage),
              const SizedBox(width: 8),
              Text('Reminders', style: serif(22)),
            ]),
            const SizedBox(height: 6),
            const Text(
              'Choose a gentle reminder for a moment that works for you.',
              style: TextStyle(color: muted),
            ),
            if (!ReminderService.isSupported)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Local reminders are available on Android devices.',
                  style: TextStyle(color: muted),
                ),
              )
            else if (reminderSettingsLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Daily check-in reminder'),
                subtitle: const Text('A private reminder once a day.'),
                value: dailyReminderEnabled,
                onChanged: reminderSettingsSaving
                    ? null
                    : (enabled) => _saveReminderSettings(dailyEnabled: enabled),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder time'),
                subtitle: Text(dailyReminderTime.format(c)),
                trailing: const Icon(Icons.schedule, color: sage),
                onTap: reminderSettingsSaving ? null : _pickDailyReminderTime,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Heads-up before risky times'),
                subtitle: const Text(
                  'Based on patterns in your recent check-ins.',
                ),
                value: riskyReminderEnabled,
                onChanged: reminderSettingsSaving
                    ? null
                    : (enabled) => _saveReminderSettings(riskyEnabled: enabled),
              ),
              if (riskyReminderEnabled &&
                  ReminderService.riskyWindows.value.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 8),
                  child: Text(
                    'No repeated time pattern is available yet. More check-ins may help identify one.',
                    style: TextStyle(color: muted),
                  ),
                ),
              if (reminderSettingsSaving)
                const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        )),
        const SizedBox(height: 14),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.event, color: sage),
            const SizedBox(width: 8),
            Text('Your personal goal', style: serif(22))
          ]),
          const SizedBox(height: 8),
          const Text(
              'Set a date and optional daily amount for your timer. Changing the date is just a way to mark a new chapter, never a judgment.',
              style: TextStyle(color: muted)),
          const SizedBox(height: 16),
          const Text('Recovery start date and time'),
          const SizedBox(height: 8),
          InkWell(
              onTap: _pick,
              child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: smoky, borderRadius: BorderRadius.circular(14)),
                  child: Text(when == null
                      ? 'Choose date and time'
                      : '${when.toString().substring(0, 16)}'))),
          const SizedBox(height: 16),
          const Text('What is this goal about?'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
              value: goals.contains(goal) ? goal : null,
              hint: const Text('Choose your recovery goal'),
              items: goals
                  .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                  .toList(),
              onChanged: (x) => setState(() => goal = x)),
          const SizedBox(height: 16),
          const Text('Estimated money saved each day (UGX)'),
          const SizedBox(height: 8),
          TextField(controller: money, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          const Text('Your clinician'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
              value: docs.any((d) => d['id'] == doc) ? doc : null,
              hint: const Text('Choose an approved doctor (optional)'),
              items: docs
                  .map((d) => DropdownMenuItem(
                      value: d['id'] as String, child: Text(d['full_name'])))
                  .toList(),
              onChanged: (x) => setState(() => doc = x)),
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Set up my clock')),
        ])),
      ]));
}
