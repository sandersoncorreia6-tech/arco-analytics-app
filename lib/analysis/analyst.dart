import '../services/schedule_parser.dart';
import '../services/stats_aggregator.dart';
import 'game_analysis.dart';
import 'season_analysis.dart';
import 'shot_zones.dart';

class AnalystReply {
  final String text;
  final List<String> suggestions;
  const AnalystReply(this.text, {this.suggestions = const []});
}

/// Analista ARCO: responde perguntas do treinador com base nas estatísticas
/// importadas e no scout. Funciona offline, sem custo e sem enviar dados.
///
/// Projetado para que uma IA conversacional possa ser ligada depois: ela
/// receberia como contexto o texto destas mesmas análises.
class ArcoAnalyst {
  final Map<String, TeamSeason> teams;
  final List<TeamSeason> myTeams;
  ArcoAnalyst({required this.teams, required this.myTeams});

  static const suggestions = [
    'De onde minha equipe mais erra?',
    'Por que perdemos o último jogo?',
    'E se tivéssemos acertado os lances livres?',
    'Em qual quarto o time mais cai?',
    'Qual a melhor formação?',
    'O que treinar esta semana?',
    'Quem são os destaques?',
    'Compare os últimos jogos',
  ];

  static String _erros(int n) => n == 1 ? '1 erro' : '$n erros';

  TeamSeason? get team => myTeams.isEmpty ? null : myTeams.first;

  AnalystReply answer(String question) {
    final q = ScheduleParser.normalize(question);
    final t = team;
    if (t == null || t.games == 0) {
      return const AnalystReply(
        'Ainda não tenho jogos da sua equipe para analisar. Importe as estatísticas na aba Stats (link do jogo na aba '
        'Estatística/Online do site) ou registre um jogo no Scout ao vivo — depois é só perguntar.',
        suggestions: ['O que você consegue analisar?'],
      );
    }

    bool has(List<String> words) => words.any((w) => q.contains(w));
    final season = SeasonAnalysis(t);

    final opponent = _findOtherTeam(q, t);
    if (opponent != null && has(['adversario', 'proximo', 'enfrentar', 'scout', 'relatorio', 'como joga', 'contra', 'pre jogo'])) {
      return _opponent(opponent);
    }
    final player = _findPlayer(q, t);
    if (player != null) return _player(player, season);

    if (has(['lance livre', 'lances livres', 'll '])) return _freeThrows(season);
    if (has(['erra', 'zona', 'onde', 'regiao', 'mapa', 'arremess', 'lado', 'canto'])) return _shooting(season);
    if (has(['turnover', 'perda de bola', 'perdas de bola', 'desperdicio', 'erros de passe', 'erros', 'bola perdida'])) return _turnovers(season);
    if (has(['rebote'])) return _rebounds(season);
    if (has(['quarto', 'periodo', 'cai', 'cresce', 'final de jogo'])) return _quarters(season);
    if (has(['formacao', 'quinteto', 'lineup', 'escalacao', 'titular'])) return _lineups(season);
    if (has(['treino', 'treinar', 'melhorar', 'melhoria', 'corrigir', 'trabalhar'])) return _training(season);
    if (has(['destaque', 'melhor jogador', 'cestinha', 'quem'])) return _leaders(t);
    if (has(['compar', 'evolu', 'ultimos jogos', 'tendencia'])) return _compare(season);
    if (has(['ultimo jogo', 'perdemos', 'por que', 'porque', 'ganhamos', 'vencemos', 'pos jogo', 'resumo'])) return _lastGame(season);
    if (has(['e se', 'teria', 'simul'])) return _whatIfs(season);
    if (has(['ritmo', 'pace', 'posse'])) return _pace(t);
    if (has(['3 pontos', 'bola de 3', 'bolas de 3', 'tres pontos', 'de tres'])) return _shooting(season, threes: true);
    if (has(['consegue', 'ajuda', 'o que voce'])) {
      return const AnalystReply(
        'Analiso os jogos importados e o scout da sua equipe: onde o time erra, o que decidiu cada jogo, simulações '
        '("e se"), quartos, formações, destaques, evolução, adversários e o que treinar. Experimente:',
        suggestions: suggestions,
      );
    }
    return _overview(season);
  }

  // ------------------------------------------------------------ respostas

