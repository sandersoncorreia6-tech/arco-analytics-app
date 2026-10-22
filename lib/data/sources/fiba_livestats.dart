import 'dart:convert';

import 'package:arco_analytics/domain/models/box_score.dart';
import 'package:arco_analytics/data/sources/schedule_parser.dart';

/// Leitura da estatística online no padrão FIBA LiveStats (Genius Sports),
/// o sistema por trás da aba "Estatística / Online" das federações.
///
/// Cada partida tem um id numérico e um arquivo público `data.json` com
/// equipes, jogadores, arremessos (com coordenadas) e lance a lance.
class FibaLiveStats {
  static const dataHost = 'https://fibalivestats.dcd.shared.geniussports.com';

  static Uri dataUrl(String matchId) => Uri.parse('$dataHost/data/$matchId/data.json');

  /// Página pública do box score (para "abrir no site").
  static String pageUrl(String matchId) => '$dataHost/u/FPB/$matchId/bs.html';

  static final _idPatterns = [
    RegExp(r'fibalivestats[^"\x27\s<>]*?/u/[A-Za-z0-9_-]+/(\d{5,9})', caseSensitive: false),
    RegExp(r'geniussports\.com[^"\x27\s<>]*?/data/(\d{5,9})', caseSensitive: false),
    RegExp(r'geniussports\.com[^"\x27\s<>]*?/match/(\d{5,9})', caseSensitive: false),
    RegExp(r'livestats[^"\x27\s<>]*?[?&](?:id|matchid|match|game|gameid)=(\d{5,9})', caseSensitive: false),
  ];

  /// Ids de partidas citados em uma página (links, iframes, scripts).
  static Set<String> findMatchIds(String html) => {
    for (final re in _idPatterns)
      for (final m in re.allMatches(html)) m.group(1)!,
  };

  /// Id a partir do que o treinador colar: link da estatística ou só o número.
  static String? matchIdFromInput(String input) {
    final t = input.trim();
    if (RegExp(r'^\d{5,9}$').hasMatch(t)) return t;
    final ids = findMatchIds(t);
    if (ids.isNotEmpty) return ids.first;
    final loose = RegExp(r'/(\d{6,9})(?:/|$|\?)').firstMatch(t);
    return loose?.group(1);
  }

  /// Converte o `data.json` em [GameBoxScore]. Lança [FormatException] se o
  /// conteúdo não for de uma partida.
  static GameBoxScore parse(String body, {required String matchId, required String league, DateTime? fetchedAt}) {
    final data = jsonDecode(body);
    if (data is! Map || data['tm'] is! Map) throw const FormatException('Resposta sem dados de equipes (tm).');
    final tm = (data['tm'] as Map).cast<String, dynamic>();
    final t1 = tm['1'] is Map ? (tm['1'] as Map).cast<String, dynamic>() : null;
    final t2 = tm['2'] is Map ? (tm['2'] as Map).cast<String, dynamic>() : null;
    if (t1 == null || t2 == null) throw const FormatException('Partida sem as duas equipes.');

    final home = _team(t1);
    final away = _team(t2);

    final rawShots = <Map<String, dynamic>>[
      for (final entry in [(1, t1), (2, t2)])
        for (final s in (entry.$2['shot'] as List?) ?? const [])
          if (s is Map) {...s.cast<String, dynamic>(), '_team': entry.$1},
    ];
    final shots = _shots(rawShots, {1: home, 2: away}, {1: t1, 2: t2});

    final pbpRaw = (data['pbp'] as List?) ?? const [];
    final plays = <PlayAction>[
      for (final a in pbpRaw)
        if (a is Map)
          PlayAction(
            period: _int(a['period']),
            clock: (a['gt'] ?? a['clock'] ?? '').toString(),
            team: _int(a['tno']),
            pno: _int(a['pno']),
            player: _title((a['player'] ?? '').toString().trim()),
            type: (a['actionType'] ?? '').toString(),
            subType: (a['subType'] ?? '').toString(),
            success: _int(a['success']) == 1,
            score: a['s1'] != null && a['s2'] != null ? '${a['s1']}-${a['s2']}' : '',
          ),
    ];

    final ended =
        plays.any((p) => p.type == 'game' && p.subType == 'end') ||
        (data['clock']?.toString() == '00:00' && _int(data['period']) >= 4 && home.score != away.score);
    final status = ended
        ? 'FINAL'
        : plays.isNotEmpty
        ? 'AO VIVO'
        : (home.score + away.score > 0 ? 'FINAL' : 'AGENDADO');

    return GameBoxScore(
      matchId: matchId,
      league: league,
      sourceUrl: pageUrl(matchId),
      home: home,
      away: away,
      status: status,
      period: _int(data['period']),
      clock: (data['clock'] ?? '').toString(),
      fetchedAt: fetchedAt ?? DateTime.now(),
      shots: shots,
      plays: plays,
    );
  }

