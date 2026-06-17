# PROJECT: tlf-everton-exp

> Documentação viva — atualizada automaticamente pelo time de agentes MuleSoft.
> Cada seção é preenchida pelo agente responsável ao concluir sua etapa.

---

## Visão Geral

| Campo | Valor |
|---|---|
| **Nome** | `tlf-everton-exp` |
| **Camada API-led** | Experience |
| **Versão atual** | `1.0.0` |
| **Org Anypoint** | `5834a905-793c-4621-9565-b8bc11830a87` |
| **Última atualização** | `2026-06-16` |

**Descrição:**
> API Experience que expõe consulta de ordens de voo (getOrderFlight) para o sistema VE, fazendo interface com o backend TLF-SALES-SYS (COM/SALESFORCE). Endpoint principal: GET /com/order/v1/getOrderFlight-e (URI param: cnpj). Retorna flag de bloqueio e lista de ordens com tipo, número, status e data de criação.

**Dependências:**
- Upstream: VE (consumidor — frontend que inicia a consulta)
- Downstream: TLF-SALES-SYS (System API — COM/SALESFORCE, GET /com/v1/getOrderFlight-s)

---

## [ms-architect] Decisões de Arquitetura

> Preenchido pelo agente `ms-architect` a cada revisão.

### Decisões Tomadas

| Decisão | Justificativa | Data |
|---|---|---|
| Experience API chama System API diretamente (sem Process Layer) | Fluxo é passthrough puro: sem agregação, sem orquestração multi-sistema, sem lógica de negócio adicional. Introduzir uma Process API seria over-engineering que aumenta latência e custo operacional sem benefício arquitetural. Padrão MuleSoft permite supressão da camada de processo em casos de mapeamento 1-to-1. | 2026-06-16 |
| Padrão síncrono GET | Consulta de dados em tempo real onde o consumidor (VE) aguarda resposta imediata. Não há processamento assíncrono ou eventual consistency envolvida. Síncrono é o padrão correto. | 2026-06-16 |
| APIkit com roteamento via flow reutilizável `request-global-sys` | Isola a lógica de chamada HTTP ao sistema downstream em um sub-flow reutilizável. Facilita mock em testes MUnit, centraliza configuração de retry/timeout e permite que outros flows de experiência reutilizem o mesmo canal para TLF-SALES-SYS. | 2026-06-16 |
| Headers Authorization (obrigatório) e X-Vivo-Transaction-Id propagados downstream | Authorization garante segurança na cadeia de chamadas. X-Vivo-Transaction-Id é o correlationId de negócio — deve ser preservado fim-a-fim para rastreabilidade e troubleshooting em produção. | 2026-06-16 |
| Query params (nomeOferta, numeroContrato, Limit, endereco) passados como-está ao System | A Experience Layer não transforma parâmetros de consulta neste caso — o contrato do sistema downstream é compatível com o que o consumidor envia. Transformação desnecessária aumenta acoplamento e dificulta versionamento. | 2026-06-16 |

### Findings e Resoluções

| Severidade | Finding | Resolução | Status |
|---|---|---|---|
| INFO | Ausência de Process Layer | Validado como correto para padrão passthrough 1-to-1 sem orquestração. Documentado como decisão arquitetural explícita. | Resolvido |
| INFO | Parâmetro `endereco` é objeto complexo (logradouro/numero/complemento/bairro/municipio/uf/cep) | Deve ser serializado como query params individuais (flat) ou como JSON no body — definir na especificação RAML. Recomendação: query params flat para compatibilidade REST. | Pendente ms-raml |

### Definition of Done Arquitetural

- [x] Camadas API-led respeitadas (Experience → System, passthrough documentado)
- [x] Naming conventions aplicadas (`tlf-everton-exp`, flow `request-global-sys`)
- [ ] Error handling global definido (a implementar pelo ms-developer)
- [ ] Estratégia de retry documentada (a implementar: 2 retries com backoff no request-global-sys)
- [x] Idempotência garantida onde necessário (GET é idempotente por natureza)

---

## [ms-raml] Contrato de API

> Preenchido pelo agente `ms-raml` a cada publicação no Exchange.

### Histórico de Versões

