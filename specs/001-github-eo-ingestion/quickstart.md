# Quickstart — validação da feature 001

**Feature**: 001 — Coleta de pessoas e equipes do GitHub para a Enterprise Ontology
**Propósito**: provar, por execução, que a fatia funciona de ponta a ponta —
do cadastro da ferramenta até a tela de pessoas e equipes.

Este documento é guia de execução e verificação. O código vive em `tasks.md` e na
implementação; aqui só entra o que se roda e o que se espera ver.

## Pré-requisitos

| Item | Verificação |
|---|---|
| Elixir 1.20.2 / OTP 29 | `elixir --version` |
| Docker | `docker compose version` |
| Token do GitHub com escopo `read:org` | necessário para US2 — sem ele, só US1 é verificável, e com credencial inválida |
| Organização real no GitHub com ao menos um time | os cenários de contagem dependem disso |

O escopo `read:org` é o que a regra `github.team_membership_evidence` declara
como requerido. Token sem ele passa na conexão e devolve zero times, o que é pior
que falhar — por isso a validação do cadastro (FR-006) checa o escopo, não apenas
o acesso.

## Preparação

```bash
cp .env.example .env          # e preencher THE_BAND_MASTER_KEY
docker compose up -d          # PostgreSQL 16
mix setup                     # deps.get + ecto.setup + assets.setup
mix phx.server                # http://localhost:4000
```

**Primeira verificação, antes de qualquer tela** — FR-005a:

```bash
THE_BAND_MASTER_KEY= mix phx.server
```

Esperado: **o boot falha**, com mensagem dizendo que a chave mestra não está
configurada. Aplicação que sobe sem chave gravaria credencial desprotegida e
ninguém perceberia. Subir aqui é defeito, não conveniência.

## Cenários de validação

Cada um corresponde ao *Independent Test* da user story e aos critérios de
sucesso que ele fecha.

### V1 — Conectar ferramenta com credencial protegida (US1)

1. Cadastrar uma organização cliente e um usuário `admin`.
2. Em `/ferramentas`, conectar o GitHub: instância `https://github.com`, token válido.
3. Recarregar a página.

| Verificar | Requisito |
|---|---|
| Conexão confirmada como válida | FR-006, SC-001 |
| A chave não é legível — só `••••` + quatro caracteres | FR-007, SC-005 |
| A chave não aparece no HTML, nem no estado do socket, nem em atributo de dado | FR-008, SC-005 |
| `select secret from tool_credentials` devolve texto cifrado | FR-005, SC-005 |

Repetir com um token inválido: a conexão é **recusada com explicação do que
faltou**, e nada é gravado — conferir que `tool_credentials` não ganhou linha.

Cadastrar uma segunda credencial: as duas coexistem, ativáveis e desativáveis de
forma independente.

### V2 — Sincronizar pessoas e equipes (US2)

1. Em `/sincronizacoes`, disparar a sincronização.
2. Acompanhar o progresso ao vivo.
3. Comparar os números com o que existe na organização do GitHub.

| Verificar | Requisito |
|---|---|
| Quantidade de pessoas e equipes bate com a origem | SC-002 |
| Contas de automação aparecem classificadas e **fora** da contagem de pessoas | FR-022 |
| Cada vínculo pessoa-equipe traz o nível de acesso observado | FR-020 |
| O relatório final traz coletados, criados, atualizados e ignorados com motivo | FR-028 |
| O número de vínculos pendentes de papel é exibido explicitamente | FR-021, SC-010 |

**Idempotência (SC-003)** — disparar de novo, sem mudança na origem:

```sql
-- antes e depois; os dois lados devem ser idênticos
select count(*), max(record_version) from eo_people;
select count(*), max(record_version) from eo_teams;
```

Esperado: **0 criados, 0 atualizados**. `record_version` não muda.

**Concorrência (FR-018)** — disparar uma segunda sincronização com a primeira em
curso: a segunda não inicia, e a interface informa que já há uma em andamento.

### V3 — Retomada após interrupção (SC-006)

