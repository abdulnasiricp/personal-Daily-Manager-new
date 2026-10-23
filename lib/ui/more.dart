import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../backup.dart';
import '../calc.dart';
import '../db.dart';
import '../notifications.dart';
import 'common.dart';
import '../l10n.dart';

class MorePage extends StatefulWidget {
  const MorePage({super.key});
  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> with Refreshable<MorePage> {
  bool _dark = false;

  @override
  Future<void> reload() async {
    final v = await AppDb.instance.getSetting('dark');
    if (mounted) setState(() => _dark = v == '1');
  }

  Future<void> _pickLanguage() async {
    final current = appLang.value;
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('Language')),
        children: [
          for (final o in const [['en', 'English'], ['ur', 'اردو']])
            ListTile(
              leading: Icon(current == o[0] ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(o[1]),
              onTap: () => Navigator.pop(ctx, o[0]),
            ),
        ],
      ),
    );
    if (chosen != null && chosen != current) {
      await AppDb.instance.setSetting('lang', chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('More'))),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: Text(tr('Reminders')),
          subtitle: Text(tr('Bills, appointments and repeating reminders')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemindersPage())),
        ),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: Text(tr('Backup & Restore')),
          subtitle: Text(tr('Save or restore all your data')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupPage())),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.dark_mode_outlined),
          title: Text(tr('Dark mode')),
          value: _dark,
          onChanged: (v) => AppDb.instance.setSetting('dark', v ? '1' : '0'),
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(tr('Language')),
          subtitle: Text(isUrdu ? 'اردو' : 'English'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickLanguage,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.payments_outlined),
          title: Text(tr('Currency')),
          subtitle: Text(tr('Pakistani Rupee (PKR)')),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(tr('Privacy')),
          subtitle: Text(tr('All data stays on this phone. The app works fully offline and has no accounts.')),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ reminders

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> with Refreshable<RemindersPage> {
  List<Reminder> _items = [];
  bool _loaded = false;
  bool _notifOk = true;
  bool _exactOk = true;

  @override
  Future<void> reload() async {
    final r = await AppDb.instance.reminders();
    final n = await Notifier.notificationsEnabled();
    final e = await Notifier.canScheduleExact();
    if (!mounted) return;
    setState(() {
      _items = r;
      _notifOk = n;
      _exactOk = e;
      _loaded = true;
    });
  }

  String _repeatText(String r) =>
      tr(const {'none': 'Once', 'daily': 'Every day', 'weekly': 'Every week', 'monthly': 'Every month'}[r] ?? r);

  Future<void> _delete(Reminder r) async {
    if (await confirm(context, tr('Delete reminder?'), tr('"{title}" will be permanently deleted.', {'title': r.title}))) {
      await AppDb.instance.deleteReminder(r.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text(tr('Reminders'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showForm(context, const ReminderForm()),
        icon: const Icon(Icons.add),
        label: Text(tr('Add reminder')),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
              if (!_notifOk)
                Card(
                  color: cs.errorContainer,
                  child: ListTile(
                    leading: Icon(Icons.notifications_off, color: cs.onErrorContainer),
                    title: Text(tr('Notifications are off'), style: TextStyle(color: cs.onErrorContainer)),
                    subtitle: Text(tr('Allow notifications so reminders can alert you.'),
                        style: TextStyle(color: cs.onErrorContainer)),
                    trailing: FilledButton(
                      onPressed: () async {
                        final ok = await Notifier.ensurePermission();
                        if (!ok && mounted) {
                          toast(context, tr('Please enable notifications for this app in Android Settings.'));
                        }
                        reload();
                      },
                      child: Text(tr('Allow')),
                    ),
                  ),
                ),
              if (_notifOk && !_exactOk)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.alarm),
                    title: Text(tr('Exact timing is not allowed')),
                    subtitle: Text(tr('Reminders may arrive a few minutes late. Allow "Alarms & reminders" for exact timing.')),
                    trailing: TextButton(
                      onPressed: () async {
                        await Notifier.requestExactAlarms();
                      },
                      child: Text(tr('Allow')),
                    ),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.send_outlined),
                  title: Text(tr('Send a test notification')),
                  onTap: () async {
                    final ok = await Notifier.ensurePermission();
                    if (ok) {
                      await Notifier.showTest();
                    } else if (mounted) {
                      toast(context, tr('Notifications are not allowed.'));
                    }
                    reload();
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(tr('Task reminders are set in each task. Loan repayment reminders are sent at 9:00 AM on the expected repayment date. Open the app now and then so repeating reminders stay scheduled.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SectionTitle(tr('Your reminders')),
              if (_items.isEmpty)
                EmptyState(icon: Icons.notifications_none, message: tr('No reminders yet.\nTap "Add reminder" to create one.'))
              else
                ..._items.map((r) {
                  final next = r.active ? upcomingOccurrences(r.when, r.repeat, now, 1) : <DateTime>[];
                  final sub = !r.active
                      ? tr('Paused')
                      : next.isEmpty
                          ? tr('Finished ({date})', {'date': fmtDateTime(r.when)})
                          : tr('Next: {date}', {'date': fmtDateTime(next.first)});
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () => showForm(context, ReminderForm(reminder: r)),
                      leading: Icon(r.kind == 'bill' ? Icons.receipt_long : Icons.notifications_active_outlined),
                      title: Text(r.title),
                      subtitle: Text('$sub\n${_repeatText(r.repeat)}${r.kind == 'bill' ? '  -  ${tr('Bill')}' : ''}'),
                      isThreeLine: true,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Switch(
                          value: r.active,
                          onChanged: (v) => AppDb.instance.updateReminder(Reminder(
                              id: r.id,
                              title: r.title,
                              notes: r.notes,
                              at: r.at,
                              repeat: r.repeat,
                              kind: r.kind,
                              active: v)),
                        ),
                        IconButton(
                            icon: const Icon(Icons.delete_outline), tooltip: tr('Delete'), onPressed: () => _delete(r)),
                      ]),
                    ),
                  );
                }),
            ]),
    );
  }
}

