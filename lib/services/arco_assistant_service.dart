import '../models/game.dart';
import '../models/lineup.dart';
import '../models/player.dart';
import 'advanced_analytics_service.dart';
import 'analytics_service.dart';

class ArcoAssistantAnswer {
  final String title;
  final String answer;
  final List<String> evidence;
  final String confidence;

  const ArcoAssistantAnswer({
    required this.title,
    required this.answer,
    required this.evidence,
    required this.confidence,
  });
}

class ArcoAssistantService {
  static ArcoAssistantAnswer answer({
    required String question,
    required List<Game> games,
    required List<Player> players,
    required List<Lineup> lineups,
  }) {
    final q = question.toLowerCase().trim();
    final summary = AdvancedAnalyticsService.summarize(games);
    final sampleNote = summary.usesDemoData
        ? 'A resposta usa dados DEMO porque ainda não há scout real suficiente.'
        : 'A resposta usa os scouts reais salvos no ARCO.';

    if (q.contains('quinteto') || q.contains('lineup') || q.contains('formação')) {
      if (lineups.isEmpty) {
        return ArcoAssistantAnswer(
          title: 'Lineups ainda sem amostra suficiente',
          answer:
              'Ainda não existem eventos suficientes com cinco jogadores em quadra para comparar quintetos com segurança.',
          evidence: [sampleNote],
          confidence: 'BAIXA',
        );
      }
      final ranked = [...lineups]
        ..sort((a, b) => b.netRating.compareTo(a.netRating));
      final best = ranked.first;
      return ArcoAssistantAnswer(
        title: 'Melhor lineup da amostra',
        answer:
            '${best.players.join(' • ')} apresenta o melhor Net Rating entre os lineups registrados.',
        evidence: [
          'Net Rating ${best.netRating >= 0 ? '+' : ''}${best.netRating.toStringAsFixed(1)}',
          '${best.possessions} posses',
          'Confiança ${AnalyticsService.sampleConfidence(best.possessions)}',
          sampleNote,
        ],
        confidence: AnalyticsService.sampleConfidence(best.possessions),
      );
    }

    if (q.contains('turnover') ||
        q.contains('perda') ||
        q.contains('posse')) {
      final high = summary.turnoverPct > 18;
      return ArcoAssistantAnswer(
        title: high ? 'Perdas de bola pedem atenção' : 'Proteção de posse controlada',
        answer: high
            ? 'O volume de turnovers está alto para a amostra atual. Antes de mudar o sistema inteiro, identifique em quais lineups e períodos as perdas se concentram.'
            : 'A taxa de turnovers está em uma faixa controlada na amostra atual. Vale preservar as ações que estão simplificando a tomada de decisão.',
        evidence: [
          'TOV ${summary.turnoverPct.toStringAsFixed(1)}%',
          '${summary.turnovers} turnovers em ${summary.possessions} posses',
          sampleNote,
        ],
        confidence: summary.sampleConfidence,
      );
    }

    if (q.contains('arremesso') ||
        q.contains('efg') ||
        q.contains('eficiência')) {
      return ArcoAssistantAnswer(
        title: 'Eficiência de arremesso',
        answer: summary.efg >= 52
            ? 'A eficiência de arremesso é uma força da amostra atual. O foco deve ser preservar a qualidade das finalizações.'
            : 'A eficiência de arremesso está abaixo de uma faixa forte. O próximo diagnóstico é separar localização, contexto e jogador antes de aumentar volume.',
        evidence: [
          'eFG ${summary.efg.toStringAsFixed(1)}%',
          '${summary.fgm} acertos em ${summary.fga} tentativas de quadra',
          sampleNote,
        ],
        confidence: summary.sampleConfidence,
      );
    }

    if (q.contains('defesa') || q.contains('defens')) {
      return ArcoAssistantAnswer(
        title: 'Leitura defensiva',
        answer:
            'O DRtg resume quanto a equipe sofreu por 100 posses. Use a tendência junto com lineups e períodos, não como diagnóstico isolado.',
        evidence: [
          'DRtg ${summary.defensiveRating.toStringAsFixed(1)}',
          'Média sofrida ${summary.avgPointsAgainst.toStringAsFixed(1)} pontos',
          '${summary.possessions} posses na amostra',
          sampleNote,
        ],
        confidence: summary.sampleConfidence,
      );
    }

    if (q.contains('ataque') || q.contains('ofens')) {
      return ArcoAssistantAnswer(
        title: 'Leitura ofensiva',
        answer:
            'O ORtg mostra a produção por 100 posses. Combine esta leitura com eFG, turnovers, rebote ofensivo e FT Rate para entender por que o ataque está produzindo.',
        evidence: [
          'ORtg ${summary.offensiveRating.toStringAsFixed(1)}',
          'eFG ${summary.efg.toStringAsFixed(1)}%',
          'TOV ${summary.turnoverPct.toStringAsFixed(1)}%',
          sampleNote,
        ],
        confidence: summary.sampleConfidence,
      );
    }

    if (q.contains('jogador') || q.contains('impact')) {
      if (players.isEmpty) {
        return const ArcoAssistantAnswer(
          title: 'Sem jogadores cadastrados',
          answer: 'Cadastre o elenco para calcular impacto individual.',
          evidence: [],
          confidence: 'BAIXA',
        );
      }
      final ranked = [...players]
        ..sort((a, b) => AnalyticsService.impactScore(b)
            .compareTo(AnalyticsService.impactScore(a)));
      final player = ranked.first;
      return ArcoAssistantAnswer(
        title: 'Maior impacto no modelo atual',
        answer:
            '${player.name} lidera o ARCO Impact entre os jogadores cadastrados. Esse indicador é experimental e precisa ser lido junto da amostra e do papel tático.',
        evidence: [
          'ARCO Impact ${AnalyticsService.impactScore(player).toStringAsFixed(0)}',
          'On/Off líquido ${AnalyticsService.onOffNet(player).toStringAsFixed(1)}',
          sampleNote,
        ],
        confidence: summary.sampleConfidence,
      );
    }

    final form = AdvancedAnalyticsService.recentForm(games).join(' – ');
    return ArcoAssistantAnswer(
      title: 'Resumo da equipe',
      answer:
          'A equipe está ${summary.wins}-${summary.losses} na amostra registrada. O Net Rating é o melhor ponto de partida para entender o saldo global, e os Four Factors explicam o porquê.',
      evidence: [
        'Forma recente: ${form.isEmpty ? 'sem jogos' : form}',
        'Net Rating ${summary.netRating >= 0 ? '+' : ''}${summary.netRating.toStringAsFixed(1)}',
        'ORtg ${summary.offensiveRating.toStringAsFixed(1)} • DRtg ${summary.defensiveRating.toStringAsFixed(1)}',
        'Confiança ${summary.sampleConfidence}',
        sampleNote,
      ],
      confidence: summary.sampleConfidence,
    );
  }
}
