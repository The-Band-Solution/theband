# API com token e controle de acesso a dados — declaração da superfície de risco

**Data**: 2026-09-09 · **Papel**: Security (`AGENTS.md` §13) · **Ramo lido**: `development`
(`eb7ac54`, 2026-09-08, versão `0.6.0`) · **Escopo**: declaração da superfície de risco de
uma feature **ainda não especificada**, pedida pela pessoa mantenedora em 2026-09-09.

**Régua**: OWASP Top 10 (2021) para nomear o risco; OWASP ASVS 4.0.3 para nomear a
verificação. O Top 10 diz *o que pode dar errado*; o ASVS diz *o que precisa ser conferido
para afirmar que não deu*.

**O que este documento não é.** Não decide prioridade, não aceita entregável e não escreve
a spec — isso é do Product Owner com a pessoa mantenedora, e a spec é do ciclo Spec Kit.
Não escreve teste — o cenário de ataque é meu, o teste é do QA (`.claude/agents/qa.md`).
Achado de severidade alta aqui é **recomendação** de bloqueio, nunca bloqueio.

**Por que vem antes da spec.** O contrato da API vai depender desta leitura, e o princípio
VI da constituição exige o contrato antes da implementação — inclusive o que a API
deliberadamente **não** expõe. Requisito de segurança que não vira FR numerado não é
rastreado, e o que não é rastreado não é entregue: uma lista de boas práticas no fim da spec
não tem tarefa, não tem teste, não tem critério de aceitação, e desaparece sem que nada
acuse. A §12 deste documento existe para que isso não aconteça.

---

## 0. O que foi verificado, com que ferramenta, e o código de saída

Nada abaixo é "o repositório está limpo". É o que cada ferramenta **mediu**, com o código de
saída lido — nunca a última linha da saída (constituição, princípio XI).

| Verificação | Comando | Saída | O que isso prova — e o que não prova |
|---|---|---|---|
| Análise estática de segurança | `mix sobelow --exit low --skip` | `SCAN COMPLETE`, **exit 0** | nenhum padrão que o Sobelow reconhece, **fora dos templates**; ele não lê `~H` (registrado em `lib/mix/tasks/gates.ex:78-90`) |
| **A ferramenta mediu?** | mesmo comando, com `String.to_atom(params["x"])` injetado num módulo novo | `DOS.StringToAtom … Line: 4`, **exit 1** | o zero acima é medição, não conversor quebrado. Defeito desfeito em seguida |
| Avisos publicados no Hex | `mix hex.audit` | `No retired or security advisory packages found`, **exit 0** — **com aviso** (ver §11.3) | nenhuma dependência tem aviso **publicado hoje**. Dependência sem aviso não é dependência sem falha |
| Segunda base de avisos | `mix deps.audit` | `No vulnerabilities found.`, **exit 0** | base diferente do `hex.audit`, e por isso não redundante (`gates.ex:60-63`) |
| Injeção em `fragment` | `grep -rn 'fragment("' lib/ \| grep '#{'` | **nenhuma ocorrência** | nenhum literal SQL com interpolação. Não cobre `Repo.query!` com string montada, que li à mão |
| `raw/1` na camada web | `grep -rn "raw(" lib/the_band_web/` | **nenhuma ocorrência** | é o que o gate 8 (`raw() fora dos templates`) guarda |
| Tenant nas consultas | 7 arquivos `queries.ex`, 125 funções públicas | **15 cabeçalhos sem `%Tenant{}`** | dos 15, 6 são cláusulas de retorno antecipado (`_tenant, []`), 4 são cálculo puro, 4 recebem `tenant` sem casar o struct e **1** recebe UUID cru (§11.4) |
| Pipeline `:api` em uso | `grep -n "pipe_through" lib/the_band_web/router.ex` | `:browser` ×5, **`:api` zero vezes** | a premissa do pedido está correta: é greenfield |

> **Ressalva de ambiente, e ela importa.** As ferramentas **não rodaram no diretório de
> trabalho**: `deps` está commitada como link simbólico para si mesma
> (`deps -> /Users/paulossjunior/projects/theband/deps`, blob `1d6c2a6`, commit `4626ec3`),
> o que produz `ELOOP` e faz `mix deps.get` abortar com `Can't continue due to errors on
> dependencies`. Rodei num clone raso em diretório temporário, com o link removido **apenas
> lá** — o repositório de trabalho não foi tocado. Isto é achado por si (§11.1).
>
> **Consequência para esta entrega**: eu **não rodei `mix gates`**. Rodei 4 dos 14 gates.
> Não afirmo verde de gate nenhum além desses quatro, e o veredito continua sendo o código
> de saída de `mix gates` (`lib/mix/tasks/gates.ex`, `mix gates --list`).

---

## 1. Resumo — a superfície em uma tabela

| # | Risco OWASP | Onde nesta feature | Sev. | O que fecha |
|---|---|---|---|---|
| A01-1 | Quebra de controle de acesso | token sem `tenant_id` amarrado na linha | **Alta** | tenant sai do token, `NOT NULL`, e teste com dois tenants povoados |
| A01-2 | Quebra de controle de acesso | tenant vindo de parâmetro, cabeçalho ou corpo | **Alta** | contrato proíbe; nenhuma rota lê tenant da requisição; teste que manda tenant vizinho |
| A01-3 | IDOR entre tenants | rota que filtra só por `id` | **Alta** | toda leitura por `%Tenant{}`; 404 para id de fora; teste par a par |
| A01-4 | Autorização por pessoa | rota que exige só "token válido do tenant" | **Alta** | reuso de `Tenants.pode_ver/3` e `pode_ver_equipe/3`; nunca reimplementação |
| A01-5 | Autoridade por outra porta | API expõe por rota o que a tela recusa por veredito | **Alta** | o veredito é do domínio, não do roteador; paridade tela↔API provada por teste |
| A01-6 | Desligamento incompleto | não existe estado "conta desativada"; token sobrevive | **Alta** | revogação pelo administrador + `disabled_at` (§11.5 — risco que a feature **expõe**) |
| A02-1 | Falha criptográfica | token guardado de forma reversível ou em claro | **Alta** | hash irreversível + comparação em tempo constante (§4.2) |
| A02-2 | Falha criptográfica | segredo do token exibido mais de uma vez | **Média** | mostra uma vez; depois só prefixo público |
| A07-1 | Autenticação | mensagem que distingue token inexistente de revogado/vencido | **Média** | 401 único; o motivo vai para o retorno e para o log, nunca para o corpo |
| A07-2 | Autenticação | ausência de expiração e de renovação explícita | **Média** | limiar na base de conhecimento (§7.4), nunca em constante |
| A09-1 | Registro e monitoramento | abuso indetectável; segredo no log | **Alta** (segredo) / **Média** (registro) | campos de `AGENTS.md` §15 + lista do que nunca vai (§7.2) |
| A09-2 | Anti-automação | sem limite de taxa | **Média** | contador no banco, na forma do `Auth` (§7.3), limiar em YAML |
| A05-1 | Configuração | pipeline `:api` sem plug de escopo, sem cabeçalhos | **Média** | pipeline própria e completa, declarada no contrato |
| A04-1 | Desenho inseguro | segunda porta de autorização, ou defesa no chamador | **Média** | um veredito só; garantia dentro da função que grava/lê |
| A04-2 | Desenho inseguro | `rescue` que devolve `[]`; ausência como zero | **Média** | recusa é retorno; ausência é nula |
| A03-1 | Injeção | filtro/ordenação/paginação vindos da query string | **Média** | lista fechada casada uma a uma, como já é nas telas |
| A10-1 | SSRF | nenhuma borda nova **se** a v1 for só leitura | **Baixa** | e é uma das razões de §10 |
| A08-1 | Integridade | rota de escrita, upload ou consulta arbitrária na v1 | — | §10: não entram |

Riscos **já existentes hoje**, que a feature não introduz — §11, separados de propósito.

---

## 2. O ponto de partida, medido: a API não herda nada

`lib/the_band_web/router.ex:44-46` declara a pipeline e **nenhum `scope` a usa**. Não há
módulo de token, não há `Authorization`, não há controller JSON além do `ErrorJSON` gerado
pelo Phoenix (`lib/the_band_web/controllers/error_json.ex`, que devolve o texto do status e
mais nada).

Isso é bom — greenfield é onde a decisão é barata. E é perigoso pelo motivo que a tabela
abaixo mostra: **toda garantia de acesso desta plataforma mora na pipeline `:browser` ou na
`on_mount` das `live_session`**, e a pipeline `:api` não passa por nenhuma das duas.

| Garantia que vale hoje | Onde ela mora | A API herda? |
|---|---|---|
| existe pessoa autenticada | `router.ex:41` (`plug TheBandWeb.Plugs.CurrentScope`) + `require_user` (`current_scope.ex:56`) | **Não** |
| o tenant sai da conta, nunca do parâmetro | `current_scope.ex:24-45`; `hooks.ex:20-40` | **Não** |
| sessão versionada — trocar senha derruba o outro navegador (FR-015) | `current_scope.ex:38`; `hooks.ex:107-111` | **Não** |
| 7 dias de inatividade encerram | `hooks.ex:18,113-119` | **Não** |
| senha temporária obriga troca antes de qualquer tela (FR-013) | `hooks.ex:122-126` | **Não** |
| espera crescente na entrada (FR-016) | `auth.ex:34-35,86-89` | **Não** |
| mensagem única de recusa (FR-002) | `auth.ex:41-68` | **Não** |
| alcance operacional (FR-023) | `current_scope.ex:101`; `hooks.ex:47-71` | **Não** |
| CSRF | `router.ex:12` (`protect_from_forgery`) | **Não** — e para `Bearer` é irrelevante; volta a ser exigência se a API aceitar cookie (§5.4) |
| CSP e cabeçalhos seguros | `router.ex:28-39` | **Não** — e a CSP não protege cliente programático; `nosniff` protege (§5.2) |
| origem conferida no handshake | `runtime.exs:115` + `TheBandWeb.Origens` | **Não**, e o próprio módulo diz por quê: *"quem não envia [o cabeçalho de origem] é cliente programático — e contra ele a defesa é a sessão, não a origem"* (`origens.ex:21-25`) |

**A leitura desta tabela é a tese deste documento.** A API não é uma tela sem HTML: é uma
segunda porta para o mesmo dado, sem nenhuma das nove travas acima, e cada uma delas tem de
ser reconstruída ou explicitamente dispensada com motivo escrito. O que **não** deve ser
reconstruído é o **veredito** — esse existe, é único, e reusá-lo é o item A01-4.

---

## 3. A01 — Quebra de controle de acesso

É o risco número um deste produto, e o multitenant é a metade dele. Os cinco caminhos abaixo
são as cinco formas de o desenho errar; cada um traz o cenário no formato que o QA converte
em teste.

**Nota de método para todos os cenários**: vazamento entre tenants se prova com **dois
tenants povoados simultaneamente** (constituição, princípio V) — um tenant só nunca prova
isolamento. E todo cenário precisa da guarda de que mediu algo: `assert length(lista) > 0`
**antes** de afirmar que nada na lista é do vizinho, senão a suíte celebra a consulta
quebrada.