1. Disparar a sincronização e derrubar a aplicação no meio (`Ctrl-C` duas vezes).
2. Subir de novo e retomar.

| Verificar | Requisito |
|---|---|
| O trabalho recomeça do checkpoint, não do zero | FR-015 |
| A origem é consultada no máximo **uma vez a mais, por página**, que a execução não interrompida | SC-006 |
| `sync_checkpoints.cursor` foi gravado após cada página, não antes | R5 |

Contar as chamadas pelo log de telemetria da execução interrompida e da íntegra, e
comparar.

### V4 — Rate limit (SC-009)

Executar contra uma organização grande o suficiente para atingir a janela, ou
reduzir artificialmente o limiar de pausa em ambiente de teste.

| Verificar | Requisito |
|---|---|
| A coleta **pausa antes** de atingir o limite e retoma sozinha | FR-016 |
| A tela mostra "aguardando janela da API" com horário de retomada | contrato de telas |
| A sincronização conclui **sem intervenção manual** | SC-009 |
| A pausa é agendamento Oban, não `Process.sleep` — a fila segue respondendo | R6 |

### V5 — Consulta com proveniência (US3)

Abrir `/pessoas` e `/equipes`.

| Verificar | Requisito |
|---|---|
| Todo registro exibe origem, identificador externo e data de coleta | FR-026, SC-004 |
| A contagem do cabeçalho bate com a listagem, sob qualquer filtro | contrato de EO |
| Nível de acesso é rotulado como **acesso na plataforma**, nunca como papel | FR-019, FR-020 |
| Organização sem equipes mostra estado vazio explicado, não erro | edge case |

### V6 — Isolamento entre tenants (SC-008)

1. Povoar **dois** tenants, cada um com sua ferramenta e sua sincronização.
2. Autenticado no tenant A, percorrer toda a interface.

| Verificar | Requisito |
|---|---|
| Nenhum caminho da interface mostra dado do tenant B | FR-027, SC-008 |
| Trocar o id na URL devolve 404, nunca o registro do outro tenant | FR-027 |

Esta é a verificação que **não** pode ser feita só por teste unitário: exige as
duas bases povoadas ao mesmo tempo.

### V7 — Reprocessar mapeamento corrigido (SC-007)

1. Alterar um mapeamento em `priv/knowledge_base/mappings/github/eo/`.
2. Validar a base, reiniciar (a base é lida no boot — R4) e reprocessar.

| Verificar | Requisito |
|---|---|
| Os registros são atualizados a partir de `raw_payloads` | FR-017 |
| **Nenhuma** chamada ao GitHub acontece — conferir no log de telemetria | SC-007 |

Alterar o YAML introduzindo erro de sintaxe e reiniciar: o **boot falha**. Base
inválida não pode gerar aplicação funcionando com o modelo pela metade (R4).

### V8 — Ausência não é remoção

1. Remover uma pessoa de um time no GitHub.
2. Sincronizar de novo.

| Verificar | Requisito |
|---|---|
| O vínculo anterior é preservado, com `no_longer_observed_at` preenchido | edge case, Assumptions |
| Nada é apagado | princípio III |
| A tela mostra o vínculo com marcação histórica | contrato de telas |

## Quality gates

Antes de abrir o PR, todos verdes — constituição, princípio VII:

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
mix dialyzer
mix test
mix knowledge.validate
mix knowledge.graph
.venv/bin/python scripts/validate_knowledge_base.py   # até a paridade com as Mix tasks ser confirmada
```

`mix knowledge.test`, `mix knowledge.docs` e `mix knowledge.information_model`
seguem como scripts Python nesta feature — dívida registrada em
[plan.md](plan.md), Complexity Tracking.

## O que esta feature NÃO prova

Declarado para que nenhum destes seja confundido com lacuna de execução:

- reconciliação de identidade entre contas — duas contas da mesma pessoa são duas linhas;
- promoção de vínculo observado a alocação formal — a coluna existe, o fluxo não;
- papéis organizacionais — o catálogo é criado vazio;
- demais ontologias, outras ferramentas, medidas e indicadores;
- agendamento periódico da sincronização — o disparo é manual sob demanda.
