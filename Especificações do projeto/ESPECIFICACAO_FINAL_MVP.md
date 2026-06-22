# CLAI 2026 — Especificação Final do MVP

> Plataforma de auditoria interna assistida por IA. **Frontend em React (Vite + TypeScript)** e **backend em FastAPI (Python)**, sobre **Google Cloud Platform** (Gemini, BigQuery, Cloud Storage, Firestore, Vertex AI Vector Search).
>
> **Contexto:** projeto pessoal / MVP. Prioridade de custo: **não estourar o free tier**. Sem requisitos corporativos de segurança/compliance nesta fase.

Este documento consolida as decisões tomadas e substitui o rascunho `ESPECIFICACAO_DETALHADA_MVP.md`.

---

## 1. Decisões fechadas

| # | Tema | Decisão |
|---|------|---------|
| **M1** | Arquitetura | **Frontend React (Vite + TS) + Backend FastAPI** separados, comunicando via **REST/JSON**. Lógica de negócio na camada de serviços do backend. |
| **M2** | Dados | **Firestore** (operacional, transacional) + **BigQuery** (analítico/correlações). |
| **M3** | RAG / busca | **Vertex AI Vector Search**, com estratégia de **on/off** para controle de custo. |
| **M4** | Notícias | Ingestão **somente via feed RSS** (sem scraping, sem upload manual). |
| **M5–M8** | — | **Fora do MVP.** Sem async obrigatório, sem structured-output formal, sem trilha de IA, sem hardening corporativo. |
| **Guardrails** | Custo | Script on/off do índice, **budget alert**, modelos `flash`/`flash-lite` (sem `pro`), atenção a quotas de free tier. |

---

## 2. Visão geral

O CLAI apoia o ciclo de auditoria em quatro frentes, cada uma com automações de IA (Gemini):

| Módulo | Objetivo | IA |
|--------|----------|----|
| **Planejamento** | Correlacionar notícias (RSS) e incidentes internos com riscos corporativos | Correlação semântica |
| **Execução — Abertura** | Carregar contexto do trabalho e gerar matriz de risco | Geração de matriz |
| **Execução — Campo** | Upload de evidências por teste (TA) e chat com agente do TA | RAG (File API + Vector Search) |
| **Execução — Fechamento** | Ler todos os TAs e gerar relatório | Síntese de contexto longo |
| **FUP** | Cadastro de pontos/planos e análise de eficiência por IA | Avaliação crítica |

**Atores:** `auditor` e `auditado` (RBAC mínimo: papel no documento do usuário no Firestore).

---

## 3. Arquitetura

```
┌─────────────────────────┐      REST / JSON       ┌──────────────────────────────────┐
│   Frontend (React)      │  ───────────────────►  │     Backend (FastAPI, Python)      │
│   Vite + TypeScript     │  ◄───────────────────  │   api/v1  →  Camada de Serviços    │
│   pages / components    │       (CORS, auth)     │  gemini · bigquery · firestore     │
│   api client (fetch)    │                        │  storage · vector_search · rss     │
└─────────────────────────┘                        └───┬───────┬─────────┬────────┬─────┘
                                                        ▼       ▼         ▼        ▼
                                                    ┌──────┐ ┌──────┐ ┌────────┐ ┌──────────────┐
                                                    │Gemini│ │BigQ. │ │Firestore│ │ GCS / Vertex │
                                                    └──────┘ └──────┘ └────────┘ └──────────────┘
              Auth GCP: ADC / Service Account pessoal   ·   Budget alert ativo
```

**Stack:**
- **Frontend:** React 18 · Vite · TypeScript · cliente HTTP (`fetch`/axios) para a API.
- **Backend:** FastAPI · Python `3.11` · `uvicorn` · `pydantic-settings`.
- **GCP/IA:** `google-genai` · `google-cloud-bigquery` · `google-cloud-firestore` · `google-cloud-storage` · `google-cloud-aiplatform` (Vertex) · `feedparser` (RSS) · `pypdf`/`python-docx` (extração).