### 3.1 Achado A01-1 — token sem tenant amarrado

**Severidade: Alta** · OWASP A01 · ASVS V4.1 (*Access Control Design*), V4.2.1 (IDOR)

**Onde erraria.** Na migração do token. Se a linha do token guardar só `user_id` e o tenant
for resolvido depois — por `preload`, por parâmetro, ou por "o tenant da conta no momento da
requisição" —, o token passa a valer para qualquer tenant a que aquela conta venha a
pertencer, e a decisão de acesso deixa de ser auditável na própria linha.

Hoje a casa já resolve isso do lado da sessão, e o padrão a copiar está em
`lib/the_band/tenants.ex:72-78`: `fetch_user/1` recebe **só o id** e devolve o usuário com
`:tenant` pré-carregado — o tenant vem **do registro**, e quem chama não tem como escolhê-lo.

**Consequência para o negócio.** Um token emitido para uma conta que responde por uma
organização passa a ler dados de outra organização cliente, sem que nada na linha do token
registre a mudança de alcance. Depois de um incidente, não há como responder *quem viu o
quê* — o que o princípio III existe para permitir.

**O que fecha.**
- `api_tokens.tenant_id` **`NOT NULL`**, `references(:tenants)`, gravado na emissão;
- o `tenant_id` do token e o `tenant_id` da conta são **conferidos entre si** a cada
  requisição, e divergência é `401` — não `403`, e não "usa o da conta". Divergência aqui é
  estado impossível, e estado impossível não se conserta em silêncio;
- `unique_index` sobre a identificação pública do token, e índice sobre `tenant_id`.

**Cenário para o QA.**
> **Dado** dois tenants povoados, `alfa` e `beta`, com pessoas, equipes e itens de trabalho
> em cada um; **e** um token emitido para uma conta de `alfa`;
> **Quando** qualquer rota de leitura da API é chamada com esse token;
> **Então** todo registro devolvido tem `tenant_id` de `alfa`;
> **E** `assert length(registros) > 0` (a guarda: sem ela, consulta quebrada passa);
> **E** `refute Enum.any?(registros, & &1.tenant_id == beta.id)`.
>
> **Prova de que o teste mede**: apagar o `where` de tenant da consulta faz este teste
> reprovar. Se não reprovar, o teste é teatro.

**Se não entrar agora.** Não há "depois": é coluna de migração. Adicionar `tenant_id` a
tokens já emitidos exige decidir retroativamente a qual tenant cada um pertence, e essa
decisão é adivinhação.

### 3.2 Achado A01-2 — o tenant vindo do parâmetro

**Severidade: Alta** · OWASP A01 · ASVS V4.1.3 (*least privilege*), V13.1 (*API genérica*)

**Onde erraria.** Numa rota como `GET /api/v1/tenants/:tenant_id/people`, ou num cabeçalho
`X-Tenant-Id`, ou num campo `tenant` no corpo. É o erro mais fácil de cometer porque parece
organização de URL, e é o mais caro porque **funciona**: a consulta filtra por tenant, o
filtro está lá, e é o tenant errado.

Esta é a forma exata da **L19** (`docs/sprints/licoes-aprendidas.md:752`) — o filtro existe,
é o filtro errado, e a ausência do certo é invisível. Lá, `mark_evidence_no_longer_observed/2`
filtrava por `tenant_id` sem escopo de organização, e coletar uma organização marcava como
"não mais observados" os vínculos da outra. Nada falhou, nada logou erro, e a semântica mais
central do projeto passou a mentir.

**Consequência para o negócio.** Quem tem token de qualquer tenant lê os dados de todos os
outros trocando um segmento da URL. É o vazamento completo, e o registro de acesso vai
mostrar requisições bem-sucedidas — porque foram.

**O que fecha.**
- **FR com MUST NOT explícito**: nenhuma rota da API MUST NOT aceitar identificador de
  tenant em caminho, query string, cabeçalho ou corpo. O tenant é **derivado do token**, e
  ponto;
- o `plug` de autenticação escreve `conn.assigns.current_tenant` e
  `conn.assigns.current_user` a partir da linha do token, na mesma forma que
  `current_scope.ex:24-45` faz para a sessão;
- nenhuma função de domínio nova aceita `tenant_id` cru — todas casam `%Tenant{}` no
  cabeçalho, que é o que torna o filtro verificável em revisão em vez de presumido
  (`lib/the_band/tenants.ex:5-7`). Ver §11.4 para a exceção que já existe.

**Cenário para o QA.**
> **Dado** um token de `alfa` e um tenant `beta` povoado;
> **Quando** a rota é chamada com `?tenant_id=<beta>`, com `X-Tenant-Id: <beta>` e com
> `{"tenant_id": "<beta>"}` no corpo — os três, em testes separados;
> **Então** a resposta é a mesma de uma chamada sem esses valores: dados de `alfa`;
> **E** nenhum registro de `beta` aparece;
> **E** a asserção é sobre **o conteúdo devolvido**, não sobre o status — 200 com dado do
> vizinho é o defeito, e um teste que só olha o status o aprova.

### 3.3 Achado A01-3 — id de recurso de outro tenant aceito por rota que filtra só por `id`

**Severidade: Alta** · OWASP A01 · ASVS V4.2.1 (*proteção contra IDOR*)

**Onde erraria.** Em `GET /api/v1/people/:id`, se a implementação chamar algo como
`Repo.get(Person, id)` — ou reusar uma função cujo tenant vem implícito. Os identificadores
são UUID, o que **reduz** a chance de adivinhar, mas não é controle de acesso: UUID vaza em
log, em URL compartilhada, em exportação e no próprio corpo de outra resposta da API.

**O que a casa já faz certo, e é o modelo.** As duas telas de detalhe respondem
**não encontrado** para id de fora, de propósito e com o motivo escrito:

| Tela | Arquivo | Comportamento |
|---|---|---|
| pessoa | `lib/the_band_web/live/people_live/show.ex:66-80` | *"Pessoa de outro tenant devolve não encontrado — nunca 'sem permissão', porque confirmar existência já é vazamento entre tenants"* |
| equipe | `lib/the_band_web/live/teams_live/show.ex:60-70` | `# FR-027 — id de outro tenant não devolve o registro; devolve 404` |

E a consulta que as sustenta filtra pelos dois campos:
`EO.fetch_person(%Tenant{id: tenant_id}, person_id)` em
`lib/the_band/ontology/seon/eo/queries.ex:1070-1072` — `where: p.tenant_id == ^tenant_id and
p.id == ^person_id`.

**O que fecha.** A API MUST reusar essas funções, e não escrever consulta nova. Quando
precisar de uma leitura que não existe, ela nasce com `%Tenant{}` no cabeçalho.

**Cenário para o QA.**
> **Dado** uma pessoa `p_beta` no tenant `beta` e um token de `alfa`;
> **Quando** `GET /api/v1/people/<p_beta.id>` é chamado com o token de `alfa`;
> **Então** a resposta é **404**, e o corpo é idêntico ao de um UUID inexistente
> — comparar os dois corpos byte a byte é a asserção;
> **E** o mesmo vale para equipe, projeto, item de trabalho e qualquer recurso com `:id`;
> **E** o teste é **paramétrico sobre a lista de rotas**, não uma cópia por rota: rota nova
> sem entrada na lista é o defeito que reincide.

### 3.4 Achado A01-4 — tenant não é escopo: a autorização por pessoa

**Severidade: Alta** · OWASP A01 · ASVS V4.2 (*controle de acesso no nível da operação*)

O pedido diz *"somente pessoas autorizadas no tenant"*, e a palavra que carrega o peso é
**autorizadas**. Filtrar por tenant impede ver *outra organização cliente*; não impede ver
*quem não é seu* dentro dela. São duas verificações, e a segunda é a que a plataforma já
decidiu em 2026-08-26 e implementou em duas features.

**Os vereditos que existem, e onde estão.** Todos passam pela fachada
`TheBand.Tenants` (`lib/the_band/tenants.ex:26-31`), que delega para
`TheBand.Tenants.Access`:

| Veredito | Assinatura | Arquivo:linha | Responde |
|---|---|---|---|
| painel de uma pessoa | `pode_ver/3` | `access.ex:210` | quem lê o trabalho de quem — FR-012 da 023, somado aos escopos da 045 |
| medidas de uma equipe | `pode_ver_equipe/3` | `access.ex:271` | quem alcança a quebra por pessoa nomeada de uma equipe — FR-024 da 058 |
| escrever estrutura | `pode_gerir_estrutura/3` | `access.ex:185` | quem declara papel, saída, composição — FR-006/080-082 da 060 |
| telas operacionais | `operacional?/2` | `access.ex:450` | quem alcança coleta e ferramentas — FR-023 da 045 |
| a união vigente | `scopes/2` | `access.ex:54` | os escopos derivados + concedidos, com a origem de cada |
| liderança declarada | `EO.Visibility.pode_ver/3` | `visibility.ex:78` | a regra da #369, somada **por último** pelo `Access` |

Os três primeiros devolvem **relator** — `{:ok, motivo}` / `{:nao, motivo}` —, nunca
booleano, e o motivo é parte do contrato: `access.ex:172-180` explica que
`:conta_sem_pessoa_declarada`, `:vinculo_encerrado` e `:sem_concessao` levam a **ações
diferentes**, e colapsá-las num `false` manda quem foi recusado procurar a administradora com
a pergunta errada.

**Quais a API tem de reusar.** Todos os que a rota correspondente da tela usa — e o
mapeamento é este:

| Rota da API (proposta) | Veredito obrigatório | Onde a tela já o chama |
|---|---|---|
| `GET /api/v1/people/:id` (painel, trabalho, mudanças, verificação) | `Tenants.pode_ver/3` | `people_live/show.ex:280` |
| `GET /api/v1/teams/:id` com quebra por pessoa nomeada | `Tenants.pode_ver_equipe/3` | `teams_live/show.ex:2988` |
| `GET /api/v1/teams/:id` só agregado | **nenhum além do tenant** — FR-023 da 058 é explícita: *"o agregado da equipe continua legível por qualquer conta do tenant"* | — |
| `GET /api/v1/syncs`, `/tools`, `/profiles` | `Tenants.operacional?/2`, **com o recorte** | `hooks.ex:47-71` |
| `GET /api/v1/accounts`, `/access-scopes`, `/roles` | `User.admin?/1` | `hooks.ex:75-90` |
| qualquer escrita | `pode_gerir_estrutura/3` | `teams_live/show.ex:718-731` — e a v1 não escreve (§10) |

