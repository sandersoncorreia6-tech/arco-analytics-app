# ARCO Analytics — Integração FPB e LBC

## Fonte estruturada (calendário oficial)

A aba **Estatísticas → Online** da FPB é alimentada pelo calendário da CBB
(`www.cbb.com.br/calendario`), que expõe cada competição ("SUB 16M 2026", "1ª DIVISÃO
MASCULINA 2026"...) com equipes, placar, status, local, horário e ids. O
`FpbProvider` (`lib/data/providers/fpb_provider.dart`) é o único ponto que conhece esse
formato:

- chama a Server Action do calendário com `competitionId`, `org: fpb` e o período da temporada;
- se a CBB republicar o site e a consulta mudar, redescobre o id automaticamente nos scripts;
- competições adicionais podem ser informadas em Mais → Minha equipe (link/UUID).

Páginas e notícias da FPB continuam como reserva para categorias sem calendário estruturado.

## Arquitetura

```
LeagueSource (FPB, LBC)  →  LeagueSyncService  →  ScheduleParser  →  LeagueGame
        páginas públicas       busca + diagnóstico     interpretação      modelo único
```

- `lib/data/sources/league_sync_service.dart` — configuração de cada liga, coleta e
  resultado por página (`SourceAttempt`) para o diagnóstico.
- `lib/data/sources/schedule_parser.dart` — interpretação tolerante a mudanças de layout.
  Não depende de classes CSS: lê dados estruturados (JSON-LD schema.org, JSON de
  Next.js/APIs), linhas de tabela, itens de lista, cards e texto livre.
- `lib/data/sources/source_fetcher.dart` — GET com timeout de 15 s, nova tentativa em
  falhas transitórias e mensagens de erro em português.
- `lib/state/league_feed.dart` — estado de cada liga, cache, intervalo adaptativo.

### Plataformas
- **Android / iOS / desktop**: consultam os sites diretamente. No Android é obrigatória a
  permissão `INTERNET` (já incluída em `android/app/src/main/AndroidManifest.xml`).
- **Web/PWA**: o navegador bloqueia leitura de outros sites (CORS), então o app consulta
  `api/fpb-online` e `api/lbc-online` (Vercel). Se a Web for publicada fora da Vercel
  (ex.: GitHub Pages), gere o build com
  `--dart-define=ARCO_PROXY_BASE_URL=https://seu-deploy.vercel.app`.

### Atualização
- 30 s quando há jogo ao vivo; 3 min sem jogo ao vivo.
- Pausa com o app em segundo plano e atualiza ao voltar.
- Falha de rede ou página vazia **não** apaga os jogos salvos.

## Estatística completa (FIBA LiveStats)

- `lib/data/sources/fiba_livestats.dart` — encontra ids de partidas em links/iframes/scripts
  (`fibalivestats…/u/<ORG>/<id>`, `geniussports…/match/<id>`, `…/data/<id>/data.json`) e
  converte o `data.json` público da partida em `GameBoxScore` (equipes, jogadores,
  arremessos com coordenadas normalizadas para meia quadra e lance a lance).
- `lib/domain/services/stats_aggregator.dart` — soma a temporada por equipe e jogador.
- No app, as partidas descobertas são baixadas automaticamente (no máximo 40 por vez, 4 em
  paralelo); jogos ao vivo são atualizados a cada ~30 s. Na Web, use o proxy `api/livestats`.
- Se a liga usar outro sistema de estatística, o link colado não terá id reconhecido e o app
  avisará — envie um exemplo do link para criarmos o leitor correspondente.

## Notícias da FPB
A programação e os resultados da base são publicados como notícias (um jogo por linha, com o
dia no cabeçalho). O app lê as últimas notícias pela API pública do WordPress
(`/wp-json/wp/v2/posts?search=jogos`).

## Quando o site muda ou bloqueia

No menu ⋮ de cada liga (Competições):
1. **Diagnóstico** — mostra, por página, HTTP, tamanho, tempo e quantos jogos foram reconhecidos.
   - Erro de rede/HTTP: problema de conexão ou bloqueio do site.
   - HTTP 200 com 0 jogos: a agenda é carregada por um widget externo ou fica em outra página.
2. **Fontes** — cadastre a página exata da tabela/agenda (somente do domínio da liga).
3. **Colar jogos** — copie a tabela do site, PDF ou WhatsApp e cole. Jogos manuais
   não são apagados pelas sincronizações.

Para melhorar o parser, salve o HTML da página (ou o texto copiado) e acrescente um caso em
`test/schedule_parser_test.dart`.

## Produção recomendada
Solicitar à FPB/LBC (ou ao provedor de estatísticas) acesso oficial a feed/API. Basta criar
um serviço que devolva `LeagueSyncResult`; telas, cache e analytics não mudam.

## O que não fazer
Não depender de endpoints privados descobertos por engenharia reversa, não contornar
autenticação e não redistribuir feeds licenciados sem autorização.
