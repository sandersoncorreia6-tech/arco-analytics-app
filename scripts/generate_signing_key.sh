#!/usr/bin/env bash
set -euo pipefail
OUT="${1:-arco-upload-keystore.jks}"
ALIAS="${ARCO_KEY_ALIAS:-arco-prod}"
: "${ARCO_KEYSTORE_PASSWORD:?Defina ARCO_KEYSTORE_PASSWORD antes de executar}"
: "${ARCO_KEY_PASSWORD:=$ARCO_KEYSTORE_PASSWORD}"
keytool -genkeypair -v \
  -keystore "$OUT" \
  -alias "$ALIAS" \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -storepass "$ARCO_KEYSTORE_PASSWORD" \
  -keypass "$ARCO_KEY_PASSWORD" \
  -dname "CN=ARCO Analytics, OU=Mobile, O=ARCO Analytics, L=Tupa, ST=SP, C=BR"
echo "Chave criada em $OUT. Faça backup seguro e nunca coloque-a no Git."
