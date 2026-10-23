# ARCO Analytics — v0.6.0 Integrated MVP

Plataforma Flutter/Dart de inteligência para comissão técnica de basquete.

**Dado → Contexto → Insight → Decisão**

## Fonte oficial

O código-fonte na raiz do repositório é a fonte oficial. ZIPs e fontes Base64 antigas ficam somente como legado de migração.

## O que a v0.6.0 entrega

### Temporada e competições
- contexto interno por organização, equipe e temporada;
- histórico unificado FPB + LBC + scouts do ARCO;
- filtros por liga, categoria, temporada e status;
- jogos de demonstração separados do histórico oficial;
- nomes oficiais/variações de Tupã reconhecidos;
- modelo federativo **CBB → FPB → clube/equipe**;
- cache e busca histórica pública da FPB em modo best-effort.

### Scout
- scout ao vivo;
- período, placar, atleta da ação e lineup em quadra;
- 2PT, 3PT, lance livre, assistências, rebotes, roubos, tocos, turnovers e faltas;
- pontos adversários;
- desfazer último evento;
- shot chart por toque na quadra com coordenadas reais;
- persistência local de scouts finalizados;
- funcionamento do scout sem depender da rede durante a partida.

### Analytics
- eFG%, ORtg, DRtg, Net Rating;
- TOV%, ORB% e FT Rate;
- Four Factors;
- lineups e confiança por tamanho da amostra;
- comparação de últimos jogos com temporada;
- shot chart real quando houver coordenadas;
- ARCO Impact experimental;
- motor de insights.

### Decisão
- central de adversários;
- Game Plan baseado na amostra registrada;
- timeline de eventos;
- vínculo de vídeo do YouTube;
- abertura aproximada do vídeo no timestamp de cada evento;
- relatório de temporada copiável;
- ARCO Assistant local baseado exclusivamente nos dados do app.

### Acesso
- sessão demo separada;
- senha demo removida do código;
- papéis: administrador, treinador, analista e atleta;
- matriz de permissões;
- gateway opcional de autenticação Supabase por variáveis de build.

## Integrações externas: limites reais

### CBB / FPB
O modelo federativo está preparado para CBB e FPB. O ARCO **não inventa número de registro oficial**. Um identificador oficial só deve ser salvo quando obtido de fonte autorizada.

A leitura pública da FPB é uma integração best-effort e pode exigir manutenção se o HTML do site mudar. Para produção comercial em larga escala, o caminho preferido é feed/API oficial ou licenciado.

### LBC
A LBC permanece como provider separado e cacheável. Não é apresentado como API oficial quando não há feed oficial configurado.

### Supabase
O código aceita autenticação Supabase, mas o APK padrão é entregue em modo demo enquanto não forem configuradas:

- `ARCO_AUTH_PROVIDER=supabase`
- `ARCO_SUPABASE_URL`
- `ARCO_SUPABASE_ANON_KEY`

## Estrutura

- `lib/models/` — entidades e contexto;
- `lib/services/` — analytics, integrações, auth, persistência e Assistant;
- `lib/state/` — estado do aplicativo;
- `lib/screens/` — interface;
- `lib/widgets/` — componentes;
- `test/` — testes automatizados;
- `web/` — PWA/Web;
- `api/` — proxies externos;
- `docs/` — documentação;
- `.github/workflows/` — CI/CD.

## Builds

O workflow **ARCO - Build Multiplataforma** valida:

1. `flutter pub get`;
2. `flutter analyze`;
3. `flutter test`;
4. Android APK/AAB;
5. Web/PWA;
6. Windows;
7. iOS unsigned.

Application ID Android:

`com.arcoanalytics.app`

## Versão

`0.6.0+6`

A v0.6.0 é um **MVP integrado**, não uma declaração de integração oficial/licenciada com CBB/FPB nem de backend cloud ativo.