| Versão | Tipo | Changelog | Data | Exchange URL |
|---|---|---|---|---|
| 1.0.0 | Criação inicial | Contrato RAML 1.0 completo para SCRUM-9 (getOrderFlight-e). GET /{cnpj} com query params flat, headers Authorization + X-Vivo-Transaction-Id, response OrderFlightResponse, error RFC 7807. Objeto `endereco` serializado em dot-notation. | 2026-06-16 | https://anypoint.mulesoft.com/exchange/5834a905-793c-4621-9565-b8bc11830a87/tlf-everton-exp/1.0.0/ |

### Recursos Definidos

| Recurso | Métodos | Descrição |
|---|---|---|
| `/com/order/v1/getOrderFlight-e/{cnpj}` | GET | Consulta ordens de voo por CNPJ. URI param: cnpj (14 dígitos numéricos). Query params: nomeOferta, numeroContrato, Limit, endereco.* (7 campos flat). Headers: Authorization (required), X-Vivo-Transaction-Id (optional). |

### Traits Aplicadas

| Trait | Aplicada em |
|---|---|
| `correlatable` | `GET /com/order/v1/getOrderFlight-e/{cnpj}` — propaga X-Vivo-Transaction-Id |
| `errorable` | `GET /com/order/v1/getOrderFlight-e/{cnpj}` — respostas 400/401/403/404/429/500/502/503 RFC 7807 |
| `rateLimited` | `GET /com/order/v1/getOrderFlight-e/{cnpj}` — headers X-RateLimit-* documentados |

### DataTypes Definidos

| Arquivo | Tipo RAML | Descrição |
|---|---|---|
| `dataTypes/ErrorResponse.raml` | DataType | Erro padronizado RFC 7807. Campos: type, title, status, detail, instance, correlationId |
| `dataTypes/OrderItem.raml` | DataType | Item de ordem: tipoOrdem, numeroOrdem, statusOrdem, dataCriacao (todos required) |
| `dataTypes/OrderFlightResponse.raml` | DataType | Response body: flagBloqueio (boolean, required) + ordem (array OrderItem, required) |
| `dataTypes/OrderFlightQueryParams.raml` | DataType | Query params documentados (nomeOferta, numeroContrato, Limit, 7x endereco.*) |
| `traits/common-traits.raml` | Library | Traits: correlatable, errorable, rateLimited, pageable |

### Decisões de Design

| Decisão | Justificativa |
|---|---|
| Objeto `endereco` serializado como query params flat com prefixo `endereco.` | Conformidade REST (RFC 3986). Objetos não são natively suportados como query params em RAML/proxies. Dot-notation garante compatibilidade sem encoding especial. |
| Endpoint `/com/order/v1/getOrderFlight-e` mantém verbo no nome | Exceção documentada: endpoint definido explicitamente no Data Mapping SCRUM-9. DM é autoridade sobre naming neste caso. |
| Security scheme `clientIdEnforcement` (Pass Through) | Client ID Enforcement policy gerenciada pelo Anypoint API Manager. Pass Through no contrato RAML é o padrão para políticas externas ao código. |
| ZIP flat para Exchange (sem subpastas) | Exchange AMF parser requer que `!include` referencie arquivos pela raiz do ZIP. Arquivos fonte mantêm estrutura `dataTypes/` e `traits/` para organização local. |

---

## [ms-developer] Implementação

> Preenchido pelo agente `ms-developer` a cada implementação ou alteração.
> Última atualização: 2026-06-16

### Flows Implementados

| Flow | Arquivo | Responsabilidade |
|---|---|---|
| `tlf-everton-exp-main` | `src/main/mule/tlf-everton-exp.xml` | Listener HTTP principal `/*`, captura attributes/payload/timeStamp em variáveis, roteia via APIkit, error handler global |
| `tlf-everton-exp-console` | `src/main/mule/tlf-everton-exp.xml` | Listener `/console/*` para API Console (documentação interativa) |
| `get:\healthz:tlf-everton-exp-config` | `src/main/mule/tlf-everton-exp.xml` | Health check — retorna `{ msg: "API is healthy." }` |
| `get:\com\order\v1\getOrderFlight-e\(cnpj):tlf-everton-exp-config` | `src/main/mule/tlf-everton-exp.xml` | Operação principal — recebe GET com cnpj, monta dataSend, delega ao request-global-sys, loga start/end |
| `request-global-sys` | `src/main/mule/common/request.xml` | Sub-flow reutilizável — executa http:request para o sistema downstream com headers/queryParams/uriParams do dataSend |

