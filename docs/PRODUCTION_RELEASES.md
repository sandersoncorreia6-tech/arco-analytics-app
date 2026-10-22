# ARCO — produção e atualizações

## Identidade fixa do Android
- Application ID: `com.arcoanalytics.app`
- Versão atual: `0.5.0+5`
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
Para v0.6.0, altere apenas em `pubspec.yaml`:
`version: 0.6.0+6`

O número depois de `+` deve sempre aumentar.

## Builds
- Android: `.github/workflows/android-release.yml`
- Web/PWA: `.github/workflows/web-build.yml`
- GitHub Pages: `.github/workflows/deploy-pages.yml`
