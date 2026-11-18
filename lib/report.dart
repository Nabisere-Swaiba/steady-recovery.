import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'common.dart';

Future<void> reportSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Generate a report',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
            for (final period in [
              ['Daily', 1],
              ['Weekly', 7],
              ['Monthly', 30],
            ])
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text('${period[0]} report'),
                onTap: () {
                  Navigator.pop(context);
                  _report(context, period[0] as String, period[1] as int);
                },
              ),
          ],
        ),
      ),
    );

Future<void> _report(BuildContext context, String label, int days) async {
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
    String join(List? values) => values?.join(', ') ?? '';
    final average = rows.isEmpty
        ? 0.0
        : rows
                .map((row) => (row['craving'] as num?) ?? 0)
                .reduce((a, b) => a + b) /
            rows.length;
    final document = pw.Document();
    document.addPage(pw.MultiPage(
      build: (_) => [
        pw.Text(
          'SteadyRecovery - $label check-in report',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          '${me!['full_name']}  |  $since to ${DateTime.now().toIso8601String().substring(0, 10)}',
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Check-ins: ${rows.length}    Average intensity: ${average.toStringAsFixed(1)}/10',
        ),
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
              'Note',
            ],
            data: rows
                .map((row) => [
                      row['checkin_date'],
                      '${row['craving']}/10',
                      join(row['inside'] as List?),
                      join(row['around'] as List?),
                      join(row['helped'] as List?),
                      join(row['halt'] as List?),
                      row['note'] ?? '',
                    ])
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 8),
          ),
      ],
    ));
    await Printing.layoutPdf(
      name: 'steadyrecovery_${label.toLowerCase()}_report.pdf',
      onLayout: (_) async => document.save(),
    );
  } catch (e) {
    if (context.mounted) snack(context, 'Report failed: $e');
  }
}