### Explicação dos Flows Principais

#### `get:\com\order\v1\getOrderFlight-e\(cnpj):tlf-everton-exp-config`
```
Entrada  → GET /com/order/v1/getOrderFlight-e/{cnpj} com Authorization (required) e X-Vivo-Transaction-Id (optional)
Processo → 1. JSON Logger Start com endpoint/transactionid/correlationid/method/payload
            2. set-variable dataSend: monta estrutura com Protocol/Method/Host/Port/BasePath/Path/Timeout/Endpoint/Producer/Consumer/header/queryParams/uriParams usando Mule::p() para todas as propriedades sensíveis
            3. flow-ref request-global-sys: executa http:request HTTPS para TLF-SALES-SYS
            4. set-variable httpStatus com statusCode da resposta
            5. JSON Logger End com endpoint/transactionid/correlationid/httpStatus/payload de resposta
Saída    → Response do sistema downstream propagado ao consumidor (VE)
```

**Por que foi implementado assim:**
> Padrão passthrough puro — a Experience Layer não transforma dados, apenas faz proxy seguro com logging estruturado. O `dataSend` como objeto java centraliza todos os parâmetros de roteamento e é passado para o sub-flow reutilizável, isolando a lógica HTTP e permitindo mock eficiente nos testes MUnit via doc:id fixo.

#### `request-global-sys`
```
Entrada  → vars.dataSend com Method/Path/Timeout/header/uriParams/queryParams
Processo → 1. JSON Logger BEFORE_REQUEST com payload de saída
            2. http:request HTTPS com doc:id fixo cc949c77-09c5-47ac-9087-fdded5aa9f97 (crítico para mock MUnit)
            3. JSON Logger AFTER_REQUEST
Saída    → Response do downstream (payload + attributes com statusCode)
```

**Por que foi implementado assim:**
> doc:id fixo idêntico ao projeto de referência para que os mocks MUnit funcionem sem reconfiguração. Sub-flow reutilizável evita duplicação de lógica HTTP caso novos endpoints sejam adicionados.

### Transformações DataWeave

#### `set-variable dataSend` (inline no flow da operação)

**Propósito:** Monta o objeto de roteamento para o sub-flow `request-global-sys` sem hardcode de URLs.

**Decisões de implementação:**
- Todas as propriedades de host/path/method/timeout lidas via `Mule::p("secure::...")` — nunca hardcoded
- `header.TransactionID` mapeado de `attributes.headers."X-Vivo-Transaction-Id"` (header com hífen requer aspas em DataWeave)
- `queryParams: attributes.queryParams` e `uriParams: attributes.uriParams` passados como-estão — sem transformação (padrão passthrough)
- `Producer: "TLF-SALES-SYS"` e `Consumer: "TLF-EVERTON-EXP"` para rastreabilidade nos logs de observabilidade

### Arquivos de Configuração

| Arquivo | Propósito |
|---|---|
| `src/main/mule/tlf-everton-exp.xml` | Main flow + APIkit config + operações |
| `src/main/mule/common/global.xml` | Autodiscovery + SecureProperties + TLS + HTTP Request Config + JSON Logger + Error Handler |
| `src/main/mule/common/request.xml` | Sub-flow `request-global-sys` reutilizável (doc:id fixo para MUnit) |
| `src/main/resources/properties/dev.yaml` | Propriedades DEV (host: fenix-lb-dev.telefonica.com.br) |
| `src/main/resources/properties/hmg.yaml` | Propriedades HMG (host: fenix-lb-hmg.telefonica.com.br) |
| `src/main/resources/properties/prod.yaml` | Propriedades PROD (host: fenix-lb-prod.telefonica.com.br) |
| `src/main/resources/log4j2.xml` | Logging de produção (RollingFile) |
| `src/test/resources/log4j2-test.xml` | Logging de testes MUnit (Console) |
| `src/main/resources/keystores/dev-Mule-truststore.jks.placeholder` | Placeholder — keystore real deve ser provisionado antes do deploy |
| `mule-artifact.json` | Configs carregados: global.xml, tlf-everton-exp.xml, request.xml |
| `pom.xml` | Build, dependências, CloudHub deployment config |

### Suites MUnit

