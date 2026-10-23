import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthConfiguration {
  static const provider = String.fromEnvironment(
    'ARCO_AUTH_PROVIDER',
    defaultValue: 'demo',
  );
  static const supabaseUrl = String.fromEnvironment('ARCO_SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('ARCO_SUPABASE_ANON_KEY');

  static bool get cloudConfigured =>
      provider.toLowerCase() == 'supabase' &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;
}

class AuthResult {
  final bool success;
  final String? userId;
  final String? accessToken;
  final String? error;

  const AuthResult({
    required this.success,
    this.userId,
    this.accessToken,
    this.error,
  });
}

class SupabaseAuthGateway {
  const SupabaseAuthGateway();

  Future<AuthResult> signIn(String email, String password) async {
    if (!AuthConfiguration.cloudConfigured) {
      return const AuthResult(
        success: false,
        error: 'Autenticação em nuvem ainda não configurada.',
      );
    }

    try {
      final base = AuthConfiguration.supabaseUrl.endsWith('/')
          ? AuthConfiguration.supabaseUrl.substring(0, AuthConfiguration.supabaseUrl.length - 1)
          : AuthConfiguration.supabaseUrl;
      final uri = Uri.parse('$base/auth/v1/token?grant_type=password');
      final response = await http.post(
        uri,
        headers: {
          'apikey': AuthConfiguration.supabaseAnonKey,
          'Authorization': 'Bearer ${AuthConfiguration.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      final body = response.body.isEmpty
          ? const <String, dynamic>{}
          : (jsonDecode(response.body) as Map).cast<String, dynamic>();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AuthResult(
          success: false,
          error: body['msg']?.toString() ??
              body['error_description']?.toString() ??
              'Falha de autenticação.',
        );
      }

      final user = body['user'] is Map
          ? (body['user'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{};
      return AuthResult(
        success: true,
        userId: user['id']?.toString(),
        accessToken: body['access_token']?.toString(),
      );
    } catch (e) {
      return AuthResult(success: false, error: 'Erro ao autenticar: $e');
    }
  }
}
