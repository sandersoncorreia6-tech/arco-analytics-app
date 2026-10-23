# Estrutura oficial do ARCO Analytics

A fonte Flutter fica diretamente na raiz do repositório.

- `lib/`: aplicação, telas, modelos, estado e serviços
- `web/`: Web/PWA
- `api/`: integrações/proxies
- `docs/`: documentação técnica e de produto
- `scripts/`: automações de build/release
- `.github/workflows/`: CI/CD

## Regra de desenvolvimento
O código-fonte na raiz é a fonte oficial. ZIPs e fragmentos Base64 são legados temporários de migração e não devem receber novas funcionalidades.
