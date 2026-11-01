import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  List<Medication> _medications = [];
  List<MedicationDoseLog> _logs = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final medications = await StorageService.getMedications();
    final logs = await StorageService.getMedicationLogs(date: DateTime.now());

    if (!mounted) return;

    setState(() {
      _medications = medications;
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _refreshNotifications() async {
    await NotificationService.scheduleMedicationReminders();
  }

  Future<void> _addMedication() async {
    final medication = await showDialog<Medication>(
      context: context,
      builder: (_) => const _MedicationDialog(),
    );

    if (medication == null) return;

    await StorageService.saveMedication(medication);
    await _refreshNotifications();
    await _loadData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Médicament ajouté avec succès.')),
    );
  }

  Future<void> _editMedication(Medication medication) async {
    final updated = await showDialog<Medication>(
      context: context,
      builder: (_) => _MedicationDialog(medication: medication),
    );

    if (updated == null) return;

    await StorageService.saveMedication(updated);
    await _refreshNotifications();
    await _loadData();
  }

  Future<void> _deleteMedication(Medication medication) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le médicament ?'),
        content: Text('Voulez-vous supprimer ${medication.name} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await StorageService.deleteMedication(medication.id);
    await _refreshNotifications();
    await _loadData();
  }

  Future<void> _toggleMedication(Medication medication) async {
    final updated = medication.copyWith(isActive: !medication.isActive);

    await StorageService.saveMedication(updated);
    await _refreshNotifications();
    await _loadData();
  }

  DateTime _scheduledDate(int minutes) {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
  }

  MedicationDoseLog? _getLog(Medication medication, int minutes) {
    final scheduled = _scheduledDate(minutes);

    for (final log in _logs) {
      if (log.medicationId == medication.id && log.scheduledAt == scheduled) {
        return log;
      }
    }

    return null;
  }

  Future<void> _confirmDose(
    Medication medication,
    int minutes,
    String status,
  ) async {
    final scheduled = _scheduledDate(minutes);

    await StorageService.saveMedicationDoseLog(
      MedicationDoseLog(
        medicationId: medication.id,
        medicationName: medication.name,
        scheduledAt: scheduled,
        confirmedAt: DateTime.now(),
        status: status,
      ),
    );

    await _loadData();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'taken'
              ? 'Prise enregistrée.'
              : 'Réponse enregistrée : pas encore.',
        ),
      ),
    );
  }

  String _statusLabel(MedicationDoseLog? log) {
    if (log == null) return 'En attente';

    if (log.status == 'taken') return 'Pris';

    return 'Pas encore';
  }

  Color _statusColor(MedicationDoseLog? log) {
    if (log == null) return Colors.orange;

    if (log.status == 'taken') return Colors.green;

    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes médicaments 💊')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMedication,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _medications.isEmpty
                  ? _emptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        _header(),
                        const SizedBox(height: 16),
                        ..._medications.map(_medicationCard),
                        const SizedBox(height: 24),
                        _historySection(),
                      ],
                    ),
            ),
    );
  }

  Widget _header() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.medication, size: 38, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Suivi de mes traitements',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_medications.length} médicament(s) enregistré(s)',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 70),
        Icon(Icons.medication_outlined, size: 80, color: Colors.blue),
        SizedBox(height: 20),
        Text(
          'Aucun médicament enregistré',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text(
          'Appuie sur le bouton Ajouter pour enregistrer '
          'un médicament et ses horaires.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _medicationCard(Medication medication) {
    final sortedTimes = [...medication.timesMinutes]..sort();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.medication)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        medication.prescribedDose,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editMedication(medication);
                    } else if (value == 'delete') {
                      _deleteMedication(medication);
                    } else if (value == 'toggle') {
                      _toggleMedication(medication);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(
                        medication.isActive ? 'Désactiver' : 'Activer',
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer'),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 8),
                Text(
                  medication.isActive
                      ? 'Horaires quotidiens'
                      : 'Rappels désactivés',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (medication.isActive)
              ...sortedTimes.map((minutes) {
                final log = _getLog(medication, minutes);

                return _doseRow(medication, minutes, log);
              }),
            if (!medication.isActive)
              const Text('Ce médicament est actuellement désactivé.'),
          ],
        ),
      ),
    );
  }

  Widget _doseRow(Medication medication, int minutes, MedicationDoseLog? log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                Medication.formatTime(minutes),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                _statusLabel(log),
                style: TextStyle(
                  color: _statusColor(log),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (log == null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _confirmDose(medication, minutes, 'taken'),
                    child: const Text('Pris'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _confirmDose(medication, minutes, 'not_taken'),
                    child: const Text('Pas encore'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _historySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historique du jour',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (_logs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucune confirmation enregistrée aujourd’hui.'),
            ),
          )
        else
          ..._logs.reversed.map(
            (log) => Card(
              child: ListTile(
                leading: Icon(
                  log.status == 'taken' ? Icons.check_circle : Icons.schedule,
                  color: log.status == 'taken' ? Colors.green : Colors.orange,
                ),
                title: Text(log.medicationName),
                subtitle: Text(
                  'Horaire : '
                  '${log.scheduledAt.hour.toString().padLeft(2, '0')}:'
                  '${log.scheduledAt.minute.toString().padLeft(2, '0')}',
                ),
                trailing: Text(log.status == 'taken' ? 'Pris' : 'Pas encore'),
              ),
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------
// FORMULAIRE AJOUT / MODIFICATION
// --------------------------------------------------

class _MedicationDialog extends StatefulWidget {
  final Medication? medication;

  const _MedicationDialog({this.medication});

  @override
  State<_MedicationDialog> createState() => _MedicationDialogState();
}

class _MedicationDialogState extends State<_MedicationDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _doseController;

  late List<int> _times;

  @override
  void initState() {
    super.initState();

    final medication = widget.medication;

    _nameController = TextEditingController(text: medication?.name ?? '');

    _doseController = TextEditingController(
      text: medication?.prescribedDose ?? '',
    );

    _times = medication == null ? [] : [...medication.timesMinutes];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selected == null) return;

    final minutes = selected.hour * 60 + selected.minute;

    if (_times.contains(minutes)) {
      return;
    }

    setState(() {
      _times.add(minutes);
      _times.sort();
    });
  }

  void _removeTime(int minutes) {
    setState(() {
      _times.remove(minutes);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_times.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute au moins un horaire.')),
      );
      return;
    }

    final old = widget.medication;

    final medication = Medication(
      id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      prescribedDose: _doseController.text.trim(),
      timesMinutes: [..._times]..sort(),
      isActive: old?.isActive ?? true,
      createdAt: old?.createdAt ?? DateTime.now(),
    );

    Navigator.pop(context, medication);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.medication != null;

    return AlertDialog(
      title: Text(editing ? 'Modifier le médicament' : 'Ajouter un médicament'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du médicament',
                    hintText: 'Exemple : Médicament A',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medication),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Saisis le nom du médicament.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _doseController,
                  decoration: const InputDecoration(
                    labelText: 'Dose prescrite',
                    hintText: 'Exemple : 1 comprimé',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Saisis la dose prescrite.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Horaires de prise',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: _addTime,
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                    ),
                  ],
                ),
                if (_times.isEmpty) const Text('Aucun horaire ajouté.'),
                ..._times.map(
                  (minutes) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: Text(Medication.formatTime(minutes)),
                    trailing: IconButton(
                      onPressed: () => _removeTime(minutes),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Renseigne uniquement les horaires et la dose '
                  'indiqués par ton professionnel de santé.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _save, child: const Text('Enregistrer')),
      ],
    );
  }
}
