import 'package:flutter/foundation.dart';

import '../models/box_score.dart';
import 'fiba_livestats.dart';
import 'source_fetcher.dart';

/// Baixa as estatísticas completas de partidas (FIBA LiveStats).
class StatsSyncService {
  StatsSyncService({SourceFetcher? fetcher}) : _fetcher = fetcher ?? SourceFetcher();

  final SourceFetcher _fetcher;

  static const _proxyBase = String.fromEnvironment('ARCO_PROXY_BASE_URL');

  Uri endpoint(String matchId) {
    if (!kIsWeb) return FibaLiveStats.dataUrl(matchId);
    final root = _proxyBase.isEmpty ? Uri.base : Uri.parse(_proxyBase.endsWith('/') ? _proxyBase : '$_proxyBase/');
    return root.resolve('api/livestats').replace(queryParameters: {'id': matchId});
  }

  Future<GameBoxScore> fetch(String matchId, {required String league}) async {
    final page = await _fetcher.get(endpoint(matchId));
    try {
      return FibaLiveStats.parse(page.body, matchId: matchId, league: league);
    } on FormatException catch (e) {
      throw SourceFetchException('A partida $matchId não tem estatísticas disponíveis (${e.message})');
    }
  }

  /// Baixa várias partidas com no máximo [parallel] requisições simultâneas.
  Future<Map<String, Object>> fetchMany(Map<String, String> idsToLeague, {int parallel = 4}) async {
    final results = <String, Object>{};
    final queue = idsToLeague.entries.toList();
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final next = queue.removeLast();
        try {
          results[next.key] = await fetch(next.key, league: next.value);
        } catch (e) {
          results[next.key] = SourceFetcher.describe(e);
        }
      }
    }

    await Future.wait(List.generate(parallel, (_) => worker()));
    return results;
  }
}