  static int _int(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.round() ?? 0;
    if (v is bool) return v ? 1 : 0;
    return 0;
  }

  /// "25:13" → 1513 segundos.
  static int _seconds(dynamic v) {
    if (v is num) return (v * 60).round();
    final s = (v ?? '').toString();
    final m = RegExp(r'^(\d+):(\d{1,2})').firstMatch(s);
    if (m == null) return 0;
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }

  static StatLine _stats(Map<String, dynamic> m, String prefix) {
    int v(String k) => _int(m['$prefix$k']);
    var fgm = v('FieldGoalsMade');
    var fga = v('FieldGoalsAttempted');
    final tpm = v('ThreePointersMade');
    final tpa = v('ThreePointersAttempted');
    if (fga == 0 && (v('TwoPointersAttempted') > 0 || tpa > 0)) {
      fgm = v('TwoPointersMade') + tpm;
      fga = v('TwoPointersAttempted') + tpa;
    }
    final oreb = v('ReboundsOffensive');
    var dreb = v('ReboundsDefensive');
    if (oreb + dreb == 0 && v('ReboundsTotal') > 0) dreb = v('ReboundsTotal');
    return StatLine(
      points: v('Points'),
      fgm: fgm,
      fga: fga,
      tpm: tpm,
      tpa: tpa,
      ftm: v('FreeThrowsMade'),
      fta: v('FreeThrowsAttempted'),
      oreb: oreb,
      dreb: dreb,
      ast: v('Assists'),
      tov: v('Turnovers'),
      stl: v('Steals'),
      blk: v('Blocks'),
      pf: v('FoulsPersonal'),
      plusMinus: v('PlusMinusPoints'),
      seconds: _seconds(m['${prefix}Minutes']),
    );
  }

  static String _playerName(Map<String, dynamic> p) {
    final first = (p['firstName'] ?? '').toString().trim();
    final family = (p['familyName'] ?? '').toString().trim();
    if (first.isNotEmpty || family.isNotEmpty) return _title('$first $family'.trim());
    return _title((p['name'] ?? p['scoreboardName'] ?? 'Jogador').toString().trim());
  }

