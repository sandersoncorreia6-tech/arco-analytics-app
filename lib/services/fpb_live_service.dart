import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../models/fpb_game.dart';

class FpbLiveResult {
  final List<FpbGameSnapshot> games;
  final DateTime fetchedAt;
  final String source;
  final String? warning;

  const FpbLiveResult({required this.games, required this.fetchedAt, required this.source, this.warning});
}

/// Integração desacoplada com a FPB.
///
/// Mobile/desktop: consulta a página pública diretamente.
/// Web: usa /api/fpb-online para evitar bloqueios CORS do navegador.
class FpbLiveService {
  static const onlineUrl = 'https://fpb.com.br/online/';
  static const championshipsUrl = 'https://fpb.com.br/';
  static const _ua = 'ARCO-Analytics/0.5 (+basketball coaching analytics)';
  static const _webProxyBase = String.fromEnvironment('FPB_PROXY_BASE_URL', defaultValue: '');

  Uri _endpoint() {
    if (kIsWeb) {
      if (_webProxyBase.isNotEmpty) {
        final base = _webProxyBase.endsWith('/') ? _webProxyBase : '${_webProxyBase}/';
        return Uri.parse(base).resolve('api/fpb-online');
      }
      return Uri.base.resolve('api/fpb-online');
    }
    return Uri.parse(onlineUrl);
  }

  Future<FpbLiveResult> fetchOnlineGames() async {
    final now = DateTime.now();
    final endpoint = _endpoint();
    String body;
    if (kIsWeb) {
      final response = await http
          .get(endpoint, headers: const {'User-Agent': _ua, 'Accept': 'text/html,application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Fonte FPB respondeu HTTP ${response.statusCode}');
      }
      body = utf8.decode(response.bodyBytes, allowMalformed: true);
    } else {
      final responses = await Future.wait([
        http.get(Uri.parse(onlineUrl), headers: const {'User-Agent': _ua, 'Accept': 'text/html'}).timeout(const Duration(seconds: 12)),
        http.get(Uri.parse(championshipsUrl), headers: const {'User-Agent': _ua, 'Accept': 'text/html'}).timeout(const Duration(seconds: 12)),
      ]);
      final ok = responses.where((r) => r.statusCode >= 200 && r.statusCode < 300).toList();
      if (ok.isEmpty) throw Exception('Fontes FPB indisponíveis');
      body = ok.map((r) => utf8.decode(r.bodyBytes, allowMalformed: true)).join('\n');
    }
    final games = _parsePublicOnlinePage(body, now);
    return FpbLiveResult(
      games: games,
      fetchedAt: now,
      source: kIsWeb ? endpoint.toString() : onlineUrl,
      warning: games.isEmpty
          ? 'A fonte respondeu, mas a estrutura pública não pôde ser interpretada. Para produção, priorize API/feed oficial.'
          : null,
    );
  }

  List<FpbGameSnapshot> _parsePublicOnlinePage(String html, DateTime fetchedAt) {
    final document = html_parser.parse(html);
    final candidates = <String>[];
    const selectors = [
      '[class*="game"]',
      '[class*="match"]',
      '[class*="event"]',
      '[class*="fixture"]',
      '[class*="score"]',
      'article',
      'li',
    ];
    for (final selector in selectors) {
      for (final node in document.querySelectorAll(selector)) {
        final text = _clean(node.text);
        if (text.length >= 12 && text.length <= 700) candidates.add(text);
      }
    }

    for (final script in document.querySelectorAll('script')) {
      final text = script.text;
      if (text.contains('Final') || text.contains('Round') || text.contains('team')) {
        candidates.add(_clean(text));
      }
    }

    final seen = <String>{};
    final result = <FpbGameSnapshot>[];
    for (final raw in candidates) {
      final parsed = _parseCandidate(raw, fetchedAt);
      if (parsed == null) continue;
      final key = '${parsed.homeTeam}|${parsed.awayTeam}|${parsed.scheduledAt?.toIso8601String() ?? ''}';
      if (seen.add(key)) result.add(parsed);
    }

    result.sort((a, b) {
      if (a.isLive != b.isLive) return a.isLive ? -1 : 1;
      final ad = a.scheduledAt ?? DateTime(2100);
      final bd = b.scheduledAt ?? DateTime(2100);
      return ad.compareTo(bd);
    });
    return result;
  }

