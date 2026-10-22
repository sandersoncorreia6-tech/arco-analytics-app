import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/league_game.dart';
import 'fiba_livestats.dart';
import 'schedule_parser.dart';
import 'source_fetcher.dart';

/// Configuração de uma competição externa.
class LeagueSource {
  final String league;
  final String name;
  final String officialUrl;

  /// Páginas públicas consultadas diretamente pelo app nativo.
  final List<String> pages;

  /// Proxy serverless usado na versão Web (o navegador bloqueia CORS).
  final String proxyPath;

  /// Domínio aceito para páginas extras configuradas pelo treinador.
  final String host;

  const LeagueSource({
    required this.league,
    required this.name,
    required this.officialUrl,
    required this.pages,
    required this.proxyPath,
    required this.host,
  });

  static const fpb = LeagueSource(
    league: 'FPB',
    name: 'Federação Paulista de Basketball',
    officialUrl: 'https://fpb.com.br/online/',
    pages: [
      'https://fpb.com.br/online/',
      'https://fpb.com.br/',
      // Notícias de programação/resultados da base (um jogo por linha) via API pública do WordPress.
      'https://fpb.com.br/wp-json/wp/v2/posts?per_page=12&search=jogos&_fields=date,link,title,content',
    ],
    proxyPath: 'api/fpb-online',
    host: 'fpb.com.br',
  );

  static const lbc = LeagueSource(
    league: 'LBC',
    name: 'Liga de Basquete do Centro-Oeste Paulista',
    officialUrl: 'https://www.lbc.org.br/',
    pages: ['https://www.lbc.org.br/'],
    proxyPath: 'api/lbc-online',
    host: 'lbc.org.br',
  );

  bool isLeagueHost(Uri uri) => (uri.scheme == 'https' || uri.scheme == 'http') && (uri.host == host || uri.host.endsWith('.$host'));

  /// Páginas extras: no app nativo, qualquer site (ex.: o endereço real da LBC,
  /// uma página da prefeitura); na Web, só o domínio da liga (limite do proxy).
  bool acceptsUrl(Uri uri) => kIsWeb ? isLeagueHost(uri) : (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.contains('.');
}

/// Resultado de uma página consultada, para o diagnóstico de conexão.
class SourceAttempt {
  final String url;
  final bool ok;
  final int? statusCode;
  final int bytes;
  final Duration? elapsed;
  final int gamesFound;
  final String? error;

  const SourceAttempt({
    required this.url,
    required this.ok,
    this.statusCode,
    this.bytes = 0,
    this.elapsed,
    this.gamesFound = 0,
    this.error,
  });
}

/// Nenhuma página da liga respondeu; [attempts] traz o detalhe de cada uma.
class LeagueSyncException extends SourceFetchException {
  final List<SourceAttempt> attempts;
  const LeagueSyncException(super.message, this.attempts);
}

class LeagueSyncResult {
  final List<LeagueGame> games;
  final DateTime fetchedAt;
  final List<SourceAttempt> attempts;

  /// Aviso quando a fonte respondeu mas nada foi interpretado.
  final String? warning;

  /// Partidas com estatística online (FIBA LiveStats) citadas nas páginas.
  final Set<String> matchIds;

  const LeagueSyncResult({required this.games, required this.fetchedAt, required this.attempts, this.warning, this.matchIds = const {}});
}

/// Coleta e interpreta os jogos de uma [LeagueSource].
///
/// Para trocar por uma API oficial/licenciada no futuro, basta outra classe
/// que devolva [LeagueSyncResult]: telas e analytics não mudam.
class LeagueSyncService {
  LeagueSyncService(this.source, {SourceFetcher? fetcher}) : _fetcher = fetcher ?? SourceFetcher();

  final LeagueSource source;
  final SourceFetcher _fetcher;

  static const _proxyBase = String.fromEnvironment('ARCO_PROXY_BASE_URL');
  static const _legacyFpbProxy = String.fromEnvironment('FPB_PROXY_BASE_URL');
  static const _legacyLbcProxy = String.fromEnvironment('LBC_PROXY_BASE_URL');

  Uri _proxyUri([String? pageUrl]) {
    var base = _proxyBase;
    if (base.isEmpty) base = source.league == 'FPB' ? _legacyFpbProxy : _legacyLbcProxy;
    final root = base.isEmpty ? Uri.base : Uri.parse(base.endsWith('/') ? base : '$base/');
    final uri = root.resolve(source.proxyPath);
    return pageUrl == null ? uri : uri.replace(queryParameters: {'url': pageUrl});
  }

  /// Endereços consultados nesta plataforma (Web passa pelo proxy).
  List<Uri> endpoints({List<String> extraPages = const []}) {
    final extras = extraPages.map(Uri.tryParse).whereType<Uri>().where(source.acceptsUrl).toList();
    if (kIsWeb) return [_proxyUri(), for (final e in extras) _proxyUri(e.toString())];
    return [for (final p in source.pages) Uri.parse(p), ...extras];
  }

