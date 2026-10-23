# Plano de desenvolvimento — ARCO Analytics

## Objetivo

**Dado → Contexto → Insight → Decisão**

## v0.6.0 — MVP integrado

### Fase 0 — Organização da base
Status: **concluída**
- fonte Flutter na raiz;
- CI/CD;
- Web/PWA + Android;
- documentação;
- Application ID estável.

### Fase 1 — Histórico real do treinador
Status: **MVP concluído**
- organizationId/teamId/seasonId;
- TeamContext;
- histórico FPB + LBC + ARCO;
- filtros de liga/categoria/temporada/status;
- mocks separados;
- persistência de scouts;
- vínculo federativo CBB → FPB;
- aliases oficiais de Tupã;
- busca histórica pública FPB com cache.

Limite: a leitura pública da FPB/LBC não substitui feed oficial/licenciado.

### Fase 2 — Banco, autenticação e acesso
Status: **arquitetura/MVP concluídos**
- papéis e permissões;
- sessão demo separada;
- senha demo removida do código;
- gateway Supabase configurável por dart-defines.

Pendente de infraestrutura externa:
- criar/fornecer projeto Supabase (ou backend próprio);
- schema remoto e políticas RLS;
- credenciais/URL de produção;
- sincronização multi-dispositivo ativa.

### Fase 3 — Scout profissional
Status: **MVP concluído**
- eventos por atleta;
- placar e período;
- lineup em quadra;
- undo;
- métricas ao vivo;
- persistência local do jogo concluído;
- funcionamento durante jogo sem depender da internet;
- quadra tocável e localização de arremessos.

Próxima robustez:
- recuperação automática de partida ativa após encerramento forçado do app;
- relógio regressivo oficial configurável;
- granularidade de tipos de posse.

### Fase 4 — Analytics avançado
Status: **MVP concluído**
- eFG%, ORtg, DRtg, Net Rating;
- TOV%, ORB%, FT Rate;
- Four Factors;
- lineups;
- confiança por posses;
- splits recentes vs temporada;
- shot chart real;
- ARCO Impact experimental.

### Fase 5 — Vídeo, adversários e Game Plan
Status: **MVP concluído**
- adversários;
- Game Plan;
- timeline;
- YouTube;
- evento → timestamp aproximado;
- relatório textual da temporada.

Próxima robustez:
- PDF nativo;
- tagging de vídeo mais avançado;
- dados ofensivos/defensivos do adversário vindos de mais fontes.

### Fase 6 — ARCO Assistant
Status: **MVP concluído**
- perguntas locais;
- evidências;
- confiança da amostra;
- não inventa métricas inexistentes;
- usa dados registrados pelo ARCO.

Próxima robustez:
- modelo de linguagem conectado ao banco real;
- RAG por clube;
- políticas de segurança e auditoria de respostas.

## Critério para release

A release só pode entrar na `main` quando passar:

1. `flutter analyze`;
2. `flutter test`;
3. build Android;
4. build Web/PWA.

Android deve manter:

`com.arcoanalytics.app`
