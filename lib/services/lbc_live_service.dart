import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../models/lbc_game.dart';

class LbcLiveResult {
  final List<LbcGameSnapshot> games;
  final DateTime fetchedAt;
  final String source;
  final String? warning;
  const LbcLiveResult({required this.games, required this.fetchedAt, required this.source, this.warning});
}

/// Conector desacoplado da Liga de Basquete do Centro-Oeste Paulista.
/// A fonte pode ser substituída por feed/API oficial sem alterar as telas.
class LbcLiveService {
  static const officialUrl = 'https://www.lbc.org.br/';
  static const _webProxyBase = String.fromEnvironment('LBC_PROXY_BASE_URL', defaultValue: '');

  Uri _endpoint() {
    if (kIsWeb) {
      if (_webProxyBase.isNotEmpty) {
        final base = _webProxyBase.endsWith('/') ? _webProxyBase : '${_webProxyBase}/';
        return Uri.parse(base).resolve('api/lbc-online');
      }
      return Uri.base.resolve('api/lbc-online');
    }
    return Uri.parse(officialUrl);
  }

  Future<LbcLiveResult> fetchGames() async {
    final now = DateTime.now();
    final endpoint = _endpoint();
    final response = await http.get(endpoint, headers: const {
      'User-Agent': 'ARCO-Analytics/0.5',
      'Accept': 'text/html,application/json',
    }).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Fonte LBC respondeu HTTP ${response.statusCode}');
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final games = _parse(body, now);
    return LbcLiveResult(
      games: games,
      fetchedAt: now,
      source: endpoint.toString(),
      warning: games.isEmpty ? 'A LBC respondeu, mas a agenda pública não pôde ser interpretada automaticamente.' : null,
    );
  }

  List<LbcGameSnapshot> _parse(String html, DateTime fetchedAt) {
    final doc = html_parser.parse(html);
    final texts = <String>[];
    for (final selector in ['[class*="game"]','[class*="jogo"]','[class*="match"]','[class*="event"]','article','li','tr']) {
      for (final node in doc.querySelectorAll(selector)) {
        final t = node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (t.length >= 10 && t.length < 700) texts.add(t);
      }
    }
    final out = <LbcGameSnapshot>[];
    final seen = <String>{};
    for (final text in texts) {
      final teams = RegExp(r'([A-Za-zÀ-ÿ0-9 .\-/]{3,60})\s+(?:x|×|X)\s+([A-Za-zÀ-ÿ0-9 .\-/]{3,60})').firstMatch(text);
      if (teams == null) continue;
      final home = teams.group(1)!.trim();
      final away = teams.group(2)!.trim();
      final key = '$home|$away|$text';
      if (!seen.add(key)) continue;
      final score = RegExp(r'\b(\d{1,3})\s*(?:x|×|X)\s*(\d{1,3})\b').firstMatch(text);
      out.add(LbcGameSnapshot(
        id: 'lbc_${key.hashCode.abs()}',
        homeTeam: home,
        awayTeam: away,
        homeScore: score == null ? null : int.tryParse(score.group(1)!),
        awayScore: score == null ? null : int.tryParse(score.group(2)!),
        competition: _competition(text),
        status: score == null ? 'AGENDADO' : 'FINAL',
        scheduledAt: _date(text, fetchedAt),
        fetchedAt: fetchedAt,
        sourceUrl: officialUrl,
      ));
    }
    return out;
  }

  String _competition(String text) {
    final m = RegExp(r'\b(?:SUB\s*[- ]?\d{2}|S\d{2})\s*[MF]?\b|\bADULTO\s*[MF]?\b|\bMASTER\b', caseSensitive: false).firstMatch(text);
    return m?.group(0)?.toUpperCase() ?? '';
  }

  DateTime? _date(String text, DateTime ref) {
    final br = RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(20\d{2}))?\b').firstMatch(text);
    if (br == null) return null;
    return DateTime(int.parse(br.group(3) ?? '${ref.year}'), int.parse(br.group(2)!), int.parse(br.group(1)!));
  }
}