---

## 4. Estratégia de RAG (importante)

Dois padrões combinados, conforme o volume da conversa:

### 4.1 Chat por TA → **Gemini File API** (sem vector store)
O conjunto de anexos de um TA é pequeno e cabe na janela de contexto (~1M tokens). Sobe-se o PDF/DOCX direto no Gemini, que lê nativamente. **Sem embeddings, sem endpoint, $0 ocioso.** É o caminho do dia-a-dia do trabalho de campo.

### 4.2 Busca semântica de acervo → **Vertex AI Vector Search**
Para buscar entre **muitos** documentos/TAs/trabalhos (quando não cabe no contexto). Pipeline:

```
pdf/docx → extração de texto → chunk → embedding → índice Vertex
pergunta → embedding → VECTOR_SEARCH (top-k) → Gemini
```

> **Extração de pdf/docx** acontece *antes* do vector store (parsing), independente dele.
> Ferramentas: Gemini File API (transcrição) ou libs (`pypdf`, `python-docx`).

### 4.3 Controle de custo do Vertex (on/off)
- O **índice** (vetores) é barato e **persiste** desligado.
- O **Index Endpoint deployado** cobra por hora 24/7 → **deve ficar desligado quando não estiver em uso**.
- **Workflow:** `deploy-index` no início da sessão de dev → `undeploy-index` ao terminar.
- Religar leva **~20–60 min** (não é instantâneo) — aceitável para MVP.
- **Guardrail:** script `vector_search start|stop` + **budget alert** no billing.

---

## 5. Modelo de dados

### 5.1 BigQuery (analítico) — dataset `clai`
| Tabela | Campos principais |
|--------|-------------------|
| `noticias` | id, fonte_rss, url, titulo, conteudo, data_publicacao, ingerido_em |
| `incidentes_internos` | id, descricao, area, severidade, data_ocorrencia |
| `riscos_corporativos` | id, codigo, titulo, descricao, categoria, criticidade |
| `correlacoes_risco` | id, risco_id, origem_tipo, origem_id, score, justificativa, criado_em |

### 5.2 Firestore (operacional) — coleções
| Coleção | Campos principais |
|---------|-------------------|
| `usuarios` | uid, nome, email, papel (`auditor`/`auditado`), area |
| `trabalhos` | id, titulo, escopo, status, criado_por, criado_em, gcs_prefix |
| `testes` (TAs) | id, trabalho_id, codigo (TA01…), objetivo, status, gcs_prefix, gemini_file_refs[] |
| `pontos` | id, trabalho_id, descricao, status (`aberto`/`notificado`/`apto`), responsavel_area |
| `planos_de_acao` | id, ponto_id, desenho, analise_desenho, implementacao, analise_implementacao, status |

### 5.3 Cloud Storage — bucket `clai-<env>`
```
documentos_trabalho/<trabalho_id>/...
documentos_testes/<trabalho_id>/<ta_id>/...
relatorios/<trabalho_id>/relatorio.md
planos_de_acao/<ponto_id>/...
```

---

## 6. Componentes de IA (Gemini)

| # | Serviço | Entrada | Saída | Técnica | Modelo sugerido |
|---|---------|---------|-------|---------|-----------------|
| 1 | Correlação risco × notícia/incidente | riscos + notícias(RSS)/incidentes | lista correlações | contexto + JSON | `gemini-2.5-flash-lite` |
| 2 | Matriz de risco | docs de abertura | matriz | contexto + JSON | `gemini-2.5-flash` |
| 3 | Chat por TA (RAG) | anexos do TA + pergunta | resposta com citações | File API | `gemini-2.5-flash` |
| 4 | Relatório de fechamento | todos os TAs do trabalho | relatório (md) | contexto longo | `gemini-2.5-flash` |
| 5 | Análise do desenho do plano | ponto + plano | eficiência + lacunas | contexto + JSON | `gemini-2.5-flash` |
| 6 | Análise da implementação | plano + evidências | efetividade + pendências | contexto + JSON | `gemini-2.5-flash` |
| 7 | Busca de acervo (Vector Search) | corpus de docs | top-k trechos | Vertex Vector Search | embeddings |

