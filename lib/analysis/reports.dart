import 'game_analysis.dart';
import 'season_analysis.dart';
import 'shot_zones.dart';

class ReportSection {
  final String heading;
  final List<String> lines;
  const ReportSection(this.heading, this.lines);
}

/// Relatório pronto para tela, PDF e WhatsApp.
class ArcoReport {
  final String title;
  final String subtitle;
  final List<ReportSection> sections;
  const ArcoReport(this.title, this.subtitle, this.sections);

  String toPlainText() {
    final b = StringBuffer('*$title*\n$subtitle\n');
    for (final s in sections.where((s) => s.lines.isNotEmpty)) {
      b.write('\n*${s.heading}*\n');
      for (final l in s.lines) {
        b.write('• $l\n');
      }
    }
    b.write('\nGerado pelo ARCO Analytics');
    return b.toString();
  }
}

class Reports {
  static ArcoReport postGame(GameAnalysis g) {
    final l = g.us.totals;
    final players = g.us.players.where((p) => p.played).toList()..sort((a, b) => b.stats.efficiency.compareTo(a.stats.efficiency));
    return ArcoReport(
      'Pós-jogo: ${g.us.name} ${g.us.score} × ${g.them.score} ${g.them.name}',
      '${g.resultLabel} • ${g.game.league == 'SCOUT' ? 'Scout ARCO' : g.game.league}',
      [
        ReportSection('Resumo', [for (final f in g.findings().take(4)) '${f.title}: ${f.detail}']),
        ReportSection('Estatísticas', [
          'Arremessos: ${l.fgm}/${l.fga} (${p0(l.fgPct)}) • 3P ${l.tpm}/${l.tpa} (${p0(l.tpPct)}) • LL ${l.ftm}/${l.fta} (${p0(l.ftPct)})',
          'eFG ${p1(l.efgPct)} • TS ${p1(l.tsPct)} • posses ${l.possessions.toStringAsFixed(0)} • pontos por posse ${g.ppp.toStringAsFixed(2)}',
          'Rebotes ${l.reb} (${l.oreb} of.) • assistências ${l.ast} • erros ${l.tov} • roubos ${l.stl} • tocos ${l.blk}',
          if (g.quarters().isNotEmpty) 'Quartos: ${g.quarters().map((q) => '${q.$2}-${q.$3}').join(' | ')}',
          for (final z in g.zones().where((z) => z.$3 > 0)) '${z.$1.label}: ${z.$2}/${z.$3}',
        ]),
        ReportSection('Destaques', [
          for (final p in players.take(3)) '${p.name}: ${p.stats.points} pts, ${p.stats.reb} reb, ${p.stats.ast} ast (eficiência ${p.stats.efficiency})',
        ]),
        ReportSection('E se...', [for (final w in g.whatIfs()) '${w.title}: ${w.detail}']),
        ReportSection('Pontos de atenção', [
          for (final f in g.findings().where((f) => f.level == FindingLevel.warning || f.level == FindingLevel.critical)) '${f.title}: ${f.detail}',
        ]),
        ReportSection('Recomendações para o próximo treino', g.trainingPlan()),
      ],
    );
  }

  static ArcoReport preGame(OpponentReport r) => ArcoReport(
        'Relatório do adversário: ${r.team.name}',
        '${r.team.games} jogos analisados • ${r.team.wins}V ${r.team.losses}D • ${n1(r.team.ppg)} pts feitos, ${n1(r.team.oppPpg)} sofridos',
        [
          ReportSection('Estilo de jogo', [r.style]),
          ReportSection('Jogadores principais', [
            for (final p in r.topScorers)
              '${p.number.isEmpty ? '' : '#${p.number} '}${p.name}: ${n1(p.ppg)} pts, ${n1(p.rpg)} reb, ${n1(p.apg)} ast, 3P ${p0(p.totals.tpPct)}',
          ]),
          ReportSection('Pontos fortes', r.strengths()),
          ReportSection('Pontos fracos', r.weaknesses()),
          ReportSection('Zonas de arremesso', [
            for (final z in r.season.zones().where((z) => z.$3 > 0)) '${z.$1.label}: ${z.$2}/${z.$3} (${p0(z.$2 * 100 / z.$3)})',
          ]),
          ReportSection('Sugestões defensivas', r.defensivePlan()),
        ],
      );

  static ArcoReport season(SeasonAnalysis s) => ArcoReport(
        'Temporada: ${s.team.name}',
        '${s.team.games} jogos • ${s.team.wins}V ${s.team.losses}D • ${n1(s.team.ppg)} × ${n1(s.team.oppPpg)} por jogo',
        [
          ReportSection('Principais conclusões', [for (final f in s.findings()) '${f.title}: ${f.detail}']),
          ReportSection('Prioridades de treino', s.trainingPriorities()),
          ReportSection('Destaques', [
            for (final p in s.team.roster.take(5)) '${p.name}: ${n1(p.ppg)} pts, ${n1(p.rpg)} reb, ${n1(p.apg)} ast em ${p.games} jogos',
          ]),
        ],
      );
}
