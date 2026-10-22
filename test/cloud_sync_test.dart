import 'dart:convert';

import 'package:arco_analytics/data/cloud/cloud_api.dart';
import 'package:arco_analytics/data/cloud/cloud_config.dart';
import 'package:arco_analytics/data/cloud/cloud_mapper.dart';
import 'package:arco_analytics/data/cloud/cloud_sync.dart';
import 'package:arco_analytics/data/mock_repository.dart';
import 'package:arco_analytics/models/coach_profile.dart';
import 'package:arco_analytics/models/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const config = CloudConfig('https://arco-test.supabase.co', 'anon-key-0123456789abcdefghij');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sem configuração o app fica no modo local', () {
    expect(const CloudConfig('', '').enabled, isFalse);
    expect(config.enabled, isTrue);
  });

  test('login, clube e envio da fila com queda de conexão', () async {
    var online = false;
    final upserts = <Map<String, dynamic>>[];
    final client = MockClient((req) async {
      expect(req.headers['apikey'], config.anonKey);
      if (req.url.path == '/auth/v1/token') {
        expect(req.url.queryParameters['grant_type'], 'password');
        expect(jsonDecode(req.body)['email'], 'adriano@tupa.com');
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'access_token': 'tok',
            'refresh_token': 'ref',
            'expires_in': 3600,
            'user': {'id': 'u1', 'email': 'adriano@tupa.com', 'user_metadata': {'full_name': 'Adriano Mião'}},
          })),
          200,
        );
      }
      expect(req.headers['Authorization'], 'Bearer tok');
      if (req.url.path == '/rest/v1/club_members') {
        expect(req.url.queryParameters['user_id'], 'eq.u1');
        return http.Response.bytes(
            utf8.encode(jsonEncode([
              {'club_id': 'c1', 'role': 'owner', 'clubs': {'id': 'c1', 'name': 'Tupã / Monstrinho', 'city': 'Tupã', 'status': 'trial'}},
            ])),
            200);
      }
      if (req.url.path == '/rest/v1/teams') {
        return http.Response.bytes(utf8.encode(jsonEncode([{'id': 't1', 'name': 'Tupã Sub-16', 'category': 'SUB 16 M'}])), 200);
      }
      if (req.url.path == '/rest/v1/games') {
        if (!online) throw http.ClientException('Failed host lookup');
        expect(req.url.queryParameters['on_conflict'], 'club_id,source,external_id');
        expect(req.headers['Prefer'], contains('resolution=merge-duplicates'));
        upserts.addAll((jsonDecode(req.body) as List).cast<Map<String, dynamic>>());
        return http.Response('[]', 201);
      }
      return http.Response('not found', 404);
    });

    final sync = CloudSync(config, api: CloudApi(config, client: client));
    await sync.signIn('adriano@tupa.com', 'segredo');
    expect(sync.session!.name, 'Adriano Mião');
    expect(sync.club!.clubName, 'Tupã / Monstrinho');
    expect(sync.club!.teamId, 't1');
    expect(sync.club!.canWrite, isTrue);

    // Scout ao vivo: os retratos do mesmo jogo se substituem na fila.
    await sync.enqueue('game:scout:s1', 'games', 'club_id,source,external_id', {'external_id': 's1', 'our_score': 2});
    await sync.enqueue('game:scout:s1', 'games', 'club_id,source,external_id', {'external_id': 's1', 'our_score': 5});
    await sync.enqueue('game:scout:s2', 'games', 'club_id,source,external_id', {'external_id': 's2', 'our_score': 1});
    expect(sync.outbox, hasLength(2));

    // Ginásio sem internet: nada se perde.
    expect(await sync.flush(), 0);
    expect(sync.outbox, hasLength(2));
    expect(sync.lastError, contains('salvos no aparelho'));

    // Fila sobrevive a fechar o app.
    final restored = CloudSync(config, api: CloudApi(config, client: client))..restore(await SharedPreferences.getInstance());
    expect(restored.outbox, hasLength(2));
    expect(restored.club!.clubId, 'c1');

    online = true;
    expect(await restored.flush(), 2);
    expect(restored.outbox, isEmpty);
    expect(upserts.map((r) => r['our_score']), [5, 1]);
    expect(upserts.every((r) => r['club_id'] == 'c1'), isTrue);
  });

  test('mensagens de erro de login em português', () async {
    final client = MockClient((_) async => http.Response(jsonEncode({'error': 'invalid_grant', 'error_description': 'Invalid login credentials'}), 400));
    final sync = CloudSync(config, api: CloudApi(config, client: client));
    expect(() => sync.signIn('x@y.com', 'errada'), throwsA(isA<CloudException>().having((e) => e.message, 'message', 'E-mail ou senha incorretos.')));
  });

  test('jogo do scout vai para a nuvem com todos os eventos e volta igual', () {
    final g = Game.fromJson(MockRepository.games.first.toJson());
    final row = CloudMapper.scoutGame(g, 'scout_1', CoachProfile.adrianoMiao, 't1', videoUrl: 'https://youtu.be/x', videoOffset: 200);
    expect(row['source'], 'scout');
    expect(row['video_offset_seconds'], 200);
    final back = Game.fromJson(((row['box_score'] as Map)['arcoGame'] as Map).cast<String, dynamic>());
    expect(back.opponent, g.opponent);
    expect(back.ourScore, g.ourScore);
    expect(CloudSync.stableUuid('c1/athlete/p1'), CloudSync.stableUuid('c1/athlete/p1'));
    expect(CloudSync.stableUuid('c1/athlete/p1'), isNot(CloudSync.stableUuid('c2/athlete/p1')));
  });
}
