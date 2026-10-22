import 'package:flutter/material.dart';
import '../models/fpb_game.dart';
import '../state/app_state.dart';

class FpbLiveScreen extends StatelessWidget {
  const FpbLiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final games = state.fpbGames;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FPB • Ao vivo'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: state.fpbSyncing ? null : state.syncFpbNow,
            icon: state.fpbSyncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.syncFpbNow,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusCard(state: state),
            const SizedBox(height: 12),
            if (state.fpbError != null)
              Card(
                color: Colors.orange.withOpacity(.08),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(state.fpbError!, style: const TextStyle(color: Colors.orangeAccent)),
                ),
              ),
            if (games.isEmpty) ...[
              const SizedBox(height: 36),
              const Icon(Icons.cloud_off_outlined, size: 52, color: Colors.white30),
              const SizedBox(height: 12),
              const Center(child: Text('Nenhum jogo interpretado da página pública da FPB.', style: TextStyle(color: Colors.white60))),
              const SizedBox(height: 8),
              const Center(child: Text('O módulo já está preparado para trocar para API oficial/Sportradar quando houver acesso.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12))),
            ] else
              ...games.map((g) => _GameCard(game: g)),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final AppState state;
  const _StatusCard({required this.state});
  @override
  Widget build(BuildContext context) {
    final last = state.fpbLastSyncAt;
    final label = last == null
        ? 'Ainda não sincronizado'
        : 'Última sincronização ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}:${last.second.toString().padLeft(2, '0')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(state.fpbSyncing ? Icons.sync : Icons.sensors, color: state.fpbError == null ? Colors.greenAccent : Colors.orangeAccent),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Sincronização FPB', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('$label • atualização automática ~30s', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ])),
        ]),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final FpbGameSnapshot game;
  const _GameCard({required this.game});
  @override
  Widget build(BuildContext context) {
    final live = game.isLive;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (game.competition.isNotEmpty) Text(game.competition, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: (live ? Colors.redAccent : Colors.white24).withOpacity(.12), borderRadius: BorderRadius.circular(99)),
              child: Text(game.status, style: TextStyle(color: live ? Colors.redAccent : Colors.white60, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text(game.homeTeam, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(game.homeScore?.toString() ?? '—', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(child: Text(game.awayTeam, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text(game.awayScore?.toString() ?? '—', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ]),
        ]),
      ),
    );
  }
}
