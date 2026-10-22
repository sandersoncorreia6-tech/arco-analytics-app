# ARCO Web / PWA

A v0.4 usa o mesmo código Flutter/Dart do Android e adiciona uma interface responsiva para navegador.

## Alvos
- Android: APK
- iPhone/iPad: Safari + Adicionar à Tela de Início (PWA)
- PC/Mac: navegador; menu lateral em telas largas

## Build local
```bash
flutter create . --platforms=web --org com.arcoanalytics
flutter pub get
flutter build web --release
```

## GitHub Pages
O workflow `deploy-pages.yml` publica a interface. Atenção: GitHub Pages é hospedagem estática e não executa o endpoint `/api/fpb-online`. Portanto, a tela FPB Live na web precisa de um backend/proxy externo (por exemplo Vercel) ou de uma API oficial.

## Vercel / produção recomendada
O arquivo `api/fpb-online.js` funciona como proxy serverless para a fonte pública da FPB. A interface web consulta `/api/fpb-online`, evitando bloqueio CORS do navegador.

Para produção comercial, substitua o parser público por uma API/feed oficialmente licenciado assim que disponível.