**O que acontece se a API reimplementar.** Duas verdades, e a segunda envelhece. O caso não é
hipotético nesta base: `pode_gerir_estrutura/3` **substituiu** uma versão anterior que
autorizava também pelo escopo `organization`/`project` da conta, e a troca foi feita com
medição antes (`access.ex:161-168`: *"Medido antes de trocar, no banco de desenvolvimento:
zero contas não-administradoras escreviam por esse caminho"*). Uma cópia da regra na camada da
API não teria acompanhado essa troca, e continuaria autorizando pelo caminho retirado — sem
que nada acusasse, porque a tela continuaria correta.

**Cenário para o QA.**
> **Dado**, no tenant `alfa`: a conta `sem_relacao` (elo declarado, nenhuma concessão,
> nenhum vínculo de equipe) e a pessoa `alvo`, de uma equipe a que `sem_relacao` não pertence;
> **e** um token de `sem_relacao`;
> **Quando** a API é chamada para o painel de `alvo`;
> **Então** a resposta **não** contém vazão, lead time, antipadrão, participação em mudança
> nem verificação — as seis medidas nomeadas em `people_live/show.ex:282-333`;
> **E** `Tenants.pode_ver(alfa, sem_relacao, alvo.id)` devolve `{:nao, :fora_dos_escopos}`
> no mesmo cenário — a asserção sobre o veredito **e** a asserção sobre o corpo, porque uma
> API que chama o veredito e ignora o retorno passa na primeira;
> **E** o teste espelho: a mesma conta com concessão `team` na equipe de `alvo` **recebe** as
> medidas. Sem esse par, o primeiro teste passa com a API devolvendo vazio para todos.

**Uma exigência de custo, herdada da FR-012h.** A recusa MUST acontecer **antes da carga**,
e não antes da serialização: *"calcular a vazão, o lead time e os antipadrões de quem não
pode vê-los é fazer o trabalho do vazamento e depois esconder o resultado — e o custo fica
igual"* (`people_live/show.ex:268-272`; spec 023 FR-012h). A casa tem o instrumento para
provar isso — `TheBand.ContadorDeConsultas` (`test/support/contador_de_consultas.ex`) —, e o
teste-guarda mede que a resposta recusada custa **menos** consultas que a permitida.

### 3.5 Achado A01-5 — a API expõe por rota o que a tela recusa por veredito

**Severidade: Alta** · OWASP A01 e A04 · ASVS V1.4 (*arquitetura de controle de acesso*),
V4.1.5 (*falhar seguro*)

Este é o achado que o pedido nomeia com precisão — *"é a mesma decisão vazando por outra
porta"* — e ele já tem precedente nesta base, resolvido a favor do domínio.

**O precedente.** `pode_ver_equipe/3` existe porque a decisão de 2026-08-26 valia numa rota e
não na outra. A doc da função diz, com estas palavras (`access.ex:238-260`):

> *"A tela da equipe passou a oferecer a mesma classe de leitura pela porta ao lado: login,
> solicitações abertas por pessoa nomeada e a mediana individual. Sem este veredito, a decisão
> de 2026-08-26 valeria numa rota e não na outra — **e a rota é artefato do roteador, não
> fronteira do domínio**."*

A API é a terceira porta para o mesmo dado. A frase acima vale nela sem alteração, e é a
razão pela qual o veredito não pode migrar para a camada web: se a autorização morar no
controller, cada porta nova recomeça a discussão.

**A forma concreta do vazamento nesta feature.** Não é uma rota óbvia chamada
`/api/v1/people/:id/dashboard`. São três formas discretas, e todas passam pelo tenant:

1. **o campo dentro do agregado.** `GET /api/v1/teams/:id` devolvendo, junto da mediana da
   equipe, a lista `members` com `login` e `open_requests` por pessoa. O agregado é aberto
   (FR-023); a quebra por pessoa nomeada não é (FR-024). Um campo a mais no serializador
   apaga a distinção;
2. **a listagem que dispensa o detalhe.** `GET /api/v1/work-items?assignee=<person_id>`
   entrega, por composição, o que o painel da pessoa recusa. O filtro é conveniente e é a
   porta;
3. **a expansão.** `?include=people.work` ou `?fields=` arbitrário — cada expansão é uma
   rota nova que ninguém revisou. É uma das razões de §10.

**O que fecha.**
- **FR**: nenhum campo da API MUST NOT ser servido sem que o veredito que o governa na tela
  tenha sido consultado para **aquele** campo. O veredito é por dado, não por rota;
- **teste de paridade**, e é o entregável mais valioso desta feature: para cada par
  (rota da API, tela correspondente), a mesma conta em `{:nao, _}` recebe da API o mesmo
  conjunto vazio que a tela mostra. Um teste tabelado sobre a lista de pares, com a lista
  no código — para que rota nova sem par apareça como lacuna e não como silêncio;
- **o serializador é lista de permissão, nunca `Map.drop`.** Campo novo no schema não deve
  aparecer na API por acidente de reflexão. `Map.take` sobre lista declarada; nunca
  `Jason.encode(struct)`.

**Cenário para o QA.**
> **Dado** a conta `sem_relacao` de `alfa` e a equipe `eq` a que ela não pertence, com dois
> integrantes e solicitações abertas;
> **Quando** `GET /api/v1/teams/<eq.id>` é chamado com o token dela;
> **Então** o corpo contém a mediana da equipe (agregado — FR-023 permite);
> **E** `refute` qualquer `login`, `person_id` ou contagem por pessoa no corpo — a asserção
> é sobre **ausência de chave**, e é ela que reprova quando alguém acrescenta um campo;
> **E** a mesma chamada com uma conta **integrante** da equipe devolve a quebra por pessoa.

### 3.6 Achado A01-6 — o token sobrevive ao desligamento da pessoa

**Severidade: Alta** · OWASP A01 e A07 · ASVS V3.3.1 (*terminação de sessão*), V4.1

O pedido pergunta o que acontece com o token quando a conta perde acesso ou sai do tenant. A
resposta tem duas metades, e só a primeira está resolvida pelo desenho da casa.

**A metade resolvida: o alcance é derivado, e encolhe sozinho.** `scopes/2` **lê as relações
vigentes a cada chamada** — *"elo → pessoa → vínculos → equipes → ligações declaradas →
projetos. Encerrou o fato, fechou o escopo — sem job, sem coluna, sem segunda verdade"*
(`access.ex:13-18`, FR-020/021). Logo, **se o token não carregar veredito nenhum**, estes
cinco eventos já surtem efeito na requisição seguinte, sem trabalho adicional:

| Evento | Efeito no alcance do token |
|---|---|
| concessão revogada (`ScopeGrant.revoke_changeset/2`, `scope_grant.ex:54`) | escopo sai da união na próxima requisição |
| vínculo de equipe encerrado | idem — `EO.person_active_teams/2` deixa de devolvê-lo |
| elo revogado (`users.person_revoked_at`, `tenants.ex:262-272`) | o piso cai; `pode_ver/3` passa a `{:nao, :sem_elo_declarado}` |
| `role` rebaixado de `admin` | os ramos `User.admin?/1` deixam de abrir |
| ferramenta com observação encerrada | o dado deixa de ser coletado; o já coletado permanece, como manda o princípio III |

**Portanto**: o token MUST NOT gravar escopo, papel, lista de organizações nem qualquer
veredito materializado. Ele guarda **quem** (`user_id`) e **onde** (`tenant_id`); o *que
pode* é recomputado. Um token com "escopos embutidos" — o desenho de JWT com claims — cria a
segunda verdade que `access.ex` foi escrito para não ter, e ela envelhece **no bolso de quem
saiu**.

**A metade não resolvida, e é achado de hoje que a feature torna material.** Não existe, na
plataforma, estado de **conta desativada**:

- `priv/repo/migrations/20260809120000_create_tenants_and_users.exs:25-31` — `users` tem
  `email`, `name`, `role`, `tenant_id`. **`tenants` tem `status`; `users` não tem nada
  equivalente**;
- `lib/the_band_web/live/accounts_live/index.ex` oferece `criar`, `reset` (senha),
  `associar` e `revogar_elo` — **não há remover nem desativar conta**;
- o desligamento hoje é, na prática, **implícito**: quem administra chama
  `Auth.reset_password/3` (`auth.ex:202-212`), recebe a temporária uma vez, e não a entrega.
  A pessoa não entra mais porque não sabe a senha nova.

Esse mecanismo implícito **para de funcionar no dia em que existir token**: o token não é a
senha, e trocar a senha não o invalida — a menos que a spec decida que invalida (§4.6, é uma
das perguntas de clarificação).

**Consequência para o negócio.** Uma pessoa que sai da organização continua lendo os dados
dela por API, e quem administra não tem um ato que resolva: precisa saber que existem tokens,
achá-los e revogá-los um a um. É o cenário clássico de acesso órfão, e ele passa
silenciosamente por todas as travas — porque o token é válido e a conta existe.

**O que fecha.**
- **FR**: quem administra o tenant MUST poder revogar **qualquer** token de **qualquer** conta
  do tenant, num ato, e a revogação MUST valer na requisição seguinte (marca, nunca `delete`
  — a forma de `ScopeGrant`, com `revoked_by_user_id` e `revoked_at`);
- **FR**: a tela de contas MUST mostrar quantos tokens vigentes cada conta tem — ausência
  dita, nunca coluna em branco;
- **backlog separado, e ele é anterior à API**: `users.disabled_at` (ou `status`), com o ato
  correspondente em `/accounts`, e a regra de que conta desativada não autentica **nem por
  senha nem por token**. Enquanto não existir, a revogação em massa por conta é o
  substituto — e isso MUST estar escrito na spec como limitação, não presumido.

**Cenário para o QA.**
> **Dado** uma conta com token vigente que responde 200 numa rota de leitura;
> **Quando** quem administra revoga os tokens dessa conta;
> **Então** a requisição seguinte, com o mesmo token, responde **401**;
> **E** o corpo é idêntico ao de um token inexistente (§9);
> **E** a linha do token continua no banco, com `revoked_at` e `revoked_by_user_id`
> preenchidos — `refute` que a linha foi apagada, porque histórico de acesso é dado de
> auditoria (SC-005 da 045).

---

## 4. O token em si — A02 e A07

### 4.1 Como se gera

**A casa já tem a primitiva, e ela está certa.** `TheBand.Tenants.User.novo_token/0`
(`user.ex:144`):

```elixir
Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
```

256 bits de um gerador criptográfico, em 43 caracteres seguros para URL. É o que a ASVS pede
(V3.2.2: entropia mínima de 64 bits para token de sessão — 256 está quatro vezes acima) e é
o que o token de API deve usar. **Não invente**: reusar esta função, ou uma irmã dela no
módulo novo, é o caminho.

O que **não** serve: `Ecto.UUID.generate/0` (não é aleatório criptográfico em todas as
versões, e 122 bits de entropia num formato que as pessoas confundem com identificador
público), `:rand.uniform/1` (gerador não criptográfico), e qualquer derivação do `user_id`.

**A forma proposta do token**, e cada parte tem razão:

```
tb_<id público: 12 caracteres>_<segredo: 43 caracteres>
│    │                          └─ os 32 bytes de `strong_rand_bytes`, nunca guardados
│    └─ identifica a LINHA, é público, vai para log e para tela
└─ prefixo fixo, reconhecível por varredor de segredo
```

### 4.2 Como se guarda — e por que a resposta não é o cofre da casa

A pergunta certa é: **o que a plataforma precisa fazer com este valor depois?** E a resposta
divide o problema em dois, que a casa já resolve de formas diferentes:

| O que a plataforma precisa | Exemplo desta base | Forma correta |
|---|---|---|
| **replicar** o segredo para um terceiro | o token do GitHub, que o coletor manda no cabeçalho (`sources.ex:183-193`) | **reversível** — `TheBand.Encrypted.Binary` sobre o `Vault` (AES-GCM 256) |
| **conferir** um segredo que alguém apresenta | a senha de entrada (`auth.ex:64`) | **irreversível** — hash |

O token de API é do segundo tipo: a plataforma nunca precisa recuperá-lo, só decidir se o
valor apresentado é o mesmo. Logo:

| Forma de guarda | Reversível? | Custo por requisição | Serve? |
|---|---|---|---|
| `TheBand.Encrypted.Binary` (`encrypted/binary.ex`, Cloak/AES-GCM, `vault.ex`) | **sim** | microssegundos | **Não.** Guardar reversível cria um alvo que, com a chave mestra, devolve **todos** os tokens em claro. É a proteção certa para credencial de terceiro, e a errada para verificador do próprio segredo |
| `Bcrypt.hash_pwd_salt/1` (`bcrypt_elixir`, já na casa) | não | **~100 ms** (medido e declarado em `mix.exs:129-132`) | **Não** para API. Aquele custo *é a proteção* contra senha humana de baixa entropia (specs/045 research R1); numa API ele é auto-negação de serviço, e impede a busca por índice |
| **SHA-256 do segredo + `Plug.Crypto.secure_compare/2`** | não | microssegundos | **Sim.** A entropia está nos 256 bits do segredo, não no KDF: não há dicionário a percorrer. É a recomendação |

**Esta recomendação não enfraquece nada.** O bcrypt continua guardando senha (`user.ex:134`),
exatamente onde a lentidão é defesa. A diferença entre os dois casos é a entropia da entrada,
e é ela que decide — não a preferência por "o hash mais forte".

**O detalhe que faz a diferença, e a casa já mostra o contraste.** Hoje a sessão compara
tokens com `==` (`current_scope.ex:38`: `user.session_token == get_session(conn,
:session_token)`), e **isso está correto lá**: o valor vem de um cookie assinado que o próprio
servidor emitiu, e sem a assinatura o atacante não consegue iterar valores para medir tempo.
Na API o valor vem cru de um cabeçalho controlado por quem chama — o canal de tempo é
alcançável, e a comparação MUST ser `Plug.Crypto.secure_compare/2`, sobre os hashes de
tamanho fixo.

**E a busca no banco não deve ser pelo hash**: `where: t.token_hash == ^hash` é comparação do
Postgres, fora do nosso controle de tempo. Busca-se pelo **id público** (indexado, único),
e a conferência do hash é em memória, em tempo constante. É por isso que o formato do token
tem duas partes.

**ASVS**: V2.10 (*autenticação de serviço* — segredo guardado com proteção suficiente),
V3.5.2 (token em vez de segredo estático, e o desvio declarado: aqui **é** um segredo
estático, o que exige expiração e revogação — §4.4 e §4.5), V6.2 (algoritmos).

### 4.3 O que se mostra uma vez, e nunca mais

**A casa já tem os dois padrões, e eles são consistentes**:

- `Auth.reset_password/3` devolve a senha temporária **uma vez, em claro**, para a tela
  mostrar — *"nunca logada, nunca persistida em claro"* (`auth.ex:183-186, 202-212`);
- `ProviderCredential.masked/1` (`ai/provider_credential.ex:47-48`) é *"a única forma em que
  [a chave] aparece"* depois de gravada: `"••••" <> last_four`.

**Para o token de API, a recomendação difere num ponto, e o motivo é preciso**: mostre o
**prefixo e o id público** (`tb_a1b2c3d4e5f6…`), não os quatro últimos do segredo. Os quatro
últimos da chave da OpenAI são úteis porque a pessoa os reconhece do painel do provedor —
ela não tem essa referência para um token que nós emitimos, e mostrar o fim do segredo
entrega 20 bits dele sem necessidade. O id público existe justamente para ser o rótulo.

- **FR**: o segredo MUST aparecer exatamente uma vez, na resposta do ato de emissão, e MUST
  NOT ser recuperável depois por nenhuma rota, tela ou tarefa Mix;
- **FR**: reemitir MUST criar linha nova e revogar a anterior — nunca "mostrar de novo".

### 4.4 Expiração — e o limiar vai para a base de conhecimento

FR-069 (spec 060, `specs/060-tela-da-equipe/spec.md:865`), decisão da pessoa mantenedora em
2026-09-07: **nenhum limiar MUST viver em constante de módulo**. Vale aqui integralmente, e
tem consequência de segurança própria — um prazo de expiração escondido num `@teto` é uma
decisão sobre risco que ninguém revisa.

**Regra proposta**: arquivo novo `priv/knowledge_base/rules/api_access_thresholds.yaml`,
`derivation_rule.id: api.access.thresholds`, no formato de
`priv/knowledge_base/rules/profile_thresholds.yaml` (com `name`, `statement`, `rationale`,
`provenance` e `what_this_is_not`, que o schema exige).

| Limiar | Nome proposto | Valor proposto | Razão do valor |
|---|---|---|---|
| validade máxima | `api.access.token_lifetime` | **90 dias** | prazo que cabe num ciclo de revisão trimestral e não obriga rotação mensal |
| expiração por desuso | `api.access.token_idle_expiry` | **30 dias sem uso** | token esquecido é a superfície que ninguém vigia; 30 dias é curto o bastante para o esquecimento e longo o bastante para integração mensal |
| aviso de vencimento | `api.access.token_expiry_warning` | **14 dias antes** | e o aviso é **ausência dita**: a tela mostra "vence em N dias", nunca só a data |
| teto de página | `api.access.page_size_max` | **100**, padrão **25** | 25 é o `@por_pagina` já usado em `people_live/show.ex:52`; 100 é o teto que impede exportação por paginação |
| taxa | `api.access.rate_limit` | ver §7.3 | — |

**Os valores acima são proposta, não decisão.** Quem decide é a pessoa mantenedora, com o
Product Owner; o que este documento afirma é que eles **precisam existir, com nome, e fora do
código**.

**Um cuidado sobre a expiração, e ele é de desenho.** A expiração MUST ser conferida na
requisição, contra `DateTime.utc_now/0`, e não por job que marca linhas — a forma do
`dentro_da_validade/1` da sessão (`hooks.ex:113-119`). Job que expira cria janela entre o
vencimento e a passagem dele, e essa janela é acesso concedido por atraso de fila.

### 4.5 Revogação

- **marca, nunca `delete`**: `revoked_at` e `revoked_by_user_id`, como
  `ScopeGrant.revoke_changeset/2` (`scope_grant.ex:53-59`) — *"a revogação é marca com
  autoria, nunca delete"*. Apagar a linha apaga a auditoria de que o token existiu, e é
  exatamente o registro que um incidente precisa;
- **quem revoga**: a própria pessoa, para os tokens dela; quem administra o tenant, para
  qualquer token do tenant (§3.6). Nunca quem administra **outro** tenant — e o par de
  `Access.grant/5` mostra a forma de conferir isso **dentro** da função, com o comentário que
  vale reproduzir (`access.ex:396-404`): *"uma função que decide acesso não pode depender de
  quem a chama ter conferido"*;
- **efeito imediato**: sem cache de token em ETS na v1. Cache é otimização, e otimização que
  atrasa revogação é decisão de segurança disfarçada de desempenho. Se o custo virar problema
  medido, ele volta como decisão com prazo de invalidação declarado.

### 4.6 O que acontece quando a conta perde acesso ou sai do tenant

A metade derivada está resolvida e a metade do desligamento é achado — §3.6, na íntegra.
Resta a decisão que **não** cabe a mim:

> **Trocar a senha (FR-015, que hoje gira `session_token` e derruba os outros navegadores)
> deve derrubar também os tokens de API?**
>
> **Recomendação: não, por padrão** — token de API não é sessão de navegador, e girar por
> troca de senha faria toda integração cair a cada rotina de senha, o que empurra a
> organização a não trocar senha. **Mas** a tela de troca de senha MUST listar os tokens
> vigentes e oferecer revogá-los no mesmo ato, e o texto MUST dizer que eles continuam
> valendo se não forem revogados. Silêncio aqui é o pior desfecho: quem troca a senha por
> suspeita de comprometimento acredita ter fechado a porta.
>
> É pergunta para o `/speckit-clarify` — §12.3.

---

## 5. A05 — configuração da pipeline `:api`

### 5.1 A pipeline hoje, e o que falta

```elixir
pipeline :api do
  plug :accepts, ["json"]
end
```

`router.ex:44-46`. É o que o `mix phx.new` gera. Faltam, no mínimo:

| Plug | Por que |
|---|---|
| autenticação por token (novo) | resolve `current_user` + `current_tenant` **da linha do token** (§3.2) |
| `:put_secure_browser_headers` **reduzido**, ou explícito | `nosniff` e `frame-ancestors` valem para qualquer resposta; a CSP inteira não faz sentido para cliente programático (ASVS V14.4.4) |
| limite de corpo explícito no `Plug.Parsers` | hoje o endpoint usa o padrão de 8 MB com `pass: ["*/*"]` (`endpoint.ex:46-50`) |
| `Plug.RequestId` | **já existe** no endpoint (`endpoint.ex:43`) — é o `correlation_id` de `AGENTS.md` §15, e a API deve **propagá-lo na resposta** para que quem integra possa citá-lo num chamado |

### 5.2 O que a CSP faz e não faz aqui

A CSP de `router.ex:28-39` é `:browser` e está escrita inteira, com o motivo linha a linha —
ela nasceu do achado `Config.CSP` do Sobelow, e `'unsafe-inline'` em `style-src` é concessão
declarada. **Ela não protege a API**: nenhum cliente HTTP a interpreta.

O que **protege** uma resposta JSON:

- `x-content-type-options: nosniff` — impede que um navegador que abra a URL da API
  interprete o corpo como HTML. É o vetor XSS de API que sobra;
- `content-type: application/json` **sempre**, e nunca `text/html` num erro. O `ErrorJSON`
  atual (`error_json.ex`) devolve JSON, mas o `ErrorHTML` é quem responde quando o
  `accepts` não casa — e aí um erro de API chega como página;
- **nenhum eco de entrada no corpo do erro.** Se a mensagem de 400 repetir o valor recebido,
  ela vira refletor; e a resposta de erro é a mais fácil de fazer refletir.

### 5.3 TLS e a origem

- `config/prod.exs:13-20` força SSL com HSTS, `rewrite_on: [:x_forwarded_proto]`. Vale para a
  API automaticamente, e quem mexer ali precisa dizer por quê;
- **o cookie de sessão continua sendo cookie de sessão.** `endpoint.ex:7-12` não declara
  `secure: true`, e não precisa: `Plug.Conn.put_resp_cookie/4` marca `Secure` quando
  `conn.scheme` é `:https`, e o `rewrite_on` acima é o que faz o esquema ser `:https` atrás
  do proxy. **Verificado por leitura do mecanismo, não por captura de resposta** — está na
  lista do que não verifiquei (§13);
- **`check_origin` não defende a API**, e o próprio `TheBandWeb.Origens` diz por quê
  (`origens.ex:21-25`). Não conte com ele; e **não** adicione origem nova por causa da API.

### 5.4 CORS e cookie — a decisão é "não"

- **a API MUST NOT aceitar cookie de sessão como credencial.** Aceitar reintroduz CSRF numa
  superfície que não tem `protect_from_forgery`, e a `same_site: "Lax"` do
  `endpoint.ex:11` **não** cobre requisição de topo por `GET`;
- **a v1 MUST NOT habilitar CORS.** Sem CORS, o consumidor é servidor a servidor, e o token
  não chega ao navegador de ninguém. No dia em que houver cliente no navegador,
  `Access-Control-Allow-Origin` MUST NOT ser `*` junto de credenciais (ASVS V14.5.3), e a
  lista de origens é a de `TheBandWeb.Origens` — nunca uma segunda lista.

### 5.5 Um detalhe do endpoint que muda o enunciado de "somente leitura"

`plug Plug.MethodOverride` está em `endpoint.ex:51`, **antes** do router. Ele converte um
`POST` com `_method=DELETE` em `DELETE`. Numa API sem rotas de escrita isso não abre nada —
a rota simplesmente não casa. Mas muda como a garantia se enuncia:

> "somente leitura" MUST ser garantido pela **ausência de rotas**, e não por um plug que
> confere o verbo. Um plug que recusa `POST` roda depois do `MethodOverride` e é
> contornável; a rota que não existe não é.

**Severidade: Informativo**, com efeito na redação do FR.

---

## 6. A04 — desenho inseguro: os quatro que esta base atrai

A constituição, princípio VIII, exige que todo padrão introduzido diga **o que piora**. Em
segurança, o que costuma piorar é a quantidade de lugares que decidem.

### 6.1 Segunda porta de autorização

Já coberto em §3.4 e §3.5. O critério de revisão é textual e barato: qualquer `if
User.admin?` , `case Tenants.scopes`, comparação de `tenant_id` ou leitura de
`access_scope_grants` **dentro de `lib/the_band_web/`** é achado. A camada web pergunta; ela
não decide.

### 6.2 Defesa que mora no chamador

**O exemplo vivo desta base**, e é o modelo do achado: `ai/provider_credential.ex:58-71` faz
`cast` de `:base_url` e apenas `validate_required`. Quem impede uma URL arbitrária é
`TheBand.AI.put/3` (`ai.ex`), que **ignora** o valor recebido e grava a constante
`@base_url`. Hoje isso está correto e **não há vulnerabilidade** — o único chamador é aquele.
Mas a garantia não está no changeset, e nasce frágil: o segundo chamador não vai saber.

**Na API, a forma que isso assume é**: o controller filtra por tenant e a função de domínio
não. Funciona até o segundo controller. **O filtro MUST estar na função que consulta**, e é
essa a doutrina que `Access.grant/5` enuncia em `access.ex:396-404`.

**Severidade: Média** (desenho), e o cenário de teste que falta para o caso do `base_url`
está em §11.6 — é achado que já existe, não da API.

### 6.3 Fallback silencioso e exceção como fluxo

`AGENTS.md` §7.7 e constituição VIII: **fallback silencioso é antipadrão declarado**. Em
segurança ele é *a* falha:

- `rescue -> []` transforma erro de autorização em tela normal. Numa API, transforma-o em
  **200 com lista vazia**, que o cliente integra como "não há dados";
- `{:error, :not_found}` colapsado em `200 []` apaga a diferença entre *não tem* e *não
  consegui verificar*;
- **ausência é nula, nunca zero** (VIII). Numa resposta JSON: `null`, e nunca `0`; e
  "nenhuma permissão encontrada" MUST NOT ser tratado como "sem restrição" — é a falha
  completa, e é a que abre por omissão.

A casa tem o precedente exato do risco: a regra que vigorava antes da FR-012 era *"toda
pessoa autenticada do tenant vê qualquer outra"*, e ela vigorava **por omissão** — *"era a
terceira opção da pergunta original, escolhida sem que ninguém a escolhesse"* (spec 023
FR-012). Uma API nova é a chance de esse regime voltar, e voltar em silêncio.

