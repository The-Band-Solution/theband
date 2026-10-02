# Conferência das telas do operador contra o protótipo aprovado (070, T060)

Conferido em **2026-10-02** pelo agente QA, que não implementou as telas. Branch
`feature/1057-070-us1`.

**A régua**: [`PROMPT.md`](PROMPT.md) §3 (itens 1.1–G.4), [`platform-operator.html`](platform-operator.html)
(versão 2, aprovada em 2026-10-01) e [`README.md`](README.md) (D1–D5, Q1–Q4).

**O que foi conferido**: o código-fonte dos templates e dos controllers —
`lib/the_band_web/plataforma/telas_html.ex`, `entrada_controller.ex`, `cadastro_controller.ex`,
`organizacao_controller.ex`, `operator_scope.ex`, `lib/the_band_web/router.ex` (escopo `/platform`,
linhas 170–206) e, onde o template só imprime o que o contexto devolve,
`lib/the_band/platform/suspensions.ex`, `suspension_reasons.ex`, `segundo_fator.ex` e
`priv/knowledge_base/rules/platform_tenant_suspension.yaml`.

**O que NÃO foi conferido**: a tela renderizada. Não há servidor neste ambiente, então **não há
captura** — nem colorida, nem em tons de cinza, nem em 360 px, que o PROMPT §4 pede. Cada linha diz
"sem captura — conferido pelo código-fonte do template, arquivo:linha". Nenhum teste nem `mix gates`
foi rodado nesta conferência (havia um `mix gates` em curso na mesma árvore). A conferência
visual, por pessoa, continua devida — e é ela que fecha G.1 e G.2.

Legenda: **confere** = o texto e a estrutura batem com a régua; **diverge** = não batem;
**diverge (declarado)** = fora do protótipo e já registrado como tal no código, à espera da
decisão da pessoa mantenedora; **não conferido** = não é verificável pelo código-fonte.

Abreviações: `T` = `lib/the_band_web/plataforma/telas_html.ex`; `EC`, `CC`, `OC` = os controllers
de entrada, cadastro e organização no mesmo diretório.

---

## Tela 1 — `GET /platform/sign-in`, `POST /platform/session`

| item | veredito | onde | observação |
|---|---|---|---|
| 1.1 cabeçalho | confere | T:22-43 (sem `operador`), `layouts/root.html.heex:17-19` | `The Band` + `platform operation`; o layout raiz só tem `{@inner_content}`, sem menu nem link de organização. Sem captura — conferido pelo código-fonte do template |
| 1.2 campos, nesta ordem | confere | T:122-148 | `Email` (`email`), `Password` (`password`), `Authenticator code` + dica `or a recovery code` (`second_factor_token`), num formulário só; placeholder e `autocomplete` iguais ao protótipo (html:217-224). Sem captura |
| 1.3 botão | confere | T:149 | `Sign in`. Sem captura |
| 1.4 texto sob o formulário | confere | T:152-155 | Literal. Sem captura |
| 1.5 recusa | **diverge** | T:48-54, T:116-118; EC:34-37 | **O texto confere**, e a recusa é uma só: `{:error, _qualquer}` → mesma frase, `422`, mesma página, nenhum segundo exibido. **A marca diverge**: o protótipo desenha a recusa com **ícone `!`** + cor + palavra, hachurada em clay (`notice refused`, html:234-235; PROMPT §2 "recusa hachurada em clay com ícone e palavra"). `recusa/1` é `alert alert-error` só com o texto em negrito: **sem ícone e sem hachura**. A mesma componente serve todas as recusas das telas 2, 3 e 5 — ver G.1. Sem captura |
| 1.6 estado após recusa | confere | T:123-147; EC:37 | `email` volta preenchido; `password` e `second_factor_token` sem `value`; nenhum campo recebe classe de erro. Sem captura |
| 1.7 sucesso | confere | EC:31-32 | `redirect` a `/platform/organizations`. Sem captura |