| Arquivo | Testes | Cobertura |
|---|---|---|
| `src/test/munit/getOrderFlight/get-com-order-v1-getOrderFlight-e-cnpj.xml` | `com-order-v1-getOrderFlight-success` (happy path) + `com-order-v1-getOrderFlight-error` (expectedErrorType=ANY) | Flow `getOrderFlight-e` |

### Dependências no pom.xml

| ArtifactId | Versão | Motivo |
|---|---|---|
| `json-logger-new` | 2.2.4 | Logging estruturado JSON (JSON Logger Config) |
| `munit-runner` | 3.4.0 | Runner MUnit para testes |
| `munit-tools` | 3.4.0 | Mock e assertions MUnit |
| `assertions` | 1.2.1 | DataWeave assertions |
| `mule-apikit-module` | 1.11.8 | APIkit roteamento automático |
| `mule-secure-configuration-property-module` | 1.3.0 | Propriedades seguras (secure::) |
| `mule-tlf-error-handler-plugin` | 1.0.27 | Error handler padronizado TLF |
| `mule-sockets-connector` | 1.2.7 | Socket connector (dependência HTTP) |
| `mule-http-connector` | 1.11.0 | HTTP Listener + HTTP Request |
| `mule-tracing-module` | 1.2.0 | Distributed tracing |
| `tlf-everton-exp` (raml/zip) | 1.0.0 | Contrato RAML publicado no Exchange (groupId=5834a905-...) |

---

## [ms-qa] Qualidade e Testes

> Preenchido pelo agente `ms-qa` a cada ciclo de validação.
> Última atualização: 2026-06-16

### Resultado da Suite MUnit

| Data | Total | Passou | Falhou | Cobertura |
|---|---|---|---|---|
| 2026-06-16 | 5 | 5 | 0 | ~80% (flows: getOrderFlight-e 100%, healthz 100%, main/console sem cobertura direta — dependência de HTTP Listener) |

### Cenários Cobertos

| Flow | Happy Path | CNPJ Bloqueado | Backend 404 | Downstream Error | Health Check |
|---|:---:|:---:|:---:|:---:|:---:|
| `get:\com\order\v1\getOrderFlight-e\(cnpj):tlf-everton-exp-config` | OK | OK | OK | OK | — |
| `get:\healthz:tlf-everton-exp-config` | — | — | — | — | OK |
| `tlf-everton-exp-main` | sem teste direto (HTTP Listener — não testável via flow-ref) | — | — | — | — |
| `tlf-everton-exp-console` | sem teste direto (HTTP Listener — não testável via flow-ref) | — | — | — | — |
| `request-global-sys` | coberto indiretamente via mock nos testes do getOrderFlight-e | — | — | — | — |

### Gaps Identificados e Resolvidos

| Gap | Prioridade | Teste Escrito | Status |
|---|---|---|---|
| `response.dwl` com wrapper `{ Body: {...} }` incorreto — não bate com contrato RAML | CRITICO | Corrigido: response.dwl removido o wrapper, retorna payload direto `{ flagBloqueio, ordem }` | Resolvido |
| `munit-tools:assert` vazio (sem expressão) nos 2 testes originais — não validava nada | ALTO | Corrigido: substituído por `munit-tools:assert-that` com verificações reais de campo | Resolvido |
| `expectedErrorType="ANY"` inválido no teste de erro — `ANY` não é tipo Mule válido para mock | ALTO | Corrigido: alterado para `HTTP:CONNECTIVITY` com typeId correto | Resolvido |
| Cenário CNPJ Bloqueado ausente (`flagBloqueio=true`, `ordem=[]`) — previsto no RAML | ALTO | Escrito: `com-order-v1-getOrderFlight-cnpj-bloqueado` + fixtures `attributes-bloqueado.json` e `response-bloqueado.dwl` | Resolvido |
| Cenário Backend 404 ausente — CNPJ não encontrado no downstream | MEDIO | Escrito: `com-order-v1-getOrderFlight-backend-404` | Resolvido |
| Flow `get:\healthz:tlf-everton-exp-config` sem nenhum teste | MEDIO | Escrito: `healthz-returns-healthy` | Resolvido |
| `request.dwl` fixture retornava `null` mas era lido como payload — GET não tem body | INFO | Documentado: `null` é correto para GET; payload nos testes agora definido diretamente como `null` em vez de leitura de arquivo | Resolvido |

### Validação de Contrato