### 6.4 O relator, e por que ele é exigência de testabilidade

A **L69** registra que defeito dentro de `Logger.info` é invisível a teste, porque o nível é
configuração. Consequência para esta feature: **toda decisão de acesso da API MUST estar no
valor de retorno de uma função de domínio**, e o log é registro — não decisão. Sem isso o QA
não tem onde asserir, e o teste vira inspeção de saída de log, que `config/prod.exs:23`
(`level: :info`) pode desligar.

---

## 7. A09 — registro, e limite de taxa

### 7.1 O que precisa ser registrado

Campos de `AGENTS.md` §15, com os desta feature em negrito: `tenant_id`, `correlation_id`
(o `Plug.RequestId` já existe), **`api_token_id`** (o id público — **nunca** o segredo),
`user_id`, `status`, `error_code`, `error_reason`, `duration`, e o **alvo** da decisão
(`person_id`, `team_id`) quando houver.

Os eventos que precisam existir, e por que cada um:

| Evento | Por que sem ele não se investiga |
|---|---|
| requisição **aceita** e requisição **recusada** | sem as duas, não se distingue ataque de esquecimento |
| falha de autenticação, com o **motivo** (inexistente / vencido / revogado) | o corpo da resposta não distingue (§9); o log tem de distinguir, ou a investigação não tem o dado |
| **recusa de autorização**, com o veredito e o `{:nao, motivo}` | é o par do que a tela mostra (SC-006 da 045 exige motivo específico na tela) |
| desaceleração acionada | é o sinal de tentativa em série |
| token emitido, e por quem | proveniência do acesso (III) |
| token revogado, e por quem | é o que responde "quando a porta fechou" |
| **primeiro uso** de um token | separa token vazado de token nunca usado |
| falha de decifragem, se houver campo cifrado | a alternativa é descobrir na próxima rotação |