## Tela 2 — `GET /platform/setup`, `POST /platform/setup`

| item | veredito | onde | observação |
|---|---|---|---|
| 2.1 passo | confere | T:179-182 | Literal, com `Step 1 of 3.` em negrito. Sem captura |
| 2.2 campos, nesta ordem | confere | T:186-219 | `Email`; `Setup code` + `from the release command, valid 30 minutes` (`setup_token`); `New password` + `12 to 128 characters` (`password`); `Repeat the new password` (`password_confirmation`, o nome do protótipo, html:272). Sem captura |
| 2.3 botão | confere | T:220 | `Set password and continue`. Sem captura |
| 2.4 aviso | confere | T:223-226 | Literal. Sem captura |
| 2.5 recusa única | confere | T:166-169; CC:50-51 | Texto literal; todo `{:error, _}` que não é changeset cai nela. A marca é a de 1.5 (sem ícone). Sem captura |
| 2.6 recusa de política | confere | T:170-172; CC:47-48 | Texto literal; só para `{:error, %Ecto.Changeset{}}`, que `Credentials.definir_senha/3` devolve depois de conferir o código e desfazer a transação (`credentials.ex`, comentário da linha 287). Sem captura |
| 2.7 código nunca na URL | confere | CC:24 (`new/2` ignora parâmetros); router:175-176 | O código vai no corpo do `POST`; o `GET` não lê parâmetro nenhum. Sem captura |
| 2.x senhas diferentes | **diverge (declarado)** | T:173-177; CC:31-32, 53-55 | *"The two passwords do not match. Your setup code still works."* — o protótipo não desenhou este estado; o comentário em T:173 o declara fora do protótipo. Pede decisão |

## Tela 3 — o cadastro do segundo fator

| item | veredito | onde | observação |
|---|---|---|---|
| 3.1 passo | confere | T:241-243 | Literal. Sem captura |
| 3.2 aviso antes do segredo | confere | T:244-247 | `1×` em mono, **`This secret is shown once.`**, `even if the code below is refused`, `ask for a new setup code`, a hora UTC (`hora/1`, T:647) e "ten minutes after the password was set"; vem **antes** do segredo (D2). Sem captura |
| 3.3 dados | confere | T:248-255 | `issuer` The Band Platform · `account` o e-mail · `type` `time-based, 6 digits, every 30 seconds`. Sem captura |
| 3.4 chave | confere | T:256-263, T:653-660 | `Setup key` + dica `type it into the app`, mono, `Base.encode32` (maiúsculo) em grupos de 4. Sem captura |
| 3.5 URI | confere | T:264-269; `segundo_fator.ex:29-34` | `Or copy the address` + `some apps accept it whole`, em texto. A forma da URI é a de `NimbleTOTP.otpauth_uri("The Band Platform:<email>", …, issuer: "The Band Platform")`; o `%20` **não foi medido** numa resposta real — confere pelo código. Sem captura |
| 3.6 sem QR | confere | T:237-296 | Nenhuma `<img>`, `<svg>` ou `<canvas>` (Q1 (a)). Sem captura |
| 3.7 formulário | confere | T:278-293 | `enrollment_token` oculto no corpo; `Code from the app` (`second_factor_token`, `inputmode="numeric"`, `placeholder="6 digits"`); `Confirm authenticator`. A mais: `email` oculto (T:280), que o protótipo não lista — não aparece na tela. Sem captura |
| 3.8 recusa | confere | T:270-276; CC:76-79 | Texto literal; com `segredo: nil` a chave e a URI **não** reaparecem. Sem captura |
| 3.9 código aceito | confere | T:306 | Literal, e **sem** notice de sucesso (Q3 (b)). Sem captura |
| 3.10 aviso dos códigos | confere | T:307-311 | `1×`, a frase em negrito e o resto (uso único, só a impressão digital, o caminho de volta), literais, **antes** da lista. Sem captura |
| 3.11 códigos | **diverge** | T:312-316; `segundo_fator.ex:101-107` | Lista numerada 1–10, mono, minúsculo (`Base.encode32(case: :lower)`) em grupos de 4: confere. **Duas colunas a partir de `sm:` = 40 rem**, e a régua diz **30 rem**. Sem captura |
| 3.12 a guarda | confere | T:324-340 | `acknowledgement_token` oculto; `codes_stored` com `required`; frase e dica literais, com a hora; `Finish setup` → `POST /platform/setup/recovery-codes`. Sem captura |
| 3.13 recusa da caixa | confere | T:317-322; CC:90, 95-96 | Texto literal; `codigos: nil` → os códigos não reaparecem; a caixa é conferida antes do contexto, o passo não é consumido. A dica da hora some na recusa, como no protótipo (html:376-377). Sem captura |
| 3.14 recusa do passo | confere | T:357-361; CC:91-93 | Texto literal. A página traz também o botão `Go to sign in` (T:362), que o protótipo não desenha para este estado (html:380 só cita a frase). Sem captura |
| 3.15 sucesso | **diverge** | T:349-356, T:362 | Notice e `Go to sign in` → `/platform/sign-in`: confere. **Falta a nota de que o link não entra sozinho** — protótipo html:390: *"The link leads to /platform/sign-in. It does not sign you in: the first sign-in uses password and code like every other."*, e o PROMPT 3.15 pede "com a nota de que não entra sozinho". Também falta o ícone `✓` do notice (html:388). Sem captura |

