# ARCO Analytics — v0.5 Coach Hub

Plataforma Flutter/Dart de inteligência para treinadores de basquete.

**Dado → Contexto → Insight → Decisão**

## Novidades v0.5

- Login/área do treinador
- Conta demo preparada para **Adriano Mião**
- Organização demo: **Tupã / Monstrinho**
- Home personalizada com insights da equipe
- Central de competições **FPB + LBC**
- Filtro por liga, categoria e equipe
- Sincronização/caches independentes para FPB e LBC
- Página/ficha de jogo com acesso à fonte oficial
- Associação de vídeo do YouTube a qualquer partida
- Vídeos salvos localmente para teste
- Continua compatível com Android APK + Web/PWA + desktop web

## Login demo

- E-mail: `adriano.miao@arco.app`
- Senha: `ARCO-DEMO`
- Também existe botão de acesso demo em um toque.

> Não use essas credenciais como segurança real. Elas existem apenas para demonstrar o fluxo. Produção deve usar Firebase/Supabase/backend próprio.

## Competições

### FPB
O serviço FPB continua desacoplado e consulta a página pública através de `lib/services/fpb_live_service.dart`.

### LBC
A v0.5 adiciona `lib/services/lbc_live_service.dart` apontando para `https://www.lbc.org.br/`. Na Web, o acesso pode passar pelo proxy `/api/lbc-online` para evitar CORS.

Como sites externos podem mudar estrutura, os conectores são experimentais. Para operação comercial, priorizar feed/API/licenciamento oficial quando disponível.

## Vídeos de jogos

Na tela **Competições**, cada jogo tem botão de vídeo. O treinador pode colar um link do YouTube e depois abrir o vídeo. O vínculo é salvo com SharedPreferences nesta versão.

## Analytics já existentes

- eFG%
- TS%
- Offensive Rating
- Defensive Rating
- Net Rating
- TOV%
- ORB%
- FT Rate
- On/Off
- ARCO Impact Score experimental
- confiança de amostra
- Four Factors
- Lineup Analytics
- motor de insights
- scout ao vivo

## APK

Com Flutter instalado:

```bash
flutter create . --platforms=android,web
flutter pub get
flutter build apk --release
```

APK em:
`build/app/outputs/flutter-apk/app-release.apk`

## Web/PWA

```bash
flutter create . --platforms=android,web
flutter pub get
flutter build web --release
```

Arquivos em `build/web/`.

## Próximas evoluções

1. Autenticação real e multiusuário
2. Banco cloud por clube/equipe
3. Permissões: técnico, auxiliar, analista e atleta
4. Calendário completo por temporada e categoria
5. Persistência cloud de vídeos, jogos e insights
6. Integração oficial com dados FPB/LBC quando disponível
7. Scout automático do próximo adversário
8. ARCO Assistant consultando dados do clube

Mais detalhes em `docs/COACH_LOGIN_AND_LEAGUES.md`.