class ReminderForm extends StatefulWidget {
  final Reminder? reminder;
  const ReminderForm({super.key, this.reminder});
  @override
  State<ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<ReminderForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(text: widget.reminder?.title ?? '');
  late final TextEditingController _notes = TextEditingController(text: widget.reminder?.notes ?? '');
  late DateTime _when = widget.reminder?.when ?? DateTime.now().add(const Duration(hours: 1));
  late String _repeat = widget.reminder?.repeat ?? 'none';
  late String _kind = widget.reminder?.kind ?? 'general';
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (_repeat == 'none' && _when.isBefore(DateTime.now()) && widget.reminder == null) {
      setState(() => _error = tr('That time has already passed. Pick a future time or a repeat option.'));
      return;
    }
    final old = widget.reminder;
    final r = Reminder(
      id: old?.id,
      title: _title.text.trim(),
      notes: _notes.text.trim(),
      at: isoLocal(DateTime(_when.year, _when.month, _when.day, _when.hour, _when.minute)),
      repeat: _repeat,
      kind: _kind,
      active: old?.active ?? true,
    );
    try {
      if (r.id == null) {
        await AppDb.instance.insertReminder(r);
      } else {
        await AppDb.instance.updateReminder(r);
      }
      await Notifier.ensurePermission();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = tr('Could not save: {error}', {'error': e}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _key,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.reminder == null ? tr('New reminder') : tr('Edit reminder'),
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'general', label: Text(tr('General')), icon: const Icon(Icons.notifications_active_outlined)),
            ButtonSegment(value: 'bill', label: Text(tr('Bill')), icon: const Icon(Icons.receipt_long)),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: tr('Title')),
          validator: (v) => (v == null || v.trim().isEmpty) ? tr('Please enter a title') : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notes,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: tr('Notes (optional)')),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: PickTile(
              icon: Icons.calendar_today,
              label: tr('Date'),
              value: DateFormat('d MMM yyyy').format(_when),
              onTap: () async {
                final d = await showDatePicker(
                    context: context, initialDate: _when, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setState(() => _when = DateTime(d.year, d.month, d.day, _when.hour, _when.minute));
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PickTile(
              icon: Icons.access_time,
              label: tr('Time'),
              value: fmtTime(_when),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
                if (t != null) setState(() => _when = DateTime(_when.year, _when.month, _when.day, t.hour, t.minute));
              },
            ),
          ),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _repeat,
          decoration: InputDecoration(labelText: tr('Repeat')),
          items: [
            DropdownMenuItem(value: 'none', child: Text(tr('Does not repeat'))),
            DropdownMenuItem(value: 'daily', child: Text(tr('Every day'))),
            DropdownMenuItem(value: 'weekly', child: Text(tr('Every week'))),
            DropdownMenuItem(value: 'monthly', child: Text(tr('Every month'))),
          ],
          onChanged: (v) => setState(() => _repeat = v ?? 'none'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: Text(tr('Save'))),
      ]),
    );
  }
}

