# ARCO Analytics

Plataforma Flutter/Dart de inteligência estatística para treinadores de basquete.
**Dado → Contexto → Insight → Decisão**

Versão: `0.8.0+8` • Application ID Android: `com.arcoanalytics.app` (não alterar)

## Novo na 0.8: Analista ARCO

O treinador pergunta e o ARCO responde com números: onde o time mais erra, por que perdeu,
"e se tivéssemos acertado os lances livres", em qual quarto cai, melhor formação, o que
treinar, como joga o próximo adversário. Relatórios pós-jogo, pré-jogo e da temporada saem
em PDF ou direto no WhatsApp. O vídeo do jogo fica sincronizado com o scout (cada ação abre
no segundo exato) e gera clipes por filtro.

Nuvem: o banco Supabase está pronto e testado (`supabase/`); falta criar o projeto e
informar URL/chave — passo a passo em [docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md).

## Novo na 0.7: estatísticas completas

A aba **Stats** importa a estatística online das partidas (padrão FIBA LiveStats, usado na
aba Estatística/Online das federações): todas as equipes, todos os jogadores, box score,
**mapa de arremessos** (onde cada cesta foi feita ou errada) e lance a lance. As partidas são
descobertas automaticamente nos links das páginas da FPB; qualquer jogo também pode ser
importado colando o link da página de estatística (botão 🔗 na aba Stats).

> A estatística online registra posição apenas para **arremessos**. Rebotes, assistências,
> roubos etc. aparecem por jogador e no lance a lance, sem coordenada na quadra.

## O que mudou na 0.6 (correção da transmissão FPB/LBC)

- **APK sem acesso à internet** — o APK de release era gerado sem a permissão `INTERNET`
  no `AndroidManifest.xml`, então nenhuma consulta à FPB/LBC saía do aparelho. A pasta
  `android/` agora faz parte do repositório, já com a permissão, e o CI falha se ela sumir.
- **App fechando ao abrir** — o script antigo `configure_android_prod.py` trocava o
  `namespace` do Android e o `MainActivity` deixava de ser encontrado. Removido; só o
  `applicationId` é fixado.
- **Leitura das páginas refeita** (`lib/services/schedule_parser.dart`): o parser antigo
  colava o texto de células vizinhas (`Tupã78`) e o id do jogo mudava a cada ponto, o que
  apagava o vídeo vinculado. O novo lê tabelas, cards, listas, JSON embutido
  (schema.org/Next.js) e texto livre, e tem testes automatizados.
- **Plano B quando o site muda**: "Colar jogos" (texto copiado do site, PDF ou WhatsApp),
  "Fontes" (páginas extras do mesmo site, ex.: a tabela da sua categoria) e
  "Diagnóstico" (status HTTP, tamanho e jogos reconhecidos por página).
- Mensagens de erro claras, nova tentativa automática, cache que não é apagado quando a
  fonte falha, sincronização a cada 30 s com jogo ao vivo (3 min sem) e pausa com o app
  em segundo plano.
- Elenco, histórico de jogos e **scout em andamento** agora ficam salvos no aparelho.

Detalhes em [CHANGELOG.md](CHANGELOG.md).

## Plataformas

| Plataforma | Como gerar |
|---|---|
| Android APK/AAB | workflow **ARCO Build** (automático a cada push) ou `./build_android.sh` |
| Web/PWA (iPhone, iPad, PC) | workflow **ARCO Build** → artefato `ARCO-Web-PWA` |
| Windows | **ARCO Build** na `main` ou manual |
| iOS sem assinatura | **ARCO Build** manual (Run workflow) |

Baixe os arquivos em **Actions → ARCO Build → (execução) → Artifacts**.

### Assinatura Android
Com os secrets `ARCO_KEYSTORE_BASE64`, `ARCO_KEYSTORE_PASSWORD`, `ARCO_KEY_ALIAS` e
`ARCO_KEY_PASSWORD` configurados, o artefato sai como `ARCO-Android-APK-assinado`.
Sem eles, sai `ARCO-Android-APK-teste` (assinado com chave de debug): instala normalmente,
mas o Android não aceita instalá-lo **por cima** de um APK assinado com outra chave —
nesse caso desinstale a versão anterior. Veja [docs/PRODUCTION_RELEASES.md](docs/PRODUCTION_RELEASES.md).

## Desenvolvimento

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Requer Flutter 3.35 ou mais novo (o CI usa 3.47.7).

## Integrações FPB/LBC
Ver [docs/FPB_INTEGRATION.md](docs/FPB_INTEGRATION.md). Na Web, o navegador exige o
proxy `api/*.js` (Vercel); o APK consulta os sites diretamente.

## Arquivos antigos
`arco_analytics_build_ready.zip` e `arco_analytics_v0_5_coach_hub.zip` são pacotes
históricos e não são usados nos builds. A antiga fonte v0.4 em base64 (`.source/`)
foi substituída pelo código-fonte deste repositório.
