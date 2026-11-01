import 'package:flutter/material.dart';

import '../models/history.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../widgets/app_background.dart';

class CalendarScreen extends StatefulWidget {
  final UserProfile profile;

  const CalendarScreen({super.key, required this.profile});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const Color blue = Color(0xFF168FE5);

  DateTime _month = DateTime.now();
  DateTime _selected = DateUtils.dateOnly(DateTime.now());

  List<DayStat> _days = [];
  List<IntakeEntry> _entries = [];

  bool _loading = true;

  static const List<String> _weekdays = [
    'Lun',
    'Mar',
    'Mer',
    'Jeu',
    'Ven',
    'Sam',
    'Dim',
  ];

  static const List<String> _months = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    final history = await StorageService.getHistory(
      370,
      fallbackGoal: widget.profile.dailyGoalMl,
    );

    final entries = await StorageService.getLogForDay(_selected);

    if (!mounted) return;

    setState(() {
      _days = history;
      _entries = entries;
      _loading = false;
    });
  }

  DayStat? _stat(DateTime date) {
    for (final day in _days) {
      if (day.date.year == date.year &&
          day.date.month == date.month &&
          day.date.day == date.day) {
        return day;
      }
    }

    return null;
  }

  void _changeMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);

    final today = DateUtils.dateOnly(DateTime.now());

    if (next.isAfter(DateTime(today.year, today.month))) {
      return;
    }

    setState(() {
      _month = next;
    });
  }

  Future<void> _selectDay(DateTime date) async {
    if (date.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      return;
    }

    setState(() {
      _selected = date;
    });

    await _load();
  }

  String _formatTime(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final offset = firstDay.weekday - 1;

    final dayCount = DateUtils.getDaysInMonth(_month.year, _month.month);

    final cellCount = ((offset + dayCount + 6) ~/ 7) * 7;

    final selectedStat = _stat(_selected);

    final consumed = selectedStat?.ml ?? 0;
    final goal = selectedStat?.goal ?? widget.profile.dailyGoalMl;

    final progress = goal > 0 ? (consumed / goal).clamp(0.0, 1.0) : 0.0;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'Calendrier d’hydratation',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: blue))
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _changeMonth(-1),
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Expanded(
                                child: Text(
                                  '${_months[_month.month - 1]} ${_month.year}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _changeMonth(1),
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: _weekdays.map((day) {
                              return Expanded(
                                child: Center(
                                  child: Text(
                                    day,
                                    style: const TextStyle(
                                      color: Colors.blueGrey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: cellCount,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  mainAxisSpacing: 7,
                                  crossAxisSpacing: 5,
                                ),
                            itemBuilder: (context, index) {
                              final day = index - offset + 1;

                              if (day < 1 || day > dayCount) {
                                return const SizedBox.shrink();
                              }

                              final date = DateTime(
                                _month.year,
                                _month.month,
                                day,
                              );

                              final stat = _stat(date);

                              final isSelected =
                                  date.year == _selected.year &&
                                  date.month == _selected.month &&
                                  date.day == _selected.day;

                              final isFuture = date.isAfter(
                                DateUtils.dateOnly(DateTime.now()),
                              );

                              final reached = stat?.reached ?? false;

                              final hasIntake = (stat?.ml ?? 0) > 0;

                              final background = isSelected
                                  ? blue
                                  : reached
                                  ? Colors.green.withValues(alpha: 0.13)
                                  : Colors.transparent;

                              return InkWell(
                                onTap: isFuture ? null : () => _selectDay(date),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? blue : Colors.black12,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$day',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Colors.white
                                              : isFuture
                                              ? Colors.black26
                                              : Colors.black87,
                                        ),
                                      ),
                                      if (hasIntake)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          width: 5,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected
                                                ? Colors.white
                                                : reached
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 15),
                          const Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 15,
                            runSpacing: 8,
                            children: [
                              _Legend(
                                color: Colors.green,
                                label: 'Objectif atteint',
                              ),
                              _Legend(
                                color: Colors.orange,
                                label: 'Consommation enregistrée',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selected.day.toString().padLeft(2, '0')}/'
                            '${_selected.month.toString().padLeft(2, '0')}/'
                            '${_selected.year}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$consumed ml / $goal ml',
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                              color: blue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: Colors.blueGrey.shade100,
                              color: blue,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Consommations de la journée',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_entries.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'Aucune prise enregistrée pour cette journée.',
                                style: TextStyle(color: Colors.blueGrey),
                              ),
                            )
                          else
                            ..._entries.map(
                              (entry) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFE7F4FF),
                                  child: Icon(
                                    Icons.water_drop_outlined,
                                    color: blue,
                                  ),
                                ),
                                title: Text(
                                  '${entry.ml} ml',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Text(
                                  _formatTime(entry.minutes),
                                  style: const TextStyle(
                                    color: Colors.blueGrey,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 9),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