## Tela 4 — `GET /platform/organizations`

| item | veredito | onde | observação |
|---|---|---|---|
| 4.1 cabeçalho | confere | T:30-38 | Nome · e-mail do operador; `Sign out` por `POST` com `_method=delete` → `DELETE /platform/session` (router:183). Sem captura |
| 4.2 título | confere | T:376 | `Organisations`. Sem captura |
| 4.3 linha de escopo | confere | T:377-380 | Literal (D5). Sem captura |
| 4.4 colunas, nesta ordem | confere | T:383-390, T:393-405 | `organisation` (link ao histórico) · `slug` (mono) · `state` · `last suspended`. Sem captura |
| 4.5 estado | **diverge** | T:631-645 | O texto vem sempre: confere. **A marca diverge**: o protótipo usa um **chip cheio** — `active` verdete, `suspended` **cinza** (`chip left`, html:199-200, 415). A implementação desenha só um ponto de 2 px antes do texto, e o de `suspended` é **`bg-warning`, âmbar** (`app.css:57`, `:93`), que é a cor do **aviso**, e não o cinza de "encerrado e mantido no registro". O mesmo `estado/1` serve a tela 5 (5.1). Sem captura |
| 4.6 nunca suspensa | confere | T:401-404; `ui.ex:295-305` | `<.absent reason="never suspended">`: marca tracejada + texto. A forma é a do `<.absent>` do design system (quadrado tracejado ao lado do texto), e não o chip tracejado do protótipo — o AGENTS.md §11.1 manda usar o componente. Sem captura |
| 4.7 episódio da migração | **diverge** | T:398-405; `suspensions.ex:54-68` | O protótipo mostra `2026-10-01 · reason not recorded` (html:422). A implementação só tem a data: `listar_organizacoes/1` devolve `max(suspended_at)` e mais nada, então a tela **não sabe** que o último episódio é `not_recorded`. A migração aparece igual a uma suspensão comum. Sem captura |
| 4.8 ordem | confere | `tenants.ex:117-118` | `order_by: t.name`. Sem captura |
| 4.9 nada de domínio | confere | T:373-411 | O template só imprime `name`, `slug`, `status` e `ultimo_episodio_em`; nenhum total nem contagem. Sem captura |
| 4.10 sem ato em lote | confere | T:382-408 | Nenhuma caixa de seleção, nenhum formulário na lista. Sem captura |
| 4.11 telefone | confere | T:382, T:393-398 | `stacked` e `data-label` em cada `<td>`. "Nada rola na horizontal" **não foi medido** em 360 px. Sem captura |

