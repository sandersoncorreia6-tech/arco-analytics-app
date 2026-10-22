# ARCO — produção e atualizações

## Identidade fixa do Android
- Application ID: `com.arcoanalytics.app`
- Versão atual: `0.6.0+6`
- Alias da chave de produção: `arco-prod`

Nunca altere o Application ID depois de distribuir o app.
Nunca perca a chave de assinatura. Sem ela, o Android não aceita atualizações do mesmo aplicativo.

## GitHub Secrets necessários
No repositório: Settings → Secrets and variables → Actions → New repository secret.

Crie:
- `ARCO_KEYSTORE_BASE64`
- `ARCO_KEYSTORE_PASSWORD`
- `ARCO_KEY_ALIAS`
- `ARCO_KEY_PASSWORD`

A chave JKS NÃO deve ser enviada ao repositório.

## Próxima versão
Para v0.7.0, altere em `pubspec.yaml` (e em `lib/config/app_config.dart`):
`version: 0.7.0+7`

O número depois de `+` deve sempre aumentar.

## Builds
- Android, Web/PWA, Windows e iOS: `.github/workflows/build.yml` (ARCO Build)
- GitHub Pages: `.github/workflows/deploy-pages.yml` (manual)

Sem os secrets, o APK é assinado com chave de teste (artefato `...-teste`). Ele não instala
por cima de um APK assinado com a chave oficial (e vice-versa): desinstale antes.

## Assinatura local
Crie `android/key.properties` (nunca commitar):
```
storePassword=...
keyPassword=...
keyAlias=arco-prod
storeFile=arco-upload-keystore.jks
```
e coloque a chave em `android/app/arco-upload-keystore.jks`.