### 7.2 O que NUNCA vai para o log

`AGENTS.md` §14: *"Log não expõe token nem payload sensível completo — redija antes de
logar"*. A lista, para esta feature, além do óbvio:

1. **o segredo do token**, em qualquer forma — inclusive truncado no meio, inclusive só o
   começo;
2. **o cabeçalho `Authorization` inteiro**, o que inclui `inspect(conn)` e
   `inspect(conn.req_headers)`. Um `Logger.error("falhou: #{inspect(conn)}")` num
   `FallbackController` publica o token de todo mundo que errou;
3. **o struct do token sem `redact: true`** no campo do hash. O `redact:` do
   `ProviderCredential` (`provider_credential.ex:25-27`) está lá exatamente com este
   propósito, e o comentário o diz: *"mantém o segredo fora de `inspect/1` — que é o que vai
   para o log quando alguém inspeciona o struct num erro"*;
4. **o changeset**, que carrega os `changes` — e o segredo está neles na emissão. O
   precedente existe: `github_work_items.ex:519` loga `inspect(changeset.errors)`, que é o
   recorte certo (`errors`, não o changeset);
5. **a senha temporária** de `Auth.reset_password/3`, se a API algum dia a tocar;
6. **`THE_BAND_MASTER_KEY` e `THE_BAND_PREVIOUS_MASTER_KEY`** — e a segunda MUST estar
   removida do ambiente depois de uma rotação: mantê-la publicada mantém viva exatamente a
   chave que se quis aposentar;
7. **o corpo da resposta de terceiro em erro de transporte.** Hoje o caminho está estreito
   e correto — `Client.verify_credential/2` (`integrations/github/client.ex:44-51`) etiqueta
   como `{:error, {:transport, reason}}` justamente *"para que quem chama saiba que vale
   retentar, sem precisar conhecer os structs de erro da biblioteca HTTP"*, e é esse `reason`
   que `sync_github_eo.ex:83` inspeciona. Um `inspect` do struct de requisição, em vez do
   `reason`, publicaria o cabeçalho;
8. **o payload de dado pessoal.** Registrar `person_id` numa recusa é auditoria; registrar o
   corpo que teria sido devolvido é vazamento para o sistema de log — que costuma ter outro
   controle de acesso, ou nenhum.

**`Logger.debug` conta.** `config/prod.exs:23` fixa `level: :info` **hoje**, e configuração
não é controle: um `debug` com o token é um vazamento a uma variável de ambiente de
distância.

**ASVS**: V7.1.1 e V7.1.2 (não registrar dado sensível nem credencial), V7.2.1 e V7.2.2
(registrar decisões de autenticação e de autorização), V8.3 (dado privado sensível).

### 7.3 Limite de taxa

**Não há dependência de limitação de taxa nesta base** — verificado em `mix.exs:83-141`: não
há `hammer`, `plug_attack` nem equivalente. Duas saídas, e a primeira é a recomendada:

| Saída | Custo | Avaliação |
|---|---|---|
| **contador no banco, por token**, na forma do `Auth` | migração + uma escrita por requisição | **Recomendada.** É o padrão que a casa já escolheu e justificou: *"Por conta e no banco: sobrevive a deploy e vale em cluster"* (`auth.ex:20-25`). A espera crescente de `espera_segundos/1` (`auth.ex:86-89`) é reusável na forma |
| dependência nova | justificativa escrita no `plan.md` avaliando manutenção, segurança e compatibilidade (constituição, Restrições tecnológicas) | possível, e **não** é decisão minha. Se entrar, entra com a justificativa — e um limitador em ETS **não** vale em cluster, o que é justamente o que a casa rejeitou para a autenticação |

**Limiares propostos**, na mesma regra YAML de §4.4:

| Limiar | Nome | Valor proposto |
|---|---|---|
| requisições por token | `api.access.rate_limit.per_token` | **600 por 5 minutos** (2/s sustentado) |
| falhas de autenticação por origem | `api.access.rate_limit.auth_failures` | **10 por 5 minutos**, depois espera crescente na forma do `Auth` |
| emissões de token por conta | `api.access.rate_limit.token_issue` | **5 por hora** |

**O detalhe que evita transformar o limite num oráculo.** Se `429` aparecer só quando o token
**existe** — porque só então há linha em que contar —, o `429` passa a confirmar existência, e
o cuidado da mensagem única (§9) é desfeito pelo código de status. **A contagem de falhas de
autenticação MUST ser por origem da requisição, independentemente de o token resolver ou
não**, e a resposta MUST ser indistinguível nos dois casos.

**ASVS**: V11.1.4 (controles anti-automação contra chamadas excessivas), V2.2.1
(anti-automação na autenticação).

### 7.4 Onde a decisão fica, para o teste poder vê-la

Consequência da L69, repetida aqui porque é o que torna tudo acima verificável: a função que
decide devolve `{:error, {:throttled, segundos}}` — exatamente a forma que `Auth` já usa
(`auth.ex:39-40`) — e o controller traduz para `429` com `Retry-After`. O teste asere o
**retorno**; o log é registro.

---

## 8. A06 e A08 — dependências e integridade

- **nenhuma dependência nova é necessária** para o token: `:crypto`, `Base`,
  `Plug.Crypto.secure_compare/2` (via Phoenix) e Ecto bastam. Se algo for proposto, a
  constituição exige justificativa escrita no `plan.md`, e versão fixada em `mix.exs`;
- **os dois auditores continuam sendo dois**: `mix hex.audit` é gate (`gates.ex:60-63`);
  `mix deps.audit` não é, e vale como leitura extra. Em 2026-08-13 um dizia "No
  vulnerabilities found" para a dependência que o outro apontava;
