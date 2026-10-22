import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/league_game.dart';
import '../state/app_state.dart';
import '../state/league_feed.dart';

String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String lastSyncLabel(LeagueFeed feed) {
  final last = feed.lastSyncAt;
  if (last == null) return 'ainda não sincronizado';
  final now = DateTime.now();
  final sameDay = last.year == now.year && last.month == now.month && last.day == now.day;
  return sameDay ? 'atualizado às ${hhmm(last)}' : 'atualizado em ${last.day.toString().padLeft(2, '0')}/${last.month.toString().padLeft(2, '0')} ${hhmm(last)}';
}

Future<void> openExternal(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  var ok = false;
  if (uri != null && uri.hasScheme) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível abrir $url')));
  }
}

/// Cartão de status de uma liga: última sincronização, erro e ações.
class LeagueStatusCard extends StatelessWidget {
  final LeagueFeed feed;
  final VoidCallback? onOpen;
  const LeagueStatusCard({super.key, required this.feed, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final problem = feed.error ?? feed.warning;
    final color = feed.error != null
        ? Colors.redAccent
        : feed.warning != null
            ? Colors.orangeAccent
            : Colors.greenAccent;
    final live = feed.games.where((g) => g.isLive).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(feed.syncing ? Icons.sync : (feed.error != null ? Icons.cloud_off_outlined : Icons.sensors), color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${feed.league} • ${gamesCount(feed.games.length)}${live > 0 ? ' • $live ao vivo' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                    feed.syncing ? 'sincronizando...' : '${lastSyncLabel(feed)} • a cada ${feed.hasLive ? '30 s' : '3 min'}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ]),
              ),
              IconButton(
                tooltip: 'Atualizar ${feed.league}',
                onPressed: feed.syncing ? null : () => state.syncLeague(feed),
                icon: feed.syncing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
              ),
              PopupMenuButton<String>(
                tooltip: 'Mais opções',
                onSelected: (v) {
                  switch (v) {
                    case 'paste':
                      showPasteGamesDialog(context, feed);
                    case 'sources':
                      showSourcesDialog(context, feed);
                    case 'diag':
                      showDiagnosticsSheet(context, feed);
                    case 'site':
                      openExternal(context, feed.source.officialUrl);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'paste', child: ListTile(leading: Icon(Icons.content_paste), title: Text('Colar jogos'))),
                  PopupMenuItem(value: 'sources', child: ListTile(leading: Icon(Icons.link), title: Text('Fontes / páginas'))),
                  PopupMenuItem(value: 'diag', child: ListTile(leading: Icon(Icons.network_check), title: Text('Diagnóstico'))),
                  PopupMenuItem(value: 'site', child: ListTile(leading: Icon(Icons.open_in_new), title: Text('Abrir site oficial'))),
                ],
              ),
            ]),
            if (problem != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  feed.games.isNotEmpty && feed.error != null ? '$problem Exibindo os últimos dados salvos.' : problem,
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                TextButton.icon(onPressed: () => showPasteGamesDialog(context, feed), icon: const Icon(Icons.content_paste, size: 18), label: const Text('Colar jogos')),
                TextButton.icon(onPressed: () => showDiagnosticsSheet(context, feed), icon: const Icon(Icons.network_check, size: 18), label: const Text('Diagnóstico')),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Linha de jogo usada no Hub e na tela de cada liga.
class LeagueGameTile extends StatelessWidget {
  final LeagueGame game;
  final bool showLeague;
  const LeagueGameTile({super.key, required this.game, this.showLeague = true});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final mine = state.coach.isMyGame(game);
    final hasVideo = state.videoLinks.containsKey(game.id);
    final statusColor = game.isLive ? Colors.redAccent : (game.isFinal ? Colors.white60 : Colors.lightBlueAccent);
    TextStyle team(String name) => TextStyle(
          fontWeight: FontWeight.w800,
          color: mine && state.coach.isMyTeam(name) ? Theme.of(context).colorScheme.primary : null,
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: mine
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: .6)),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showLeagueGameSheet(context, game),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (showLeague) _Pill(game.league, Colors.white24),
                  _Pill(game.status, statusColor),
                  if (game.competition.isNotEmpty) Text(game.competition, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  if (game.manual) const Text('• manual', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text(game.homeTeam, style: team(game.homeTeam))),
                  Text(game.homeScore?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: Text(game.awayTeam, style: team(game.awayTeam))),
                  Text(game.awayScore?.toString() ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ]),
                if (game.dateLabel.isNotEmpty || game.venue.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text([game.dateLabel, game.venue].where((e) => e.isNotEmpty).join(' • '),
                      style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ]),
            ),
            IconButton(
              tooltip: hasVideo ? 'Vídeo do jogo' : 'Adicionar vídeo',
              icon: Icon(hasVideo ? Icons.play_circle_fill : Icons.video_library_outlined),
              onPressed: () => showVideoDialog(context, game),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: TextStyle(color: color == Colors.white24 ? Colors.white70 : color, fontSize: 10, fontWeight: FontWeight.w800)),
      );
}

Future<void> showLeagueGameSheet(BuildContext context, LeagueGame g) async {
  final state = AppScope.of(context);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${g.homeTeam} × ${g.awayTeam}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        if (g.hasScore) Text(g.scoreLabel, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text([g.league, g.competition, g.status, g.dateLabel, g.venue].where((e) => e.isNotEmpty).join(' • '),
            style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(sheetContext);
            showVideoDialog(context, g);
          },
          icon: const Icon(Icons.ondemand_video),
          label: Text(state.videoLinks.containsKey(g.id) ? 'Assistir / editar vídeo' : 'Adicionar vídeo do YouTube'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => openExternal(context, g.sourceUrl),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Abrir fonte oficial'),
        ),
      ]),
    ),
  );
}

