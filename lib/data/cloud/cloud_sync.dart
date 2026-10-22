import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:arco_analytics/data/cloud/cloud_api.dart';
import 'package:arco_analytics/data/cloud/cloud_config.dart';

/// Operação pendente de envio. Operações com a mesma [key] se substituem
/// (ex.: o scout ao vivo manda só o retrato mais recente).
class OutboxOp {
  final String key;
  final String table;
  final String onConflict;
  final Map<String, dynamic> row;
  final DateTime createdAt;
  int attempts;
  OutboxOp({required this.key, required this.table, required this.onConflict, required this.row, DateTime? createdAt, this.attempts = 0})
    : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {'k': key, 't': table, 'c': onConflict, 'r': row, 'at': createdAt.toIso8601String(), 'n': attempts};
  factory OutboxOp.fromJson(Map<String, dynamic> m) => OutboxOp(
    key: m['k'] as String,
    table: m['t'] as String,
    onConflict: m['c'] as String,
    row: (m['r'] as Map).cast<String, dynamic>(),
    createdAt: DateTime.tryParse(m['at'] as String? ?? ''),
    attempts: (m['n'] as num?)?.toInt() ?? 0,
  );
}

/// Clube/equipe ativos do usuário na nuvem.
class CloudClub {
  final String clubId;
  final String clubName;
  final String city;
  final String role;
  final String status;
  final String teamId;
  final String teamName;
  final String category;
  const CloudClub({
    required this.clubId,
    required this.clubName,
    this.city = '',
    this.role = 'coach',
    this.status = 'trial',
    this.teamId = '',
    this.teamName = '',
    this.category = '',
  });

  bool get canWrite => const {'owner', 'admin', 'coach', 'analyst', 'assistant'}.contains(role);

  Map<String, dynamic> toJson() => {
    'clubId': clubId,
    'clubName': clubName,
    'city': city,
    'role': role,
    'status': status,
    'teamId': teamId,
    'teamName': teamName,
    'category': category,
  };
  factory CloudClub.fromJson(Map<String, dynamic> m) => CloudClub(
    clubId: m['clubId'] as String,
    clubName: (m['clubName'] as String?) ?? '',
    city: (m['city'] as String?) ?? '',
    role: (m['role'] as String?) ?? 'coach',
    status: (m['status'] as String?) ?? 'trial',
    teamId: (m['teamId'] as String?) ?? '',
    teamName: (m['teamName'] as String?) ?? '',
    category: (m['category'] as String?) ?? '',
  );
}

/// Login, clube ativo e sincronização offline-first com o Supabase.
///
/// Tudo é gravado primeiro no aparelho e entra na fila; a fila é enviada
/// quando há internet. Nenhum scout depende da conexão do ginásio.
class CloudSync {
  CloudSync(this.config, {CloudApi? api}) : api = api ?? CloudApi(config);

  final CloudConfig config;
  final CloudApi api;

  CloudSession? session;
  CloudClub? club;
  final List<OutboxOp> outbox = [];
  DateTime? lastPushAt;
  String? lastError;
  bool flushing = false;

  bool get enabled => config.enabled;
  bool get signedIn => session != null;
  bool get ready => signedIn && club != null;

  static const _sessionKey = 'arco_cloud_session_v1';
  static const _clubKey = 'arco_cloud_club_v1';
  static const _outboxKey = 'arco_cloud_outbox_v1';

  static const _ns = '6ba7b811-9dad-11d1-80b4-00c04fd430c8'; // namespace URL (RFC 4122)

  /// UUID estável para um id local (ex.: jogador "p3" do clube X).
  static String stableUuid(String name) => const Uuid().v5(_ns, 'arco:$name');

  // ------------------------------------------------------------- persistência