- **a API não muda a cadeia de publicação**, e ela continua valendo: `latest` é apontador, a
  identidade é `vX.Y.Z`, e o workflow é o publicador. Mudança em `.github/workflows/` que
  toque `secrets`, `permissions` ou gatilho é revisão de segurança, não de CI;
- **o contêiner roda sem privilégio** (`USER band` no `Dockerfile`) e voltar a root é
  regressão. A API não pede exceção.

---

## 9. Enumeração e vazamento por mensagem — A01 e A07

A tela responde "Team not found" para equipe de outro tenant **de propósito**
(`teams_live/show.ex:60-70`, FR-027), e "Person not found" com o motivo escrito
(`people_live/show.ex:66-80`): *"confirmar existência já é vazamento entre tenants"*. A API
tem de manter a mesma decisão, e a tabela abaixo é a tradução — com a diferença de que o
protocolo HTTP dá três códigos onde a tela dava uma frase, e **é aí que a existência vaza**.

| Situação | Status | Corpo | Cabeçalho | Por quê |
|---|---|---|---|---|
| sem credencial | **401** | mensagem única | `WWW-Authenticate: Bearer` | não confirma nada |
| token malformado | **401** | **a mesma** | idem | distinguir "malformado" ensina o formato |
| token inexistente | **401** | **a mesma** | idem | — |
| token vencido | **401** | **a mesma** | idem | "vencido" confirma que o token existiu |
| token revogado | **401** | **a mesma** | idem | idem — e confirma que a conta existe |
| token válido, `tenant_id` divergente da conta | **401** | **a mesma** | idem | estado impossível não se conserta em silêncio (§3.1) |
| recurso de **outro tenant** | **404** | igual ao de UUID inexistente | — | é a decisão de FR-027, sem alteração |
| recurso **do tenant**, veredito `{:nao, motivo}` | **403** | **com o motivo** | — | ver o parágrafo abaixo: aqui a existência já não é segredo |
| capacidade que o token não tem (ex.: token de leitura pedindo escrita) | **403** | com o motivo | — | quem chama já se autenticou; não há existência nova revelada |
| taxa excedida | **429** | mensagem única | `Retry-After` | e MUST NOT depender de o token existir (§7.3) |
| erro nosso | **500** | sem detalhe, **com o `correlation_id`** | — | detalhe de erro é reconhecimento de infraestrutura |

**As cinco primeiras linhas são a FR-002 traduzida.** `Auth.authenticate/2` já devolve o
**mesmo** `{:error, :invalid_credentials}` para senha errada, e-mail inexistente, usuário do
GitHub ambíguo, elo revogado e conta sem senha (`auth.ex:5-10`) — e a razão vale igual para
token. O motivo específico vai para o **retorno da função** (assertável) e para o **log**
(investigável); nunca para o corpo.

**E o relógio também.** `Auth` roda `Bcrypt.no_user_verify()` quando não há conta
(`auth.ex:46`) porque *"a recusa instantânea entregaria pelo tempo o que a mensagem
esconde"*. Na API o custo é microssegundos e a assimetria é menor, mas ela existe: token
inexistente sai antes de qualquer consulta, token revogado depois de uma. **O caminho de
recusa MUST fazer o mesmo trabalho nos cinco casos** — resolver o id público, comparar o
hash em tempo constante, e só então decidir. Sem isso, o relógio é o oráculo.

**Por que `403` com motivo dentro do tenant, e é a única assimetria proposta.** Um `403`
confirma que o recurso existe. Dentro do tenant, **isso já é público para qualquer conta
autenticada**, e a afirmação é medida, não presumida:

- `/people` e `/teams` estão na `live_session :autenticado` (`router.ex:67-72`), atrás de
  `require_user` e nada mais;
- `lib/the_band_web/live/people_live/index.ex` **não menciona** `pode_ver`, `Access`,
  `scopes/2` nem `admin?` — varredura em busca dos quatro, zero ocorrências;
- `lib/the_band_web/live/teams_live/index.ex` menciona `User.admin?/1` **duas vezes**
  (linhas 48 e 111), e as duas guardam a **seção de declaração** de equipe — não a listagem.

Logo, `403` não revela nada que a plataforma já não mostre, e o motivo é o remédio:
`:conta_sem_pessoa_declarada` pede declaração do elo, `:vinculo_encerrado` pede renovação,
`:sem_concessao` pede a concessão — as três ações diferentes que `access.ex:172-180` existe
para distinguir.

> **A dependência desta decisão está declarada, e é o que a torna revisável**: ela decorre
> de `/people` e `/teams` serem visíveis a todo o tenant **hoje**. No dia em que uma feature
> restringir a listagem, esta linha da tabela MUST voltar para `404`. Escrevo a dependência
> porque uma decisão derivada de um fato precisa apontar para o fato — senão sobrevive a ele.

**ASVS**: V4.2 (controle de acesso na operação), V7.4.1 (mensagem de erro genérica),
V13.1 (API genérica).

---

## 10. O que NÃO entra na primeira versão

O critério é um só: **a leitura ainda não foi provada.** Cada item abaixo amplia a superfície
antes de existir teste de paridade tela↔API, e o custo de tirá-los depois é maior que o de
não os colocar.

| Não entra | Por que | O que ele exigiria antes |
|---|---|---|
| **qualquer escrita** (`POST`/`PATCH`/`DELETE`) | escrita atravessa `pode_gerir_estrutura/3`, que é veredito **diferente** do de leitura (`access.ex:154-159` separa ver de mexer de propósito). Duas superfícies novas num PR é o que `AGENTS.md` §17 proíbe misturar | idempotência por chave de requisição, proveniência do ato (III), e o veredito de escrita testado |
| **upload de arquivo** | não há upload em lugar nenhum desta aplicação hoje; introduziria travessia de caminho, tipo de conteúdo e antivírus de uma vez | ASVS V12 inteiro, que hoje não se aplica |
| **consulta arbitrária** (GraphQL exposto, `?filter=` livre, `?sort=` livre, SQL) | é a porta de A03 e de exfiltração por composição. E a casa já rejeitou o padrão largo nas telas: aba, granulação e escala são **casadas uma a uma**, com o motivo escrito — *"`String.to_atom/1` sobre parâmetro de URL cria átomo a partir de entrada de fora, que não é coletado"* (`teams_live/show.ex:145-147`, `people_live/show.ex:54-62`) | modelagem de ameaça própria, teto de profundidade e custo, e ADR (`AGENTS.md` §16 exige ADR para contrato público) |
| **expansão livre** (`?include=`, `?fields=`) | cada combinação é uma rota que ninguém revisou — é o vetor 3 de §3.5 | o teste de paridade cobrindo o produto das combinações, que é o que torna a ideia caro |
| **exportação em massa** (`?page_size=10000`, CSV do tenant) | transforma leitura autorizada em cópia do banco. É onde vazamento deixa de ser incidente e passa a ser transferência | teto de página (§4.4), registro de volume por token, e decisão de negócio |
| **webhook de saída** | borda de saída nova = A10, e a casa tem três bordas conhecidas e só três (`github/http/req.ex`, `llm/http/req.ex`, `ai.ex`) | allowlist de esquema e host validada onde o dado entra, e recusa de seguir redirecionamento |
| **token de máquina sem conta** (*service account*) | quebra a premissa de que todo acesso é de uma **pessoa** com elo, e é dela que `scopes/2` deriva tudo. Sem pessoa, `pode_ver/3` não tem o que responder | um modelo de identidade não-humana, que é feature própria |
| **CORS** | §5.4 | um consumidor no navegador, que não existe |
| **escopos do próprio token** (leitura parcial, por recurso) | tentador e prematuro: o alcance já é derivado da pessoa, e um segundo sistema de escopo **no token** cria a interseção de dois modelos — e interseção mal feita **amplia** | a v1 medida, e a necessidade concreta. `AGENTS.md` §7.7: padrão sem problema é antipadrão |

**O que **entra**, então**: leitura, `GET`, token por conta, tenant do token, veredito reusado
do domínio, paginação com teto, 401/403/404 na disciplina de §9, limite de taxa, e registro.
É uma fatia vertical se vier com a tela de gestão dos tokens no mesmo PR — o princípio VI
exige tela e backend juntos, e "API sem tela para emitir o token" é infraestrutura sem
consumidor visível.

---

## 11. Riscos que já existem hoje — não são desta feature

Separados de propósito, como pedido. Alguns a feature **expõe**; nenhum ela **introduz**.

### 11.1 `deps` commitada como link simbólico para si mesma

**Severidade: Média** · OWASP A08 · ASVS V14.2 (*dependências e build*)

**Onde**: entrada de índice `120000 1d6c2a6090a0abfcbda658014d214a9e8102887a 0 deps`,
introduzida em `4626ec3` (*"feat(060): a saída alcança o par…"*, 2026-09-08). O conteúdo do
blob é `/Users/paulossjunior/projects/theband/deps` — o caminho absoluto do próprio link.

**Caminho concreto**: `git clone` recria o link; na máquina de origem ele aponta para si e
`mix deps.get` aborta com `ELOOP`. No CI (Linux, outro caminho), `mkdir_p` **cria** o
diretório absoluto `/Users/paulossjunior/…/deps` no runner e a build passa — o que explica
por que os seis últimos `CI` de `development` estão `success` (verificado com `gh run list`).

**Consequência**: o repositório deixou de ser construível na máquina de quem o mantém, e a
build do CI passou a depender de um caminho que não descreve nada. Vale menos como
vulnerabilidade e mais como **integridade**: um artefato cuja construção depende de um
caminho acidental não é reproduzível, e reprodutibilidade é o que liga commit a imagem.
Está em `development` e **não** em `main` — chega em `main` no próximo release.

**O que fecha**: `git rm --cached deps`, entrada `deps/` no `.gitignore`, e um teste ou passo
de gate que reprove link simbólico apontando para dentro da própria árvore.

### 11.2 `ssl: true` do Repo comentado em produção

**Severidade: a determinar — depende da topologia, que eu não verifiquei** · OWASP A02 ·
ASVS V9.2.1 (*TLS nas conexões internas*)

**Onde**: `config/runtime.exs:86` — `# ssl: true,` dentro do bloco `config_env() == :prod`.

**Caminho**: se a base e a aplicação estiverem em **hosts diferentes**, o tráfego —
incluindo os valores cifrados, os hashes e todo dado de tenant — atravessa a rede em claro,
e quem estiver no caminho lê. Se estiverem no **mesmo host**, via socket local ou rede de
contêiner isolada, o risco é outro e menor.

**Não afirmo qual dos dois é o caso**: a topologia de produção (VPS Contabo + Dokploy) não
foi verificada por mim, e a `DATABASE_URL` é segredo do ambiente — que eu não peço e não leio.
**Pergunta para quem opera**, e ela é anterior à API: *a base roda no mesmo host da
aplicação?* Se não, isto é achado **alto** e independe desta feature.

### 11.3 A exceção de aviso em `mix.exs` ficou obsoleta — e o sinal disparou

**Severidade: Baixa** · OWASP A06 · ASVS V10.3 (*integridade de dependências*)

