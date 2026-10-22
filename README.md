# ARCO Analytics

Repositório oficial de build do ARCO Analytics.

## Fonte oficial atual

A versão usada pelos builds é **ARCO Analytics v0.4 Multiplatform**.

O pacote original é preservado em partes de texto em `.source/v0_4/`. Antes de qualquer compilação, o GitHub Actions reconstrói o ZIP e valida o SHA-256:

`247421b7dfbf944fcd7cbd4d7c5a775d7afe01443b322a08d578d0934ee7fd6d`

Isso impede que um ZIP antigo seja compilado por engano.

## Builds

O workflow **Build ARCO Multiplatform** gera, a partir da mesma fonte:

- Android APK — instalação direta.
- Android AAB — pacote para publicação na Google Play; para produção é necessário configurar a assinatura da loja.
- Web/PWA — funciona em navegadores e pode ser instalado no iPhone/iPad pelo Safari e em PCs compatíveis.
- Windows — build nativo para PC.
- iOS unsigned — build técnico sem assinatura. Para TestFlight/App Store ou instalação nativa em iPhone é necessário configurar certificados e conta Apple Developer.

O workflow **Build ARCO APK (manual)** continua disponível apenas como atalho manual para gerar o APK Android.

## Arquivos antigos

Os ZIPs `arco_analytics_build_ready.zip` e `arco_analytics_v0_5_coach_hub.zip` permanecem no histórico do repositório, mas **não são usados pelos workflows oficiais atuais**.

## Como gerar

Abra **Actions** no GitHub e execute **Build ARCO Multiplatform**, ou faça uma alteração na fonte oficial em `.source/v0_4/`.