// ------------------------------------------------------------------ backup

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final data = await AppDb.instance.exportAll();
      final dir = await getTemporaryDirectory();
      final name = 'PersonalDailyManager_backup_${DateFormat('yyyyMMdd_HHmm', 'en_US').format(DateTime.now())}.json';
      final file = File(p.join(dir.path, name));
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')],
          subject: 'Personal Daily Manager backup');
      if (mounted) {
        toast(context, tr('Backup file created. Choose "Save to Drive", "Files" or send it to yourself to keep it safe.'));
      }
    } catch (e) {
      if (mounted) toast(context, tr('Backup failed: {error}', {'error': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.any);
      if (picked == null || picked.files.single.path == null) return;
      final text = await File(picked.files.single.path!).readAsString();

      Object? json;
      try {
        json = jsonDecode(text);
      } catch (_) {
        if (mounted) toast(context, tr('This file is not a valid backup (it could not be read).'));
        return;
      }
      final err = validateBackup(json);
      if (err != null) {
        if (mounted) toast(context, err);
        return;
      }
      final map = Map<String, Object?>.from(json as Map);
      if (!mounted) return;
      final ok = await confirm(
        context,
        tr('Replace all current data?'),
        tr('This backup contains {summary}.\n\nRestoring will DELETE everything currently in the app and replace it with the backup. A safety copy of your current data will be saved first.',
            {'summary': backupSummary(map)}),
        yes: tr('Replace data'),
      );
      if (!ok) return;

      // Safety copy of the current data before anything is overwritten.
      final docs = await getApplicationDocumentsDirectory();
      final safety = File(p.join(docs.path, 'before_last_restore.json'));
      await safety.writeAsString(jsonEncode(await AppDb.instance.exportAll()));

      await AppDb.instance.importAll(map);
      if (mounted) toast(context, tr('Backup restored successfully.'));
    } on AppException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (e) {
      if (mounted) toast(context, tr('Restore failed: {error}', {'error': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Backup & Restore'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        InfoCard(
          title: tr('Export backup'),
          icon: Icons.upload_file,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Creates one file with all your tasks, transactions, loans, repayments, reminders and settings. Then choose where to keep it: Google Drive, Files, WhatsApp, email, etc.')),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: _busy ? null : _export, icon: const Icon(Icons.ios_share), label: Text(tr('Export & save backup'))),
          ]),
        ),
        InfoCard(
          title: tr('Restore backup'),
          icon: Icons.download,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Pick a backup file you exported earlier. The file is checked first, and you will be asked to confirm before your current data is replaced.')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: _busy ? null : _restore, icon: const Icon(Icons.folder_open), label: Text(tr('Choose backup file'))),
          ]),
        ),
        if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
      ]),
    );
  }
}
