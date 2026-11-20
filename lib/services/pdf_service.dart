import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import 'schedule_engine.dart';

/// Caregiver sharing (local, no server) + the doctor-report PDF.
class ShareService {
  static String _fmtQty(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  /// Nicely formatted plain-text summary for share sheet / WhatsApp / SMS.
  static String scheduleText({
    required Profile profile,
    required List<Medication> meds,
    required List<DoseInstance> today,
    required DateTime now,
  }) {
    final df = DateFormat('EEEE d MMMM');
    final tf = DateFormat('h:mm a');
    final b = StringBuffer()
      ..writeln('Dosique — medicine schedule for ${profile.name}')
      ..writeln(df.format(now))
      ..writeln('');
    if (today.isEmpty) {
      b.writeln('No scheduled doses today.');
    } else {
      for (final i in today) {
        final st = i.statusAt(now);
        final mark = switch (st) {
          ResolvedStatus.taken => 'TAKEN',
          ResolvedStatus.skipped => 'SKIPPED',
          ResolvedStatus.missed => 'MISSED',
          ResolvedStatus.due => 'DUE NOW',
          ResolvedStatus.upcoming => 'upcoming',
        };
        b.writeln(
          '${tf.format(i.scheduledFor)}  ${i.med.title} — $mark${i.med.instruction.isNotEmpty ? ' (${i.med.instruction})' : ''}',
        );
      }
    }
    final prn = meds.where((m) => !m.archived && m.hasPrnOnly).toList();
    if (prn.isNotEmpty) {
      b
        ..writeln('')
        ..writeln('As needed: ${prn.map((m) => m.title).join(', ')}');
    }
    b
      ..writeln('')
      ..writeln(
        'Shared from Dosique. Reminder/recording tool only — not medical advice.',
      );
    return b.toString();
  }

  static String missedText({
    required Profile profile,
    required List<DoseInstance> missed,
  }) {
    final tf = DateFormat('EEE d MMM, h:mm a');
    final b = StringBuffer()
      ..writeln('Dosique — missed doses for ${profile.name}')
      ..writeln('');
    if (missed.isEmpty) {
      b.writeln('No missed doses. All on track.');
    } else {
      for (final i in missed) {
        b.writeln('${tf.format(i.scheduledFor)}  ${i.med.title} — missed');
      }
    }
    b
      ..writeln('')
      ..writeln(
        'Shared from Dosique. Reminder/recording tool only — not medical advice.',
      );
    return b.toString();
  }

  static Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  static Future<void> shareWhatsApp(String text) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await shareText(text);
    }
  }

  static Future<void> shareSms(String text) async {
    final uri = Uri.parse('sms:?body=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await shareText(text);
    }
  }

  /// Build the doctor-report PDF and hand it to the share sheet.
  static Future<void> shareDoctorReport({
    required Profile profile,
    required List<Medication> meds,
    required List<DoseLog> logs,
    required DateTime from,
    required DateTime to,
    required DateTime now,
  }) async {
    final df = DateFormat('d MMM yyyy');
    final tf = DateFormat('h:mm a');
    final active = meds.where((m) => !m.archived).toList();

    // Adherence for the last 30 days.
    var adhTaken = 0, adhTotal = 0;
    for (var i = 0; i < 30; i++) {
      final day = dayOnly(now).subtract(Duration(days: i));
      final inst = instancesForDay(active, logs, day);
      final a = adherenceFor(inst, now);
      adhTaken += a.taken;
      adhTotal += a.total;
    }
    final adhPct = adhTotal == 0 ? 100 : (adhTaken / adhTotal * 100).round();

    // History rows inside the chosen range.
    final rows = <List<String>>[];
    var day = dayOnly(from);
    while (!day.isAfter(dayOnly(to))) {
      final inst = instancesForDay(active, logs, day);
      for (final i in inst) {
        final st = i.statusAt(now);
        if (st == ResolvedStatus.upcoming) continue;
        rows.add([
          df.format(i.scheduledFor),
          tf.format(i.scheduledFor),
          i.med.title,
          st.name.toUpperCase(),
          i.log?.takenAt != null ? tf.format(i.log!.takenAt!) : '',
        ]);
      }
      day = day.add(const Duration(days: 1));
    }
    for (final l in logs.where(
      (l) =>
          l.isPrn &&
          !l.scheduledFor.isBefore(dayOnly(from)) &&
          !l.scheduledFor.isAfter(dayOnly(to).add(const Duration(days: 1))),
    )) {
      final med = meds.where((m) => m.id == l.medId).firstOrNull;
      rows.add([
        df.format(l.scheduledFor),
        tf.format(l.scheduledFor),
        '${med?.title ?? 'Medicine'} (as needed)',
        'TAKEN',
        tf.format(l.scheduledFor),
      ]);
    }
    rows.sort((a, b) => a[0].compareTo(b[0]));

    final doc = pw.Document();
    final headerStyle = pw.TextStyle(
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    );
    final cellStyle = const pw.TextStyle(fontSize: 10);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(color: PdfColors.grey300),
            pw.Text(
              'Generated by Dosique — a reminder and recording tool only. It does not '
              'provide medical advice, does not check drug interactions, and is not a '
              'medical device. Always follow your prescriber\u2019s instructions.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (ctx) => [
          pw.Text(
            'Medication Report',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'For: ${profile.name}    ·    ${df.format(now)}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Adherence (last 30 days): $adhPct%  ($adhTaken of $adhTotal doses taken)',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Active medications',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Medication', 'Form', 'Schedule', 'Instructions'],
            headerStyle: headerStyle,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal600),
            cellStyle: cellStyle,
            cellAlignment: pw.Alignment.centerLeft,
            data: active
                .map(
                  (m) => [
                    m.title,
                    m.form.label,
                    m.schedules.map((s) => s.describe()).join('\n'),
                    [
                      if (m.instruction.isNotEmpty) m.instruction,
                      if (m.notes.isNotEmpty) m.notes,
                    ].join('\n'),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Dose history (${df.format(from)} – ${df.format(to)})',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (rows.isEmpty)
            pw.Text('No doses recorded in this range.', style: cellStyle)
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Due', 'Medication', 'Status', 'Taken at'],
              headerStyle: headerStyle,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.teal600,
              ),
              cellStyle: cellStyle,
              cellAlignment: pw.Alignment.centerLeft,
              data: rows,
            ),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/dosique_report_${profile.name.replaceAll(' ', '_')}.pdf',
    );
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Dosique medication report — ${profile.name}',
        text: 'Medication report for ${profile.name} (Dosique)',
      ),
    );
  }

  static String fmtQty(double v) => _fmtQty(v);
}
