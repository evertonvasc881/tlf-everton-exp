#!/usr/bin/env bash
# apply-policies.sh — Aplica políticas Anypoint API Manager para tlf-everton-exp
#
# USO:
#   ./scripts/apply-policies.sh <ENV_ID> <API_MANAGER_ID>
#
# EXEMPLO:
#   ./scripts/apply-policies.sh a1b2c3d4-dev 12345678
#
# REQUISITOS:
#   - CLIENT_ID e CLIENT_SECRET exportados (ou passados via env)
#   - curl disponível no PATH
#
# VARIÁVEIS DE AMBIENTE (obrigatórias se não fornecidas via .env):
#   ANYPOINT_CLIENT_ID     — Connected App Client ID com escopo API Manager
#   ANYPOINT_CLIENT_SECRET — Connected App Client Secret

set -euo pipefail

ORG_ID="5834a905-793c-4621-9565-b8bc11830a87"
ANYPOINT_BASE="https://anypoint.mulesoft.com"

ENV_ID="${1:?Informe o Environment ID como primeiro argumento}"
API_ID="${2:?Informe o API Manager ID como segundo argumento}"

CLIENT_ID="${ANYPOINT_CLIENT_ID:?Variável ANYPOINT_CLIENT_ID não definida}"
CLIENT_SECRET="${ANYPOINT_CLIENT_SECRET:?Variável ANYPOINT_CLIENT_SECRET não definida}"

echo "==> [1/3] Obtendo access token..."
TOKEN_RESPONSE=$(curl -s -X POST "${ANYPOINT_BASE}/accounts/api/v2/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}")

ACCESS_TOKEN=$(echo "${TOKEN_RESPONSE}" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)

if [ -z "${ACCESS_TOKEN}" ]; then
  echo "ERRO: Falha ao obter access token. Resposta: ${TOKEN_RESPONSE}"
  exit 1
fi
echo "    Token obtido."

# -----------------------------------------------------------------------------
# Política 1 — JSON Threat Protection
# Bloqueia payloads maliciosos: JSON profundamente aninhado, arrays massivos, etc.
# -----------------------------------------------------------------------------
echo "==> [2/3] Aplicando JSON Threat Protection..."
JSON_TP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "${ANYPOINT_BASE}/apimanager/api/v1/organizations/${ORG_ID}/environments/${ENV_ID}/apis/${API_ID}/policies" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "configurationData": {
      "maxContainerDepth": 10,
      "maxStringValueLength": 512,
      "maxObjectEntryNameLength": 256,
      "maxObjectEntryCount": 20,
      "maxArrayElementCount": 50
    },
    "pointcutData": null,
    "assetId": "json-threat-protection",
    "assetVersion": "1.3.3",
    "groupId": "68ef9520-24e9-4cf2-b2f5-620025690913"
  }')

if [ "${JSON_TP_RESPONSE}" = "201" ] || [ "${JSON_TP_RESPONSE}" = "200" ]; then
  echo "    JSON Threat Protection aplicado (HTTP ${JSON_TP_RESPONSE})."
else
  echo "AVISO: JSON Threat Protection retornou HTTP ${JSON_TP_RESPONSE}."
  echo "       Verifique manualmente no API Manager se a política já existe (409 = já aplicada)."
fi

# -----------------------------------------------------------------------------
# Política 2 — Client ID Enforcement
# Garante que somente apps registradas no Exchange consomem esta API.
# -----------------------------------------------------------------------------
echo "==> [3/3] Aplicando Client ID Enforcement..."
CLIENT_ENF_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST "${ANYPOINT_BASE}/apimanager/api/v1/organizations/${ORG_ID}/environments/${ENV_ID}/apis/${API_ID}/policies" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "configurationData": {
      "credentialsOriginHasHttpBasicAuthenticationHeader": "customExpression",
      "clientIdExpression": "#[attributes.headers['\''client_id'\'']]",
      "clientSecretExpression": "#[attributes.headers['\''client_secret'\'']]"
    },
    "pointcutData": null,
    "assetId": "client-id-enforcement",
    "assetVersion": "1.3.2",
    "groupId": "68ef9520-24e9-4cf2-b2f5-620025690913"
  }')

if [ "${CLIENT_ENF_RESPONSE}" = "201" ] || [ "${CLIENT_ENF_RESPONSE}" = "200" ]; then
  echo "    Client ID Enforcement aplicado (HTTP ${CLIENT_ENF_RESPONSE})."
else
  echo "AVISO: Client ID Enforcement retornou HTTP ${CLIENT_ENF_RESPONSE}."
  echo "       Verifique manualmente no API Manager (409 = já aplicada)."
fi

echo ""
echo "==> Políticas aplicadas. Verifique em:"
echo "    ${ANYPOINT_BASE}/apimanager/api/v1/organizations/${ORG_ID}/environments/${ENV_ID}/apis/${API_ID}/policies"
