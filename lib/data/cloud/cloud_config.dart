/// Configuração da nuvem (Supabase), definida no build:
///   --dart-define=ARCO_SUPABASE_URL=https://xxxx.supabase.co
///   --dart-define=ARCO_SUPABASE_ANON_KEY=...
/// Sem ela, o ARCO funciona no modo local (dados só no aparelho).
class CloudConfig {
  final String url;
  final String anonKey;
  const CloudConfig(this.url, this.anonKey);

  static const fromEnvironment = CloudConfig(String.fromEnvironment('ARCO_SUPABASE_URL'), String.fromEnvironment('ARCO_SUPABASE_ANON_KEY'));

  bool get enabled => url.startsWith('https://') && anonKey.length > 20;

  Uri auth(String path, [Map<String, String>? query]) => Uri.parse('${url.replaceAll(RegExp(r'/+$'), '')}/auth/v1/$path').replace(queryParameters: query);
  Uri rest(String table, [Map<String, String>? query]) => Uri.parse('${url.replaceAll(RegExp(r'/+$'), '')}/rest/v1/$table').replace(queryParameters: query);
}