`mix hex.audit` saiu 0, e imprimiu:

```
ignore_advisories entry "CVE-2026-32686" (set in mix.exs) does not match any
advisory for the locked dependencies and can be removed
```

`mix.exs:21-38` documenta a exceção com cuidado exemplar, e escreve o critério da própria
remoção: *"`mix hex.audit` continua imprimindo o achado sob `Ignored advisories:` e denuncia a
entrada quando ela ficar obsoleta — que é o sinal para remover esta exceção"*. **O sinal
disparou** — um dia depois de a avaliação ser escrita (`docs/seguranca/2026-09-08-decimal-expoente-ilimitado.md`),
com `decimal` ainda em `3.1.1` (`mix.lock:12`).

Enquanto a entrada fica, ela é uma supressão dormente: qualquer aviso futuro com aquele
identificador é silenciado sem que ninguém decida. Remover **não enfraquece** o gate — o
próprio auditor diz que não há aviso correspondente, e removê-la o devolve ao estado em que
nada é ignorado. O teste que protege de verdade continua sendo
`test/the_band/decimal_limitado_test.exs`.

### 11.4 Uma assinatura pública que recebe `tenant_id` cru

**Severidade: Baixa** (desenho) · OWASP A01 · ASVS V4.1

`EO.fetch_organization_by_login(tenant_id, login)` —
`lib/the_band/ontology/seon/eo/queries.ex:645-652`, exposta por
`lib/the_band/ontology/seon/eo.ex:158`. A consulta **filtra corretamente**
(`where: o.tenant_id == ^tenant_id and o.login == ^login`), e os cinco chamadores derivam o
id de fonte já escopada (`ctx.tool.organization_login`, `tool.tenant_id`). **Não há
vulnerabilidade hoje.**

É a forma que importa: das 125 funções públicas dos sete `queries.ex`, esta é a **única** que
aceita o tenant como UUID em vez de `%Tenant{}` — e é exatamente a forma que deixa um tenant
vindo de parâmetro entrar sem que a assinatura reclame. **Regra para a feature**: a API MUST
NOT chamar nenhuma função cujo tenant chegue como UUID cru; leitura nova nasce com
`%Tenant{}`.

### 11.5 Não existe conta desativada — e a API torna isso material

**Severidade: Média hoje; ver §3.6 para o efeito na feature** · OWASP A01 · ASVS V3.3

Detalhado em §3.6. Registro aqui porque é **risco que a feature expõe, não que ela cria**: a
lacuna existe desde a 045, e hoje é mitigada por acidente — sem token, quem não sabe a senha
não entra.

### 11.6 O `base_url` da credencial de modelo: a garantia mora no chamador

**Severidade: Média** (desenho) · OWASP A10 · ASVS V12.6 (*SSRF*), V5.1 (*validação de
entrada*)

`ai/provider_credential.ex:58-71` aceita qualquer `base_url` no changeset; quem garante que
ela é sempre `https://api.openai.com` é `TheBand.AI.put/3`, que grava a constante
`@base_url`. Correto hoje, frágil por desenho (§6.2).

**O cenário de ataque que falta**, e é o entregável para o QA — os testes de
`test/the_band/ai_test.exs` asseram que a opção **resulta** na constante, o que passa
igualmente se a garantia sair do `put/3`, porque eles nunca mandam uma URL hostil:

> **Quando**
> `AI.put(tenant, %{"provider" => "openai", "secret" => "<segredo de teste>", "base_url" => "http://169.254.169.254/latest/meta-data/"})`
> **Então** a linha gravada tem `base_url == "https://api.openai.com"`;
> **E** a asserção é sobre **o que ficou no banco**, não sobre o que a função devolveu.

Não é desta feature, e vale registrar porque a API é a próxima superfície a herdar o padrão
"a garantia mora no chamador".

### 11.7 `pode_ver/3` e `pode_ver_equipe/3` discordam sobre administrar e ver

**Severidade: Média** · OWASP A01 · ASVS V4.1.3 (*menor privilégio*)

O cabeçalho de `TheBand.Tenants.Access` afirma, em `access.ex:20-24`:

> *"**Administrar não é ver (FR-022).** Nenhum ramo aqui olha `users.role` para conceder
> visão."*

E `access.ex:273`, dentro de `pode_ver_equipe/3`, é:

```elixir
User.admin?(user) and user.tenant_id == tenant.id -> {:ok, :admin}
```