**Estratégia de modelos (free tier):** `gemini-2.5-flash` é o cavalo de batalha (análises, chat, relatório); `gemini-2.5-flash-lite` fica nas tarefas leves/alto volume (ex.: correlação em massa). **Sem modelo `pro`** no MVP para conter custo.

*(Confirmar disponibilidade dos modelos no projeto/região antes do uso.)*

---

## 7. Comportamento esperado do app (detalhado)

Cada fluxo abaixo segue o formato: **objetivo → atores → pré-condições → passo a passo (usuário ⇄ sistema ⇄ IA) → resultado/persistência → estados e exceções.**

---

### 7.1 Módulo de Planejamento — Correlação de riscos

**Objetivo:** produzir uma **lista dos riscos corporativos que tiveram alguma notícia ou incidente interno relacionado à descrição do risco**, para orientar a priorização do planejamento de auditoria.

**Ator:** `auditor`.

**Pré-condições:**
- Tabela `riscos_corporativos` populada (carga inicial de riscos mapeados).
- Pelo menos um feed RSS cadastrado e/ou incidentes internos importados.

**Passo a passo:**
1. O auditor acessa a página **Planejamento**. Vê três blocos: *Feeds RSS*, *Incidentes internos* e *Riscos correlacionados*.
2. Em *Feeds RSS*, cadastra/edita URLs de feeds (ex.: portais de notícia, reguladores). Botão **"Atualizar notícias"** dispara o serviço `rss`, que lê os feeds (`feedparser`), normaliza (título, conteúdo, fonte, data, URL) e grava novas entradas em `noticias` (dedup por URL).
3. Em *Incidentes internos*, o auditor importa/cadastra incidentes (descrição, área, severidade, data) → tabela `incidentes_internos`.
4. O auditor clica em **"Correlacionar"**. O sistema:
   - Carrega os riscos de `riscos_corporativos` e as notícias/incidentes recentes.
   - Para cada risco, o **serviço de correlação (Gemini)** avalia se há notícia/incidente cuja descrição se relaciona à **descrição do risco**, retornando, para cada par relevante: `risco_id`, `origem_tipo` (notícia/incidente), `origem_id`, `score` de relevância (0–1) e uma **justificativa textual** do porquê estão relacionados.
   - Resultados são gravados em `correlacoes_risco`.
5. A tela exibe **somente os riscos que tiveram ao menos uma correlação**, ordenados por maior score, cada um expansível para mostrar as notícias/incidentes que o motivaram + a justificativa da IA.

**Resultado/persistência:** registros em `correlacoes_risco`; lista renderizada na UI.

**Estados e exceções:**
- Nenhuma correlação encontrada → mensagem "Nenhum risco com notícia/incidente relacionado no período".
- Feed RSS inacessível → ignora o feed com aviso, processa os demais.
- Reexecução → atualiza/regrava correlações do período (idempotente por par risco×origem).

---

### 7.2 Execução — Abertura do trabalho

**Objetivo:** abrir um novo trabalho de auditoria, **alimentar um agente com o conhecimento do trabalho** (normativos, atas de reunião com o auditado, escopo) e, opcionalmente, **gerar uma matriz de risco** a partir desse material.

**Ator:** `auditor`.

**Pré-condições:** usuário autenticado como auditor.