  FpbGameSnapshot? _parseCandidate(String raw, DateTime fetchedAt) {
    final text = _clean(raw);
    if (text.length < 12) return null;

    final finalPattern = RegExp(r'(.{2,80}?)\s+(\d{1,3})\s+(Final|FINAL|Ao Vivo|AO VIVO|Live|LIVE)?\s*[-x×:]?\s*(.{2,80}?)\s+(\d{1,3})(?:\s|$)');
    final m = finalPattern.firstMatch(text);
    if (m != null) {
      final home = _team(m.group(1)!);
      final away = _team(m.group(4)!);
      if (_validTeam(home) && _validTeam(away)) {
        return FpbGameSnapshot(
          id: _id('$home|$away|${m.group(2)}|${m.group(5)}'),
          homeTeam: home,
          awayTeam: away,
          homeScore: int.tryParse(m.group(2)!),
          awayScore: int.tryParse(m.group(5)!),
          status: (m.group(3) ?? 'EM ANDAMENTO').toUpperCase(),
          competition: _competition(text),
          venue: _venue(text),
          scheduledAt: _dateTime(text, fetchedAt),
          fetchedAt: fetchedAt,
          sourceUrl: onlineUrl,
        );
      }
    }

    final time = RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b|\b([1-9]|1[0-2]):([0-5]\d)\s*(AM|PM)\b', caseSensitive: false).firstMatch(text);
    if (time == null || !text.toLowerCase().contains('round')) return null;
    final beforeRound = text.split(RegExp('round', caseSensitive: false)).first;
    final chunks = beforeRound.split(RegExp(r'\s{2,}|\s+-\s+')).map(_clean).where((e) => e.length > 2).toList();
    if (chunks.length < 2) return null;
    final plausible = chunks.where(_validTeam).toList();
    if (plausible.length < 2) return null;
    final home = plausible[plausible.length - 2];
    final away = plausible.last;
    return FpbGameSnapshot(
      id: _id('$home|$away|$text'),
      homeTeam: home,
      awayTeam: away,
      competition: _competition(text),
      venue: _venue(text),
      status: 'AGENDADO',
      scheduledAt: _dateTime(text, fetchedAt),
      fetchedAt: fetchedAt,
      sourceUrl: onlineUrl,
    );
  }

  String _clean(String input) => input.replaceAll(RegExp(r'\s+'), ' ').trim();
  String _team(String input) => _clean(input).replaceAll(RegExp(r'^[\W\d_]+|[\W\d_]+$'), '').trim();
  bool _validTeam(String s) => s.length >= 3 && s.length <= 80 && RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(s) && !RegExp(r'^(round|final|online|estatísticas?)$', caseSensitive: false).hasMatch(s);
  String _competition(String text) => RegExp(r'\b(SUB\s*\d{2}\s*[MF]|S\d{2}[MF]|DEM\d?|DEF|NBB)\b', caseSensitive: false).firstMatch(text)?.group(0)?.toUpperCase() ?? '';
  String _venue(String text) => '';

  DateTime? _dateTime(String text, DateTime reference) {
    final iso = RegExp(r'\b(20\d{2})[-/](\d{1,2})[-/](\d{1,2})\b').firstMatch(text);
    if (iso != null) {
      return DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
    }
    final br = RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(20\d{2}))?\b').firstMatch(text);
    if (br != null) {
      return DateTime(int.parse(br.group(3) ?? '${reference.year}'), int.parse(br.group(2)!), int.parse(br.group(1)!));
    }
    return null;
  }

  String _id(String s) {
    var hash = 0x811c9dc5;
    for (final c in s.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return 'fpb_$hash';
  }
}
