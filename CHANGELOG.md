# Changelog

## 0.7.0+7 — Estatísticas completas (aba Estatística/Online)
### Novo
- Importação da estatística online no padrão FIBA LiveStats: box score de todas as equipes e
  jogadores (MIN, PTS, REB O/D, AST, ROB, TOC, ERR, FLT, FG/3P/LL, +/-, eficiência).
- Mapa de arremessos em meia quadra com medidas FIBA (cesta ● / erro ✕), filtros por equipe,
  jogador e período, e aproveitamento por zona (garrafão, meia distância, 3 da zona morta, 3 frontal).
- Lance a lance de cada partida (rebotes, assistências, roubos, faltas, substituições...).
- Temporada agregada: médias, eficiência por 100 posses, four factors, líderes e jogo a jogo.
- Aba "Stats" (Equipes / Jogadores / Jogos); estatísticas da minha equipe na Home e no Analytics.
- Descoberta automática das partidas nos links da FPB e importação manual pelo link do jogo.
- Programação e resultados da base lidos das notícias da FPB (API pública do WordPress),
  com data do cabeçalho ("Sábado – 18/04") e categoria (S16M → SUB 16 M).
- Elenco real da equipe pode substituir o elenco demo da aba Equipe.
- Páginas extras de qualquer site no app (ex.: endereço atual da LBC).
- Proxy Web `api/livestats`.

## 0.6.0+6 — Correção da transmissão FPB/LBC
### Corrigido
- APK de release sem permissão `INTERNET`: a sincronização FPB/LBC falhava sempre no aparelho.
- Troca de `namespace` no build Android fazia o app fechar ao abrir (MainActivity não encontrada).
- Parser colava textos de células vizinhas e não reconhecia jogos em tabelas/cards.
- Id do jogo mudava a cada atualização de placar, perdendo o vídeo vinculado.
- Falha de rede ou página vazia apagava os jogos já salvos.
- Cache antigo podia sobrescrever dados recém-baixados na abertura do app.
- Erros da FPB não apareciam na tela de Competições.
- Telas de Jogos/Scout e FPB ao vivo estavam inacessíveis pela navegação.
- Cartões de métricas estouravam o layout em celulares de tela estreita.
- Rebotes ofensivos disponíveis eram contados em dobro no fechamento do scout.
- Workflow de deploy do GitHub Pages com `environment` inválido.

### Novo
- Parser genérico com testes: tabelas, cards, listas, JSON-LD/JSON embutido e texto livre.
- "Colar jogos", "Fontes" (páginas extras do site da liga) e "Diagnóstico" de conexão.
- Mensagens de erro em português, nova tentativa automática e identificação como navegador.
- Sincronização adaptativa (30 s ao vivo / 3 min) e pausa em segundo plano.
- Filtros "Minha equipe" e "Ao vivo"; próximo jogo da equipe na Home.
- Persistência de elenco, histórico de jogos e scout em andamento.
- Prorrogação no scout ao vivo.
- Ícone do ARCO no Android e nome "ARCO Analytics" no launcher.
- Proxies Web com CORS, timeout e páginas extras restritas ao domínio da liga.
- CI único (`ARCO Build`): análise + testes antes de gerar APK/AAB/Web; assinatura opcional.

## 0.5.0+5 — Production-ready repository
- Coach Hub e login demo de Adriano Mião
- Tupã / Monstrinho
- Hub FPB + LBC
- vídeos de partidas via YouTube
- Web/PWA
- Application ID estável `com.arcoanalytics.app`
- workflow Android assinado com GitHub Secrets
- geração de APK + AAB
- workflow Web/PWA e GitHub Pages
- versionamento preparado para atualização sem desinstalar