  AnalystReply _overview(SeasonAnalysis s) {
    final t = s.team;
    final f = s.findings().take(5).map((e) => '• ${e.title}: ${e.detail}').join('\n');
    return AnalystReply(
      '${t.name}: ${t.games} jogos, ${t.wins}V ${t.losses}D, ${n1(t.ppg)} pontos feitos e ${n1(t.oppPpg)} sofridos por jogo '
      '(saldo ${t.netRating >= 0 ? '+' : ''}${n1(t.netRating)} por 100 posses).\n\n$f',
      suggestions: suggestions.take(4).toList(),
    );
  }

  AnalystReply _shooting(SeasonAnalysis s, {bool threes = false}) {
    final shots = threes ? s.team.shots.where((x) => x.isThree).toList() : s.team.shots;
    if (shots.isEmpty) {
      final l = s.team.totals;
      return AnalystReply(
        'As partidas importadas não têm posição dos arremessos, mas os números gerais são: 2 pontos ${l.twoPm}/${l.twoPa} '
        '(${p0(l.twoPct)}), 3 pontos ${l.tpm}/${l.tpa} (${p0(l.tpPct)}), lances livres ${l.ftm}/${l.fta} (${p0(l.ftPct)}).',
      );
    }
    final zones = s.zones(shots).where((z) => z.$3 > 0).toList()..sort((a, b) => (b.$3 - b.$2).compareTo(a.$3 - a.$2));
    final lines = zones.map((z) => '• ${z.$1.label}: ${z.$2}/${z.$3} (${p0(z.$2 * 100 / z.$3)}) — ${_erros(z.$3 - z.$2)}').join('\n');
    final sides = s.sides(threesOnly: threes, shots: shots).where((x) => x.$3 > 0).map((x) => '${x.$1} ${x.$2}/${x.$3} (${p0(x.$2 * 100 / x.$3)})').join(' • ');
    final worst = zones.first;
    return AnalystReply(
      '${threes ? 'Bolas de 3' : 'Arremessos'} de ${s.team.name} (${shots.length} com posição registrada):\n$lines\n\n'
      'Por lado da quadra: $sides.\n\n'
      'Onde mais erra: ${worst.$1.label.toLowerCase()} (${_erros(worst.$3 - worst.$2)}). '
      '${worst.$2 / worst.$3 < .35 ? 'Vale reduzir o volume nessa zona ou treiná-la especificamente.' : 'O volume é alto, mas o aproveitamento está aceitável.'}',
      suggestions: const ['Quem arremessa melhor?', 'E se tivéssemos acertado os lances livres?'],
    );
  }

  AnalystReply _freeThrows(SeasonAnalysis s) {
    final l = s.team.totals;
    final buf = StringBuffer('Lances livres na temporada: ${l.ftm}/${l.fta} (${p0(l.ftPct)}).\n');
    final flipped = s.lossesFlippedByFreeThrows();
    if (flipped.isEmpty) {
      buf.write('Nenhuma derrota teria virado só com 75% nos lances livres.');
    } else {
      buf.write('Com 75% nos lances livres, ${flipped.length == 1 ? 'esta derrota teria virado' : 'estas derrotas teriam virado'}:\n');
      for (final (g, w) in flipped) {
        buf.write('• vs ${g.them.name} (${g.us.score} × ${g.them.score}): ${w.detail}\n');
      }
    }
    for (final g in s.losses) {
      final w = g.whatIfs().where((x) => x.title == 'Lances livres');
      if (w.isNotEmpty && !w.first.flipsResult) buf.write('• vs ${g.them.name}: ${w.first.detail}\n');
    }
    final shooters = s.team.roster.where((p) => p.totals.fta >= 6).toList()..sort((a, b) => a.totals.ftPct.compareTo(b.totals.ftPct));
    if (shooters.isNotEmpty) {
      buf.write('\nPior aproveitamento individual: ${shooters.take(3).map((p) => '${p.name} ${p.totals.ftm}/${p.totals.fta} (${p0(p.totals.ftPct)})').join(', ')}.');
    }
    return AnalystReply(buf.toString().trim(), suggestions: const ['O que treinar esta semana?', 'Por que perdemos o último jogo?']);
  }