## Tela 5 — `GET /platform/organizations/:slug`, `POST …/suspension`, `POST …/reactivation`

| item | veredito | onde | observação |
|---|---|---|---|
| 5.1 cabeçalho | confere | T:430-441 | `← Organisations`, operador, `Sign out`, nome em `h1`, slug mono, marca de estado, `since <data>` quando há episódio aberto. Diferenças de arranjo: o protótipo põe `← Organisations` **dentro** da faixa, ao lado do operador, e não mostra o e-mail nesta tela (html:447); a implementação põe o link abaixo da faixa e repete o e-mail. A marca de estado herda a divergência de 4.5. Sem captura |
| 5.2 histórico | **diverge** | T:445-484; `suspensions.ex:84` | `Suspension history`, do mais novo ao mais antigo (`desc: suspended_at`), cada episódio um bloco de duas metades: confere. **Lado a lado a partir de `sm:` = 40 rem**, e a régua diz **44 rem**. Sem captura |
| 5.3 metade | confere | T:453-467, T:468-479, T:542-547 | Instante UTC (`hora_completa/1`, T:626) · `by <nome>` · rótulo + código mono · nota entre aspas (`<q>`) ou `no note` com `<.absent>` (frase da base, `platform_tenant_suspension.yaml:119`). Nenhuma contagem (Q4 (b)). Sem captura |
| 5.4 episódio aberto | confere | T:480-482 | `not reactivated — still suspended` com `<.absent>`. Sem captura |
| 5.5 `not_recorded` | confere | T:458-461, T:462-465; yaml:69-70 | `by: not recorded — suspended by hand before this record existed` com `<.absent>`; rótulo `The reason was not recorded` da base. Ver também 5.x "no note na migração". Sem captura |
| 5.6 só o ato que cabe | confere | T:488-534 | `if @suspensa?` escolhe um dos dois formulários; o outro não é renderizado (D3). Sem captura |
| 5.7 razões de suspender | confere | T:515, T:567-592; yaml:49-65 | Os quatro, na ordem do protótipo, rótulo + código mono, `note required` em `suspected_compromise` e `other` (`nota_obrigatoria?/2`). Sem captura |
| 5.8 razões de reativar | confere | T:492, T:586-590; `suspension_reasons.ex:32-36` | `investigation_closed_no_compromise` só contra `suspected_compromise`, com a frase *"Offered because the open suspension's reason is Suspected compromise; it is the answer to that reason."*; `note required` só em `other`. Sem captura |
| 5.9 nota | confere | T:594-596, T:620-624 | `Note` + as duas dicas literais, terminando em `Kept with the episode.` Sem captura |
| 5.10 consequências de suspender | confere | T:523-532, T:598-599 | Cabeçalho e as cinco frases literais (html:481-487). Sem captura |
| 5.11 consequências de reativar | confere | T:500-509, T:598-600 | Cabeçalho e as cinco frases literais (html:548-555). Sem captura |
| 5.12 confirmação | confere | T:603-612; OC:55, 74-75 | `Type <slug> to confirm` (`confirm_slug`), nos dois atos, comparação exata antes do ato. No protótipo o slug do rótulo é mono (html:489); aqui é texto corrido. Sem captura |
| 5.13 botões | confere | T:497, T:520, T:613-615 | `Suspend, sign everyone out, revoke all tokens` com `btn-error` (clay, `app.css:60`); `Reactivate <nome>` com `btn-primary` (verdete, `app.css:81`). Sem captura |
| 5.14 recusas | confere | T:486; OC:72, 75, 120-170 | Página re-renderizada (`422`), notice acima do formulário, cada frase terminando em `Nothing changed.`, literais: `already suspended` com desde quando e por quem e o formulário de reativar; `is not suspended`; `A note is required for this reason (<rótulo>)` + "Write what was seen and why it calls for suspension."; `Choose a reason from the list.`; as duas de confirmação; `The list of reasons is not available …`. O negrito de `already suspended` vai até "by <nome>." — no protótipo para em "suspended" (html:568). Marca sem ícone, como 1.5. Sem captura |
| 5.16 sessão caída no meio | confere | OC:35-36, 64-65, 101-102, 107-108 | `:nao_autorizado` → `SessaoDoOperador.soltar/1` + o mesmo `404`. Sem captura |
| 5.x sucesso do ato | **diverge (declarado)** | T:443; OC:59-62, 116-117 | *"Suspended. Every session was ended and every API token revoked."* / *"Reactivated. No session or token came back."* no flash depois do `302`. O protótipo não desenha estado de sucesso na tela 5. Pede decisão |
| 5.x nota obrigatória na reativação | **diverge (declarado)** | OC:167-168, 176 | *"Not reactivated. A note is required for this reason (Other). Write why the organisation can come back. Nothing changed."* — o protótipo só desenha a da suspensão (html:570). Pede decisão |
| 5.x `:sem_episodio_aberto` | **diverge (declarado)** | OC:147-151 | *"Not reactivated. No open suspension was found for <nome>. Nothing changed. Tell whoever runs the server."* — fora do protótipo, declarado em OC:147. Pede decisão |
| 5.x histórico vazio | **diverge** | T:446-448 | Organização sem episódio mostra `<.absent reason="never suspended">` sob `Suspension history`. O protótipo não desenha este estado (Northwind tem histórico), e **não está declarado** como fora dele no código. É coerente com 4.6 e com D4, mas é frase de tela que ninguém aprovou. Sem captura |
| 5.x `no note` no caso da migração | **diverge** | T:466 | O episódio `not_recorded` tem `suspend_note` nulo, e `nota/1` escreve `no note`. O protótipo desenha o caso da migração **sem** essa linha (html:576-581). Sem captura |
| 5.x formulário depois de `already suspended` | **diverge** | OC:51, 72, 93-95; T:488-510, T:572, T:595, T:607 | Achado de QA, fora do texto da régua. Depois da recusa `already suspended` (a corrida de duas abas, D3), a página passa a mostrar o formulário de **reativar** — e os `valores` do formulário de suspender vão junto: a nota, o `confirm_slug` já digitado e, se a razão escolhida foi `other`, o rádio `other` marcado, que também é razão de reativar. O operador que queria suspender recebe um formulário de reativar **pronto para um clique**, com a nota da suspensão. O PROMPT 5.14 diz "formulário como estava"; o protótipo não diz o que acontece com os valores quando o formulário troca. O mesmo vale ao contrário em `is not suspended`. Sem captura |

