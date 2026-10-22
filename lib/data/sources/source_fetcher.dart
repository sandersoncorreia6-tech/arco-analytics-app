import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Falha ao consultar uma fonte externa, com mensagem pronta para o treinador.
class SourceFetchException implements Exception {
  final String message;
  final int? statusCode;
  const SourceFetchException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class FetchedPage {
  final Uri url;
  final int statusCode;
  final String body;
  final Duration elapsed;
  const FetchedPage({required this.url, required this.statusCode, required this.body, required this.elapsed});
}

/// GET com timeout, nova tentativa em falhas transitórias e erros traduzidos.
class SourceFetcher {
  SourceFetcher({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const timeout = Duration(seconds: 15);

  // Alguns sites/firewalls recusam user-agents desconhecidos; no app nativo
  // nos identificamos como um navegador móvel comum. No navegador o
  // user-agent é do próprio browser (cabeçalhos extras forçariam preflight CORS).
  static const _nativeHeaders = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Mobile Safari/537.36 ARCO-Analytics/0.7',
    'Accept': 'text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8',
    'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.6',
  };

  Map<String, String>? _headers(Map<String, String>? extra) {
    if (kIsWeb) return extra;
    return {..._nativeHeaders, ...?extra};
  }

  Future<FetchedPage> get(Uri url, {int retries = 1}) => _request(
    url,
    retries: retries,
    send: () => _client.get(url, headers: kIsWeb ? null : _nativeHeaders),
  );

  /// POST textual usado por fontes estruturadas que publicam o calendário por
  /// ação HTTP (ex.: o Schedule da FPB/CBB). Na Web o app usa o proxy /api,
  /// evitando CORS; no app nativo a chamada é direta.
  Future<FetchedPage> post(Uri url, {Map<String, String>? headers, Object? body, int retries = 1}) => _request(
    url,
    retries: retries,
    send: () => _client.post(url, headers: _headers(headers), body: body),
  );

  Future<FetchedPage> _request(Uri url, {required Future<http.Response> Function() send, int retries = 1}) async {
    Object? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      if (attempt > 0) await Future<void>.delayed(Duration(milliseconds: 1500 * attempt));
      final watch = Stopwatch()..start();
      http.Response response;
      try {
        response = await send().timeout(timeout);
      } catch (e) {
        lastError = e;
        continue;
      }
      final code = response.statusCode;
      if (code >= 200 && code < 300) {
        return FetchedPage(url: url, statusCode: code, body: utf8.decode(response.bodyBytes, allowMalformed: true), elapsed: watch.elapsed);
      }
      final error = SourceFetchException(httpMessage(code), statusCode: code);
      if (code != 429 && code < 500) throw error;
      lastError = error;
    }
    if (lastError is SourceFetchException) throw lastError;
    throw SourceFetchException(describe(lastError));
  }

  static String httpMessage(int code) {
    switch (code) {
      case 401:
      case 403:
        return 'O site recusou o acesso automático (HTTP $code).';
      case 404:
        return 'Página não encontrada (HTTP 404). O endereço da fonte pode ter mudado.';
      case 429:
        return 'Muitas consultas seguidas (HTTP 429). Aguarde alguns minutos.';
      default:
        return code >= 500 ? 'O site da fonte está instável (HTTP $code).' : 'A fonte respondeu HTTP $code.';
    }
  }

  /// Traduz exceções de rede (dart:io / navegador) sem depender de dart:io,
  /// para o mesmo código compilar no Android, iOS, desktop e Web.
  static String describe(Object? error) {
    if (error == null) return 'Falha desconhecida ao acessar a fonte.';
    if (error is SourceFetchException) return error.message;
    if (error is TimeoutException) return 'Tempo esgotado: a fonte não respondeu em ${timeout.inSeconds} s.';
    final s = error.toString();
    bool has(String p) => s.toLowerCase().contains(p.toLowerCase());
    if (has('HandshakeException') || has('CERTIFICATE') || has('TlsException')) {
      return 'Falha de segurança (certificado SSL). Confira data/hora do aparelho; aparelhos com Android muito antigo podem não reconhecer o certificado do site.';
    }
    if (has('Failed host lookup') ||
        has('No address associated') ||
        has('Network is unreachable') ||
        has('SocketException') ||
        has('Connection refused') ||
        has('Connection reset') ||
        has('Connection closed') ||
        has('Software caused connection abort')) {
      return 'Sem conexão com a fonte. Verifique a internet do aparelho (Wi-Fi/dados móveis).';
    }
    if (kIsWeb && (has('XMLHttpRequest') || has('Failed to fetch') || has('ClientException'))) {
      return 'O navegador bloqueou o acesso (CORS). A versão Web precisa do proxy /api publicado (Vercel) ou de ARCO_PROXY_BASE_URL.';
    }
    return 'Falha ao acessar a fonte: $s';
  }
}
