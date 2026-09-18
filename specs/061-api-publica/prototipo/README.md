# O protótipo da tela de tokens de API

[`api-tokens.html`](api-tokens.html) — abrir no navegador. Quatro telas numa página só,
separadas pelas faixas `screen 1 · the list at rest`, `screen 2 · the value, shown once`,
`screen 3 · revoking, with the label named` e `screen 4 · what this screen refuses, and why`,
mais a seção `decisions and open questions`. Tudo visível ao carregar: o formulário de criação, o
painel do valor em claro e a confirmação de revogação aparecem **abertos**, como exemplo. Não há
uma linha de JavaScript.

Desenhado em **2026-09-18**, a partir da T001 da feature **061 — A API pública com token**.
Publicado em `https://claude.ai/artifact/N2Ranqy14hQmgKUP1iq9vA`; **a cópia deste diretório é a
que vale** — o endereço publicado pode mudar, a spec não pode depender dele. Mesmo vocabulário
visual do último protótipo aprovado (`specs/066-pronto-declarado/prototipo/`) e do `DESIGN.md`.

A estrutura seção a seção — **que é a régua do QA** — está na seção 3 do [`PROMPT.md`](PROMPT.md),
com 60 itens, cada um separando aprovado de reprovado por algo observável.

**Aprovação: aguardando a pessoa mantenedora.**

**T001 bloqueia T009, T010, T011 e T013** (`tasks.md`). Enquanto esta tela não for aprovada, a
fatia 1 avança só pela fundação (T002 a T008) e pelas histórias sem tela.

## O dado que a tela mostra, e de onde veio

Lido no **banco de desenvolvimento** em **2026-09-18**, por consulta direta ao Postgres de
`the_band_dev`:

| O que | O valor real lido | Onde aparece na tela |
|---|---|---|
| tenant | **The Band Solution** (`the-band-solution`, `active`) | barra superior |
| contas | `admin@the-band-solution.example` (admin) · `consulta@the-band-solution.example` (member) — **nenhuma das duas tem elo de pessoa** | select de conta dona; linhas 3 e 6 |
| equipes | 10, entre elas **IA** (6 membros), **PLATAFORMA** (19), **QA** (7), **LEDS - ConectaFapes** (31) | alcance das linhas |
| projetos | **ConectaFapes** e **Valida** | alcance das linhas |
| vínculo equipe↔projeto | equipe **IA** → projetos **ConectaFapes** e **Valida**; equipe **LEDS - ConectaFapes** → **ConectaFapes** | é a derivação que o alcance mostra |
| concessões | **zero** linhas em `access_scope_grants` | por isso todo alcance da tela é **derivado**, e a ausência de concessão é escrita |
| tokens | **a tabela `api_access_tokens` não existe** | **todos** os tokens da tela levam `example` |

**O que é invenção, e está marcado `example`**: os seis tokens, seus rótulos, seus instantes, os
quatro últimos caracteres, o valor em claro da tela 2, a conta `ana.vieira@the-band-solution.example`
(administradora fictícia, a mesma da 066) e a conta `integracao@the-band-solution.example`. Nenhuma
pessoa real é nomeada, e nenhum segredo real aparece: o valor da tela 2 é sintático — prefixo, id
público de 8 caracteres e 43 caracteres de segredo, que é o comprimento exato de 32 bytes em
Base64 URL-safe sem padding.

**O achado que o dado real deu de graça, e que a tela usa:** as duas contas que existem hoje no
banco **não têm elo de pessoa**, e portanto `Access.scopes/2` devolve **lista vazia** para as
duas. Um token gerado para qualquer uma delas hoje **autentica e devolve coleção vazia**. Essa é
a consequência de FR-028 no seu caso mais cru, e ela está escrita na linha 3 da lista, com as
palavras que a tela usa: *"sees nothing today — no person declared for this account… calls are
accepted and come back empty: nothing found is not not collected"*. A linha 6 acrescenta o outro
meio caso: a conta **administradora** também não vê nada, porque *administrar não é ver*.

**Onde o dado e a spec divergem, a tela segue o dado:**

| a spec diz | o dado/os artefatos dizem | a tela mostra |
|---|---|---|
| FR-001: prefixo proposto `tbnd_` | `tasks.md` T006 decidiu `tb_api_<id_publico>_<segredo>` | `tb_api_`, com a divergência levantada em **Q2** |
| FR-011: ausência de expiração é **permitida** e explícita | Q8 declarou **validade máxima de 90 dias** | o formulário **não oferece** "no expiration" e explica onde ela foi parar; a lista **continua escrevendo** *no expiration* para linhas antigas. Levantado em **Q1** |
| `ToolCredential.masked/1` mascara com **quatro** bullets | FR-007 e o pedido pedem `••••••••••••••••` | dezesseis bullets, e a divergência do helper está registrada em **D2** |

## As decisões de desenho, e a razão de cada uma (2026-09-18)