Ver as medidas de uma equipe — incluindo a quebra por pessoa nomeada, que é o que FR-024
fechou — **é visão**. Então o `role` de plataforma concede visão em um veredito e não no
outro, e a afirmação do cabeçalho é falsa para `pode_ver_equipe/3`. A doc da própria função
lista o ramo abertamente (`access.ex:262-268`, *"Admin do tenant; escopo `team` naquela
equipe…"*), o que indica decisão consciente — mas ela **contradiz** o cabeçalho do módulo e a
FR-022, e não há registro de que a FR-022 tenha sido revista para equipes.

**A spec 023 agrava**: `specs/023-painel-da-pessoa/spec.md:271` ainda diz *"**FR-012j**: Quem
tem `admin` de plataforma MUST ver todos os painéis do tenant"*, sem marca de que a 045
FR-022 a revogou. `visibility.ex:32-40` documenta a revogação; a spec 023, não.

**Por que isto é urgente agora, e não em geral.** Quem escrever a spec da API vai ler os dois
documentos e implementar um dos dois regimes — e a escolha decidirá se um token de conta
administradora lê o painel de todas as pessoas do tenant. **A discordância tem de ser
resolvida antes do contrato da API**, não depois: o roteador da API vai congelar a resposta
que alguém escolher sem saber que havia escolha.

**O que fecha**: decisão registrada da pessoa mantenedora sobre *administrar concede visão de
equipe, sim ou não*; correção do cabeçalho de `access.ex` **ou** do ramo, conforme a decisão;
e marca de revogação em `specs/023-painel-da-pessoa/spec.md:271` apontando para 045 FR-022.
Nenhuma das três é implementação de feature — são registro e coerência.

---

## 12. Insumo para a spec — os FR, os SC e as perguntas

Os rótulos abaixo são **locais deste documento** (`SEC-nn`), para que as tarefas possam
citá-los antes de a `spec.md` existir. Ao entrar na spec eles recebem número de FR na **mesma
lista dos demais** — não numa seção de segurança apartada, que é como esse tipo de requisito
desaparece.

### 12.1 Requisitos funcionais propostos

| # | Enunciado | Fecha |
|---|---|---|
| **SEC-01** | Todo token MUST carregar `tenant_id` **não nulo**, gravado na emissão, e o tenant de toda requisição MUST ser derivado da linha do token. | A01-1 |
| **SEC-02** | Nenhuma rota da API MUST NOT aceitar identificador de tenant em caminho, query string, cabeçalho ou corpo. | A01-2 |
| **SEC-03** | Toda leitura MUST passar por função que receba `%Tenant{}`; recurso de outro tenant MUST responder **404**, com corpo idêntico ao de identificador inexistente. | A01-3 |
| **SEC-04** | Toda rota MUST reusar o veredito de `TheBand.Tenants` que governa a tela equivalente, e MUST NOT reimplementar decisão de acesso na camada web. | A01-4 |
| **SEC-05** | A recusa de autorização MUST acontecer **antes da carga** dos dados, e o custo em consultas da resposta recusada MUST ser menor que o da permitida. | A01-4, FR-012h da 023 |
| **SEC-06** | Nenhum campo MUST ser servido sem que o veredito que o governa na tela tenha sido consultado para **aquele campo**; o serializador MUST ser lista de permissão declarada. | A01-5 |
| **SEC-07** | O token MUST NOT gravar escopo, papel nem veredito materializado; o alcance MUST ser derivado a cada requisição. | A01-6 |
| **SEC-08** | Quem administra o tenant MUST poder revogar qualquer token de qualquer conta do tenant, num ato, com efeito na requisição seguinte; a revogação MUST ser marca com autoria, nunca `delete`. | A01-6 |
| **SEC-09** | O segredo do token MUST ser 256 bits de `:crypto.strong_rand_bytes/1`, guardado apenas como hash irreversível, conferido com comparação em tempo constante, e localizado por identificação pública indexada. | A02-1 |
| **SEC-10** | O segredo MUST aparecer exatamente uma vez, na resposta da emissão, e MUST NOT ser recuperável depois por rota, tela ou tarefa Mix. O token MUST ter prefixo fixo reconhecível. | A02-2 |
| **SEC-11** | Token ausente, malformado, inexistente, vencido, revogado ou com tenant divergente MUST produzir a **mesma** resposta **401**; o motivo MUST estar no retorno da função de domínio e no registro, nunca no corpo. | A07-1 |
| **SEC-12** | Todo token MUST ter validade máxima e expiração por desuso, conferidas **na requisição**; os limiares MUST viver na base de conhecimento, e MUST NOT viver em constante de módulo. | A07-2, FR-069 |
| **SEC-13** | A API MUST registrar requisição aceita, requisição recusada, falha de autenticação com motivo, recusa de autorização com veredito, desaceleração, emissão, revogação e primeiro uso — com os campos de `AGENTS.md` §15 e o `api_token_id` público. | A09-1 |
| **SEC-14** | O registro MUST NOT conter o segredo do token, o cabeçalho `Authorization`, o struct da conexão, o changeset de emissão nem o corpo de dado pessoal. Vale para todos os níveis, inclusive `debug`. | A09-1 |
| **SEC-15** | A API MUST ter limite de taxa por token e por origem, com estado **no banco**; a contagem de falhas de autenticação MUST ser independente de o token existir, e a resposta MUST ser indistinguível nos dois casos. | A09-2 |
| **SEC-16** | A pipeline da API MUST ser própria, com autenticação por token, `nosniff`, `content-type: application/json` em toda resposta — inclusive de erro — e limite explícito de corpo. | A05-1 |
| **SEC-17** | A API MUST NOT aceitar cookie de sessão como credencial, e MUST NOT habilitar CORS na primeira versão. | A05-1 |
| **SEC-18** | A v1 MUST NOT expor escrita, upload, consulta arbitrária, expansão livre, exportação em massa, webhook de saída nem token sem conta. "Somente leitura" MUST ser garantido pela ausência de rotas. | §10, §5.5 |
| **SEC-19** | Filtro, ordenação e paginação MUST vir de lista fechada casada uma a uma; nenhum parâmetro MUST NOT ser convertido em átomo. Paginação MUST ter teto declarado. | A03-1 |
| **SEC-20** | Recusa MUST ser retorno, nunca exceção nem lista vazia; ausência MUST ser `null`, nunca `0`; e "não consegui verificar" MUST NOT ser servido como "não há dados". | A04-2 |

### 12.2 Critérios de sucesso mensuráveis

Um critério de segurança é mensurável ou não existe. *"A API é segura"* não é verificável;
os cinco abaixo são.

| # | Critério |
|---|---|
| **SC-S1** | Com dois tenants povoados simultaneamente, **nenhuma** rota da API devolve registro cujo `tenant_id` seja diferente do tenant do token — medido sobre a lista completa de rotas, com `assert length(resultados) > 0` como guarda. |
| **SC-S2** | Para **cada** par (rota da API, tela correspondente), uma conta em `{:nao, _}` recebe da API o mesmo conjunto vazio que a tela mostra. Rota sem par declarado reprova o teste. |
| **SC-S3** | Os seis desfechos de falha de autenticação (ausente, malformado, inexistente, vencido, revogado, tenant divergente) produzem respostas **idênticas byte a byte**, e os seis motivos aparecem distintos no retorno da função. |
| **SC-S4** | Revogar um token faz a requisição seguinte responder 401, medido em **uma** requisição — não em duas, não depois de um job. |
| **SC-S5** | Nenhuma saída de log da suíte contém o segredo de nenhum token emitido em teste — verificado com captura de log sobre o caminho de emissão, de uso e de erro. |

### 12.3 As perguntas para o `/speckit-clarify`

Cinco, e cada uma tem consequência de desenho — não são preferências.

1. **Trocar a senha derruba os tokens de API?** (§4.6) A FR-015 hoje gira o `session_token` e
   derruba os outros navegadores. Recomendação: **não** por padrão, **com** a tela de troca
   oferecendo a revogação no mesmo ato e dizendo que sem ela os tokens seguem valendo.
2. **Administrar concede visão de equipe?** (§11.7) `pode_ver_equipe/3` diz que sim
   (`access.ex:273`); o cabeçalho do módulo e a FR-022 dizem que não. A API vai congelar a
   resposta de quem escolher.
3. **Um token herda o alcance da pessoa, ou pode ser mais restrito que ela?** Recomendação:
   **herda, e nada mais** na v1 (§10, último item). Escopo no token é um segundo modelo, e a
   interseção de dois modelos mal feita amplia em vez de restringir.
4. **Quem pode emitir token: qualquer conta, ou só quem administra?** Recomendação:
   **qualquer conta, para si**, porque o alcance é o dela e não há elevação — mas com o
   inventário visível a quem administra (§3.6) e o teto de emissões de §7.3.
5. **Existe conta desativada?** (§11.5) Se a resposta for "ainda não", a spec MUST escrever a
   limitação: o desligamento de uma pessoa exige revogar os tokens dela **explicitamente**,
   e trocar a senha não basta.

### 12.4 Para o Product Owner — os itens, dimensionados

Cada linha é um item de backlog. **Eu não decido prioridade, e nenhuma destas linhas é uma
decisão de bloqueio** — as de severidade alta são recomendação de bloqueio da release que
contiver a API, e a decisão de liberar mesmo assim é do Product Owner, registrada em
`docs/releases/vX.Y.Z.md` como risco residual aceito, com quem decidiu, quando e por quê.

| Item | Sev. | Consequência para o negócio, em uma frase | O que fecha |
|---|---|---|---|
| SEC-01 · tenant amarrado ao token | Alta | um token passa a ler os dados de outra organização cliente sem que nada registre a mudança | coluna `NOT NULL` + teste com dois tenants |
| SEC-02 · tenant nunca do parâmetro | Alta | quem tem qualquer token lê tudo de todas as organizações trocando um segmento da URL | FR com MUST NOT + teste que manda o tenant vizinho pelos três caminhos |
| SEC-03 · 404 para id de fora | Alta | um identificador vazado em log ou link entrega o registro de outra organização | reuso de `EO.fetch_person/2` e irmãs + teste paramétrico por rota |
| SEC-04/05/06 · veredito por pessoa | Alta | quem não tem relação com uma pessoa lê o desempenho dela pela API, o que a tela recusa desde 2026-08-26 | reuso de `pode_ver/3` e `pode_ver_equipe/3` + teste de paridade tela↔API |
| SEC-07/08 · revogação e alcance derivado | Alta | quem sai da organização continua lendo os dados dela, e quem administra não tem ato que resolva | revogação por conta + inventário na tela de contas |
| SEC-09 · guarda do segredo | Alta | um vazamento da base entrega todos os tokens em claro se a guarda for reversível | hash + `secure_compare` + busca por id público |
| SEC-13/14 · registro | Alta (segredo) / Média (registro) | abuso indetectável; e um `inspect(conn)` num erro publica o token de quem errou | lista de eventos + lista do que nunca vai ao log + captura de log em teste |
| SEC-11 · mensagem única | Média | a API vira oráculo de contas e tokens existentes | 401 idêntico nos seis casos + motivo no retorno |
| SEC-12 · expiração em YAML | Média | token esquecido vale para sempre, e o prazo fica escondido num `@teto` que ninguém revisa | `api.access.thresholds` na base de conhecimento |
| SEC-15 · limite de taxa | Média | exfiltração por repetição, e força bruta de token sem freio | contador no banco na forma do `Auth` |
| SEC-16/17 · pipeline e CORS | Média | erro de API chega como HTML; cookie reintroduz CSRF onde não há proteção | pipeline própria declarada no contrato |
| SEC-18/19/20 · superfície e recusa | Média | cada porta a mais é uma decisão que ninguém revisou; e `[]` mudo faz o cliente integrar "não há dados" | §10 escrita como MUST NOT na spec |
| §11.1 · `deps` como link para si | Média | o repositório não constrói na máquina de quem o mantém, e a build do CI depende de um caminho acidental | `git rm --cached deps` + `.gitignore` + passo de gate |
| §11.7 · discordância sobre administrar/ver | Média | a spec da API vai congelar um dos dois regimes sem saber que havia escolha | decisão registrada + correção do cabeçalho ou do ramo + marca na spec 023 |
| §11.5 · conta desativada não existe | Média | tirar acesso de alguém hoje é implícito, e para de funcionar quando houver token | `users.disabled_at` + ato em `/accounts` |
| §11.2 · `ssl: true` comentado | **a determinar** | se a base estiver em outro host, todo dado de tenant atravessa a rede em claro | responder a pergunta de topologia (§11.2) |
| §11.6 · `base_url` garantido pelo chamador | Média | o segundo chamador não vai saber, e a borda de saída aceita URL arbitrária | cenário de ataque de §11.6 virado teste |
| §11.3 · exceção obsoleta em `mix.exs` | Baixa | supressão dormente de um identificador de aviso, sem ninguém decidindo | remover a entrada; o auditor confirma que nada é ignorado |
| §11.4 · `tenant_id` cru em assinatura pública | Baixa | é a forma que deixa um tenant de parâmetro entrar sem a assinatura reclamar | migrar para `%Tenant{}`, ou proibir o uso pela API |

---

## 13. O que eu NÃO verifiquei

Esta seção existe para que a entrega não seja lida como *"está seguro"*. Ela é resultado, não
ressalva.

**Não rodei `mix gates`.** Rodei 4 dos 14 gates (`sobelow`, `hex.audit`, e `deps.audit` que
não é gate), num clone temporário, porque `deps` está quebrada no diretório de trabalho
(§11.1). Não afirmo verde de `credo`, `dialyzer`, `test`, `format`, `compile`,
`mensagens.verificar`, `raw() fora dos templates`, `knowledge.*`, validador Python,
`derivação reproduzível` nem `validadores concordam`. **O veredito continua sendo o código de
saída de `mix gates`, e ele não foi obtido.**

Não verifiquei, e cada item é nomeado:

1. **a topologia de produção** — se a base roda no mesmo host da aplicação (§11.2). É a
   pergunta que decide a severidade daquele item, e ela é para quem opera;
2. **os atributos reais do cookie em produção** — concluí `Secure` por leitura do mecanismo
   (`put_resp_cookie` + `rewrite_on`), não por captura de resposta HTTP;
3. **os segredos e as variáveis do ambiente de produção** — não peço, não leio, não aceito
   em conversa. Se algum aparecer num diff ou num chat, o achado não é "remova a linha", é
   **rotacione a chave**;
4. **a rotação de chave em produção** — se `THE_BAND_PREVIOUS_MASTER_KEY` está ausente do
   ambiente hoje. `mix the_band.rotate_key` existe e reporta contagens; o estado do ambiente
   não é legível daqui;
5. **os workflows do CD** — li que o CI de `development` está verde (`gh run list`), mas não
   revisei `.github/workflows/` quanto a `secrets`, `permissions` e gatilhos nesta passagem;
6. **a suíte de testes existente** — não rodei `mix test`, e portanto não sei se algum teste
   atual já cobre os cenários de §3 por outro caminho. O QA sabe, e é dele a medida;
7. **as telas que não abri** — li `people_live/show.ex`, `teams_live/show.ex`,
   `sync_live/index.ex`, `accounts_live/index.ex`, e varri `people_live/index.ex` e
   `teams_live/index.ex` em busca de veredito (§9). As demais **dezesseis** rotas `live` de
   `router.ex:68-92` — organizações, perfil, processo, projetos, quadros, trabalho,
   commits, arquivos, verificações, mudanças, repositórios, ferramentas, perfis, AI,
   escopos e papéis — não foram lidas quanto a veredito, e **cada uma é um par em potencial
   para o teste de paridade de SC-S2**;
8. **os cinco `Oban.Worker`** (`lib/the_band/jobs/`, `lib/the_band/profiles/*_worker.ex`) —
   não conferi, nesta passagem, se todos validam o `tenant_id` que recebem antes de executar
   (constituição V). A API não muda isso, e por isso ficou fora — mas fica **dito**, e não
   presumido;
9. **`Repo.query!` e SQL cru** — o `grep` de `fragment` com interpolação saiu vazio; a
   varredura de `Repo.query!` com string montada foi por leitura dos pontos que encontrei
   (`mix/tasks/the_band.rotate_key.ex` usa SQL cru **sem** entrada externa), não exaustiva;
10. **a base de conhecimento** — `mix knowledge.validate` não rodou, e não sei se o YAML
    proposto em §4.4 casa com o schema de `derivation_rule` sem ajuste. Quem escrever o
    arquivo descobre no gate;
11. **a exportação e a impressão** — nenhuma passagem sobre se algum caminho existente
    serializa struct de conta ou de credencial para fora (relatório, `mix qa.reports`,
    telemetria). É a pergunta que fica aberta para a próxima leitura.

**E o mais importante**: este documento cobre **o que a feature introduz** e **o que ela
expõe**. Não é uma varredura completa do repositório. A varredura completa é outro trabalho,
e este não é ele.

---

## Referências

**Nesta base**: `.specify/memory/constitution.md` (princípios III, V, VI, VII, VIII, XI) ·
`AGENTS.md` §14, §15, §17 · `lib/mix/tasks/gates.ex` (a definição única dos gates) ·
`docs/sprints/licoes-aprendidas.md` (L19, L22, L23, L69) ·
`specs/023-painel-da-pessoa/spec.md` (FR-012 a FR-012j) ·
`specs/045-autenticacao-e-acesso/contracts/auth.md` e `contracts/access-scopes.md` ·
`specs/049-entrar-com-github/spec.md` (FR-001 a FR-009, OAuth ainda não implementado) ·
`specs/058-medidas-da-equipe/spec.md` (FR-022 a FR-024) ·
`specs/060-tela-da-equipe/spec.md` (FR-069) ·
`docs/seguranca/2026-09-08-decimal-expoente-ilimitado.md`.

**Externas**: OWASP Top 10 (2021) · OWASP ASVS 4.0.3, capítulos V1 a V14 conforme citados
por seção.
