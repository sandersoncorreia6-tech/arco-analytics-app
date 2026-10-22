# Arquitetura do ARCO Analytics

```
lib/
  main.dart, app.dart          entrada e roteamento (login → primeiro acesso → app)
  config/                      versão e Application ID
  presentation/
    screens/                   telas (Início, Jogos, Ligas, Stats, Elenco, Mais...)
    widgets/                   componentes (mapa de arremessos, tabelas, cartões)
    theme/
  state/                       AppState (estado do app) e LeagueFeed (sincronização por liga)
  domain/
    models/                    entidades: LeagueGame (partida), Game/LiveGameSession (scout),
                               Player, CoachProfile, GameBoxScore...
    analysis/                  Analista ARCO, análise de jogo/temporada, lineups, duplas/trios,
                               zonas de arremesso, tamanho da amostra, relatórios
    services/                  métricas (eFG, TS, ratings), agregação da temporada, insights
  data/
    providers/                 CompetitionProvider → FpbProvider (calendário CBB/FPB), LbcProvider
    sources/                   acesso HTTP, parsers de páginas, estatística online (FIBA LiveStats)
    repositories/              GameRepository: histórico completo e consultas da área Jogos
    cloud/                     Supabase (Auth + REST), fila offline (outbox), mapeamento das tabelas
    demo/                      dados de demonstração (nunca aparecem como jogos reais)
  services/                    exportação de relatórios (PDF, WhatsApp)
supabase/                      banco (migração com RLS) e testes de isolamento
api/                           proxies Web (Vercel) para FPB, LBC e estatística online
```

## Fluxo de jogos

```
FPB (calendário CBB) ─┐
FPB (páginas/notícias)├─► LeagueSyncService ─► LeagueFeed (histórico, upsert por gameId)
LBC (páginas)         ┘                                   │
Scout do ARCO ────────────────────────────────────────────┤
                                                          ▼
                                   GameRepository (sem duplicatas entre fontes)
                                                          ▼
                     Treinador → Equipe → Categoria → Temporada → Competição
                                                          ▼
                       Jogos: Próximos | Últimos | Todos | Temporada + filtros
```

* Cada partida tem `gameId` próprio (fonte estruturada: `fpb_m<matchId>`), além de
  `competitionId`, `seasonId`, `categoryId`, ids das equipes e da estatística online.
* Sincronizações **acumulam** a temporada: atualizam placar/horário/status e nunca
  descartam jogos antigos (as páginas da liga só mostram a rodada atual).
* A equipe do treinador é identificada por clube **e** categoria **e** temporada
  (Monstrinho Sub-13 ≠ Monstrinho Sub-16), configuráveis em Mais → Minha equipe.

## Nova liga

Implementar `CompetitionProvider` (competições, calendário estruturado) e registrar em
`LeagueSyncService`. Telas, histórico, análises e nuvem não mudam.

## Nuvem e offline

Tudo é salvo primeiro no aparelho. Com o Supabase configurado, cada alteração entra na
fila (`CloudSync.outbox`) e é enviada quando há internet; operações do mesmo item se
substituem (o scout ao vivo envia sempre o retrato mais recente). Em outro aparelho, o
`pullFromCloud` recupera elenco, jogos do scout, scout em andamento e vídeos.