## Nota — quem não é operador

| item | veredito | onde | observação |
|---|---|---|---|
| N.1 anônimo ou admin | confere | `operator_scope.ex:52-53, 61-67`; router:180-206 | `require_operator/2` e o curinga respondem pela **mesma** função `nao_encontrado/1`, sem redirecionamento. "Mesmos cabeçalhos e corpo" não foi medido aqui (há `nao_encontrado_test.exs`, não rodado). Sem captura |
| N.2 slug inexistente | confere | OC:68-69, 98-99 | O mesmo `nao_encontrado/1`. Sem captura |
| N.3 cookie fora de `/platform` | confere | `sessao_do_operador.ex:21` | Cookie próprio `_the_band_operator`, que só `OperatorScope` lê; `/people`, API e MCP não o conhecem. O comportamento (`/sign-in`, `401`) é coberto por `cookie_do_operador_em_dominio_test.exs`, não rodado. Sem captura |

## Em toda tela

| item | veredito | onde | observação |
|---|---|---|---|
| G.1 tons de cinza | **diverge** | T:48-54, T:60-67, T:631-645 | Ausência (tracejado + texto) e aviso (`1×` + texto) se distinguem pela forma. **A recusa não**: sem ícone e sem hachura, em cinza é uma faixa com texto em negrito, como o sucesso. **`active` × `suspended`** têm o mesmo ponto redondo, e só o texto os separa — a régua pede forma **e** texto. Sem captura, e a confirmação em cinza depende dela |
| G.2 360 px | não conferido | T:24, T:382 | Coluna única por padrão, `sm:` para colunas, tabela `stacked`. Rolagem horizontal e alvos de 44 px **não são mensuráveis pelo código**: os rádios são `radio-sm`, dentro de `<label>` que aumenta a área. Precisa de captura em 360 px |
| G.3 inglês, com o comentário | confere | T:8-9; OC:18-19 | O `@moduledoc` de `TelasHTML` e o de `OrganizacaoController` dizem que as frases são de tela e não se traduzem. Sem captura |
| G.4 nada de domínio | confere | T:373-537; `suspensions.ex:29-36` | Nenhum template lê pessoa, equipe, issue ou contagem; o `resumo` tem só `id`, `name`, `slug`, `status`, `ultimo_episodio_em`. Sem captura |

