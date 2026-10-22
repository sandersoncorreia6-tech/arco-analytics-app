import '../models/box_score.dart';

/// Desempenho de um quinteto (combinação de 5 jogadores em quadra).
class LineupStat {
  /// Chaves dos jogadores (nome normalizado), ordenadas.
  final List<String> keys;
  final List<String> names;
  int seconds = 0;
  int pointsFor = 0;
  int pointsAgainst = 0;
  double offPossessions = 0;
  double defPossessions = 0;

  LineupStat(this.keys, this.names);

  String get id => keys.join('|');
  double get minutes => seconds / 60;
  int get plusMinus => pointsFor - pointsAgainst;
  double get offRating => offPossessions < 1 ? 0 : pointsFor * 100 / offPossessions;
  double get defRating => defPossessions < 1 ? 0 : pointsAgainst * 100 / defPossessions;
  double get netRating => offRating - defRating;

  void absorb(LineupStat o) {
    seconds += o.seconds;
    pointsFor += o.pointsFor;
    pointsAgainst += o.pointsAgainst;
    offPossessions += o.offPossessions;
    defPossessions += o.defPossessions;
  }
}

/// Reconstrói quem estava em quadra a partir do lance a lance (substituições)
/// e soma pontos, posses e minutos de cada quinteto.
class LineupBuilder {
  static List<LineupStat> forGame(GameBoxScore g, int side) {
    final box = g.team(side);
    final starters = box.players.where((p) => p.starter).map((p) => p.pno).toSet();
    if (starters.length != 5 || g.plays.isEmpty) return const [];
    final byPno = {for (final p in box.players) p.pno: p};

    var on = {...starters};
    final stats = <String, LineupStat>{};
    LineupStat? current() {
      if (on.length != 5 || !on.every(byPno.containsKey)) return null;
      final players = on.map((n) => byPno[n]!).toList()..sort((a, b) => a.key.compareTo(b.key));
      final keys = players.map((p) => p.key).toList();
      return stats.putIfAbsent(keys.join('|'), () => LineupStat(keys, players.map((p) => p.name).toList()));
    }

    // data.json traz o lance a lance do mais novo para o mais antigo.
    final plays = g.plays.reversed.toList();
    // Duração de cada período: o maior relógio visto (a súmula registra o início
    // do período em 10:00/08:00); sem isso, arredonda para múltiplos de 5 min.
    final periodLength = <int, int>{};
    for (final a in plays) {
      final c = a.clockSeconds;
      if (c > (periodLength[a.period] ?? 0)) periodLength[a.period] = c;
    }
    int lengthOf(int p) {
      final max = periodLength[p] ?? 0;
      if (max >= 240 && max % 60 == 0) return max;
      return max <= 0 ? 600 : ((max + 299) ~/ 300) * 300;
    }

    var period = 0;
    var clock = 0;
    for (final a in plays) {
      if (a.period != period) {
        if (period != 0) current()?.seconds += clock; // restante do período anterior
        period = a.period;
        clock = lengthOf(period);
      }
      final now = a.clockSeconds;
      if (now <= clock) {
        current()?.seconds += clock - now;
        clock = now;
      }

      final lineup = current();
      final ours = a.team == side;
      if (lineup != null && a.team != 0) {
        if (a.isScoring) {
          if (ours) {
            lineup.pointsFor += a.points;
          } else {
            lineup.pointsAgainst += a.points;
          }
        }
        // Posses (estimativa): arremessos + 0,44·LL + erros − rebotes ofensivos.
        final poss = switch (a.type) {
          '2pt' || '3pt' => 1.0,
          'freethrow' => 0.44,
          'turnover' => 1.0,
          'rebound' when a.subType == 'offensive' => -1.0,
          _ => 0.0,
        };
        if (ours) {
          lineup.offPossessions += poss;
        } else {
          lineup.defPossessions += poss;
        }
      }

      if (a.type == 'substitution' && ours && a.pno != 0) {
        if (a.subType == 'out') on = {...on}..remove(a.pno);
        if (a.subType == 'in') on = {...on, a.pno};
      }
    }
    return stats.values.where((l) => l.seconds > 0 || l.pointsFor + l.pointsAgainst > 0).toList();
  }

  /// Soma os quintetos de várias partidas (mesmos jogadores = mesmo quinteto).
  static List<LineupStat> combine(Iterable<List<LineupStat>> games) {
    final all = <String, LineupStat>{};
    for (final list in games) {
      for (final l in list) {
        all.putIfAbsent(l.id, () => LineupStat(l.keys, l.names)).absorb(l);
      }
    }
    return all.values.toList()..sort((a, b) => b.seconds.compareTo(a.seconds));
  }
}