**Passo a passo:**
1. O auditor clica em **"Novo trabalho"**, informa título e escopo → cria documento em `trabalhos` (status `aberto`, `gcs_prefix` definido).
2. Na aba **"Conhecimento do trabalho"**, faz **upload de documentos** (normativos, políticas, atas de reunião com o auditado, papéis de trabalho prévios). Cada arquivo:
   - é salvo em `documentos_trabalho/<trabalho_id>/...` no Cloud Storage;
   - é enviado ao **Gemini (File API)** e a referência (`gemini_file_ref`) é guardada no documento do trabalho, formando a **base de conhecimento do agente do trabalho**.
3. (Opcional) O auditor clica em **"Gerar matriz de risco"**. O **serviço de matriz (Gemini)** lê o material de abertura e produz uma matriz estruturada — para cada risco identificado: `descrição`, `probabilidade`, `impacto`, `controles existentes` e `sugestão de teste`.
4. A matriz é exibida em tabela editável (o auditor pode ajustar) e salva (no documento do trabalho / como artefato).

**Resultado/persistência:** `trabalhos` atualizado; arquivos no Storage; referências de arquivo no Gemini; matriz de risco salva.

**Estados e exceções:**
- Documento ilegível/sem texto → aviso de que o arquivo não pôde ser interpretado.
- "Gerar matriz" sem documentos suficientes → solicita upload de ao menos um documento de contexto.
- O conhecimento alimentado aqui é **reaproveitado** nas etapas seguintes do mesmo trabalho.

---

### 7.3 Execução — Trabalho de campo

**Objetivo:** durante a execução dos testes, permitir, **para cada teste de auditoria (TA)**, subir **individualmente** todas as evidências/análises do auditor e **conversar com um agente que conhece aquele TA específico**.

**Ator:** `auditor`.

**Pré-condições:** trabalho aberto (7.2).

**Passo a passo:**
1. Dentro do trabalho, o auditor cria os **TAs** (ex.: `TA01`, `TA02`...) com objetivo de cada teste → coleção `testes`.
2. Para um TA selecionado (ex.: `TA01`), há uma área de **upload individual de evidências** (planilhas, PDFs, prints, análises). Cada anexo:
   - é salvo em `documentos_testes/<trabalho_id>/<ta_id>/...`;
   - é registrado/enviado ao Gemini (File API), com a referência guardada em `gemini_file_refs[]` **daquele TA** — ou seja, o conhecimento fica **isolado por TA** (anexos do `TA01` não vazam para o `TA02`).
3. O auditor abre o **"Chat do TA"**. O agente responde perguntas **fundamentado apenas nos anexos daquele TA** (ex.: "o controle X foi testado?", "resuma as exceções encontradas"), citando os documentos usados.
4. O auditor pode registrar a conclusão do TA (status `concluído`).

**Resultado/persistência:** `testes` com anexos e referências; histórico de chat por TA (em memória/estado da sessão no MVP).

**Estados e exceções:**
- Chat sem anexos → agente avisa que o TA ainda não tem evidências.
- Isolamento garantido: cada chat usa somente os `gemini_file_refs[]` do TA corrente.
- Anexo grande → respeitar limites da File API; avisar se exceder.

---

### 7.4 Execução — Fechamento do trabalho

**Objetivo:** criar um agente que **lê todos os TAs do trabalho** e **gera um relatório** consolidado.

**Ator:** `auditor`.

**Pré-condições:** trabalho com um ou mais TAs (idealmente concluídos).

**Passo a passo:**
1. Na aba **"Fechamento"**, o auditor clica em **"Gerar relatório"**.
2. O **serviço de relatório (Gemini)** reúne o contexto de **todos os TAs** do trabalho (objetivos + evidências/anexos via File API + conclusões) e o material de abertura, e produz um **relatório estruturado**: contexto/escopo, testes realizados, achados/exceções por TA, riscos e recomendações.
3. O relatório é exibido para revisão e salvo em `relatorios/<trabalho_id>/relatorio.md` no Cloud Storage.
4. O auditor pode editar e regenerar.