  void restore(SharedPreferences prefs) {
    try {
      final s = prefs.getString(_sessionKey);
      if (s != null) session = CloudSession.fromJson((jsonDecode(s) as Map).cast<String, dynamic>());
      final c = prefs.getString(_clubKey);
      if (c != null) club = CloudClub.fromJson((jsonDecode(c) as Map).cast<String, dynamic>());
      final o = prefs.getString(_outboxKey);
      if (o != null) {
        outbox
          ..clear()
          ..addAll((jsonDecode(o) as List).map((e) => OutboxOp.fromJson((e as Map).cast<String, dynamic>())));
      }
    } catch (_) {
      // Dados de nuvem locais ilegíveis: pede login de novo, sem perder dados do app.
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (session == null) {
      await prefs.remove(_sessionKey);
    } else {
      await prefs.setString(_sessionKey, jsonEncode(session!.toJson()));
    }
    if (club == null) {
      await prefs.remove(_clubKey);
    } else {
      await prefs.setString(_clubKey, jsonEncode(club!.toJson()));
    }
    await prefs.setString(_outboxKey, jsonEncode([for (final op in outbox) op.toJson()]));
  }

  // ------------------------------------------------------------- conta

  Future<void> signIn(String email, String password) async {
    session = await api.signIn(email, password);
    await loadClub();
    await _save();
  }

  /// `true` = conta criada e já logada; `false` = precisa confirmar o e-mail.
  Future<bool> signUp(String email, String password, String name) async {
    final s = await api.signUp(email, password, name);
    if (s == null) return false;
    session = s;
    club = null;
    await _save();
    return true;
  }

  Future<void> recover(String email) => api.recoverPassword(email);

  Future<void> signOut() async {
    final s = session;
    session = null;
    club = null;
    await _save();
    if (s != null) await api.signOut(s);
  }

  Future<CloudSession> _fresh() async {
    final s = session;
    if (s == null) throw const CloudException('Entre na sua conta para sincronizar.', status: 401);
    if (!s.expiringSoon) return s;
    session = await api.refresh(s);
    await _save();
    return session!;
  }

  /// Carrega o primeiro clube do usuário (e a equipe principal).
  Future<CloudClub?> loadClub() async {
    final s = await _fresh();
    final rows = await api.select(s, 'club_members', {'select': 'club_id,role,clubs(id,name,city,status)', 'user_id': 'eq.${s.userId}'});
    if (rows.isEmpty) {
      club = null;
      return null;
    }
    final m = rows.first;
    final c = (m['clubs'] as Map?)?.cast<String, dynamic>() ?? const {};
    final teams = await api.select(s, 'teams', {'select': 'id,name,category', 'club_id': 'eq.${m['club_id']}', 'order': 'created_at.asc'});
    final t = teams.isEmpty ? const <String, dynamic>{} : teams.first;
    club = CloudClub(
      clubId: m['club_id'] as String,
      clubName: (c['name'] ?? '').toString(),
      city: (c['city'] ?? '').toString(),
      role: (m['role'] ?? 'coach').toString(),
      status: (c['status'] ?? 'trial').toString(),
      teamId: (t['id'] ?? '').toString(),
      teamName: (t['name'] ?? '').toString(),
      category: (t['category'] ?? '').toString(),
    );
    await _save();
    return club;
  }

  /// Primeiro acesso: cria clube → equipe/categoria → temporada.
  Future<CloudClub> createClub({
    required String clubName,
    required String city,
    required String teamName,
    required String category,
    required String season,
  }) async {
    final s = await _fresh();
    final clubRow = (await api.upsert(s, 'clubs', [
      {'name': clubName, 'city': city, 'created_by': s.userId},
    ])).single;
    final clubId = clubRow['id'] as String;
    final teamRow = (await api.upsert(s, 'teams', [
      {'club_id': clubId, 'name': teamName, 'category': category, 'gender': category.endsWith('F') ? 'F' : 'M'},
    ])).single;
    await api.upsert(s, 'seasons', [
      {'club_id': clubId, 'team_id': teamRow['id'], 'name': season, 'active': true},
    ]);
    club = CloudClub(clubId: clubId, clubName: clubName, city: city, role: 'owner', teamId: teamRow['id'] as String, teamName: teamName, category: category);
    await _save();
    return club!;
  }

  // ------------------------------------------------------------- fila

  /// Coloca uma linha na fila (substitui pendência com a mesma chave) e salva.
  Future<void> enqueue(String key, String table, String onConflict, Map<String, dynamic> row) async {
    outbox.removeWhere((op) => op.key == key);
    outbox.add(OutboxOp(key: key, table: table, onConflict: onConflict, row: row));
    await _save();
  }

  /// Envia a fila em ordem. Falha temporária: para e tenta depois.
  /// Falha permanente (dado recusado): descarta a operação e registra o erro.
  Future<int> flush() async {
    if (flushing || !ready || outbox.isEmpty) return 0;
    flushing = true;
    var sent = 0;
    try {
      while (outbox.isNotEmpty) {
        final op = outbox.first;
        try {
          final s = await _fresh();
          final row = {...op.row, 'club_id': club!.clubId};
          await api.upsert(s, op.table, [row], onConflict: op.onConflict.isEmpty ? null : op.onConflict);
          outbox.removeAt(0);
          sent++;
          lastError = null;
        } on CloudException catch (e) {
          op.attempts++;
          lastError = e.message;
          if (e.retryable) break;
          outbox.removeAt(0);
        }
      }
      if (sent > 0) lastPushAt = DateTime.now();
    } finally {
      flushing = false;
      await _save();
    }
    return sent;
  }

  Future<List<Map<String, dynamic>>> pull(String table, Map<String, String> query) async {
    if (!ready) return const [];
    final s = await _fresh();
    return api.select(s, table, {...query, 'club_id': 'eq.${club!.clubId}'});
  }
}
