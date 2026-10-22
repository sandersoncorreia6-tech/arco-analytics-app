import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cloud_config.dart';

class CloudException implements Exception {
  final String message;
  final int? status;
  const CloudException(this.message, {this.status});

  /// Falhas temporárias (sem internet, servidor fora): o envio é refeito depois.
  bool get retryable => status == null || status == 401 || status == 408 || status == 429 || status! >= 500;

  @override
  String toString() => message;
}

/// Sessão do usuário autenticado.
class CloudSession {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String userId;
  final String email;
  final String name;
  const CloudSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
    required this.email,
    this.name = '',
  });

  bool get expiringSoon => DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 2)));

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.toIso8601String(),
        'user_id': userId,
        'email': email,
        'name': name,
      };

  factory CloudSession.fromJson(Map<String, dynamic> m) => CloudSession(
        accessToken: m['access_token'] as String,
        refreshToken: m['refresh_token'] as String,
        expiresAt: DateTime.tryParse(m['expires_at'] as String? ?? '') ?? DateTime.now(),
        userId: m['user_id'] as String,
        email: (m['email'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
      );

  /// Resposta do endpoint de token do Supabase Auth.
  factory CloudSession.fromAuth(Map<String, dynamic> m) {
    final user = (m['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final meta = (user['user_metadata'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CloudSession(
      accessToken: m['access_token'] as String,
      refreshToken: m['refresh_token'] as String,
      expiresAt: DateTime.now().add(Duration(seconds: (m['expires_in'] as num?)?.toInt() ?? 3600)),
      userId: user['id'] as String,
      email: (user['email'] as String?) ?? '',
      name: (meta['full_name'] as String?) ?? '',
    );
  }
}

/// Acesso ao Supabase pela API REST oficial (Auth + PostgREST), sem SDK.
/// A segurança dos dados vem das regras RLS do banco (cada clube isolado).
class CloudApi {
  CloudApi(this.config, {http.Client? client}) : _client = client ?? http.Client();

  final CloudConfig config;
  final http.Client _client;
  static const _timeout = Duration(seconds: 20);

  Map<String, String> _headers([String? token]) => {
        'apikey': config.anonKey,
        'Authorization': 'Bearer ${token ?? config.anonKey}',
        'Content-Type': 'application/json',
      };

  Future<dynamic> _send(Future<http.Response> Function() call) async {
    http.Response r;
    try {
      r = await call().timeout(_timeout);
    } on TimeoutException {
      throw const CloudException('A nuvem não respondeu. Os dados ficam salvos no aparelho e serão enviados depois.');
    } catch (_) {
      throw const CloudException('Sem conexão com a nuvem. Os dados ficam salvos no aparelho e serão enviados depois.');
    }
    final body = r.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes, allowMalformed: true));
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final msg = body is Map ? (body['msg'] ?? body['error_description'] ?? body['message'] ?? body['error'] ?? '').toString() : '';
    throw CloudException(_translate(msg, r.statusCode), status: r.statusCode);
  }

  static String _translate(String msg, int status) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid_grant')) return 'E-mail ou senha incorretos.';
    if (m.contains('already registered') || m.contains('already exists')) return 'Este e-mail já tem cadastro. Use "Entrar" ou "Esqueci a senha".';
    if (m.contains('email not confirmed')) return 'Confirme o e-mail pelo link enviado antes de entrar.';
    if (m.contains('password') && m.contains('characters')) return 'A senha precisa ter pelo menos 6 caracteres.';
    if (m.contains('row-level security') || status == 403) return 'Sem permissão para estes dados (clube bloqueado, fora do período de teste ou papel sem acesso).';
    return msg.isEmpty ? 'A nuvem respondeu com erro $status.' : msg;
  }

  // ------------------------------------------------------------- Auth

  Future<CloudSession> signIn(String email, String password) async => CloudSession.fromAuth(
        (await _send(() => _client.post(config.auth('token', {'grant_type': 'password'}),
            headers: _headers(), body: jsonEncode({'email': email.trim(), 'password': password})))) as Map<String, dynamic>,
      );

  /// Cria a conta. Retorna a sessão quando o projeto não exige confirmar e-mail;
  /// `null` quando o usuário precisa clicar no link enviado.
  Future<CloudSession?> signUp(String email, String password, String name) async {
    final res = await _send(() => _client.post(config.auth('signup'),
        headers: _headers(), body: jsonEncode({'email': email.trim(), 'password': password, 'data': {'full_name': name.trim()}})));
    if (res is Map && res['access_token'] != null) return CloudSession.fromAuth(res.cast<String, dynamic>());
    return null;
  }

  Future<void> recoverPassword(String email) =>
      _send(() => _client.post(config.auth('recover'), headers: _headers(), body: jsonEncode({'email': email.trim()})));

  Future<CloudSession> refresh(CloudSession s) async => CloudSession.fromAuth(
        (await _send(() => _client.post(config.auth('token', {'grant_type': 'refresh_token'}),
            headers: _headers(), body: jsonEncode({'refresh_token': s.refreshToken})))) as Map<String, dynamic>,
      );

  Future<void> signOut(CloudSession s) async {
    try {
      await _send(() => _client.post(config.auth('logout'), headers: _headers(s.accessToken)));
    } catch (_) {
      // Sair localmente mesmo sem internet.
    }
  }

  // ------------------------------------------------------------- Dados (PostgREST)

  Future<List<Map<String, dynamic>>> select(CloudSession s, String table, Map<String, String> query) async {
    final res = await _send(() => _client.get(config.rest(table, query), headers: _headers(s.accessToken)));
    return (res as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Insere ou atualiza (upsert) pelas colunas únicas [onConflict].
  Future<List<Map<String, dynamic>>> upsert(CloudSession s, String table, List<Map<String, dynamic>> rows, {String? onConflict}) async {
    final res = await _send(() => _client.post(
          config.rest(table, {if (onConflict != null) 'on_conflict': onConflict}),
          headers: {
            ..._headers(s.accessToken),
            'Prefer': '${onConflict != null ? 'resolution=merge-duplicates,' : ''}return=representation',
          },
          body: jsonEncode(rows),
        ));
    return res is List ? res.map((e) => (e as Map).cast<String, dynamic>()).toList() : const [];
  }
}
