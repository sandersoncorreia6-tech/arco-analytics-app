import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../services/league_sync_service.dart';
import '../../services/schedule_parser.dart';
import '../../services/source_fetcher.dart';
import 'competition_provider.dart';

/// Federação Paulista de Basketball.
///
/// A aba Estatísticas → Online da FPB é alimentada pelo calendário da CBB
/// (www.cbb.com.br/calendario), que expõe os jogos de cada competição de
/// forma estruturada (equipes, placar, status, local, horário, ids).
/// Esta classe é o único ponto do app que conhece esse formato.
class FpbProvider implements CompetitionProvider {
  FpbProvider({SourceFetcher? fetcher, Uri Function()? webProxy})
      : _fetcher = fetcher ?? SourceFetcher(),
        _webProxy = webProxy;

  final SourceFetcher _fetcher;
  final Uri Function()? _webProxy;

  @override
  String get league => 'FPB';

  static const calendarUrl = 'https://www.cbb.com.br/calendario';

  /// Id da Server Action do calendário CBB. Muda quando o site da CBB é
  /// republicado; por isso é redescoberto automaticamente quando falha.
  static String scheduleAction = '7fa44f483f0a4da7815d44be667b13a23d4fc7bc44';

  // Em 2026 o catálogo público da CBB está com os rótulos U16 masc/fem
  // invertidos; este é o ID que efetivamente devolve "SUB 16M 2026".
  static const _known = <int, List<CompetitionRef>>{
    2026: [CompetitionRef(id: '323cc7a9-ee0b-11ee-8350-435475889b11', name: 'SUB 16M 2026', category: 'SUB 16 M', season: 2026)],
  };

  static final _uuid = RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', caseSensitive: false);

  @override
  List<CompetitionRef> knownCompetitions(int season) => _known[season] ?? const [];

  @override
  Future<List<ProviderSchedule>> fetchSchedules({required int season, List<String> competitionIds = const []}) async {
    // Ids informados pelo treinador (link ou UUID da competição) têm prioridade.
    final custom = [
      for (final raw in competitionIds)
        if (_uuid.firstMatch(raw) case final m?) m.group(0)!.toLowerCase(),
    ];
    final refs = <CompetitionRef>[
      ...knownCompetitions(season).where((c) => custom.isEmpty || custom.contains(c.id)),
      for (final id in custom)
        if (!knownCompetitions(season).any((c) => c.id == id)) CompetitionRef(id: id, name: 'Competição FPB', category: '', season: season),
    ];
    return Future.wait(refs.map((c) => _fetchOne(c, season)));
  }

  Future<ProviderSchedule> _fetchOne(CompetitionRef c, int season) async {
    final display = '$calendarUrl • FPB ${c.name}';
    try {
      final page = kIsWeb ? await _fetcher.get(_proxyScheduleUri(c.id, season)) : await _callAction(c.id, season);
      var games = parseSchedule(page.body);
      if (c.category.isNotEmpty) games = games.where((g) => g.competition == c.category || g.competition.isEmpty).toList();
      return ProviderSchedule(
        c,
        SourceAttempt(url: display, ok: true, statusCode: page.statusCode, bytes: page.body.length, elapsed: page.elapsed, gamesFound: games.length),
        games,
      );
    } catch (e) {
      return ProviderSchedule(
        c,
        SourceAttempt(url: display, ok: false, statusCode: e is SourceFetchException ? e.statusCode : null, error: SourceFetcher.describe(e)),
        const [],
      );
    }
  }

  Uri _proxyScheduleUri(String competitionId, int season) {
    final base = _webProxy?.call() ?? Uri.base.resolve('api/fpb-online');
    return base.replace(queryParameters: {'mode': 'schedule', 'competitionId': competitionId, 'year': '$season'});
  }

  Future<FetchedPage> _callAction(String competitionId, int season) async {
    Future<FetchedPage> call(String action) => _fetcher.post(
          Uri.parse(calendarUrl),
          headers: {'Accept': 'text/x-component', 'Content-Type': 'text/plain;charset=UTF-8', 'Next-Action': action},
          body: jsonEncode([
            {'competitionId': competitionId, 'org': 'fpb', 'fromDate': '$season-01-01', 'toDate': '$season-12-31'},
          ]),
        );

    try {
      final page = await call(scheduleAction);
      if (_hasList(page.body)) return page;
    } on SourceFetchException {
      // Action desatualizada: tenta redescobrir abaixo.
    }
    final discovered = await discoverAction();
    if (discovered == null || discovered == scheduleAction) {
      throw const SourceFetchException('O calendário da CBB mudou e o ARCO não encontrou a nova consulta de jogos.');
    }
    scheduleAction = discovered;
    return call(discovered);
  }

  static bool _hasList(String body) => parseSchedule(body).isNotEmpty || body.contains('"competitors"') || body.trim() == '[]';

