# ARCO Analytics — v0.5 Coach Hub

Plataforma Flutter/Dart de inteligência para treinadores de basquete.

**Dado → Contexto → Insight → Decisão**

## Fonte oficial

A partir desta organização, o **código-fonte v0.5 na raiz do repositório é a fonte oficial**.

As pastas `.source/v0_4/` e os arquivos ZIP antigos são legados de migração e não devem receber novas funcionalidades.

## Estrutura

- `lib/` — aplicação Flutter
- `lib/models/` — modelos
- `lib/services/` — integrações e regras de serviço
- `lib/state/` — estado atual do aplicativo
- `lib/screens/` — telas
- `lib/widgets/` — componentes reutilizáveis
- `web/` — PWA/Web
- `api/` — proxies/integrações para fontes externas
- `docs/` — documentação técnica e de produto
- `.github/workflows/` — builds e validações

## Funcionalidades atuais

- login/área do treinador;
- perfil demo de Adriano Mião;
- organização demo Tupã / Monstrinho;
- central FPB + LBC;
- filtros por competição/categoria/equipe;
- cache local de jogos externos;
- vínculo de vídeo do YouTube por partida;
- scout ao vivo;
- eFG%, TS%, ORtg, DRtg, Net Rating;
- TOV%, ORB%, FT Rate;
- Four Factors;
- On/Off;
- Lineup Analytics;
- ARCO Impact Score experimental;
- motor de insights;
- Web/PWA e build Android.

## Situação atual dos dados

A v0.5 ainda utiliza `MockRepository` para parte do elenco, jogos e demonstrações. FPB/LBC já possuem serviços separados, mas a próxima evolução estrutural deve ser um banco persistente por:

**organização → equipe → temporada → categoria → competição → jogo**

Essa migração é prioridade porque o histórico do treinador não deve depender de uma lista mockada.

## Login demo

As credenciais existentes são apenas para demonstração e **não são autenticação de produção**. Antes de comercializar, substituir por autenticação real e remover segredos/credenciais fixas do código.

## Builds

### Multiplataforma

O workflow **ARCO - Build Multiplataforma** valida a fonte da raiz e gera:

- APK Android;
- AAB Android;
- Web/PWA;
- Windows;
- iOS unsigned.

### APK rápido

O workflow **ARCO - APK Android Manual** gera somente o APK.

O Application ID Android deve permanecer:

`com.arcoanalytics.app`

## Prioridades técnicas

1. banco real e persistência em nuvem;
2. histórico completo por treinador/equipe/temporada/categoria;
3. IDs consistentes para times, jogos, competições e temporadas;
4. autenticação real e permissões;
5. ingestão robusta de FPB/LBC;
6. scout e lineups persistentes;
7. analytics avançado;
8. vídeo + timeline;
9. Game Plan;
10. ARCO Assistant.

Veja também `docs/REPOSITORY_STRUCTURE.md` e os demais documentos da pasta `docs/`.