| Endpoint | Contrato vs Response | Observações |
|---|---|---|
| `GET /com/order/v1/getOrderFlight-e/{cnpj}` | CONFORME | Response fixture `response.dwl` alinhado com RAML: `flagBloqueio: boolean`, `ordem: [{ tipoOrdem, numeroOrdem, statusOrdem, dataCriacao }]`. Tipos corretos. `flagBloqueio=true` + `ordem=[]` coberto em cenário separado. |
| `GET /healthz` | CONFORME | Response `{ msg: "API is healthy." }` assertado no teste `healthz-returns-healthy`. |

### Checklist QA

- [x] Flow `getOrderFlight-e` tem happy path
- [x] Flow `getOrderFlight-e` tem cenário CNPJ bloqueado (flagBloqueio=true)
- [x] Flow `getOrderFlight-e` tem cenário 404 do backend
- [x] Flow `getOrderFlight-e` tem cenário erro de conectividade (HTTP:CONNECTIVITY)
- [x] Flow `healthz` tem happy path
- [x] Mock referencia doc:id correto `cc949c77-09c5-47ac-9087-fdded5aa9f97` do http:request em request-global-sys
- [x] Fixtures representam dados reais (CNPJ 12345678000195 válido, nomeOferta FIBRA-500M, datas ISO 8601)
- [x] JSON Logger com masking de `Authorization`, `client_id`, `client_secret` verificado em global.xml
- [x] X-Vivo-Transaction-Id propagado nos logs: verificado em tlf-everton-exp.xml (Transactionid: vars.attributes.headers."x-vivo-transaction-id")
- [x] Assertions reais em todos os testes (nenhum assert vazio)
- [ ] `tlf-everton-exp-main` e `tlf-everton-exp-console` sem cobertura direta — HTTP Listener não é testável via flow-ref; justificativa: BUG-002 (ms-qa-fixit.md) — flows de listener são tecnicamente impossíveis de testar isoladamente em MUnit sem munit:enable-flow-sources

---

## [ms-security] Auditoria de Segurança

> Preenchido pelo agente `ms-security` a cada auditoria.
> Última atualização: 2026-06-16

### Postura de Segurança

| Data | Críticos | Altos | Médios | Baixos | Resultado |
|---|---|---|---|---|---|
| 2026-06-16 | 0 | 1 (corrigido) | 3 | 0 | SECURITY_APPROVED (com pendências documentadas) |

### Findings e Correções

| Severidade | Área | Finding | Vulnerabilidade | Fix Aplicado | Status |
|---|---|---|---|---|---|
| ALTO | Dados / LGPD | CNPJ logado em requestPath sem masking | `vars.attributes.requestPath` contém `/com/order/v1/getOrderFlight-e/12345678000195` — CNPJ exposto em texto claro nos logs de aplicação. LGPD Art. 5º, XI: CNPJ é dado de identificação de pessoa jurídica, protegido quando vinculado a fluxo de dados pessoais. | `requestPath` substituído por string literal `"/com/order/v1/getOrderFlight-e/{cnpj}"` nos loggers Start e End do flow `getOrderFlight-e`. message do logger alterado para `GET_getOrderFlight-e` sem CNPJ. Aplicado em `tlf-everton-exp.xml`. | Corrigido |
| MÉDIO | Transporte (TLS) | `insecure="true"` no TLS Truststore — sem validação de certificado do downstream | `<tls:trust-store insecure="true" />` em `global.xml` desabilita a verificação do certificado SSL do servidor downstream (TLF-SALES-SYS). Permite Man-in-the-Middle em todos os ambientes onde este valor for usado. **BLOQUEADOR para produção.** | Em `dev.yaml` e ambientes não-prod: aceitável como trade-off operacional documentado. **Para `prod.yaml`: `insecure` deve ser removido ou definido como `false`, e o truststore real deve ser provisionado.** Fix deve ser aplicado pelo ms-devops antes do deploy em prod. | Documentado — ms-devops bloqueia prod |
| MÉDIO | Autenticação | API Console exposto sem autenticação | Flow `tlf-everton-exp-console` expõe `/console/*` sem nenhuma política de autenticação. Em ambientes expostos externamente, o console permite enumeração do contrato de API. | Recomendação: desativar o console em prod via propriedade `anypoint.platform.config.analytics.agent.enabled` ou remover o flow `tlf-everton-exp-console` no deploy de produção. Em dev/hmg: aceitável. | Documentado — pendente ms-devops |
| MÉDIO | Autenticação | Client ID Enforcement no API Manager não verificável | Autodiscovery configurado corretamente (`api-gateway:autodiscovery`), porém sem Client ID disponível não é possível confirmar que a política `Client ID Enforcement` está ativa no API Manager para este ambiente. | Verificar no Anypoint API Manager → API tlf-everton-exp → Policies se `Client ID Enforcement` está aplicada antes do deploy em produção. | Pendente verificação manual |
| MÉDIO | Proteção de Payload | JSON/XML Threat Protection não configurado | Nenhuma política de Threat Protection aplicada no flow de entrada. Payloads maliciosos (XML bomb, JSON deeply nested) podem causar DoS. | Aplicar `JSON Threat Protection` via API Manager policy no ambiente de produção. Recomendação: `maxContainerDepth=10`, `maxStringValueLength=512`, `maxKeyCount=20`. | Documentado — pendente API Manager |
| INFO | Headers HTTP | Headers de segurança HTTP ausentes (Strict-Transport-Security, X-Content-Type-Options) | Respostas não incluem `Strict-Transport-Security` nem `X-Content-Type-Options`. Em CloudHub com load balancer gerenciado pela Anypoint Platform, esses headers são tipicamente adicionados pela infraestrutura. | Confirmar com ms-devops se o load balancer CloudHub 2.0 já injeta esses headers. Se não, adicionar via `outboundHeaders` no listener ou via política HTTP Headers no API Manager. | Documentado — verificação infraestrutura |