  /// "JOÃO DA SILVA" → "João da Silva" (nomes vêm em maiúsculas em muitas súmulas).
  static String _title(String s) {
    if (s != s.toUpperCase()) return s;
    const lower = {'da', 'de', 'do', 'das', 'dos', 'e'};
    return s.toLowerCase().split(' ').where((w) => w.isNotEmpty).map((w) => lower.contains(w) ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  static TeamBox _team(Map<String, dynamic> t) {
    final players = <PlayerBox>[];
    final pl = t['pl'];
    if (pl is Map) {
      for (final entry in pl.entries) {
        final raw = entry.value;
        if (raw is! Map) continue;
        final p = raw.cast<String, dynamic>();
        final name = _playerName(p);
        players.add(
          PlayerBox(
            key: ScheduleParser.normalize(name),
            pno: int.tryParse(entry.key.toString()) ?? _int(p['pno']),
            name: name,
            number: (p['shirtNumber'] ?? '').toString(),
            position: (p['playingPosition'] ?? '').toString(),
            starter: _int(p['starter']) == 1,
            stats: _stats(p, 's'),
          ),
        );
      }
    }
    players.sort((a, b) {
      if (a.starter != b.starter) return a.starter ? -1 : 1;
      return b.stats.seconds.compareTo(a.stats.seconds);
    });

    var totals = _stats(t, 'tot_s');
    if (totals.fga == 0 && totals.points == 0 && players.isNotEmpty) {
      totals = players.fold(StatLine.zero, (sum, p) => sum + p.stats);
    }

    final periods = <int>[
      for (var i = 1; i <= 4; i++) _int(t['p${i}_score']),
      for (var i = 1; i <= 6; i++)
        if (t['ot${i}_score'] != null) _int(t['ot${i}_score']),
    ];
    final score = _int(t['full_score'] ?? t['score']) != 0 ? _int(t['full_score'] ?? t['score']) : totals.points;

    const extraKeys = {
      'paint': 'tot_sPointsInThePaint',
      'fastBreak': 'tot_sPointsFastBreak',
      'secondChance': 'tot_sPointsSecondChance',
      'fromTurnovers': 'tot_sPointsFromTurnovers',
      'bench': 'tot_sBenchPoints',
      'biggestLead': 'tot_sBiggestLead',
    };

    final name = (t['name'] ?? t['nameInternational'] ?? t['shortName'] ?? 'Equipe').toString().trim();
    return TeamBox(
      name: _title(name),
      code: (t['code'] ?? t['shortName'] ?? '').toString(),
      score: score,
      periodScores: periods,
      totals: totals,
      players: players,
      extras: {
        for (final e in extraKeys.entries)
          if (t[e.value] != null) e.key: _int(t[e.value]),
      },
    );
  }

  static List<ShotAttempt> _shots(List<Map<String, dynamic>> raw, Map<int, TeamBox> teams, Map<int, Map<String, dynamic>> rawTeams) {
    if (raw.isEmpty) return const [];
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 50;

    // O eixo do comprimento da quadra é o que mais se afasta do centro
    // (arremessos se concentram perto das cestas, nas pontas).
    var devX = 0.0, devY = 0.0;
    for (final s in raw) {
      devX += (d(s['x']) - 50).abs();
      devY += (d(s['y']) - 50).abs();
    }
    final lengthIsX = devX >= devY;

    // Nome do jogador pelo número de cadastro (pno) na equipe.
    String nameOf(int team, dynamic pno) {
      final pl = rawTeams[team]?['pl'];
      if (pl is Map && pl['$pno'] is Map) return _playerName((pl['$pno'] as Map).cast<String, dynamic>());
      return '';
    }

    return [
      for (final s in raw)
        () {
          final team = s['_team'] as int;
          final along = lengthIsX ? d(s['x']) : d(s['y']);
          final across = lengthIsX ? d(s['y']) : d(s['x']);
          final mirrored = along > 50;
          final depth = (mirrored ? 100 - along : along) / 50;
          final lateral = (mirrored ? 100 - across : across) / 100;
          final type = (s['actionType'] ?? '').toString().toLowerCase();
          var name = nameOf(team, s['pno'] ?? s['p']);
          if (name.isEmpty) name = _title((s['player'] ?? '').toString().trim());
          return ShotAttempt(
            x: lateral.clamp(0.0, 1.0),
            y: depth.clamp(0.0, 1.0),
            made: _int(s['r']) == 1,
            points: type.contains('3') ? 3 : 2,
            period: _int(s['per'] ?? s['period']),
            player: name,
            playerKey: ScheduleParser.normalize(name),
            team: team,
            subType: (s['subType'] ?? '').toString(),
          );
        }(),
    ];
  }
}