  AnalystReply _turnovers(SeasonAnalysis s) {
    final t = s.team;
    final w = SplitAverages.of(s.wins), l = SplitAverages.of(s.losses);
    final worst = t.roster.where((p) => p.games > 0).toList()..sort((a, b) => b.perGame(b.totals.tov).compareTo(a.perGame(a.totals.tov)));
    final fromTov = s.games.fold<int>(0, (sum, g) => sum + (g.them.extras['fromTurnovers'] ?? 0));
    return AnalystReply(
      'Erros (turnovers): ${n1(t.perGame(t.totals.tov))} por jogo, ${p0(t.tovPct)} das posses.\n'
      '${s.wins.isNotEmpty && s.losses.isNotEmpty ? 'Vitórias: ${n1(w.tov)} por jogo • derrotas: ${n1(l.tov)} por jogo.\n' : ''}'
      '${fromTov > 0 ? 'Pontos que o adversário fez após nossos erros: $fromTov.\n' : ''}'
      'Quem mais erra: ${worst.take(3).map((p) => '${p.name} (${n1(p.perGame(p.totals.tov))}/jogo)').join(', ')}.\n'
      'Cada erro custa em média ${n1(t.totals.possessions <= 0 ? 0 : t.pointsFor / t.totals.possessions)} pontos (uma posse perdida).',
      suggestions: const ['O que treinar esta semana?', 'Em qual quarto o time mais cai?'],
    );
  }

  AnalystReply _rebounds(SeasonAnalysis s) {
    final t = s.team;
    final leaders = t.roster.toList()..sort((a, b) => b.rpg.compareTo(a.rpg));
    return AnalystReply(
      'Rebotes: ${n1(t.perGame(t.totals.reb))} por jogo (${n1(t.perGame(t.totals.oreb))} ofensivos, ${n1(t.perGame(t.totals.dreb))} defensivos).\n'
      'Recuperamos ${p0(t.orbPct)} dos nossos erros; o adversário recupera '
      '${p0(t.opponents.oreb + t.totals.dreb == 0 ? 0 : t.opponents.oreb * 100 / (t.opponents.oreb + t.totals.dreb))} dos dele.\n'
      'Líderes: ${leaders.take(3).map((p) => '${p.name} ${n1(p.rpg)}').join(', ')}.',
    );
  }

  AnalystReply _quarters(SeasonAnalysis s) {
    final qs = s.quarterAverages();
    if (qs.isEmpty) return const AnalystReply('As partidas importadas não têm o placar por quarto.');
    final lines = qs.map((q) => '• ${q.$1}: ${n1(q.$2)} × ${n1(q.$3)} (saldo ${q.$2 >= q.$3 ? '+' : ''}${n1(q.$2 - q.$3)})').join('\n');
    final sorted = [...qs]..sort((a, b) => (a.$2 - a.$3).compareTo(b.$2 - b.$3));
    return AnalystReply(
      'Média por quarto (nós × adversário):\n$lines\n\nO time mais cai no ${sorted.first.$1} e mais cresce no ${sorted.last.$1}.',
      suggestions: const ['Qual a melhor formação?', 'O que treinar esta semana?'],
    );
  }

  AnalystReply _lineups(SeasonAnalysis s) {
    final list = s.lineups().where((l) => l.minutes >= 3).toList();
    if (list.isEmpty) {
      return const AnalystReply('Para analisar formações preciso do lance a lance com substituições (vem na estatística online completa).');
    }
    list.sort((a, b) => b.plusMinus.compareTo(a.plusMinus));
    String row(l) => '${l.names.join(' – ')}: ${l.plusMinus >= 0 ? '+' : ''}${l.plusMinus} em ${n1(l.minutes)} min '
        '(ataque ${n1(l.offRating)}, defesa ${n1(l.defRating)} por 100 posses)';
    final most = [...list]..sort((a, b) => b.seconds.compareTo(a.seconds));
    return AnalystReply(
      'Melhores formações:\n${list.take(3).map((l) => '• ${row(l)}').join('\n')}\n\n'
      'Piores:\n${list.reversed.take(2).map((l) => '• ${row(l)}').join('\n')}\n\n'
      'Mais utilizada: ${row(most.first)}.\nAtenção: formações com poucos minutos têm amostra pequena.',
    );
  }