### Análise por Área

| Área | Status | Observação |
|---|---|---|
| Autenticação / Autorização | CONFORME (ressalva) | RAML define `Authorization: required: true`. APIkit valida automaticamente. Autodiscovery configurado. Client ID Enforcement no API Manager deve ser confirmado antes de prod. |
| Credenciais / Secrets | CONFORME | Nenhuma credencial hardcoded. `dev.yaml` sem valores sensíveis. `mule-artifact.json` lista corretamente 6 secureProperties: `security.key`, `anypoint.platform.client_id`, `anypoint.platform.client_secret`, `truststore.mule.password`, `request.sys.client.id`, `request.sys.client.secret`. Todas as propriedades no flow usam `Mule::p('secure::...')` ou `Mule::p('runtime.properties...')`. |
| Transporte (TLS) | PARCIAL | HTTPS configurado em todos os canais. Protocolo HTTPS definido no HTTP Request Connection. `insecure="true"` aceitável para dev, bloqueador para prod. |
| Masking de dados sensíveis | CONFORME | JSON Logger Config com `contentFieldsDataMasking="client_id,client_secret,Authorization,content_base64"`. CNPJ no requestPath corrigido nesta auditoria. |
| Validação de Input | CONFORME | APIkit valida automaticamente via RAML: CNPJ (`^[0-9]{14}$`), Limit (1-100), UF (`^[A-Z]{2}$`), CEP (`^[0-9]{8}$`). Threat Protection ausente (documentado). |
| Auditoria e Rastreabilidade | CONFORME | CorrelationID (`correlationid`) e `x-vivo-transaction-id` logados em Start e End. `tracePoint="END"` configurado. Error handler global loga exceções com `tracePoint="EXCEPTION"`. |
| Exposição de Internals em erros | CONFORME | `module-error-handler-plugin` (mule-tlf-error-handler-plugin 1.0.27) padroniza respostas de erro RFC 7807. O erro logado usa `JSONLoggerModule::stringifyNonJSON(payload)` — apenas o payload processado, sem stack trace exposto ao consumidor. |

### Decisões de Segurança Documentadas

| Decisão | Justificativa | Ambiente |
|---|---|---|
| `insecure="true"` no TLS Context | Ambiente de dev usa certificado auto-assinado do servidor downstream (fenix-lb-dev.telefonica.com.br). Validação de CA não disponível em dev. Aceitável com restrição: `insecure` DEVE ser `false` em prod com truststore real provisionado. | Dev/HMG only |
| API Console exposto em `/console/*` | Necessário para desenvolvimento e validação do contrato. Deve ser desativado ou protegido em produção. | Dev/HMG only |
| CNPJ como URI param (por design) | Definido no Data Mapping SCRUM-9. Decisão de negócio documentada pelo ms-architect. Fix de segurança: mascarar no log (aplicado). Não altera o contrato de API. | Todos |

