import 'package:flutter/material.dart';

import '../models/history.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../widgets/app_background.dart';

String _fmtMl(int ml) {
  if (ml >= 1000) {
    return '${(ml / 1000).toStringAsFixed(1).replaceAll('.', ',')} L';
  }
  return '$ml ml';
}

class StatsScreen extends StatefulWidget {
  final UserProfile profile;
  const StatsScreen({super.key, required this.profile});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<DayStat> _all = [];
  int _range = 7;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await StorageService.getHistory(
      90,
      fallbackGoal: widget.profile.dailyGoalMl,
    );
    if (!mounted) return;
    setState(() {
      _all = h;
      _loading = false;
    });
  }

  int _streak() {
    var i = _all.length - 1;
    if (i >= 0 && !_all[i].reached) i--; // aujourd'hui pas encore terminé
    var s = 0;
    while (i >= 0 && _all[i].reached) {
      s++;
      i--;
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final goal = widget.profile.dailyGoalMl;

    final range = _all.length > _range
        ? _all.sublist(_all.length - _range)
        : _all;
    final withData = range.where((d) => d.ml > 0).toList();
    final avg = withData.isEmpty
        ? 0
        : (withData.fold<int>(0, (s, d) => s + d.ml) / withData.length).round();
    final reached = range.where((d) => d.reached).length;
    final best = range.fold<int>(0, (m, d) => d.ml > m ? d.ml : m);
    final total = range.fold<int>(0, (s, d) => s + d.ml);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Statistiques'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Center(
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 7, label: Text('7 jours')),
                        ButtonSegment(value: 30, label: Text('30 jours')),
                      ],
                      selected: {_range},
                      onSelectionChanged: (s) =>
                          setState(() => _range = s.first),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 0,
                    color: scheme.surface.withValues(alpha: 0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Consommation par jour',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Trait = objectif (${_fmtMl(goal)})',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          _BarChart(
                            days: range,
                            goal: goal,
                            weekly: _range == 7,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.timeline,
                          label: 'Moyenne (jours renseignés)',
                          value: _fmtMl(avg),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.flag_outlined,
                          label: 'Objectifs atteints',
                          value: '$reached / ${range.length}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.local_fire_department_outlined,
                          label: 'Série en cours',
                          value: '${_streak()} j',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.emoji_events_outlined,
                          label: 'Meilleur jour',
                          value: _fmtMl(best),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      total == 0
                          ? "Pas encore de données : ajoutez de l'eau depuis l'accueil."
                          : 'Total sur la période : ${_fmtMl(total)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surface.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<DayStat> days;
  final int goal;
  final bool weekly;
  const _BarChart({
    required this.days,
    required this.goal,
    required this.weekly,
  });

  static const _weekdays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = days.fold<int>(goal, (m, d) => d.ml > m ? d.ml : m);
    const barArea = 140.0;
    const labelArea = 22.0;

    return SizedBox(
      height: barArea + labelArea,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: labelArea + barArea * goal / maxV,
            child: Container(
              height: 1.5,
              color: scheme.tertiary.withValues(alpha: 0.8),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in days)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: weekly ? 6 : 1.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: d.ml == 0 ? 3.0 : barArea * d.ml / maxV,
                          decoration: BoxDecoration(
                            color: d.ml == 0
                                ? scheme.outlineVariant
                                : (d.reached
                                      ? scheme.primary
                                      : scheme.primary.withValues(alpha: 0.45)),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: labelArea,
                          child: Center(
                            child: Text(
                              weekly
                                  ? _weekdays[d.date.weekday - 1]
                                  : (d.date.day % 5 == 0
                                        ? '${d.date.day}'
                                        : ''),
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
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
        ],
      ),
    );
  }
}
