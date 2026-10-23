# Plano de desenvolvimento — ARCO Analytics

## Objetivo do produto

Transformar o ARCO em uma plataforma de inteligência para comissão técnica de basquete:

**Dado → Contexto → Insight → Decisão**

## Fase 0 — Organização da base
Status: **concluída na branch organize-v0.5**

- código-fonte v0.5 na raiz;
- estrutura Flutter visível;
- Web/PWA e API separadas;
- workflows usando a v0.5;
- documentação de arquitetura;
- proteção básica de arquivos sensíveis;
- Application ID Android preservado.

## Fase 1 — Histórico real do treinador
Status: **em implementação**

Objetivo:
- treinador vinculado a organização e equipe por IDs;
- contexto de temporada;
- histórico unificado FPB + LBC + scout ARCO;
- jogos demo separados dos jogos oficiais;
- sem limite fixo de 3 partidas;
- deduplicação entre jogo oficial e scout do ARCO;
- associação futura de vídeo e estatísticas ao mesmo jogo.

Implementado:
- `TeamContext`;
- `FederativeLink` e hierarquia CBB → FPB;
- nomes oficiais FPB de Tupã reconhecidos como identidades externas;
- IDs internos para organização/equipe/temporada;
- `CoachGameRecord` normalizado;
- `CoachScheduleService`;
- metadados de jogo no modelo `Game`;
- jogos demo marcados explicitamente como `mock`;
- tela de Jogos reorganizada em temporada, histórico completo e scouts analisados.

Pendente nesta fase:
- tornar o coletor FPB capaz de percorrer calendário/temporada completos;
- tornar o coletor LBC mais robusto;
- filtros por categoria, competição e temporada;
- persistir jogos do scout após fechar o aplicativo; **concluído localmente**
- substituir correspondência por nome por mapeamento persistido quando a fonte oficial fornecer IDs;
- caminho federativo CBB → FPB modelado, com nomes oficiais externos e registro oficial ainda não verificado.

## Fase 2 — Banco e autenticação reais
Status: **pendente**

- banco em nuvem;
- usuários e organizações;
- treinador/auxiliar/analista/admin;
- equipes e categorias;
- temporadas;
- permissões;
- recuperação de senha;
- sincronização multi-dispositivo;
- remover credenciais demo do código.

## Fase 3 — Scout profissional
Status: **pendente**

- persistência offline;
- relógio/período;
- substituições;
- lineups automáticos;
- eventos por atleta;
- tipos de posse;
- localização do arremesso;
- sincronização posterior.

## Fase 4 — Analytics avançado
Status: **pendente**

- eFG%, TS%, ORtg, DRtg e Net Rating por filtros;
- Four Factors;
- On/Off;
- duplas, trios, quartetos e quintetos;
- splits;
- confiança/tamanho da amostra;
- tendências.

## Fase 5 — Vídeo e adversários
Status: **pendente**

- timeline de eventos;
- evento → timestamp do vídeo;
- central de adversários;
- shot chart ofensivo/defensivo;
- scouting de tendências;
- Game Plan.

## Fase 6 — ARCO Assistant
Status: **pendente**

- perguntas em linguagem natural;
- respostas somente a partir dos dados reais do clube;
- diagnóstico;
- comparação;
- recomendações com contexto;
- indicação explícita de baixa amostra.

## Regra de desenvolvimento

Não adicionar grandes módulos antes de estabilizar a fase anterior. Cada fase deve passar por:

1. `flutter analyze`;
2. testes automatizados;
3. build Android;
4. build Web/PWA;
5. revisão antes de merge na `main`.
