import 'dart:convert';

import 'package:arco_analytics/data/providers/fpb_provider.dart';
import 'package:arco_analytics/models/coach_profile.dart';
import 'package:arco_analytics/services/league_sync_service.dart';
import 'package:arco_analytics/services/source_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _rsc = r'''0:{"a":"$@1","f":""}
1:[{"matchId":"m-77","competitionId":"323cc7a9-ee0b-11ee-8350-435475889b11","matchStatus":"COMPLETE","matchTime":"2026-03-17T19:00:00","competitionName":"SUB 16M 2026","roundNumber":"3","venue":{"venueName":"Ginásio Elias Kenayfes"},"competitors":[{"isHomeCompetitor":1,"teamId":"t1","teamName":"F.R. TUPÃ","scoreString":"72"},{"isHomeCompetitor":0,"teamId":"t2","teamName":"SÃO JOSÉ DOS CAMPOS BASKETBALL","scoreString":"61"}]},{"matchId":"m-78","matchStatus":"SCHEDULED","matchTime":"2026-11-07T15:00:00","competitionName":"SUB 16M 2026","competitors":[{"isHomeCompetitor":1,"teamName":"PAULISTANO","scoreString":"0"},{"isHomeCompetitor":0,"teamName":"F.R. TUPÃ","scoreString":"0"}]}]''';

void main() {
  test('partida estruturada vira registro com ids oficiais', () {
    final games = FpbProvider.parseSchedule(_rsc);
    expect(games, hasLength(2));
    expect(games.last.homeScore, isNull); // agendado: "0" não é placar
    final service = LeagueSyncService(LeagueSource.fpb);
    final g = service.toLeagueGame(games.first, fetchedAt: DateTime(2026, 10, 22), sourceUrl: LeagueSource.fpb.officialUrl);
    expect(g.id, 'fpb_mm-77');
    expect(g.competitionId, 'fpb_c323cc7a9-ee0b-11ee-8350-435475889b11');
    expect(g.competitionName, 'SUB 16M 2026');
    expect(g.seasonId, '2026');
    expect(g.categoryId, 'sub16m');
    expect(g.round, '3');
    expect(g.homeTeamId, 'fpb_tt1');
    expect(CoachProfile.adrianoMiao.isMyGame(g), isTrue);
  });

  test('busca o calendário e redescobre a consulta quando a CBB muda o site', () async {
    final posts = <String>[];
    final client = MockClient((req) async {
      if (req.method == 'POST') {
        final action = req.headers['Next-Action']!;
        posts.add(action);
        expect(jsonDecode(req.body)[0]['org'], 'fpb');
        return action == 'abcdef0123456789abcdef0123456789ab'
            ? http.Response.bytes(utf8.encode(_rsc), 200)
            : http.Response('not found', 404);
      }
      if (req.url.path == '/calendario') {
        return http.Response('<script src="/_next/static/chunks/app/calendario/page-1.js"></script>', 200);
      }
      return http.Response('x({"abcdef0123456789abcdef0123456789ab":0}); export const getMatchesByRange = 1;', 200);
    });
    FpbProvider.scheduleAction = 'acaoantiga';
    final provider = FpbProvider(fetcher: SourceFetcher(client: client));
    final result = await provider.fetchSchedules(season: 2026);
    expect(result.single.attempt.ok, isTrue);
    expect(result.single.games, hasLength(2));
    expect(posts, ['acaoantiga', 'abcdef0123456789abcdef0123456789ab']);
    expect(FpbProvider.scheduleAction, 'abcdef0123456789abcdef0123456789ab');
  });

  test('competição informada pelo treinador (link/UUID) é usada', () async {
    final asked = <String>[];
    final client = MockClient((req) async {
      asked.add(jsonDecode(req.body)[0]['competitionId'] as String);
      return http.Response.bytes(utf8.encode(_rsc), 200);
    });
    FpbProvider.scheduleAction = 'qualquer';
    final provider = FpbProvider(fetcher: SourceFetcher(client: client));
    await provider.fetchSchedules(season: 2026, competitionIds: ['https://fpb.com.br/online/?c=AAAAAAAA-1111-2222-3333-444444444444']);
    expect(asked, ['aaaaaaaa-1111-2222-3333-444444444444']);
  });
}