**Resultado/persistência:** relatório no Storage; status do trabalho → `relatório gerado`.

**Estados e exceções:**
- Sem TAs → bloqueia geração com aviso.
- Volume de anexos muito grande para a janela de contexto → estratégia de resumo por TA antes da consolidação (degradação graciosa).

---

### 7.5 Submódulo de FUP (Follow-up)

**Objetivo:** acompanhar os **pontos de auditoria** até a implementação dos planos de ação, com **análise por IA** da eficiência do desenho e da efetividade da implementação.

**Atores:** `auditor` (cadastra ponto) e `auditado` (cadastra plano e implementação).

**Fluxo completo (máquina de estados do ponto):**

```
[auditor]  cadastra ponto ─────────────► status: ABERTO
[sistema]  notifica área auditada ──────► status: NOTIFICADO
[auditado] cadastra DESENHO do plano ──► status: APTO  + análise IA (eficiência do desenho)
[auditado] cadastra IMPLEMENTAÇÃO ─────► status: IMPLEMENTADO + análise IA (efetividade)
```

**Passo a passo:**
1. O **auditor** cadastra o **ponto de auditoria** (descrição, risco associado, área responsável) → coleção `pontos`, status `aberto`.
2. O sistema **notifica a área auditada** — no MVP, **notificação in-app** (o ponto aparece na fila do auditado); o ponto passa a `notificado` e fica **apto a receber o desenho do plano**.
3. O **auditado** cadastra o **desenho do plano de ação** (o que será feito, responsáveis, prazos). Ao salvar:
   - o **serviço de análise de desenho (Gemini)** avalia se o plano **endereça adequadamente o ponto/risco**, retornando `eficiência` (ex.: alta/média/baixa), `lacunas` identificadas e `recomendações` de melhoria;
   - resultado exibido imediatamente ao auditado e salvo em `planos_de_acao.analise_desenho`; status → `apto`.
4. O **auditado** cadastra a **implementação do plano** (evidências do que foi efetivamente feito; arquivos vão para `planos_de_acao/<ponto_id>/`). Ao salvar:
   - o **serviço de análise de implementação (Gemini)** avalia a **efetividade** da implementação frente ao desenho proposto e ao ponto original, retornando `efetividade` e `pendências`;
   - resultado salvo em `planos_de_acao.analise_implementacao`; status → `implementado`.
5. O auditor acompanha tudo em um painel de FUP com o status e as análises de cada ponto.

**Resultado/persistência:** `pontos` e `planos_de_acao` com desenho, implementação e as duas análises de IA.

**Estados e exceções:**
- Auditado tenta cadastrar plano em ponto não `notificado` → bloqueado.
- Análise de IA é **assistiva** (não bloqueia o avanço): o auditor mantém a palavra final.
- Reenvio de desenho/implementação → regera a análise correspondente.

> **Observação (notificação):** o requisito original prevê notificar a área auditada. No MVP isso é **in-app** (fila/painel do auditado). Notificação por e-mail fica para fase 2 (ver seção 10).

---

## 8. Estrutura do projeto (monorepo: backend + frontend)

