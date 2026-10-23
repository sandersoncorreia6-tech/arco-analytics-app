import 'package:flutter/material.dart';
import '../models/access_control.dart';
import '../services/auth_gateway.dart';

class AccessControlScreen extends StatelessWidget {
  const AccessControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = AuthConfiguration.cloudConfigured;
    return Scaffold(
      appBar: AppBar(title: const Text('Acesso e permissões')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: ListTile(
              leading: Icon(cloud ? Icons.cloud_done : Icons.cloud_off),
              title: Text(cloud ? 'Autenticação em nuvem ativa' : 'Backend de autenticação não configurado'),
              subtitle: Text(
                cloud
                    ? 'O build recebeu as variáveis de autenticação necessárias.'
                    : 'O APK usa sessão demo. Para produção, configure ARCO_AUTH_PROVIDER=supabase, ARCO_SUPABASE_URL e ARCO_SUPABASE_ANON_KEY.',
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Papéis previstos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ...AppRole.values.map((role) {
            final perms = AccessPolicy.permissions[role] ?? const {};
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                title: Text(AccessPolicy.roleLabel(role), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${perms.length} permissões'),
                children: perms.map((permission) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.check, size: 18),
                  title: Text(_permissionLabel(permission)),
                )).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _permissionLabel(AppPermission permission) {
    switch (permission) {
      case AppPermission.manageOrganization:
        return 'Gerenciar organização';
      case AppPermission.manageUsers:
        return 'Gerenciar usuários';
      case AppPermission.manageRoster:
        return 'Gerenciar elenco';
      case AppPermission.manageGames:
        return 'Gerenciar jogos';
      case AppPermission.recordScout:
        return 'Registrar scout';
      case AppPermission.viewAnalytics:
        return 'Ver analytics';
      case AppPermission.viewGamePlan:
        return 'Ver Game Plan';
      case AppPermission.manageVideos:
        return 'Gerenciar vídeos';
      case AppPermission.exportReports:
        return 'Exportar relatórios';
    }
  }
}