### Checklist de Segurança

- [x] Client ID Enforcement declarado no RAML (Pass Through — gerenciado pelo API Manager)
- [ ] Client ID Enforcement confirmado ativo no API Manager (verificação manual pendente)
- [x] HTTPS configurado em todas as conexões (Listener: porta segura, Request: protocolo HTTPS)
- [x] TLS Context configurado com truststore (caminho parametrizado por ${env})
- [ ] insecure=false no prod.yaml e truststore real provisionado (bloqueador para deploy prod)
- [x] Nenhuma credencial hardcoded (dev.yaml sem segredos, todos via secure:: ou runtime.properties)
- [x] secureProperties declarados no mule-artifact.json (6 campos)
- [x] CNPJ mascarado nos logs (corrigido nesta auditoria — requestPath substituído por literal)
- [x] Authorization/client_id/client_secret mascarados no JSON Logger Config
- [x] CorrelationId (x-vivo-transaction-id + correlationid) presente em todos os flows de negócio
- [ ] JSON/XML Threat Protection configurado no API Manager (pendente)
- [ ] API Console desativado em produção (pendente ms-devops)

---

## [ms-devops] Pipeline e Deploy

> Preenchido pelo agente `ms-devops` a cada deploy.
> Última atualização: 2026-06-16

### Status de Pipeline

| Item | Status |
|---|---|
| Análise estática pom.xml | APROVADO |
| Análise estática mule-artifact.json | APROVADO |
| Análise estática dev.yaml | APROVADO |
| RAML dep no pom.xml | APROVADO (groupId=5834a905..., classifier=raml, type=zip, version=1.0.0) |
| Health endpoint | CONFIRMADO (`get:\healthz:tlf-everton-exp-config`) |
| GitHub Actions pipeline | GERADO (`.github/workflows/deploy.yml`) |
| Deploy Checklist | GERADO (`DEPLOY_CHECKLIST.md`) |
| Deploy real | PENDENTE (Client ID não disponível — READY_FOR_DEV) |

### Histórico de Deploys

| Data | Versão | Ambiente | Status | URL | Observações |
|---|---|---|---|---|---|
| 2026-06-16 | 1.0.0 | — | READY_FOR_DEV | — | Pipeline gerado. Deploy bloqueado: Connected App credentials não configuradas. Configurar ANYPOINT_CLIENT_ID e ANYPOINT_CLIENT_SECRET nos GitHub Secrets para ativar o pipeline. |

### Configuração de Pipeline

| Estágio | Ferramenta | Trigger | Status |
|---|---|---|---|
| Build + MUnit | `mvn clean package -DskipTests=false` | push em main/develop | Configurado |
| Deploy Dev | mule-maven-plugin CloudHub 2.0 | Automático após build | Configurado |
| Deploy HMG | mule-maven-plugin CloudHub 2.0 | Automático após deploy-dev em main | Configurado |
| Deploy Prod | mule-maven-plugin CloudHub 2.0 | `workflow_dispatch` manual OBRIGATÓRIO | Configurado |

### Parâmetros de Deploy CloudHub 2.0

| Parâmetro | Dev | HMG | Prod |
|---|---|---|---|
| App Name | `dev-tlf-everton-exp` | `hmg-tlf-everton-exp` | `prod-tlf-everton-exp` |
| Runtime | 4.9-java17 | 4.9-java17 | 4.9-java17 |
| Worker | 1 x MICRO | 1 x MICRO | 1 x SMALL |
| Region | sa-east-1 | sa-east-1 | sa-east-1 |
| ObjectStore V2 | true | true | true |

### Bloqueadores para Deploy PROD

| Severidade | Bloqueador | Origem | Status |
|---|---|---|---|
| CRITICO | `insecure=false` no prod.yaml + truststore real provisionado | ms-security | Pendente |
| CRITICO | API Console desativado em prod | ms-security | Pendente |
| CRITICO | JSON Threat Protection ativo no API Manager | ms-security | Pendente |
| CRITICO | Client ID Enforcement confirmado no API Manager | ms-security | Pendente verificação manual |
| ALTO | Revisão LGPD aprovada | ms-security | Aprovado (CNPJ corrigido em 2026-06-16) |

### Artefatos Gerados

