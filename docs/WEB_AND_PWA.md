# ARCO Web / PWA

O ARCO usa o mesmo código Flutter/Dart do Android e adiciona uma interface responsiva para navegador.

## Alvos
- Android: APK
- iPhone/iPad: Safari + Adicionar à Tela de Início (PWA)
- PC/Mac: navegador; menu lateral em telas largas

## Build local
```bash
flutter pub get
flutter build web --release
```

## GitHub Pages
O workflow `deploy-pages.yml` (manual) publica a interface. GitHub Pages é hospedagem estática e não executa `/api/fpb-online` nem `/api/lbc-online`. Publique os proxies na Vercel e configure a variável do repositório `ARCO_PROXY_BASE_URL` (Settings → Secrets and variables → Actions → Variables) com a URL do deploy; o build Web passa a usá-la.

## Vercel / produção recomendada
Os arquivos `api/fpb-online.js` e `api/lbc-online.js` são proxies serverless (com CORS e timeout) para as fontes públicas. A interface web consulta `/api/fpb-online` e `/api/lbc-online`, evitando o bloqueio CORS do navegador. Páginas extras (`?url=`) só são aceitas dos domínios da FPB/LBC.

Para produção comercial, substitua o parser público por uma API/feed oficialmente licenciado assim que disponível.