  Future<LeagueSyncResult> fetch({List<String> extraPages = const []}) async {
    final now = DateTime.now();
    final targets = endpoints(extraPages: extraPages);
    final matchIds = <String>{};

    final attempts = await Future.wait(targets.map((uri) async {
      try {
        final page = await _fetcher.get(uri);
        final (parsed, ids) = parsePage(page.body, now);
        matchIds.addAll(ids);
        return (
          SourceAttempt(
            url: uri.toString(),
            ok: true,
            statusCode: page.statusCode,
            bytes: page.body.length,
            elapsed: page.elapsed,
            gamesFound: parsed.length,
          ),
          parsed,
        );
      } catch (e) {
        final code = e is SourceFetchException ? e.statusCode : null;
        return (
          SourceAttempt(
            url: uri.toString(),
            ok: false,
            statusCode: code,
            // Na Web, 404/405 vem do servidor do próprio app: o proxy /api não foi publicado.
            error: kIsWeb && (code == 404 || code == 405)
                ? 'Proxy ${source.proxyPath} não encontrado neste site. Publique a pasta api/ na Vercel '
                    'ou gere a Web com ARCO_PROXY_BASE_URL. Enquanto isso, use "Colar jogos".'
                : SourceFetcher.describe(e),
          ),
          const <ParsedGame>[],
        );
      }
    }));

    final ok = attempts.where((a) => a.$1.ok).toList();
    if (ok.isEmpty) {
      throw LeagueSyncException(
        attempts.first.$1.error ?? 'Fonte ${source.league} indisponível.',
        [for (final a in attempts) a.$1],
      );
    }

    final byId = <String, LeagueGame>{};
    for (final (_, parsed) in ok) {
      for (final g in parsed) {
        final game = toLeagueGame(g, fetchedAt: now, sourceUrl: source.officialUrl);
        byId.putIfAbsent(game.id, () => game);
      }
    }

    return LeagueSyncResult(
      games: byId.values.toList(),
      fetchedAt: now,
      matchIds: matchIds,
      attempts: [for (final a in attempts) a.$1],
      warning: byId.isEmpty && matchIds.isEmpty
          ? 'O site da ${source.league} respondeu, mas nenhum jogo foi reconhecido na página. '
              'Use "Colar jogos" ou cadastre a página exata da agenda em "Fontes".'
          : null,
    );
  }

  /// Interpreta uma resposta: página HTML ou lista de notícias JSON do WordPress.
  /// Devolve os jogos e os ids de partidas com estatística online.
  static (List<ParsedGame>, Set<String>) parsePage(String body, DateTime now) {
    final trimmed = body.trimLeft();
    if (trimmed.startsWith('[')) {
      try {
        final posts = jsonDecode(trimmed) as List;
        final games = <ParsedGame>[];
        final ids = <String>{};
        for (final post in posts.whereType<Map>()) {
          final content = post['content'];
          final html = content is Map ? (content['rendered'] ?? '').toString() : '';
          final published = DateTime.tryParse((post['date'] ?? '').toString()) ?? now;
          games.addAll(ScheduleParser(reference: published).parseArticleHtml(html));
          ids.addAll(FibaLiveStats.findMatchIds(html));
        }
        return (games, ids);
      } catch (_) {
        // Não era JSON do WordPress; segue como HTML.
      }
    }
    return (ScheduleParser(reference: now).parseHtml(body), FibaLiveStats.findMatchIds(body));
  }

  /// Interpreta texto colado pelo treinador (copiado do site, planilha ou WhatsApp).
  List<LeagueGame> parsePasted(String text) {
    final now = DateTime.now();
    return ScheduleParser(reference: now)
        .parseText(text)
        .map((g) => toLeagueGame(g, fetchedAt: now, sourceUrl: source.officialUrl, manual: true))
        .toList();
  }

  LeagueGame toLeagueGame(ParsedGame g, {required DateTime fetchedAt, required String sourceUrl, bool manual = false}) {
    final d = g.scheduledAt;
    final day = d == null ? '' : '${d.year}-${d.month}-${d.day}';
    return LeagueGame(
      id: ScheduleParser.stableId(source.league, [g.competition, g.homeTeam, g.awayTeam, day]),
      league: source.league,
      homeTeam: g.homeTeam,
      awayTeam: g.awayTeam,
      homeScore: g.homeScore,
      awayScore: g.awayScore,
      competition: g.competition,
      venue: g.venue,
      status: g.status,
      scheduledAt: g.scheduledAt,
      fetchedAt: fetchedAt,
      sourceUrl: sourceUrl,
      manual: manual,
    );
  }
}