| Artefato | Caminho | Descrição |
|---|---|---|
| Pipeline CI/CD | `.github/workflows/deploy.yml` | GitHub Actions: build → test → deploy-dev → deploy-hmg → deploy-prod (manual) |
| Deploy Checklist | `DEPLOY_CHECKLIST.md` | Checklist completo pré/pós-deploy por ambiente com bloqueadores prod |

### Alertas a Configurar (Pós-Deploy Prod)

| Alerta | Threshold | Canal |
|---|---|---|
| Taxa de erro | > 1% em 5min | Anypoint Monitoring |
| Latência P95 | > 30s | Anypoint Monitoring |
| JVM Heap | > 80% | Anypoint Monitoring |

### Secrets GitHub Actions Necessários

| Secret | Ambiente | Descrição |
|---|---|---|
| `ANYPOINT_CLIENT_ID` | Todos | Connected App Client ID (Anypoint Platform) |
| `ANYPOINT_CLIENT_SECRET` | Todos | Connected App Client Secret |
| `MULE_SECURITY_KEY` | Dev/HMG | Chave de criptografia de propriedades seguras |
| `PROD_MULE_SECURITY_KEY` | Prod | Chave separada para produção |
| `DEV_API_MANAGER_ID` | Dev | ID da instância no API Manager DEV |
| `HMG_API_MANAGER_ID` | HMG | ID da instância no API Manager HMG |
| `PROD_API_MANAGER_ID` | Prod | ID da instância no API Manager PROD |
| `DEV/HMG/PROD_REQUEST_SYS_CLIENT_ID` | Por ambiente | Client ID do sys (TLF-SALES-SYS) |
| `DEV/HMG/PROD_REQUEST_SYS_CLIENT_SECRET` | Por ambiente | Client Secret do sys |
| `DEV/HMG/PROD_TRUSTSTORE_PASSWORD` | Por ambiente | Senha do truststore JKS |

---

## Changelog Consolidado

| Versão | Data | Agentes Envolvidos | Resumo da Mudança |
|---|---|---|---|
| 1.0.0 | 2026-06-16 | ms-architect | Criação inicial do projeto. Estrutura de pastas, PROJECT.md e validação arquitetural para SCRUM-9 (getOrderFlight-e). |
| 1.0.0 | 2026-06-16 | ms-raml | Contrato RAML 1.0 gerado e publicado no Exchange. 6 arquivos (1 raiz + 4 dataTypes + 1 traits library). Endpoint GET /{cnpj} com traits correlatable/errorable/rateLimited. Publicado em: https://anypoint.mulesoft.com/exchange/5834a905-793c-4621-9565-b8bc11830a87/tlf-everton-exp/1.0.0/ |
| 1.0.0 | 2026-06-16 | ms-developer | Implementação completa dos flows Mule 4. 5 flows: main, console, healthz, getOrderFlight-e, request-global-sys. pom.xml com 11 dependências. Properties dev/hmg/prod. MUnit suite com 2 testes (happy path + error). |
| 1.0.0 | 2026-06-16 | ms-qa | QA completo: corrigidos 3 bugs críticos/altos na suite MUnit (response.dwl wrapper incorreto, assert vazio, errorType inválido), adicionados 3 novos cenários (CNPJ bloqueado, backend 404, healthz), 5 testes no total. QA_APPROVED. |
| 1.0.0 | 2026-06-16 | ms-security | Auditoria de segurança completa. 1 finding ALTO corrigido (CNPJ/LGPD: requestPath suprimido dos logs, substituído por literal). 3 findings MÉDIOS documentados (insecure=true bloqueador prod, console sem auth, Threat Protection ausente). 1 INFO (headers HTTP). Postura: SECURITY_APPROVED com pendências para prod documentadas. |
| 1.0.0 | 2026-06-16 | ms-devops | Validação estática de pipeline concluída. Análise: pom.xml/mule-artifact.json/dev.yaml aprovados. RAML dep correta. Health endpoint confirmado (/healthz). Gerados: `.github/workflows/deploy.yml` (pipeline CI/CD com 4 jobs: build+MUnit, deploy-dev automático, deploy-hmg automático, deploy-prod manual) e `DEPLOY_CHECKLIST.md` (pré/pós-deploy todos os ambientes, 5 bloqueadores prod documentados). Status: READY_FOR_DEV — aguardando configuração de secrets no GitHub. |