  AnalystReply _training(SeasonAnalysis s) {
    final priorities = s.trainingPriorities();
    final last = s.games.isEmpty ? <String>[] : s.games.last.trainingPlan();
    return AnalystReply(
      'Prioridades da temporada:\n${priorities.map((e) => '• $e').join('\n')}\n\n'
      'Para o próximo treino (com base no último jogo):\n${last.map((e) => '• $e').join('\n')}',
      suggestions: const ['De onde minha equipe mais erra?', 'Em qual quarto o time mais cai?'],
    );
  }

  AnalystReply _leaders(TeamSeason t) {
    final r = t.roster.where((p) => p.games > 0).toList();
    String top(String label, double Function(PlayerSeason) f) {
      final sorted = [...r]..sort((a, b) => f(b).compareTo(f(a)));
      return '• $label: ${sorted.take(3).map((p) => '${p.name} ${n1(f(p))}').join(', ')}';
    }

    return AnalystReply([
      'Destaques de ${t.name} (médias por jogo):',
      top('Pontos', (p) => p.ppg),
      top('Rebotes', (p) => p.rpg),
      top('Assistências', (p) => p.apg),
      top('Eficiência', (p) => p.effPerGame),
    ].join('\n'));
  }

  AnalystReply _lastGame(SeasonAnalysis s) {
    final g = s.games.last;
    final findings = g.findings().take(6).map((f) => '• ${f.title}: ${f.detail}').join('\n');
    final whatIfs = g.whatIfs().take(3).map((w) => '• ${w.title}: ${w.detail}').join('\n');
    return AnalystReply(
      'Último jogo: ${g.us.name} ${g.us.score} × ${g.them.score} ${g.them.name} — ${g.resultLabel}.\n\n$findings'
      '${whatIfs.isEmpty ? '' : '\n\nE se...\n$whatIfs'}\n\nPara o treino:\n${g.trainingPlan().map((e) => '• $e').join('\n')}',
      suggestions: const ['Compare os últimos jogos', 'De onde minha equipe mais erra?'],
    );
  }

  AnalystReply _whatIfs(SeasonAnalysis s) {
    final buf = StringBuffer();
    for (final g in s.finals.reversed.take(5)) {
      final w = g.whatIfs();
      if (w.isEmpty) continue;
      buf.write('vs ${g.them.name} (${g.us.score} × ${g.them.score}):\n${w.take(3).map((x) => '• ${x.title}: ${x.detail}').join('\n')}\n\n');
    }
    return AnalystReply(buf.isEmpty ? 'Nos jogos recentes nenhum fator isolado teria mudado o placar de forma relevante.' : buf.toString().trim());
  }

  AnalystReply _compare(SeasonAnalysis s) {
    final list = s.games.reversed.take(5).toList().reversed.toList();
    final rows = list.map((g) {
      final f = FourFactors.of(g.us.totals, g.them.totals);
      return '• vs ${g.them.name}: ${g.us.score}×${g.them.score} • eFG ${p0(f.efg)} • erros ${g.us.totals.tov} • reb ${g.us.totals.reb} '
          '• LL ${p0(g.us.totals.ftPct)} • posses ${g.us.totals.possessions.toStringAsFixed(0)}';
    }).join('\n');
    return AnalystReply('Comparação dos últimos ${list.length} jogos:\n$rows', suggestions: const ['Por que perdemos o último jogo?']);
  }

  AnalystReply _pace(TeamSeason t) => AnalystReply(
        'Ritmo: ${n1(t.pace)} posses por jogo. Pontos por posse: '
        '${(t.totals.possessions <= 0 ? 0 : t.pointsFor / t.totals.possessions).toStringAsFixed(2)} (ataque) e '
        '${(t.opponents.possessions <= 0 ? 0 : t.pointsAgainst / t.opponents.possessions).toStringAsFixed(2)} (defesa).',
      );