  /// Localiza o id da Server Action `getMatchesByRange` nos scripts do calendário.
  Future<String?> discoverAction() async {
    final page = await _fetcher.get(Uri.parse(calendarUrl));
    final srcs = RegExp(r'''<script[^>]+src=["']([^"']+\.js)["']''')
        .allMatches(page.body)
        .map((m) => Uri.parse(calendarUrl).resolve(m.group(1)!))
        .toList()
      ..sort((a, b) => _rank(a.toString()).compareTo(_rank(b.toString())));
    for (final src in srcs) {
      try {
        final js = await _fetcher.get(src, retries: 0);
        final id = actionIdFromScript(js.body);
        if (id != null) return id;
      } catch (_) {
        // Um chunk pode falhar sem impedir os demais.
      }
    }
    return null;
  }

  static int _rank(String s) => s.contains('/calendario') ? 0 : (s.contains('/app/') ? 1 : 2);

  static String? actionIdFromScript(String js) {
    final marker = js.indexOf('getMatchesByRange');
    if (marker < 0) return null;
    final before = js.substring(marker - 900 < 0 ? 0 : marker - 900, marker);
    final ids = RegExp(r'''["']([0-9a-f]{32,64})["']''', caseSensitive: false).allMatches(before).toList();
    return ids.isEmpty ? null : ids.last.group(1);
  }

  /// Converte a resposta do calendário (JSON ou payload RSC da Server Action).
  static List<ParsedGame> parseSchedule(String body) {
    dynamic decoded;
    final trimmed = body.trim();
    try {
      if (trimmed.startsWith('[')) {
        decoded = jsonDecode(trimmed);
      } else if (trimmed.startsWith('{')) {
        final root = jsonDecode(trimmed);
        decoded = root is Map && root['games'] is List ? root['games'] : root;
      } else {
        for (final line in const LineSplitter().convert(body)) {
          final colon = line.indexOf(':');
          if (colon < 0) continue;
          final payload = line.substring(colon + 1).trimLeft();
          if (!payload.startsWith('[')) continue;
          final value = jsonDecode(payload);
          if (value is List) {
            decoded = value;
            break;
          }
        }
      }
    } catch (_) {
      return const [];
    }
    if (decoded is Map && decoded['data'] is List) decoded = decoded['data'];
    if (decoded is! List) return const [];

    final out = <ParsedGame>[];
    for (final raw in decoded.whereType<Map>()) {
      final competitors = (raw['competitors'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
      if (competitors.length < 2) continue;
      Map? home, away;
      for (final team in competitors) {
        final flag = team['isHomeCompetitor'];
        if (flag == true || flag == 1 || flag?.toString() == '1') {
          home ??= team;
        } else if (flag == false || flag == 0 || flag?.toString() == '0') {
          away ??= team;
        }
      }
      home ??= competitors.first;
      away ??= competitors.firstWhere((e) => !identical(e, home), orElse: () => competitors.last);
      final homeName = (home['teamName'] ?? '').toString().trim();
      final awayName = (away['teamName'] ?? '').toString().trim();
      if (homeName.isEmpty || awayName.isEmpty) continue;

      int? score(Map team) {
        final value = team['scoreString'] ?? team['score'];
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString().trim() ?? '');
      }

      String teamId(Map team) => (team['teamId'] ?? team['competitorId'] ?? team['id'] ?? '').toString();

      final competitionRaw = (raw['competitionName'] ?? '').toString();
      final competition = ScheduleParser.competitionOf(competitionRaw);
      final venue = raw['venue'];
      final venueName = venue is Map ? (venue['venueName'] ?? venue['name'] ?? '').toString() : '';
      final scheduledAt = DateTime.tryParse((raw['matchTime'] ?? raw['matchTimeUTC'] ?? '').toString());
      final status = switch ((raw['matchStatus'] ?? '').toString().toUpperCase()) {
        'COMPLETE' || 'COMPLETED' || 'FINAL' || 'FINISHED' => 'FINAL',
        'IN_PROGRESS' || 'LIVE' || 'IN PROGRESS' => 'AO VIVO',
        'POSTPONED' => 'ADIADO',
        'CANCELLED' || 'CANCELED' => 'CANCELADO',
        _ => 'AGENDADO',
      };
      final hs = score(home), as = score(away);
      out.add(ParsedGame(
        homeTeam: homeName,
        awayTeam: awayName,
        // Jogo ainda não iniciado vem com "0"/vazio: não é placar.
        homeScore: status == 'AGENDADO' ? null : hs,
        awayScore: status == 'AGENDADO' ? null : as,
        status: status,
        competition: competition.isEmpty ? competitionRaw : competition,
        venue: venueName,
        scheduledAt: scheduledAt,
        sourceId: (raw['matchId'] ?? raw['id'] ?? '').toString(),
        competitionId: (raw['competitionId'] ?? '').toString(),
        competitionName: competitionRaw,
        homeTeamId: teamId(home),
        awayTeamId: teamId(away),
        round: (raw['roundNumber'] ?? raw['round'] ?? raw['phaseName'] ?? '').toString(),
      ));
    }
    return out;
  }
}