| # | decisão | a razão |
|---|---|---|
| **D1** | **A marca do estado carrega a proveniência do estado.** *active* e *expired* são âmbar hachurado — são **leitura** contra o relógio, e não existe coluna de estado; *revoked* é cinza cheio **mais** a marca `declared`, com instante e autor | o data-model diz que estado não é coluna, e a tela tinha de dizer o mesmo sem uma nota de rodapé. A única transição que alguém **declarou** é a revogação — e é a única que parece declarada. De quebra, quem implementar não vai criar coluna de estado: a tela não tem onde pendurá-la |
| **D2** | **A máscara é dezesseis bullets de largura fixa mais os quatro últimos.** Largura fixa de propósito: uma máscara proporcional ao valor conta o comprimento do segredo | FR-007. E a divergência importa para quem implementa: reusar `ToolCredential.masked/1` entrega **quatro** bullets e contradiz esta tela. A máscara do token é própria, e a do `ToolCredential` fica como está |
| **D3** | **O alcance aparece na linha em duas linhas por origem** — `derived` (elo, equipes, projetos) e `granted` (concessões) —, **nunca somadas**, e com a ausência escrita de cada lado | "as duas afirmações lado a lado, nunca somadas". Um total ("3 scopes") esconde exatamente a diferença que importa: o derivado muda sozinho, o concedido tem autor. E não vira segunda tela de concessões porque são duas linhas de texto e um ponteiro |
| **D4** | **A prévia do alcance vive dentro do formulário de criação**, embaixo do select de conta dona, com as duas consequências escritas: muda de equipe, devolve menos; conta desativada, tudo recusado | o pedido é explícito — *"quem gera o token precisa ver isso na hora de gerar, não quando o painel de terceiro esvaziar"*. FR-047 pede na lista; a lista mostra depois, e o formulário mostra **antes**. Os dois lugares, porque são dois momentos |
| **D5** | **O valor em claro é painel, não modal**, com copiar, a instrução do gerenciador de segredo, e o "não volta" escrito como **what it does not do** — e a linha da lista logo abaixo já com a máscara | modal se fecha por engano e some sem deixar rastro de que existiu. O par painel + linha mascarada mostra, num olhar, a diferença entre *agora* e *de agora em diante*. O par faz/não faz é o padrão da casa desde a 045 |
| **D6** | **As três partes do valor são anotadas** — prefixo público, id público, segredo | é o único instante em que alguém olha para o valor. Explica por que um token vazado é achável por varredura (o prefixo) e por que a conferência nunca busca pelo hash (o id público) — as duas decisões de Q1, ditas onde fazem sentido |
| **D7** | **Recarregar não devolve nada, e a linha quieta nomeia o caminho de volta**: criado há N minutos, mostrado uma vez, não pode ser mostrado de novo, revogue e crie outro | quem recarrega está procurando o valor. Uma tela que só volta ao normal deixa a pessoa procurando em log, em banco e no suporte — e é assim que segredo vaza: alguém o procura em lugar onde ele não deveria estar |
| **D8** | **A confirmação nomeia o rótulo no título e no botão, e traz o último uso aceito** — *"last accepted call 14 minutes ago"* | FR-049 pede o rótulo; o rótulo sozinho não impede o erro, porque quem erra já leu o rótulo errado. O que impede é o fato: **algo está chamando com este token agora**. É o único dado que a plataforma tem e que responde *"isto está em uso?"* |
| **D9** | **Conta desativada produz duas marcas na mesma célula** — `active` (o registro) e `calls refused` (a conta) — com a frase de que uma não resume a outra | o edge case da spec diz que o token não sobrevive à conta. Uma linha dizendo só *active* seria a tela afirmando o que a API nega — e a primeira reclamação seria *"a tela diz que está ativo"* |
| **D10** | **As recusas ganham faixa própria**, seis delas, cada uma escrita como a expectativa de quem chega | "botão que desaparece faz quem procura concluir que a plataforma não sabe fazer aquilo" — é a lição escrita no `accounts_live/index.ex`, e vale inteira aqui. A lacuna de Q6 (não há auditoria do **que** foi consultado) aparece duas vezes de propósito: na caixa embaixo da lista, onde alguém procuraria, e na faixa das recusas |

## As perguntas que ficaram abertas, para a pessoa mantenedora

