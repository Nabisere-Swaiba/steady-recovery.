import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'common.dart';

const _muted = Color(0xFF6B7D6F);

TextStyle _heading([double size = 26]) =>
    GoogleFonts.lora(fontSize: size, color: ink);

Future<Map<String, dynamic>?> _loadBlueprint() async {
  return await db
      .from('safety_blueprint')
      .select('triggers,warning_signs,coping_strategies,contacts')
      .eq('user_id', me!['id'])
      .maybeSingle();
}

Future<void> _callContact(BuildContext context, String phone) async {
  try {
    final launched = await launchUrl(
      Uri(scheme: 'tel', path: phone),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      snack(context, 'A phone app is not available on this device.');
    }
  } catch (e) {
    if (context.mounted) snack(context, 'Could not open the phone app: $e');
  }
}

class CopingPlanCard extends StatefulWidget {
  final bool compact;

  const CopingPlanCard({super.key, this.compact = false});

  @override
  State<CopingPlanCard> createState() => _CopingPlanCardState();
}

class _CopingPlanCardState extends State<CopingPlanCard> {
  late Future<Map<String, dynamic>?> _plan;

  @override
  void initState() {
    super.initState();
    _plan = _loadBlueprint();
  }

  void _reload() {
    setState(() => _plan = _loadBlueprint());
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
        future: _plan,
        builder: (context, snapshot) {
          final strategies =
              (snapshot.data?['coping_strategies'] as String? ?? '')
                  .split('\n')
                  .map((line) => line.trim())
                  .where((line) => line.isNotEmpty)
                  .toList();
          final contacts = (snapshot.data?['contacts'] as List? ?? [])
              .whereType<Map>()
              .map((contact) => Map<String, dynamic>.from(contact))
              .toList();

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: EdgeInsets.all(widget.compact ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8E3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.compact
                      ? 'Your coping strategies'
                      : 'Your coping plan',
                  style: _heading(widget.compact ? 19 : 22),
                ),
                if (snapshot.hasError)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'Your plan could not be loaded. Please try again.',
                          style: TextStyle(color: _muted),
                        ),
                      ),
                      TextButton(
                        onPressed: _reload,
                        child: const Text('Try again'),
                      ),
                    ],
                  )
                else if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (strategies.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        widget.compact
                            ? 'Add a few ideas that may help you through a difficult moment.'
                            : 'Your plan is ready when you are. Add a few ideas that may help in a difficult moment.',
                        style: const TextStyle(color: _muted),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 8),
                    ...strategies.map((strategy) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: sage, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(strategy)),
                            ],
                          ),
                        )),
                  ],
                  if (!widget.compact && contacts.isNotEmpty) ...[
                    const Divider(height: 28),
                    const Text(
                      'People in your corner',
                      style:
                          TextStyle(color: _muted, fontWeight: FontWeight.w600),
                    ),
                    ...contacts.map((contact) {
                      final name = '${contact['name'] ?? 'Trusted person'}';
                      final phone = '${contact['phone'] ?? ''}';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(name),
                        subtitle: phone.isEmpty ? null : Text(phone),
                        trailing: IconButton(
                          tooltip: 'Call $name',
                          icon: const Icon(Icons.call, color: sage),
                          onPressed: phone.isEmpty
                              ? null
                              : () => _callContact(context, phone),
                        ),
                      );
                    }),
                  ],
                  if (!widget.compact)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => context.go(
                          '/blueprint',
                          extra: '/sos',
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(strategies.isEmpty
                            ? 'Build my coping plan'
                            : 'Edit my coping plan'),
                      ),
                    ),
                  if (widget.compact)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => context.go(
                          '/blueprint',
                          extra: '/tools',
                        ),
                        child: const Text('Edit coping plan'),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      );
}

class CopingPlanScreen extends StatefulWidget {
  final String returnRoute;

  const CopingPlanScreen({
    super.key,
    this.returnRoute = '/sos',
  });

  @override
  State<CopingPlanScreen> createState() => _CopingPlanScreenState();
}

class _CopingPlanScreenState extends State<CopingPlanScreen> {
  final _triggers = TextEditingController();
  final _warningSigns = TextEditingController();
  final _strategies = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _triggers.dispose();
    _warningSigns.dispose();
    _strategies.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final plan = await _loadBlueprint();
      if (!mounted) return;
      _triggers.text = plan?['triggers'] as String? ?? '';
      _warningSigns.text = plan?['warning_signs'] as String? ?? '';
      _strategies.text = plan?['coping_strategies'] as String? ?? '';
    } catch (e) {
      if (mounted) {
        setState(() => _loadFailed = true);
        snack(context, 'Could not load your coping plan: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await db.from('safety_blueprint').upsert({
        'user_id': me!['id'],
        'triggers': _triggers.text.trim(),
        'warning_signs': _warningSigns.text.trim(),
        'coping_strategies': _strategies.text.trim(),
      }, onConflict: 'user_id');
      if (!mounted) return;
      snack(context, 'Your coping plan is saved.');
      context.go(widget.returnRoute);
    } catch (e) {
      if (mounted) snack(context, 'Could not save your coping plan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(widget.returnRoute),
          ),
          title: Text('Coping plan', style: _heading(22)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadFailed
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Your coping plan could not be loaded. Your saved notes have not been changed.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        'A few notes for a difficult moment',
                        style: _heading(26),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Write what feels useful to you. You can change this plan at any time.',
                        style: TextStyle(color: _muted),
                      ),
                      const SizedBox(height: 18),
                      _field(
                        controller: _triggers,
                        label: 'High-risk triggers',
                        hint: 'One item per line',
                      ),
                      const SizedBox(height: 14),
                      _field(
                        controller: _warningSigns,
                        label: 'Early warning signs',
                        hint: 'One item per line',
                      ),
                      const SizedBox(height: 14),
                      _field(
                        controller: _strategies,
                        label: 'Personal coping strategies',
                        hint: 'One idea per line',
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving...' : 'Save coping plan'),
                      ),
                    ],
                  ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      );
}