```
clai-2026/
├── backend/                          # FastAPI (Python 3.11)
│   ├── app/
│   │   ├── main.py                   # cria FastAPI, CORS, inclui routers
│   │   ├── api/
│   │   │   ├── deps.py               # dependências (auth, clients GCP)
│   │   │   └── v1/
│   │   │       ├── router.py
│   │   │       └── endpoints/
│   │   │           ├── planning.py   # RSS, incidentes, correlação
│   │   │           ├── works.py      # trabalhos + abertura + matriz
│   │   │           ├── fieldwork.py  # TAs, upload, chat
│   │   │           ├── closing.py    # relatório
│   │   │           └── fup.py        # pontos, planos, análises
│   │   ├── core/
│   │   │   ├── config.py             # pydantic-settings (.env)
│   │   │   └── security.py           # auth/RBAC (auditor/auditado)
│   │   ├── models/                   # schemas Pydantic (request/response + entidades)
│   │   ├── services/
│   │   │   ├── gcp/
│   │   │   │   ├── auth.py
│   │   │   │   ├── bigquery_client.py
│   │   │   │   ├── firestore_client.py
│   │   │   │   ├── storage_client.py
│   │   │   │   └── vector_search.py  # deploy/undeploy + query
│   │   │   ├── gemini/
│   │   │   │   ├── client.py
│   │   │   │   ├── correlation.py
│   │   │   │   ├── risk_matrix.py
│   │   │   │   ├── ta_chat.py
│   │   │   │   ├── report.py
│   │   │   │   └── fup_analysis.py
│   │   │   └── rss.py
│   │   └── repositories/
│   ├── requirements.txt
│   └── tests/
├── frontend/                         # React (Vite + TypeScript)
│   ├── src/
│   │   ├── main.tsx
│   │   ├── App.tsx
│   │   ├── pages/                    # Planning, WorkOpening, FieldWork, Closing, Fup
│   │   ├── components/
│   │   ├── api/                      # cliente HTTP do backend
│   │   ├── hooks/
│   │   └── types/
│   ├── index.html
│   ├── vite.config.ts
│   └── package.json
├── scripts/
│   └── vector_search.py              # CLI: start | stop (deploy/undeploy índice)
├── .env.example                      # config compartilhada (backend lê via pydantic-settings)
└── .gitignore
```

> O **frontend** consome a API do backend (`VITE_API_BASE_URL`). O **backend** habilita **CORS** para a origem do frontend e lê a config de `.env` (seção de variáveis).

---

## 9. Guardrails de free tier (substitui M8)

| Risco | Guardrail |
|-------|-----------|
| Endpoint Vertex ligado 24/7 | Script `stop` + rotina de desligar ao fim da sessão |
| Estouro geral de custo | **Budget alert** no Cloud Billing (limite baixo, ex. R$/US$ poucos) + e-mail |
| Quota de queries BigQuery | Evitar `SELECT *`; particionar/clusterizar; ficar < 1TB/mês |
| Custo de tokens Gemini | `flash-lite` em tarefas leves/alto volume e `flash` no restante (sem `pro`); cache simples por hash |
| Storage | Cloud Storage free 5GB; Firestore free 1GB/50k leituras dia |
| Vazamento de credenciais | `.env` no `.gitignore`; chave da Service Account fora do repo |

---

## 10. Escopo

**No MVP:**
- Planejamento: RSS + correlação risco × notícia/incidente.
- Abertura: trabalho + upload de contexto + matriz de risco.
- Campo: upload por TA + chat por TA (File API).
- Fechamento: relatório.
- FUP: pontos, planos, análises 5 e 6 (notificação só in-app).
- Vector Search de acervo (com on/off).
- Auth básico (2 papéis).

**Fora do MVP (fase 2+):**
- Podcast/TTS.
- Scraping de notícias.
- Async formal, structured-output formal, trilha de IA, hardening corporativo (M5–M8).
- Notificações por e-mail, dashboards, multi-tenant.

---

## 11. Próximos passos
1. Definir **projeto GCP** e região; criar Service Account pessoal + `.env`.
2. Configurar **budget alert** (guardrail nº 1).
3. Scaffolding: **backend** (FastAPI + `uvicorn`, estrutura da seção 8) e **frontend** (`npm create vite@latest frontend -- --template react-ts`).
4. Subir a base: endpoint `GET /health` no backend + tela inicial no frontend consumindo a API (valida a integração REST/CORS).
5. Implementar por ordem de prioridade (sugestão: **Planejamento → Abertura → Campo → Fechamento → FUP**), cada módulo como um router no backend + páginas no frontend.