| # | pergunta | opções | recomendação |
|---|---|---|---|
| **Q1** | **Pode-se criar token sem expiração?** FR-011 diz que a ausência é permitida e explícita; Q8 declarou **validade máxima de 90 dias**. Máximo do qual se pode abrir mão não é máximo, e o formulário precisa escolher | (a) o formulário oferece 7/30/90 dias e explica numa caixa tracejada onde foi parar o "sem expiração"; a lista continua escrevendo *no expiration* nas linhas antigas · (b) o formulário oferece "sem expiração" atrás de confirmação digitada | **(a)** — é o que o protótipo desenha; e então a FR-011 é corrigida para dizer que a ausência é **exibida**, não **oferecida** |
| **Q2** | **Qual prefixo o token carrega?** FR-001 propõe `tbnd_`; a T006 decidiu `tb_api_<id público>_<segredo>`. A tela mostra um, e o padrão do varredor de segredo é escrito uma vez | (a) `tbnd_` · (b) `tb_api_`, como as tarefas dizem | **(b)** — é a decisão mais recente e a que o formato de três partes pressupõe. Qualquer que vença, o outro documento é corrigido no mesmo PR: hoje há duas respostas no repositório |
| **Q3** | **A revogação exige digitar o rótulo?** | (a) não: a confirmação nomeia o rótulo no título e no botão, e mostra o último uso aceito · (b) sim | **(a)** — não há revogação em massa nem caixa de seleção aqui, então o ato já é uma linha por vez; *"chamada aceita há 14 minutos"* segura a mão melhor que digitação, e digitação é atrito que se aprende a atravessar rápido |
| **Q4** | **A revogação registra razão?** Desativar conta nesta casa registra cláusula e nota; revogar token, como especificado, registra só quem e quando | (a) sem razão, como está especificado · (b) cláusula curta — *integração encerrada*, *suspeita de vazamento*, *substituído por outro* , *outro* — mais nota livre | **(b)**, se for barato: *suspeita de vazamento* é o único caso em que o ato seguinte muda (girar tudo o que aquela conta tem), e revogação sem razão é decisão que ninguém reconstrói em seis meses. **É campo novo, logo é decisão sua, não do Design** |
| **Q5** | **O aviso de vencimento entra nesta fatia?** A tela mostra *"expires in 9 days"* a partir de `api.access.token_expiry_warning` (14 dias), mas o plano só aplica `token_lifetime` na fatia 1 | (a) sim — o limiar vai no mesmo YAML e a lista o lê; é leitura contra o relógio, não job · (b) não — na fatia 1 a lista mostra só a data | **(a)** — a tela já compara datas com o relógio, então o aviso custa uma comparação; e *"vence em N dias"* é a metade do fato que faz alguém agir (Q8 já diz: "nunca só a data") |
| **Q6** | **Alguém é avisado antes de um token expirar?** A tela avisa quem a abre — e ninguém abre tela administrativa numa terça sem motivo | (a) nada nesta fatia — a tela é a única superfície · (b) uma linha na tela de operação · (c) e-mail para quem criou, 14 dias antes | **(a)** nesta fatia, **registrado como lacuna conhecida**: integração que para às 3 da manhã porque a credencial venceu é exatamente o silêncio que esta casa não aceita, e (c) é o conserto — mas é canal de entrega que esta feature não abre |

## Os nomes que a base precisa antes do código

Princípio IV — nada na tela sem declaração na base de conhecimento:

- `api.access.thresholds` — a regra que guarda **todo** número que esta tela mostra:
  `api.access.token_lifetime` (90 dias, **aplicado**), `api.access.token_idle_expiry` (30 dias
  sem uso, **declarado e não aplicado** nesta fatia — e a regra diz qual é qual),
  `api.access.token_expiry_warning` (14 dias — ver Q5);
- `api.access.token_prefix` — o prefixo público (ver Q2). Ele é impresso na tela, colado no
  padrão de um varredor de segredo, e não pode viver como literal em dois lugares;
- `api.access.token_state` — o vocabulário da coluna de estado: *active*, *revoked*, *expired*,
  cada um com **como é lido** e **se alguém o declarou**. A tela mostra uma quarta frase que
  **não** é estado de token — *calls refused · owner account disabled* — e ela precisa de nome
  próprio para que a linha e a API digam a mesma palavra;
- as **palavras das duas ausências**, para que tela e API não divirjam: *never used* (nenhuma
  chamada aceita ainda) e *no expiration* (nenhum fim declarado) — nunca um vazio, nunca um zero,
  e nunca a data de criação ocupando o lugar de um uso.

## Premissas que a spec carrega até serem contestadas

- **A tela vive só na área administrativa**, atrás do mesmo `require_admin` de `/accounts` e
  `/access-scopes`, e entra no menu *Settings*, grupo **Contas**, depois de *Access scopes*.
  Autoatendimento é decisão posterior, e a tela diz isso onde alguém procuraria.
- **Não há edição de token depois de criado** — nem rótulo, nem expiração. A fronteira não expõe
  `update_api_token/2`, e a tela não tem lápis em lugar nenhum.
- **O alcance é lido, nunca gravado.** A célula de alcance e a prévia do formulário chamam
  `Access.scopes/2` na carga da tela; nada é materializado no token. Se a tela um dia precisar
  paginar, o alcance pagina junto — não vira coluna.
- **A lista não pagina nesta fatia.** Seis linhas cabem; quando um tenant passar de uma tela de
  tokens, a paginação entra e a própria tela declara o recorte, como manda o `DESIGN.md`.
- **O rótulo é a palavra de quem criou** e nunca é traduzido, pela mesma razão que os nomes de
  estágio ficam em português na 066.
- **Quem não administra recebe recusa com motivo nomeado** — não página em branco, não 404 mudo,
  não redirecionamento silencioso.
- **A tela não mostra nada sobre *o que* uma integração consultou**, e diz isso duas vezes: a
  lacuna de Q6 é declarada, não esquecida.
