import '../../services/league_sync_service.dart';
import '../../services/schedule_parser.dart';

/// Competição numa fonte oficial (ex.: "SUB 16M 2026" da FPB).
class CompetitionRef {
  /// Id na fonte (ex.: UUID do calendário CBB/FPB).
  final String id;
  final String name;

  /// Categoria no formato das ligas ("SUB 16 M").
  final String category;
  final int season;
  const CompetitionRef({required this.id, required this.name, required this.category, required this.season});
}

/// Calendário estruturado de uma competição, com o diagnóstico da consulta.
class ProviderSchedule {
  final CompetitionRef competition;
  final SourceAttempt attempt;
  final List<ParsedGame> games;
  const ProviderSchedule(this.competition, this.attempt, this.games);
}

/// Integração de uma liga/federação com o ARCO.
///
/// Cada fonte (FPB, LBC, futuras ligas) implementa esta interface; telas,
/// histórico e análises não sabem de onde os dados vieram. Se a fonte mudar
/// o site, só a implementação dela muda.
///
///   Competição → Temporada → Categoria → Equipes → Jogos → Detalhes
abstract class CompetitionProvider {
  String get league;

  /// Competições estruturadas conhecidas para a temporada.
  List<CompetitionRef> knownCompetitions(int season);

  /// Calendário completo (jogos realizados e futuros) das competições pedidas;
  /// sem ids, usa [knownCompetitions].
  Future<List<ProviderSchedule>> fetchSchedules({required int season, List<String> competitionIds = const []});
}

/// Fonte sem calendário estruturado conhecido (usa só páginas/notícias).
class PagesOnlyProvider implements CompetitionProvider {
  @override
  final String league;
  const PagesOnlyProvider(this.league);

  @override
  List<CompetitionRef> knownCompetitions(int season) => const [];

  @override
  Future<List<ProviderSchedule>> fetchSchedules({required int season, List<String> competitionIds = const []}) async => const [];
}

/// LBC: ainda sem calendário estruturado público conhecido. Usa as páginas
/// cadastradas em "Fontes" e a importação manual; quando a liga publicar um
/// calendário/API, ele entra aqui sem mudar o resto do app.
class LbcProvider extends PagesOnlyProvider {
  const LbcProvider() : super('LBC');
}