---

## O placar

- **confere**: 54
- **diverge**: 14 — 4 declarados no código e 10 não declarados
- **não conferido**: 1 (G.2, precisa de captura em 360 px)

Nenhum item foi conferido em tela renderizada. "Confere" quer dizer que o código-fonte do template
bate com a régua; a captura colorida, em cinza e em 360 px continua devida (PROMPT §4).

## Os `diverge` abertos, com a proposta

Quem decide, entre voltar ao protótipo e corrigir o código, é a pessoa mantenedora, pelo Product
Owner e o Design. A coluna "proposta" é a recomendação do QA, não a decisão.

| # | item | divergência | proposta do QA |
|---|---|---|---|
| D-1 | 1.5, 2.5, 2.6, 3.8, 3.13, 3.14, 5.14, G.1 | a recusa não tem o ícone `!` nem a hachura clay do protótipo | **corrigir o código**: dar a `recusa/1` (T:48-54) o ícone e a marca; uma componente conserta todas as telas |
| D-2 | 4.5, 5.1, G.1 | `suspended` é um ponto âmbar (`bg-warning`), não o chip cinza; `active` é ponto, não o chip verdete; os dois têm a mesma forma | **corrigir o código**: `estado/1` (T:631-645) com o chip do protótipo, `suspended` em cinza. O âmbar é a cor do aviso, e confundir os dois é o que a régua proíbe |
| D-3 | 4.7 | o episódio da migração aparece só com a data, sem `· reason not recorded` | **corrigir o código**, com emenda do contrato de `listar_organizacoes/1` (devolver também a razão do último episódio), que hoje não carrega a informação; ou o Design republica a coluna sem a marca. A primeira mantém a migração distinguível na lista |
| D-4 | 3.15 | falta a nota "The link leads to /platform/sign-in. It does not sign you in…" e o ícone `✓` | **corrigir o código**: a frase está no protótipo e no PROMPT |
| D-5 | 3.11 | os códigos vão para duas colunas em 40 rem, e não em 30 rem | **corrigir o código** (variante de 30 rem); ou o Design aceita `sm:` e republica |
| D-6 | 5.2 | as duas metades ficam lado a lado em 40 rem, e não em 44 rem | **corrigir o código**; ou o Design aceita `sm:` e republica |
| D-7 | 5.x histórico vazio | `never suspended` sob `Suspension history`, não desenhado nem declarado | **voltar ao protótipo**: o Design desenha a página de uma organização nunca suspensa, e a frase entra aprovada |
| D-8 | 5.x `no note` na migração | o caso `not_recorded` mostra `no note`, que o protótipo não mostra | **voltar ao protótipo**: o Design decide se a migração escreve `no note` (coerente com D4) ou se a linha some |
| D-9 | 5.x formulário depois de `already suspended` | o formulário do outro ato herda nota, `confirm_slug` e, com `other`, a razão: um clique reativa o que o outro operador acabou de suspender | **voltar ao protótipo** para decidir, com a recomendação do QA de **corrigir o código** para renderizar o outro formulário **vazio** quando o ato trocar. É defeito do ato que derruba ou devolve acesso a uma organização inteira, então pede a avaliação do agente `security` (AGENTS.md §14.0, "na dúvida, trate como se fosse") |
| D-10 (declarado) | 2.x | *"The two passwords do not match. Your setup code still works."* | **voltar ao protótipo**: o Design acrescenta o estado; a frase é coerente com 2.6 |
| D-11 (declarado) | 5.x sucesso | *"Suspended. Every session was ended and every API token revoked."* / *"Reactivated. No session or token came back."* | **voltar ao protótipo**: o Design desenha o estado depois do `302`, com a marca (o protótipo não tem sucesso na tela 5) |
| D-12 (declarado) | 5.x nota na reativação | *"… Write why the organisation can come back. Nothing changed."* | **voltar ao protótipo**: o Design acrescenta a recusa ao 5c, que só tem a da suspensão |
| D-13 (declarado) | 5.x `:sem_episodio_aberto` | *"Not reactivated. No open suspension was found for <nome>. …"* | **voltar ao protótipo**: o Design registra o estado; só é alcançável com o trigger de T044a desligado |

