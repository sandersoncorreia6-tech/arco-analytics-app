# ARCO Analytics — Pacote completo para desenvolvimento

Este pacote contém o projeto ARCO Analytics preparado para:

- Android (APK)
- Android App Bundle (AAB)
- Web
- PWA
- GitHub Actions
- Deploy Web
- Integrações experimentais com FPB e LBC
- Login/demo do treinador Adriano Mião — Tupã / Monstrinho
- Associação de vídeos do YouTube aos jogos

## 1. Tecnologia

- Flutter
- Dart
- Android
- Web/PWA
- GitHub Actions

## 2. Identidade do aplicativo

Application ID oficial:

`com.arcoanalytics.app`

Não alterar este ID se a intenção for manter futuras atualizações do mesmo aplicativo.

## 3. Rodar localmente

Instale Flutter e execute:

```bash
flutter pub get
flutter run
```

## 4. Gerar APK

```bash
./build_android.sh
```

A pasta `android/` já vem pronta (permissão de internet, ícone, applicationId e
assinatura). Não rode `flutter create` por cima dela.

Saída esperada:

`build/app/outputs/flutter-apk/app-release.apk`

## 5. Gerar AAB

```bash
flutter build appbundle --release
```

Saída esperada:

`build/app/outputs/bundle/release/app-release.aab`

## 6. Gerar versão Web

```bash
flutter pub get
flutter build web --release
```

Saída:

`build/web/`

## 7. Assinatura Android

A chave privada NÃO está incluída neste pacote.

Para builds oficiais assinados pelo GitHub Actions, configure estes Repository Secrets:

- `ARCO_KEYSTORE_BASE64`
- `ARCO_KEYSTORE_PASSWORD`
- `ARCO_KEY_ALIAS`
- `ARCO_KEY_PASSWORD`

O responsável pelo projeto deve fornecer/configurar esses valores diretamente no repositório.
Nunca colocar senhas ou arquivo `.jks` dentro do Git.

## 8. GitHub Actions

Os workflows ficam em:

`.github/workflows/`

O principal é:

`build.yml` (ARCO Build)

Ele gera:

- APK
- AAB

Ele também gera Web/PWA (e Windows/iOS na main ou manualmente). O deploy no GitHub Pages é `deploy-pages.yml`.

## 9. Web/PWA e integrações

O projeto possui estrutura Web/PWA e endpoints/proxies para integrações públicas.

Arquivos importantes:

- `web/`
- `api/`
- `vercel.json`

Para publicação com proxies serverless, Vercel é uma opção adequada.

## 10. Observação sobre FPB/LBC

As integrações com sites públicos são experimentais. Mudanças no HTML, CORS ou disponibilidade dos sites podem exigir manutenção.

Para uso comercial em escala, considerar API/licenciamento oficial de dados.

## 11. Segurança

Não publicar no repositório:

- chaves `.jks`
- passwords
- arquivos de backup de assinatura
- valores de GitHub Secrets

## 12. Versão

ARCO Analytics v0.6.0 — veja o CHANGELOG para as correções da transmissão FPB/LBC.

Objetivo do produto:

**Dado → Contexto → Insight → Decisão**
