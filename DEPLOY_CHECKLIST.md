# Deploy Checklist — tlf-everton-exp

> Gerado pelo agente `ms-devops` em 2026-06-16.
> Este checklist e obrigatorio antes de qualquer deploy.

---

## PRE-DEPLOY DEV

### Build e Testes
- [ ] `mvn clean package -DskipTests=false` executado localmente sem erros
- [ ] MUnit: todos os 5 testes passando (happy path, cnpj bloqueado, backend 404, http:connectivity, healthz)
- [ ] Cobertura MUnit >= 75% (requiredApplicationCoverage configurado no pom.xml)
- [ ] Sem warnings de compilacao DataWeave

### Configuracao
- [ ] `pom.xml` — artifactId: `tlf-everton-exp`, version: `1.0.0`, packaging: `mule-application`
- [ ] `pom.xml` — RAML dep: groupId=`5834a905-793c-4621-9565-b8bc11830a87`, classifier=`raml`, type=`zip` (versao 1.0.0)
- [ ] `pom.xml` — runtime: `4.9-java17`, mule-maven-plugin: `4.3.0`
- [ ] `mule-artifact.json` — configs na ordem: `common/global.xml`, `tlf-everton-exp.xml`, `common/request.xml`
- [ ] `mule-artifact.json` — secureProperties: todos os 6 campos declarados
- [ ] `dev.yaml` — listener.port: `8091`, request.server.tlf-sales-sys.host preenchido
- [ ] Keystore placeholder em `src/main/resources/keystores/dev-Mule-truststore.jks.placeholder` presente (nao bloqueia dev)

### Secrets GitHub (Environment: dev)
- [ ] `ANYPOINT_CLIENT_ID` configurado
- [ ] `ANYPOINT_CLIENT_SECRET` configurado
- [ ] `MULE_SECURITY_KEY` configurado
- [ ] `DEV_API_MANAGER_ID` configurado
- [ ] `DEV_REQUEST_SYS_CLIENT_ID` configurado
- [ ] `DEV_REQUEST_SYS_CLIENT_SECRET` configurado
- [ ] `DEV_TRUSTSTORE_PASSWORD` configurado

---

## POS-DEPLOY DEV

- [ ] Health check `GET /healthz` retorna HTTP 200 em < 5s
- [ ] Resposta do healthz: `{ "msg": "API is healthy." }`
- [ ] App visivel no Anypoint CloudHub 2.0 como `dev-tlf-everton-exp` com status STARTED
- [ ] Logs nao contem CNPJ em texto claro (validar no Anypoint Monitoring)
- [ ] Autodiscovery registrado no API Manager (verificar em Runtime Manager > Applications)

---

## PRE-DEPLOY HMG

- [ ] Deploy DEV concluido e health check aprovado
- [ ] `hmg.yaml` revisado — host: `fenix-lb-hmg.telefonica.com.br`
- [ ] Secrets GitHub (Environment: hmg) configurados analogamente ao dev
- [ ] Testes de integracao executados em DEV sem erros

---

## POS-DEPLOY HMG

- [ ] Health check `GET /healthz` retorna HTTP 200 em < 5s em HMG
- [ ] Teste de smoke: `GET /com/order/v1/getOrderFlight-e/{cnpj}` com CNPJ valido retorna 200
- [ ] Teste de contrato: resposta contem `flagBloqueio` (boolean) e `ordem` (array)
- [ ] App Manager HMG: Client ID Enforcement ativo
- [ ] Aprovacao de QA registrada

---

## PRE-DEPLOY PROD

> ATENCAO: Estes itens sao BLOQUEADORES. Deploy em prod nao deve ocorrer sem todos marcados.

### Bloqueadores de Seguranca (CRITICOS para prod)

- [x] **[RESOLVIDO] TLS insecure=false**: `insecure="false"` aplicado em `common/global.xml` em 2026-06-16. Valido para todos os ambientes.
- [ ] **[BLOQUEADOR] Keystore real provisionado**: substituir os placeholders `.jks.placeholder` pelo JKS real em `src/main/resources/keystores/` para cada ambiente (dev/hmg/prod). Configurar senha via secret `*_TRUSTSTORE_PASSWORD` no GitHub Actions.
- [x] **[RESOLVIDO] API Console removido**: flow `tlf-everton-exp-console` removido de `tlf-everton-exp.xml` em 2026-06-16. O endpoint `/console/*` nao esta mais presente no codigo.
- [ ] **[BLOQUEADOR] JSON Threat Protection ativo no API Manager**: executar `scripts/apply-policies.sh <ENV_ID> <API_MANAGER_ID>` após o deploy. Script aplica a policy via REST API com maxContainerDepth=10, maxStringValueLength=512, maxArrayElementCount=50.
- [ ] **[BLOQUEADOR] Client ID Enforcement confirmado**: o mesmo script `apply-policies.sh` também aplica Client ID Enforcement. Executar uma vez após o deploy em cada ambiente.

### Revisao LGPD
- [ ] Revisao LGPD aprovada — CNPJ mascarado nos logs (corrigido pelo ms-security em 2026-06-16)
- [ ] Nenhum dado pessoal exposto em logs de aplicacao

### Configuracao Prod
- [ ] `prod.yaml` revisado — host: `fenix-lb-prod.telefonica.com.br`
- [ ] `prod.yaml` — TLS: `insecure: "false"` e truststore configurado
- [ ] Secrets GitHub (Environment: prod) configurados:
  - [ ] `PROD_MULE_SECURITY_KEY`
  - [ ] `PROD_API_MANAGER_ID`
  - [ ] `PROD_REQUEST_SYS_CLIENT_ID`
  - [ ] `PROD_REQUEST_SYS_CLIENT_SECRET`
  - [ ] `PROD_TRUSTSTORE_PASSWORD`
- [ ] GitHub Environment `prod` com revisores obrigatorios configurados
- [ ] Worker sizing revisado: `SMALL` (minimo recomendado para prod)
- [ ] Deploy via `workflow_dispatch` com `deploy_reason` preenchida
- [ ] Janela de mudanca aprovada (ITSM/JIRA)

---

## POS-DEPLOY PROD

- [ ] Health check `GET /healthz` retorna HTTP 200 em < 5s
- [ ] App Manager PROD: status STARTED, sem erros no log de inicializacao
- [ ] Anypoint Monitoring dashboard criado para `prod-tlf-everton-exp`
- [ ] Alertas configurados no Anypoint Monitoring:
  - [ ] Taxa de erro > 1% em 5 minutos → notificacao
  - [ ] Latencia P95 > 30s → notificacao
  - [ ] JVM Heap > 80% → notificacao
- [ ] Teste de smoke em prod com CNPJ de teste (nao de cliente real)
- [ ] Smoke test registrado no JIRA com evidencia de screenshot

---

## Rollback

Em caso de falha no deploy prod:

1. Acessar Anypoint CloudHub 2.0 > Applications > `prod-tlf-everton-exp`
2. Selecionar versao anterior em "Deployment History"
3. Clicar "Redeploy" na versao estavel anterior
4. Confirmar health check apos rollback
5. Registrar incidente no JIRA com causa raiz

---

## Referencias

| Recurso | URL |
|---|---|
| Anypoint Platform | https://anypoint.mulesoft.com |
| Exchange — tlf-everton-exp | https://anypoint.mulesoft.com/exchange/5834a905-793c-4621-9565-b8bc11830a87/tlf-everton-exp/1.0.0/ |
| Pipeline GitHub Actions | `.github/workflows/deploy.yml` |
| PROJECT.md | `mule-apps/tlf-everton-exp/PROJECT.md` |