O placar conta 14 `diverge` e a tabela tem 13 propostas: D-2 reúne 4.5 e G.1 (a parte de
`active` × `suspended`), e D-1 reúne a recusa de G.1.

Fora da contagem e sem divergência, mas para quem revisar: o negrito de `already suspended` (5.14),
o slug que não está em mono em 5.12 e na recusa de confirmação, e o arranjo do cabeçalho da tela 5
(5.1) diferem do protótipo na tipografia ou na posição, não no texto. Ficam como observação; se o
Design os considerar parte da estrutura aprovada, viram `diverge`.

---

## Correções depois da conferência (2026-10-02)

Feitas no código, no mesmo branch, depois do relatório acima. Ainda **sem captura**: a captura
colorida, em cinza e em 360 px (PROMPT §4) continua devida, e G.1 e G.2 não fecham sem ela.

| divergência | o que mudou | onde |
|---|---|---|
| D-1, a marca da recusa | borda e hachura cor de argila e o `!` em texto; em cinza, a recusa fica distinta do sucesso | `telas_html.ex`, `recusa/1` |
| D-2, a marca de estado | `active` em chip verdete cheio, `suspended` em chip cinza cheio, os dois com o texto | `telas_html.ex`, `estado/1` |
| D-3, a migração na lista | `listar_organizacoes/1` devolve também a razão do último episódio (`DISTINCT ON`), e a lista escreve `· reason not recorded` | `suspensions.ex`, `telas_html.ex` |
| D-4, o fim do cadastro | o `✓` e a nota "The link leads to /platform/sign-in…" | `telas_html.ex`, `concluido/1` |
| D-5, colunas dos códigos | duas colunas a partir de 30 rem | `telas_html.ex`, `codigos/1` |
| D-6, metades do episódio | lado a lado a partir de 44 rem | `telas_html.ex`, `organizacao/1` |
| D-8, "no note" na migração | o caso `not_recorded` não mostra a linha da nota | `telas_html.ex`, `organizacao/1` |
| **D-9**, o formulário depois da corrida | na recusa por estado que mudou (`already suspended` ou `is not suspended`), o outro formulário vem **vazio**: sem razão, nota nem `confirm_slug`. Provado com o defeito injetado (`historico_e_ato_test.exs`) | `organizacao_controller.ex` |

**Continuam abertas, para a decisão da pessoa mantenedora**: D-7 (a frase `never suspended` sob o
histórico vazio, mantida porque a regra da casa manda escrever a ausência, mas não desenhada) e
D-10 a D-13 (as frases fora do protótipo). O D-9 pede ainda a avaliação do agente `security`
(AGENTS §14.0), por mexer no que um ato que derruba uma organização inteira mostra depois de uma
corrida.
