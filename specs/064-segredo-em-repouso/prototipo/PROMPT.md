# PROMPT — o pedido de troca da credencial (064, T018)

Protótipo: [`credential-age.html`](credential-age.html) · publicado em
<https://claude.ai/artifact/S5ZD8j7dsaDSH4QZsfYJUP> · 2026-10-03 · versão 1 · **para aprovação**
(data de aprovação: pendente).

## 1. Os pedidos, textuais e em ordem

**Da pessoa mantenedora** (os que regem estas telas):

1. 2026-09-07: *"quero exatamente a tela aprovada"*.
2. Spec 064, FR-016 a FR-019 e SC-009/SC-010 (aprovada): pedir a troca depois de três meses,
   **pedir e não impedir**; dizer **há quanto tempo** — *"Registrada há 4 meses" é acionável;
   "credencial antiga" não*; sem data é *idade desconhecida*, nunca dentro do prazo.

**Do pedido que encomendou o protótipo** (2026-10-03, textual):

> Protótipo da tela da tarefa T018 (#883) da spec 064 — "Pedir a troca na tela que administra":
> nas telas de credencial de ferramenta e de provedor de modelos, mostrar há quanto tempo a
> credencial está em uso e pedir a troca quando vencida ("registrada há 4 meses", não "credencial
> antiga"); a coleta não para — é pedido, não bloqueio (FR-016, FR-017). […]
> Obrigações da avaliação de segurança para a tela: a `API_KEY` que vem do ambiente aparece como
> idade desconhecida, NUNCA "no prazo"; os três estados tratados um a um; nenhuma parte do segredo
> aparece. Estados a desenhar: no prazo; vencida (o pedido, com "registered N months ago" e quem
> pode trocar); idade desconhecida (credencial sem data, e a do ambiente — dizer de quem é a
> ausência); logo depois da troca (a contagem volta, a data anterior fica registrada); quem não
> administra (o que vê ou não). Telefone a 360 px.

## 2. O brief de design seguido

- **Desenhar a partir do que existe**: `lib/the_band_web/live/source_live/index.ex` (`/tools`) e
  `lib/the_band_web/live/ai_live/index.ex` (`/ai`), com abas, cabeçalhos, cartões, tabela
  `stacked`, flashes e textos atuais; só o que a T018 acrescenta muda.
- **Herdar, não reinventar**: tokens do protótipo da 070 (papel, tinta, verdete, `info`, âmbar,
  clay; serif no corpo, grotesca nos títulos, mono em datas e identificadores; nenhuma webfont).
- **Marcas**: `within 3 months` contorno fino verdete; `replace · N months in use` borda dupla
  âmbar com "!"; `age unknown` tracejada; data inferida hachurada (derivado). Texto sempre;
  botão *View in greyscale*.
- **Domínio**: `TheBand.Credenciais.Idade` — `estado/2` (`:no_prazo | :vencida |
  :idade_desconhecida`), `em_uso_desde/1`, `limite_em_meses/0` = 3 meses de calendário;
  `AI.put/3` com `secret_set_at` e `previous_secret_set_at`; `AI.origem_da_chave/1` para a chave
  do ambiente.
- **Nenhuma parte do segredo no pedido**; os quatro últimos caracteres ficam onde já estão.
- **Dado só de exemplo**, marcado `example`; "hoje" = 2026-10-03.

## 3. A estrutura, seção por seção — a régua do QA

O QA confere na tela real, com captura ao lado, **em cores, em tons de cinza e a 360 px**. Texto
entre crases é o texto exato da tela; `N` e as datas vêm do dado.

### Regras de formato (valem em toda tela)

| # | item | o que tem de existir |
|---|---|---|
| F.1 | data | a data registrada, `AAAA-MM-DD`, sempre presente quando existe |
| F.2 | intervalo | abaixo de 1 mês: `N days ago` (ou `today`); de 1 mês em diante: meses de calendário inteiros arredondados para baixo — `N month(s) ago` / `N months in use` |
| F.3 | três estados | `:no_prazo` → `within 3 months`; `:vencida` → `replace · N months in use`; `:idade_desconhecida` → `age unknown`. Cada um tratado por cláusula própria; nenhum `_ ->` |
| F.4 | o "3" | lido de `Idade.limite_em_meses/0`, em todas as frases |
| F.5 | no prazo | também `replacement asked from <data + 3 meses>` |
| F.6 | nada bloqueia | nenhum botão desabilitado, escondido ou alterado pelo estado; coleta e geração não consultam o estado |
| F.7 | sem dispensar | nenhum "dismiss", "snooze" ou "remind me later" |

### Tela 1 — `/tools` (Connected tools)

| # | item | o que tem de existir |
|---|---|---|
| 1.1 | abas, cabeçalho, cartão da ferramenta | como hoje (inclusive o título atual), fora a marca da Q3 |
| 1.2 | botão | `replace the token` ao lado de `Credentials`, como hoje |
| 1.3 | pedido (1a) | entre `Credentials` e o formulário/tabela, um por credencial **ativa** vencida, ícone `!` + borda dupla: **`Replace the token “<label>”.`** · `It was registered N months ago, on <data>. The platform asks for a new token 3 months after one is saved.` · `Collection goes on with this token meanwhile. Nothing stops and nothing is blocked.` · `Generate a new token on GitHub, add it below, and once it works deactivate or remove the old one here. Removing it here does not revoke it on GitHub: revoke it there too.` · `Who can replace it: an administrator, or someone who answers for <organization_login>.` |
| 1.4 | coluna | `validated at` passa a se chamar `registered`; a célula tem data + marca (+ intervalo e F.5 no prazo); ordem: `label · credential · scopes · registered · state · ações` |
| 1.5 | linha vencida | fundo âmbar leve além da marca |
| 1.6 | no prazo (1b) | nenhum pedido; célula `2026-09-04` · `29 days ago` · `within 3 months` · `replacement asked from 2026-12-04` |
| 1.7 | logo depois da troca (1c) | flash atual `Credential <label> added and validated. Nothing was ended, and no data was marked.`; a linha nova `today` + `within 3 months`; se a antiga segue ativa e vencida, o pedido vira **`The new token is in. “<antiga>” is still active.`** · `“<antiga>” was registered N months ago, on <data>. Once “<nova>” has collected, deactivate or remove the old one, and revoke it on GitHub.` · `Collection goes on with both meanwhile.` |
| 1.8 | inativa vencida | conforme a resposta da **Q1** (recomendação: sem pedido; linha discreta sob a tabela pedindo para remover) |
| 1.9 | idade desconhecida (1d) | `age unknown` tracejada + `the platform has no date for this credential`; aviso tracejado `?` conforme a **Q2**. Nunca `within` |
| 1.10 | rodapé | as duas notas atuais, mais `We ask for a new token 3 months after one is saved. We ask; we never stop collecting because of age.` |
| 1.11 | ferramenta encerrada | sem credenciais, sem pedido (como hoje) |

### Tela 2 — `/ai` (AI provider)

| # | item | o que tem de existir |
|---|---|---|
| 2.1 | abas, cabeçalho, formulário | como hoje, fora a marca da Q3 e a nota do formulário (2.9) |
| 2.2 | pedido (2a) | dentro de `Key in use`, depois do selo e do mascarado: **`Replace this key.`** · `It was registered N months ago, on <data>. The platform asks for a new key 3 months after one is saved.` · `Profile generation goes on with this key meanwhile. Nothing stops and nothing is blocked.` · `Generate a new key at the provider, paste it in the form below, then revoke the old one at the provider.` · `Who can replace it: an administrator, or anyone with access to Connected tools. The key is one for the whole organisation.` |
| 2.3 | linha nova | `key registered`: data + marca (+ intervalo e F.5 no prazo); `checked against the provider at` continua |
| 2.4 | no prazo (2b) | nenhum pedido |
| 2.5 | data inferida (2c) | `secret_set_at` nulo: `inferred from the last check` hachurada + `This key was saved before the platform recorded replacement dates. The date is the last check against the provider, which is when this key was saved.`; vencida, o pedido de 2.2 com a marca mantida |
| 2.6 | chave do ambiente (2d) | o aviso atual, e abaixo `key registered`: `age unknown` + `The key was set in the server environment, and the platform never recorded when. The absence is the platform's, not the provider's.`; conforme a **Q2**, aviso tracejado **`This key's age is unknown, so it is not counted as within 3 months.`** `Whoever runs the server replaces it, in the server's environment settings. Or save a key for this organisation below: its age is recorded from the day it is saved.` **Nunca `within`** |
| 2.7 | logo depois da troca (2e) | flash `Key checked against the provider and saved (••••<4>). It replaces the key registered on <data antiga>; the count starts again today.`; `key registered` `today` + `within 3 months`; `previous key`: `<data antiga> → <data nova>` · `in use for N months` · `the date is kept; the secret is gone` |
| 2.8 | mesma chave (2f) | conforme a **Q4**: `Key checked against the provider and saved (••••<4>). It is the key already registered, so it still counts from <data>.`; o cartão e o pedido não mudam |
| 2.9 | nota do formulário | `Saving a different key replaces the previous one and starts the count again; the date the previous key was registered is kept, the secret is not. Saving the same key again keeps its date.` (substitui a nota atual) |
| 2.10 | sem chave (2g) | como hoje; sem idade, sem pedido |

### Tela 3 — telefone, 360 px

| # | item | o que tem de existir |
|---|---|---|
| 3.1 | ordem | abas → cabeçalho → `Credentials` / `Key in use` → **pedido** → lista |
| 3.2 | tabela | empilhada (`stacked`, `data-label`), `registered` com data e marca |
| 3.3 | rolagem | nenhuma horizontal; controles de 44 px |

### Tela 4 — quem não administra

| # | item | o que tem de existir |
|---|---|---|
| 4.1 | sem acesso operacional | o redirecionamento atual para `/people` com a mensagem atual; nenhuma idade nem pedido em lugar algum |
| 4.2 | concessão organization | em `/tools` só os pedidos das ferramentas das organizações concedidas; nada, nem contagem, sobre as outras |
| 4.3 | em `/ai` | todo operador vê o pedido da chave (decisão de 2026-08-28) |
| 4.4 | segredo | nenhum pedido, flash ou marca contém parte do segredo; os quatro últimos ficam só onde já estão |

### Marca na aba — conforme a Q3

| # | item | o que tem de existir |
|---|---|---|
| A.1 | (b) | `replace` em âmbar com borda, ao lado do rótulo da aba cuja tela tem credencial ativa vencida; ausente se nenhuma |

### Em toda tela

| # | item |
|---|---|
| G.1 | em tons de cinza, as três marcas, o pedido e a data inferida se distinguem pela forma **e** pelo texto |
| G.2 | texto de tela em inglês, com o comentário no código dizendo que é tela |
| G.3 | teste da T018: 4 meses → pedido **e** tempo; ontem → nada; coleta com credencial vencida continua |

## 4. Como cada papel usa este arquivo

- **Product Owner**: registra o link e este `PROMPT.md` no item da T018 (#883); leva Q1–Q4 à
  pessoa mantenedora; aceita a entrega só conferida contra a seção 3.
- **Design**: marca *Decided <data>*, ajusta o protótipo às respostas e republica **no mesmo
  endereço**; registra a data de aprovação no topo.
- **Elixir/Phoenix Developer**: implementa exatamente a seção 3; o que não for possível ou honesto
  com o dado volta ao protótipo. **Antes**, o defeito da chave anterior regravada (README, "O que
  o protótipo descobriu") precisa de conserto, ou a 2c mente.
- **Security**: dá o aval na Q4 e confere 4.4.
- **QA**: confere F.1–G.3 na tela renderizada, em cores, em cinza e a 360 px, por quem não
  implementou.
