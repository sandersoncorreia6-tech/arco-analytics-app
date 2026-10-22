# Estrutura do repositório ARCO Analytics

Este repositório usa o código-fonte Flutter diretamente na raiz.

## Diretórios principais
- lib/: aplicação Flutter
- web/: PWA/Web
- api/: integrações/proxies web
- docs/: documentação
- .github/workflows/: CI/CD
- scripts/: automações de build/release

## Regra
Novas versões devem alterar o código-fonte diretamente. ZIPs e fontes Base64 são mantidos apenas temporariamente durante a migração e não devem ser a fonte oficial de build.