  AnalystReply _player(PlayerSeason p, SeasonAnalysis s) {
    final l = p.totals;
    final zones = s.zones(p.shots).where((z) => z.$3 >= 3).map((z) => '${z.$1.label} ${z.$2}/${z.$3}').join(', ');
    final usg = usageRate(p, s.team);
    final last = p.log.length > 5 ? p.log.sublist(p.log.length - 5) : p.log;
    final recent = last.isEmpty ? 0.0 : last.fold<int>(0, (sum, e) => sum + e.box.stats.points) / last.length;
    final strengths = <String>[
      if (l.efgPct >= 50 && l.fga >= 10) 'aproveitamento eficiente (eFG ${p0(l.efgPct)})',
      if (p.apg >= 3) 'criação (${n1(p.apg)} ast)',
      if (p.rpg >= 6) 'rebote (${n1(p.rpg)})',
      if (p.perGame(l.stl) >= 1.5) 'defesa/roubos (${n1(p.perGame(l.stl))})',
    ];
    final develop = <String>[
      if (l.fta >= 6 && l.ftPct < 65) 'lances livres (${p0(l.ftPct)})',
      if (l.tpa >= 8 && l.tpPct < 30) 'arremesso de 3 (${p0(l.tpPct)})',
      if (p.perGame(l.tov) >= 3) 'proteção de bola (${n1(p.perGame(l.tov))} erros/jogo)',
      if (p.perGame(l.pf) >= 3.5) 'controle de faltas (${n1(p.perGame(l.pf))}/jogo)',
    ];
    return AnalystReply(
      '${p.name}${p.number.isEmpty ? '' : ' #${p.number}'} — ${p.games} jogos\n'
      '${n1(p.ppg)} pts • ${n1(p.rpg)} reb • ${n1(p.apg)} ast • ${n1(p.mpg)} min • eficiência ${n1(p.effPerGame)}\n'
      'FG ${p0(l.fgPct)} • 3P ${l.tpm}/${l.tpa} (${p0(l.tpPct)}) • LL ${p0(l.ftPct)} • TS ${p0(l.tsPct)} • '
      'AST/ERR ${l.tov == 0 ? l.ast.toString() : (l.ast / l.tov).toStringAsFixed(1)}${usg == null ? '' : ' • USG ${p0(usg)}'}\n'
      'Últimos ${last.length} jogos: ${n1(recent)} pts (temporada ${n1(p.ppg)}).\n'
      '${zones.isEmpty ? '' : 'Zonas: $zones.\n'}'
      'Pontos fortes: ${strengths.isEmpty ? 'sem destaque estatístico claro ainda' : strengths.join(', ')}.\n'
      'Desenvolver: ${develop.isEmpty ? 'nenhum ponto crítico nos números' : develop.join(', ')}.',
    );
  }

  AnalystReply _opponent(TeamSeason o) {
    final r = OpponentReport(o);
    return AnalystReply(
      'Relatório de ${o.name} (${o.games} jogos, ${o.wins}V ${o.losses}D, ${n1(o.ppg)} pts feitos, ${n1(o.oppPpg)} sofridos)\n'
      'Estilo: ${r.style}.\n\n'
      'Principais pontuadores: ${r.topScorers.take(3).map((p) => '${p.name} ${n1(p.ppg)}').join(', ')}.\n\n'
      'Pontos fortes:\n${r.strengths().map((e) => '• $e').join('\n')}\n\n'
      'Pontos fracos:\n${r.weaknesses().map((e) => '• $e').join('\n')}\n\n'
      'Sugestões defensivas:\n${r.defensivePlan().map((e) => '• $e').join('\n')}',
    );
  }

  // ------------------------------------------------------------ busca por nomes

  TeamSeason? _findOtherTeam(String q, TeamSeason mine) {
    TeamSeason? best;
    var bestLen = 0;
    for (final t in teams.values) {
      if (t.key == mine.key) continue;
      for (final word in t.key.split(' ').where((w) => w.length >= 4)) {
        if (q.contains(word) && word.length > bestLen) {
          best = t;
          bestLen = word.length;
        }
      }
    }
    return best;
  }

  PlayerSeason? _findPlayer(String q, TeamSeason t) {
    final number = RegExp(r'(?:#|numero |camisa )(\d{1,2})\b').firstMatch(q);
    if (number != null) {
      for (final p in t.players.values) {
        if (p.number == number.group(1)) return p;
      }
    }
    PlayerSeason? best;
    var bestLen = 0;
    for (final p in t.players.values) {
      for (final word in p.key.split(' ').where((w) => w.length >= 4)) {
        if (RegExp('\\b$word\\b').hasMatch(q) && word.length > bestLen) {
          best = p;
          bestLen = word.length;
        }
      }
    }
    return best;
  }
}
