class IntakeEntry {
  final int minutes; // minutes depuis minuit
  final int ml;
  const IntakeEntry(this.minutes, this.ml);

  String encode() => '$minutes|$ml';

  static IntakeEntry? tryDecode(String s) {
    final p = s.split('|');
    if (p.length != 2) return null;
    final m = int.tryParse(p[0]);
    final v = int.tryParse(p[1]);
    if (m == null || v == null) return null;
    return IntakeEntry(m, v);
  }
}

class DayStat {
  final DateTime date;
  final int ml;
  final int goal;
  const DayStat({required this.date, required this.ml, required this.goal});

  bool get reached => goal > 0 && ml >= goal;
}