Future<void> showVideoDialog(BuildContext context, LeagueGame g) async {
  final state = AppScope.of(context);
  final controller = TextEditingController(text: state.videoLinks[g.id] ?? '');
  String? error;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setLocal) => AlertDialog(
        title: const Text('Vídeo do jogo'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(labelText: 'Link do YouTube', hintText: 'https://youtube.com/...', errorText: error),
        ),
        actions: [
          if ((state.videoLinks[g.id] ?? '').isNotEmpty)
            TextButton(onPressed: () => openExternal(context, state.videoLinks[g.id]!), child: const Text('ASSISTIR')),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCELAR')),
          FilledButton(
            onPressed: () async {
              var url = controller.text.trim();
              if (url.isNotEmpty && !url.startsWith('http')) url = 'https://$url';
              final uri = Uri.tryParse(url);
              if (url.isNotEmpty && (uri == null || uri.host.isEmpty)) {
                setLocal(() => error = 'Link inválido');
                return;
              }
              await state.setVideoLink(g.id, url);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('SALVAR'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}

/// Plano B quando o site muda/bloqueia: o treinador copia a tabela do site
/// (ou de um PDF/WhatsApp) e cola aqui.
Future<void> showPasteGamesDialog(BuildContext context, LeagueFeed feed) async {
  final state = AppScope.of(context);
  final controller = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Colar jogos • ${feed.league}'),
      content: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Copie a tabela/resultados do site oficial, de um PDF ou do WhatsApp e cole abaixo. Exemplos:\n'
            '• Tupã 78 x 65 Marília 22/10\n'
            '• Bauru x Lins - 25/10 às 20h - Sub 17',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Cole aqui...'),
          ),
        ]),
      ),
      actions: [
        if (feed.games.any((g) => g.manual))
          TextButton(
            onPressed: () async {
              await state.removeManualGames(feed);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('LIMPAR MANUAIS'),
          ),
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCELAR')),
        FilledButton(
          onPressed: () async {
            final count = await state.importPastedGames(feed, controller.text);
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(count == 0
                  ? 'Nenhum jogo reconhecido. Confira se cada jogo tem as duas equipes (ex.: "Tupã x Marília").'
                  : '$count jogo(s) importado(s) para a ${feed.league}.'),
            ));
          },
          child: const Text('IMPORTAR'),
        ),
      ],
    ),
  );
  controller.dispose();
}

/// Páginas extras do mesmo site (ex.: a tabela da categoria do treinador).
Future<void> showSourcesDialog(BuildContext context, LeagueFeed feed) async {
  final state = AppScope.of(context);
  final controller = TextEditingController(text: feed.extraPages.join('\n'));
  String? error;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setLocal) => AlertDialog(
        title: Text('Fontes • ${feed.league}'),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sempre consultadas:\n${feed.source.pages.join('\n')}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 12),
            Text(
              'Páginas extras, uma por linha — por exemplo, a tabela da sua categoria ou o endereço atual do site da liga'
              '${kIsWeb ? ' (na versão Web, só páginas de ${feed.source.host})' : ''}:',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(border: const OutlineInputBorder(), hintText: 'https://...', errorText: error),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCELAR')),
          FilledButton(
            onPressed: () async {
              final urls = controller.text.split(RegExp(r'\s+')).where((u) => u.isNotEmpty).toList();
              final invalid = urls.where((u) {
                final uri = Uri.tryParse(u);
                return uri == null || !feed.source.acceptsUrl(uri);
              }).toList();
              if (invalid.isNotEmpty) {
                setLocal(() => error = kIsWeb ? 'Na Web, use apenas endereços de ${feed.source.host}: ${invalid.first}' : 'Endereço inválido: ${invalid.first}');
                return;
              }
              Navigator.pop(dialogContext);
              await state.setExtraPages(feed, urls);
            },
            child: const Text('SALVAR E ATUALIZAR'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}

/// Detalhes técnicos da última sincronização — útil para reportar problemas.
Future<void> showDiagnosticsSheet(BuildContext context, LeagueFeed feed) async {
  final state = AppScope.of(context);
  if (!feed.syncing) state.syncLeague(feed);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => AnimatedBuilder(
      animation: state,
      builder: (context, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Diagnóstico • ${feed.source.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Situação: ${feed.syncing ? 'sincronizando...' : feed.error ?? feed.warning ?? 'OK — ${gamesCount(feed.games.length)}'}'),
            Text('Última sincronização: ${lastSyncLabel(feed)}', style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 12),
            if (feed.lastAttempts.isEmpty && !feed.syncing)
              const Text('Nenhuma página respondeu nesta tentativa.', style: TextStyle(color: Colors.white60)),
            ...feed.lastAttempts.map((a) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(a.ok ? Icons.check_circle : Icons.error_outline, color: a.ok ? Colors.greenAccent : Colors.redAccent),
                  title: Text(a.url, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(a.ok
                      ? 'HTTP ${a.statusCode} • ${(a.bytes / 1024).toStringAsFixed(0)} KB • ${a.elapsed?.inMilliseconds ?? 0} ms • ${a.gamesFound} jogos reconhecidos'
                      : a.error ?? 'falhou'),
                )),
            const SizedBox(height: 8),
            const Text(
              'Se a página responde mas 0 jogos são reconhecidos, o site provavelmente carrega a agenda por um widget externo. '
              'Cadastre a página exata da tabela em "Fontes" ou use "Colar jogos".',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ]),
        ),
      ),
    ),
  );
}
