# Conferência da tela `/accounts` contra o protótipo aprovado — 072/T012

**Quem confere**: agente QA, 2026-10-03. **Como**: leitura do código, item a item da régua
(`PROMPT.md` §3, itens 1 a 35) contra o protótipo (`accounts-admin-role.html`, aprovado em
2026-10-03 com Q1 (b), Q2 (a), Q3 (a), Q4 (a), Q5 (b), Q6 (a) — `README.md`, seção *Aprovação*).
**O que não foi feito**: a suíte não foi rodada (a base de teste é compartilhada), e nenhuma tela
foi aberta num navegador. Os itens visuais ficam como "não verificável sem navegador", e não como
"confere".

**Estado do código conferido**: branch `feature/568-papel-de-administrador`, commit `aa24588`
(a T011, `6fc929c`, mais o teto de 2000 caracteres da nota, que entrou durante a conferência:
`index.ex:476-484` e `papel.ex:399`). Os números de linha abaixo são os desse commit.

Arquivos lidos:

- `lib/the_band_web/live/accounts_live/index.ex` (render, eventos `abrir_papel`, `mudar_papel`,
  `confirmar_papel`, `recusar_papel/4`)
- `lib/the_band_web/live/accounts_live/papel.ex` (componentes e frases)
- `lib/the_band_web/live/hooks.ex` (`reconferir`, `manter_na_area`, `recusar_por_papel`)
- `lib/the_band/tenants/mudanca_de_papel.ex`, `lib/the_band/tenants/account_role.ex`
- `lib/the_band_web/ui.ex` (`absent/1`), `lib/the_band_web/components/core_components.ex` (`flash/1`)
- `assets/css/app.css:244-288` (`table.stacked`)
- `test/the_band_web/live/accounts_papel_test.exs`, `test/the_band_web/live/papel_aba_aberta_test.exs`

## Uma observação sobre a própria régua, antes da tabela

O `PROMPT.md` §3 **ainda diz** "versão 1, **ainda não aprovada**", e o item 4 ainda diz que o
administrador desativado tem ato "**nenhum** (Q1)". A aprovação de 2026-10-03 (Q1 = (b)) inverteu
isso, e o `PROMPT.md` §4 manda o Design marcar as decisões e ajustar a §3. Não foi feito. Esta
conferência usa a régua **com as decisões aprovadas aplicadas** (o `README.md` e a `spec.md`
US3 cenário 1 dizem o mesmo: "cada administrador tem 'rebaixar', inclusive o desativado").

## A conferência, item a item

Legenda do veredito: **confere** · **diverge** · **não verificável sem navegador**.

### Tela 1 — `/accounts` em repouso

| # | o que a régua pede | o que a tela faz | veredito | se diverge: razão e decisão |
|---|---|---|---|---|
| 1 | contagem termina com `· N active administrators` (singular `1 active administrator`), mono, `tabular-nums` | `index.ex:744-752`: `<p class="font-mono text-sm tabular-nums">` termina com `<strong>{N} active {plural(N, "administrator", "administrators")}</strong>`; N = `Papel.admins_ativos/1` (`papel.ex:157-159`), só `admin` **e** ativa | confere | — |
| 2 | bloco "Who administers this organisation", com o texto exato, abaixo do cabeçalho e antes da tabela | `papel.ex:161-175`, renderizado em `index.ex:761`, logo depois do bloco do cabeçalho e antes de `nota_da_tela`, `remocao_de_acesso`, criação e tabela. Texto comparado palavra a palavra com o protótipo (`accounts-admin-role.html:240`): idêntico, inclusive o trecho em negrito | confere | — |
| 3 | seis colunas na ordem de hoje: Person, GitHub, Management, Account, Sign-in credential, ações; cabeçalho `Management` | `index.ex:856-861`: as seis, na ordem; `<th>Management</th>` | confere | (o `<th>` das ações é vazio, como antes da 072; o protótipo tem `Actions` só para leitor de tela. Ver item 34) |
| 4 | célula `Management` por caso (tabela de cinco linhas da régua) | `papel.ex:186-244` e `linha_do_papel` `papel.ex:250-266`. **Ativo, outra pessoa**: badge + `since DD Mon · by <autor>` + "Remove admin role…" — confere. **Própria conta**: badge + linha + "Step down…" — confere (linha: ver item 5). **Membro ativo**: `member` em palavra + "Make administrator…" — confere; a linha de baixo **diverge** (abaixo). **Admin desativado**: badge, "not counted while the account is disabled", "Role changes wait for reactivation.", **nenhum ato** (`papel.ex:211-212`). **Membro desativado**: `member` + "Role changes wait for reactivation." + nenhum ato — confere | **diverge** | Três divergências: **(4a)** o administrador desativado **não** tem "Remove admin role…", e a Q1 aprovada é (b): "permitir só 'Remove admin role' em administrador desativado" (`README.md:100`; `spec.md:97-99`). O domínio já aceita (`mudanca_de_papel.ex:31-38`); a célula é que o barra pelo `cond` em `papel.ex:211`. **Há decisão, e a tela a contraria.** E a frase "Role changes wait for reactivation." passa a ser falsa para o admin desativado. **(4b)** membro sem episódio diz só a marca tracejada "no role change recorded", e não "never an administrator" (ver item 5 — mesma razão, **decisão pendente**). **(4c)** defeito de código: `periodo/2` (`papel.ex:269`) usa `when de < ate` sobre `DateTime`, que é comparação **estrutural** de mapa: compara o **dia** antes do mês e do ano. Medido: `~U[2026-09-28 10:00:00Z] < ~U[2026-10-02 14:00:00Z]` dá `false` (`DateTime.compare` dá `:lt`). Um membro promovido em 28 Sep e rebaixado em 02 Oct lê "administrator until 02 Oct" — a forma que o comentário da linha 268 reserva para "sem a promoção registrada". A tela afirma que falta registro que existe. **Sem decisão: é defeito**, nenhum teste o pega (o teste dos itens 18-21 roda tudo no mesmo instante) |
| 5 | admin sem mudança registrada (a primeira conta): `since the organisation was created ·` seguido da marca tracejada "no role change recorded" | `papel.ex:259-263`: só `<.absent reason="no role change recorded">` (quadrado tracejado + texto, `ui.ex:295-305`). **Não** há "since the organisation was created" | **diverge** | Razão declarada em `papel.ex:15-18`: as frases "since the organisation was created" e "never an administrator" afirmam o tempo **anterior** ao registro, que nasce com a 072; uma conta promovida antes da 072 diria o falso. **A Q6 não cobre**: a Q6 (a) decide "nenhuma entrada fabricada" e diz "the row writes 'no role change recorded', **as drawn**" — e o desenhado tem as duas frases. A Q6 trata da **entrada no registro**; a frase na célula é outra coisa. A razão é boa (honesta com o dado), mas o `PROMPT.md` §4 manda: "se algo não for honesto com o dado, **volta ao protótipo** — não improvisa no código". Foi improvisado no código. **Decisão pendente.** O teste `accounts_papel_test.exs:65` (`refute ... "never an administrator"`) trava a divergência como se fosse a régua |
| 6 | nenhum `—` na coluna `Management` | `linha_do_papel` não emite `—`; o período usa `–` (meia-risca entre datas, como o protótipo `:299`). Teste `accounts_papel_test.exs:53` refuta `—` nas três células | confere | — |
| 7 | legenda ganha três entradas: `administrator` (marca), `member` (palavra) e a frase do último | `papel.ex:478-503`, montada em `index.ex:1334` dentro da legenda existente. Terceira frase idêntica à régua: "the last active administrator cannot step down or be removed — make someone else administrator first." | confere | — |
| 8 | seção "Administrator changes", subtítulo exato; entrada com `DD Mon HH:MM` mono, as duas frases, de→para mono, nota entre aspas ou "no note" em itálico; mais recente primeiro; limite Q5 | `papel.ex:507-572`, renderizada em `index.ex:953`. Subtítulo idêntico (`:519`). Instante `%d %b %H:%M` mono `tabular-nums` (`:534-536`). "made X administrator" / "removed the administrator role from X" (`:538-552`). De→para mono com rótulo da base. `<q>` ou `<em>no note</em>` (`:554-555`). Ordem `desc: inserted_at, desc: id` e limite 20 + total (`mudanca_de_papel.ex:159-173`); "N earlier changes, all kept" (`papel.ex:559-561`) — Q5 (b) | confere | (observação: "no note" está escrito à mão em `papel.ex:555`, e a D8 manda reaproveitar a frase da base, `AccountLifecycle.frase_sem_nota/0`. O texto hoje é o mesmo; a fonte não) |
| 9 | sob a lista, a frase de que a marca da primeira conta é anterior ao registro, e de que desativar/reativar não são mudança de papel | `papel.ex:564-569`. Generaliza a frase do protótipo (que nomeia "Ana Example"), sem pronome; diz as duas coisas | confere | — |

### Tela 2 — painel "Make administrator"

| # | o que a régua pede | o que a tela faz | veredito | se diverge |
|---|---|---|---|---|
| 10 | abre **abaixo da tabela, no lugar onde abrem desativar e reativar**; borda azul | Painel em `index.ex:945-951`, borda `border-info/50` (`papel.ex:290`). Ordem do render: tabela → legenda (`:940`) → avisos (`:943`) → **painel do papel** (`:945`) → **"Administrator changes"** (`:953`) → formulário de desativação (`:955`) → de reativação (`:961`). Na `development`, os dois formulários vinham **logo depois da legenda** | **diverge** | O painel do papel abre abaixo da tabela, mas **não** no mesmo lugar dos formulários de desativar e reativar: a seção nova ficou entre os dois, e com até 20 entradas empurra desativar/reativar para longe da tabela. O protótipo põe "Administrator changes" sob a tabela (tela 1) e diz que os painéis abrem "where the disable and reactivate forms already open" (`:356`). E o brief (`PROMPT.md` §2) manda os formulários de desativação e reativação ficarem "como estão". **Sem decisão** |
| 11 | eyebrow `Make an account administrator`; título `Make <nome> administrator — <e-mail>` | `papel.ex:294-305` | confere | — |
| 12 | de→para `member → administrator` (marca) | `papel.ex:315-319`: `member` em palavra → badge `administrator` | confere | — |
| 13 | "what happens": gerir ferramentas, credenciais, syncs e contas, **incluindo remover o seu papel**; vale na próxima ação, sem entrar de novo; registrado com seu nome, este instante e a nota | `papel.ex:333-344`. Conteúdo completo. Texto: "{nome} can connect…" (protótipo: "Bia can connect…", só o primeiro nome) e "It takes effect at **their** next action. **They** do not need to sign in again." (protótipo: "**her** next action. **She** does not…") | **diverge** | Pronome trocado pela forma neutra. Razão em `papel.ex:19-20`: a tela não sabe o pronome de ninguém. Razão boa; **nenhuma das Q1-Q6 a cobre**. **Decisão pendente** (divergência P, abaixo) |
| 14 | "what it does not do": senha, elo do GitHub e sessões; equipes, trabalho e medidas | `papel.ex:373-378`: "**Their** password, **their** GitHub link and **their** open sessions…"; "**Their** teams, **their** work and every measure about **them**… what **they** can manage, not about what **they** did." Protótipo: "Her … she" | **diverge** | Mesma divergência P. **Decisão pendente** |
| 15 | campo `Note — optional · kept on the record, not written to the log` | `papel.ex:394-400`; texto idêntico | confere | — |
| 16 | botão primário "Make <nome> administrator" e "Cancel"; **sem campo de digitar** (Q2) | `papel.ex:416-435`; o campo de e-mail só existe com `acao == "deixar"` (`:402`). Teste `accounts_papel_test.exs:75` refuta o campo | confere | — |
| 17 | depois do ato, no lugar do painel: aviso ✓ "<nome> is now an administrator. Recorded at DD Mon HH:MM, by you."; linha, seção e contagem refletem | `index.ex:423-433`: `papel: nil`, `aviso_papel: Papel.sucesso(:promover, …)`, e `carregar/1` relê contagem, células e registro. Aviso em `papel.ex:460-463`, com `✓`, imediatamente antes do lugar do painel (`index.ex:943`). Texto (`papel.ex:42-47`) idêntico às duas frases da régua. **Falta a terceira frase do protótipo** (`:391`): "Her row and 'Administrator changes' show it; the header now reads 3 active administrators." | **diverge** | A régua cita só as duas primeiras frases, mas a tela aprovada é o protótipo, e ele tem três. A terceira foi omitida, sem razão escrita (provavelmente pelo "Her"). **Sem decisão** |

### Tela 3 — painel "Remove admin role" (outra pessoa)

| # | o que a régua pede | o que a tela faz | veredito | se diverge |
|---|---|---|---|---|
| 18 | abaixo da tabela, borda barro; título `Remove the administrator role from <nome> — <e-mail>`; de→para `administrator → member` | `papel.ex:291` (`border-error/40`, a mesma do formulário de desativação), `:306-308`, `:320-324` | confere | (o lugar herda a divergência do item 10) |
| 19 | "what happens": deixa de gerir; a tela aberta dele para **na próxima ação**; a organização fica com N administradores (nomeia quem); registrado | `papel.ex:345-354`, `quantos_ficam/1` `:440-445`. Conteúdo completo. Texto: "A screen **they** have open stops acting as administrator at **their** next action" (protótipo: "he/his"); "The organisation keeps 1 active administrator: **Ana Example**." (protótipo: "…: **you**.", quando quem fica é quem está olhando) | **diverge** | Divergência P (pronome), **decisão pendente**. E o "you": a tela nomeia a própria pessoa pelo nome em vez de "you" — **sem decisão**; não há razão escrita para essa |
| 20 | "what it does not do": **"It does not remove access."**, continua entrando como membro, desativar é o ato; sessões, senha e elo não mudam | `papel.ex:379-387`. "It does not remove access." idêntico e em negrito. Resto: "If **they** left…", "**Their** sessions…", "Nothing **they** did is erased." (protótipo: "he / His") | **diverge** | Divergência P. **Decisão pendente** |
| 21 | nota opcional; botão barro "Remove <nome>'s administrator role" e "Cancel"; sem digitar | `papel.ex:394-400`, `:417-435` (`btn-error`), campo de e-mail ausente fora de "deixar" | confere | — |

### Tela 4 — painel "Step down"

| # | o que a régua pede | o que a tela faz | veredito | se diverge |
|---|---|---|---|---|
| 22 | título `Step down as administrator of <organização> — your account, <e-mail>` | `papel.ex:309-311` | confere | — |
| 23 | "what happens" com **"You cannot give the role back yourself."** e nomeia quem pode | `papel.ex:355-365`; `quem_pode_devolver/1` `:447-450`: "Rui Example, the administrator who remains, can." (plural com a lista) | confere | — |
| 24 | campo "Type your e-mail to confirm" com o e-mail como dica; o botão não fica desabilitado enquanto se digita | `papel.ex:402-414` (dica mono com o e-mail); o botão `:417` não tem `disabled`; a comparação é no servidor, `index.ex:389-402` | confere | — |
| 25 | e-mail errado: painel aberto, nota preservada; aviso hachurado "Not changed. That is not the e-mail of your account. You are still an administrator." | `index.ex:396-397`: `papel` (com nota e e-mail) fica, `recusa_papel: Papel.email_errado()`; texto `papel.ex:75-80` idêntico; aviso hachurado com `!` (`papel.ex:465-472`). Teste `accounts_papel_test.exs:108-115` confere texto, nota e o papel no banco | confere | (o aviso aparece acima do painel, e não ao lado do campo como no desenho; a régua não fixa o lugar) |

### Tela 5 — o último administrador

| # | o que a régua pede | o que a tela faz | veredito | se diverge |
|---|---|---|---|---|
| 26 | contagem `1 active administrator`; célula diz `the only active administrator`; ato **no lugar, tracejado e inerte**, com a frase | `papel.ex:190-191` (`unico?`), `:207`, `:213-222`: `<span class="btn btn-outline btn-dash … pointer-events-none" aria-disabled="true">` e a frase idêntica. Teste `accounts_papel_test.exs:126-137` | confere | — |
| 27 | recusa depois de corrida: aviso hachurado com ícone — "Not changed: the organisation would have no active administrator." **seguido de quem agiu antes e quando**, e "Your role is unchanged."; a marca continua | `index.ex:445-460` e `papel.ex:86-111`. A primeira frase confere, o aviso é hachurado com `!`, a marca continua (`carregar/1`). **Quem agiu antes** é `List.first(mudancas)` (`index.ex:447`): a mudança **mais recente da organização**, seja ela a causa ou não. Texto produzido no caso do protótipo (Ana deixou o papel um instante antes): "**Ana Example removed the administrator role from Ana Example at 14:02.** Your role is unchanged." Protótipo (`:533`): "**Ana Example stepped down at 14:02, a moment before this request, so you are now the only one.** Your role is unchanged." | **diverge** | Três diferenças, **nenhuma com decisão**: (a) o caso de quem deixou o próprio papel sai como "X removed the administrator role from X" — a própria célula já sabe dizer "stepped down" (`papel.ex:256-257`), e a frase da recusa não; (b) falta "so you are now the only one"; (c) a mudança nomeada é a última da organização, e não a que causou a recusa, e leva só `HH:MM`, sem data: se a última mudança foi há três semanas, a frase atribui a recusa a ela, com uma hora que parece de hoje. É o defeito que a D5 existe para evitar ("sem quem e quando, a pessoa não distingue…") ao contrário: aqui o quem e o quando podem estar errados. Nenhum teste cobre o item 27 |
| 28 | a mesma frase recusa desativar o último administrador | `index.ex:517-519`: `recusa_de_desativacao(:ultimo_admin_ativo)` → `Papel.ultimo_admin(nil, nil)` = "Not changed: the organisation would have no active administrator." | confere | (aparece no `@erro` do topo, `index.ex:763`, vermelho e não hachurado; a régua só pede a frase. Nenhum teste da tela cobre) |

### Tela 6 — estado que mudou em outra aba

| # | o que a régua pede | o que a tela faz | veredito | se diverge |
|---|---|---|---|---|
| 29 | aviso hachurado: "Not changed: <nome> is already an administrator. <autor> made **her one** at HH:MM." (espelho: "… is already a member. <autor> removed the role at HH:MM."); a linha re-renderiza; o painel fecha | `index.ex:463-473`, `papel.ex:113-143`. Primeira frase idêntica. Segunda: "<autor> **made the change** at HH:MM." — espelho idêntico ("removed the role at HH:MM."). `carregar/1` re-renderiza a linha; `papel: nil` fecha o painel (teste `accounts_papel_test.exs:139-149`, com `refute` do painel). Falta também a frase do protótipo "The row below shows her current role." (`:548`), que a régua não cita | **diverge** | Divergência P ("made her one" → "made the change"). **Decisão pendente**. A frase omitida segue a mesma sorte |

### Tela 7 — perdeu o papel com a tela aberta

| # | o que a régua pede | o que a tela faz | veredito | se diverge |
|---|---|---|---|---|
| 30 | rebaixado por outro: a próxima ação não roda; vai para `/people` com "Only organisation administrators can do that." (Q3) | `mudanca_de_papel.ex:100-101` avisa no tópico da conta depois do `commit`; `hooks.ex:162-176` relê a conta e, na área admin, chama `recusar_por_papel/1` (`hooks.ex:124-128`): flash de erro com a frase de hoje e `/people`. O ato que chega antes do aviso volta `:nao_autorizado` e cai no mesmo lugar (`index.ex:435-436`). Teste `papel_aba_aberta_test.exs:29-39` | confere | — |
| 31 | deixou o papel: vai para `/people` com **aviso de sucesso** "You stepped down as administrator of <organização>. Recorded at DD Mon HH:MM. <nome> can give the role back." | `index.ex:415-421`: `put_flash(:info, Papel.deixou(…))` e `redirect(to: "/people")`. Texto (`papel.ex:60-71`) idêntico à régua. Mas o flash `:info` é o toast azul do canto, com o ícone de **informação** (`core_components.ex:59-85`, `hero-information-circle`, `role="alert"`), e não o aviso de sucesso com ✓ do protótipo (`:582`) | **diverge** | O texto confere; a **marca** não: a casa só tem `:info` e `:error`, e o sucesso sai como informação. **Sem decisão**. Ver também "o sucesso de rebaixar", abaixo |
| 32 | membro nunca vê `/accounts`; nenhum controle de papel para quem não é administrador | `router.ex:360-363`: `/accounts` em `live_session :admin` com `require_admin`; `hooks.ex:102-116` recusa no `mount`. Os componentes de papel só são usados em `AccountsLive.Index` (busca em `lib/`) | confere | — |

### Em todas as telas

| # | o que a régua pede | o que a tela faz | veredito | se diverge |
|---|---|---|---|---|
| 33 | toda marca tem texto; tudo lê em escala de cinza | **O que o código garante**: toda marca carrega palavra — `administrator` no badge (`papel.ex:197`), `member` em palavra (`:199`), a ausência com quadrado tracejado **e** "no role change recorded" (`ui.ex:295-305`), o ato recusado tracejado **e** a frase ao lado (`papel.ex:214-222`), a recusa hachurada **e** "Not changed…" com `!` (`papel.ex:465-472`), o sucesso com `✓` **e** a frase. Nenhum estado é dito só por cor. **O que só o navegador mede**: contraste do badge `badge-info` e do hachurado de `color-mix(… 12% …)` em escala de cinza, e se o hachurado se distingue do fundo — o CSS compilado e a captura com filtro de cinza | não verificável sem navegador | — |
| 34 | a 360 px, sem rolagem lateral; a tabela empilha com o nome da coluna em cada célula (Q4) | **O que o código garante**: `<table class="table stacked">` (`index.ex:853`), `data-label` em Person, GitHub, Management, Account e Sign-in credential (`:867-896`); a regra `@media (max-width: 40rem)` (`app.css:244-288`) esconde o `thead` e põe `attr(data-label)` antes de cada célula. **Mas** a célula das ações tem `data-label=""` (`index.ex:916`) e o `<th>` é vazio (`:861`): empilhada, a célula dos atos é a única **sem o nome da coluna** — o protótipo tem `data-label="Actions"` (`:268`) e `<span class="sr">Actions</span>` no cabeçalho. **O que só o navegador mede**: a ausência de rolagem lateral a 360 px — o invólucro continua `overflow-x-auto` (`index.ex:851`), que **esconde** um estouro numa rolagem dentro do cartão em vez de evitá-lo; e o "Administrator changes", o painel e os avisos (`max-w-3xl`) fora da tabela | **diverge** | A célula sem nome é certa pelo código; a medida a 360 px continua por fazer. **Sem decisão** |
| 35 | inglês na tela | Todas as frases novas da 072 são inglês (`papel.ex`, `index.ex:356-492`, `hooks.ex:126`) | confere | (observação **fora da 072**: `index.ex:130`, `:153` e `:222` mostram "Conta não criada…", "Conta não encontrada." e "Essa pessoa já está associada…" em português — o `en/errors.po:541-542` tem `msgstr ""`, então o português vai à tela. Antecede a 072; vale issue própria) |

## O que a régua não prevê e a tela faz

**O sucesso de rebaixar outra pessoa não tem frase no protótipo.** O protótipo só desenha o sucesso
de promover (tela 2) e o de deixar o papel (tela 7). A implementação inventou
(`papel.ex:49-56`): "<nome> is no longer an administrator, and keeps signing in as a member.
Recorded at DD Mon HH:MM, by you." A frase é coerente com o item 20, mas é **texto de tela sem
protótipo** — `PROMPT.md` §4: "não improvisa no código". **Sem decisão.**

**A recusa da nota longa** (`index.ex:476-484`): "Not
changed: the note is longer than 2000 characters." — também sem protótipo. **Sem decisão.**

**A recusa de promover conta desativada** (`papel.ex:145-153`): "Not changed: <nome>'s account is
disabled. Role changes wait for reactivation." Sem protótipo, e com Q1 (b) aplicada a segunda frase
fica imprecisa (rebaixar não espera). **Sem decisão.**

## Observações que não são item da régua, mas são defeito ou risco

- **A frase de reserva no código**. `papel.ex:261` e `:524` escrevem
  `AccountRole.frase_sem_registro() || "no role change recorded"`. O moduledoc de
  `account_role.ex:11-13` diz o contrário: "uma frase de reserva no código seria a duplicata
  silenciosa que a FR-069 da 060 proíbe". E a frase da recusa do último está escrita à mão em
  `papel.ex:89`, enquanto a base a declara em `access.account_role` (`frase_ultimo_admin/0`, que
  ninguém chama). Se a base mudar a frase, a tela não acompanha, e nenhum teste nota.
- **Os testes da tela não asserem ordem** (só a do registro, `accounts_papel_test.exs:158-160`). A
  régua da casa para protótipo pede "teste LiveView que assere a ordem dos títulos no HTML". Não há
  teste para: o bloco do item 2 antes da tabela; o painel e os formulários no mesmo lugar (10); a
  linha do administrador desativado (4, Q1); o período de um membro promovido e rebaixado em meses
  diferentes (4c — é o teste que reprovaria o defeito de `periodo/2`); a recusa depois de corrida
  (27); a recusa de desativar o último (28); a legenda (7).
- **O teste trava uma divergência**: `accounts_papel_test.exs:65` refuta "never an administrator".
  Se a decisão sobre o item 5 for voltar ao protótipo, esse `refute` passa a reprovar o código
  certo.
- **Os horários são UTC e a tela não diz** (`Calendar.strftime` sobre `inserted_at`). É a convenção
  da tela de contas antes da 072 também; fica registrado, não é divergência do protótipo.

## A contagem

| veredito | itens | quantos |
|---|---|---|
| confere | 1, 2, 3, 6, 7, 8, 9, 11, 12, 15, 16, 18, 21, 22, 23, 24, 25, 26, 28, 30, 32, 35 | **22** |
| diverge | 4, 5, 10, 13, 14, 17, 19, 20, 27, 29, 31, 34 | **12** |
| não verificável sem navegador | 33 (e a parte visual de 34) | **1** |

**Total: 35.** Fora da régua, mais três textos de tela sem protótipo (sucesso de rebaixar, nota
longa, promover conta desativada).

## As divergências — e o estado de cada uma depois de 2026-10-03

A condição da T012 é "não há diverge aberto sem decisão". Na primeira passada **não estava
cumprida**. A coluna *recomendação* é a da primeira passada; o **estado** de cada uma, depois das
decisões da pessoa mantenedora e da correção do código, vem no fim da linha.

| id | itens | a divergência | tem decisão? | recomendação |
|---|---|---|---|---|
| **A** | 4 | administrador desativado **sem** "Remove admin role…", e com "Role changes wait for reactivation." | **sim, e a tela a contraria** (Q1 = (b)) | **Corrigir a tela**: o `cond` de `papel.ex:210-241` passa a dar "Remove admin role…" ao admin desativado (nunca "Make administrator"); teste novo para a linha. A frase que substitui "Role changes wait for reactivation." **nessa** linha precisa do Design (o protótipo não foi republicado com a Q1 (b), e o `PROMPT.md` §3 ainda diz "nenhum (Q1)") — o Design republica o item 4 e a §3 · **estado**: **corrigido em `8bb5e2b`** (código: o ato "Remove admin role…" no administrador desativado, e a frase de espera só no membro desativado; teste "item 4: o administrador desativado tem o ato de rebaixar…"). A parte de texto — o que a linha diz no lugar da frase removida — **aguarda o Design** republicar o item 4 e a §3 do `PROMPT.md` com a Q1 (b) |
| **B** | 4 (linha de baixo), 5 | "no role change recorded" sozinho, sem "since the organisation was created" e sem "never an administrator" | **não** — a Q6 decide sobre entrada fabricada, e diz "as drawn" | **Levar ao Product Owner / pessoa mantenedora**, com opções: (a) aceitar a tela como está, e o Design republica os itens 4 e 5 só com a ausência; (b) voltar ao protótipo como está, aceitando que uma conta promovida antes da 072 leia "since the organisation was created" ou "never an administrator" falsamente; (c) dizer "since the organisation was created" só para a conta que se prova a primeira (criada pelo bootstrap), e a ausência nas demais. **Recomendação: (a)** — a razão da implementação é honesta com o dado, e a regra da casa é não afirmar o que o registro não sabe; mas quem decide não é o código · **estado**: **decidido pela pessoa mantenedora em 2026-10-03: (b) voltar ao protótipo**, contra a recomendação. **corrigido em `8bb5e2b`**: o administrador sem episódio diz "since the organisation was created ·" com a ausência, e o membro "never an administrator" (teste "itens 4 e 5: sem episódio…", que substitui o `refute` que travava a divergência). Risco aceito e escrito no moduledoc de `papel.ex`: para uma conta anterior à 072, a frase pode afirmar o que o registro não prova |
| **C** | 4 (período) | `periodo/2` compara `DateTime` com `<` (`papel.ex:269`), e meses diferentes viram "administrator until DD Mon", dizendo que falta a promoção registrada | não (é defeito) | **Corrigir a tela**: `DateTime.compare/2`, ou só conferir que a entrada existe (com o papel atual `member`, a última promoção é sempre anterior à última retirada). E o teste com datas em meses diferentes, visto reprovando antes da correção · **estado**: **corrigido em `8bb5e2b`** — `DateTime.compare/2`; teste "item 4: o período de quem foi administrador atravessa a virada do mês" (episódios de 28 Sep e 02 Oct inseridos com a data, porque o registro é somente-acréscimo), visto reprovando antes: "administrator until 02 Oct" |
| **D** | 10, 18 | o painel do papel e os formulários de desativar/reativar abrem em lugares diferentes; "Administrator changes" ficou entre a tabela e os formulários de hoje | não | **Corrigir a tela**: renderizar `<Papel.mudancas>` depois dos dois formulários (`index.ex:953` para depois de `:961`), e os três painéis voltam a abrir logo abaixo da tabela, como na `development`. Teste de ordem · **estado**: **corrigido em `8bb5e2b`** — `<Papel.mudancas>` depois dos dois formulários; teste "item 10: os três painéis abrem antes de Administrator changes" (posição no HTML de `</table>`, do painel e de `#mudancas-de-papel`, para o painel do papel, desativar e reativar) |
| **P** | 13, 14, 19, 20, 29 (e a frase omitida de 17 e 29) | pronome "her/his/she/he" trocado por "their/they", "made her one" por "made the change"; primeiro nome por nome completo | **não** — razão escrita em `papel.ex:19-20`, nenhuma Q cobre | **Levar ao Product Owner, para o Design republicar**: (a) aceitar a forma neutra, e o Design republica as telas 2, 3 e 6 com as frases como estão no código; (b) a tela passa a ter o pronome de cada conta (dado novo, feature própria). **Recomendação: (a)** — a tela não tem o dado, e inventá-lo seria pior; é republicação, não mudança de código · **estado**: **decidido pela pessoa mantenedora em 2026-10-03: (a) a forma neutra é aceita**; o código fica como está. **Pendência do Design** (não bloqueia a T012): republicar as telas 2, 3 e 6 com as frases do código |
| **E** | 17 | falta "…row and 'Administrator changes' show it; the header now reads N active administrators." | não | **Corrigir a tela**, com a frase na forma que a decisão P fixar (ex.: "The row and “Administrator changes” show it; the header now reads 3 active administrators.") · **estado**: **corrigido em `8bb5e2b`** — "The row and “Administrator changes” show it; the header now reads N active administrators." no sucesso de promover e no de rebaixar, com a contagem depois do ato; teste "item 17: o sucesso diz onde a mudança aparece e a contagem nova" |
| **F** | 19 | "The organisation keeps 1 active administrator: Ana Example." em vez de "…: you." quando quem fica é quem está olhando | não | **Corrigir a tela**: `quantos_ficam/1` recebe o `current_user` e escreve "you" para ele · **estado**: **corrigido em `8bb5e2b`** — "you" no lugar do nome de quem age, na lista de quem fica; teste "item 19: a organização fica com quem age, e a tela diz you" |
| **G** | 27 | quem deixou o papel sai como "X removed the administrator role from X"; falta "so you are now the only one"; a mudança nomeada é a última da organização, não a causa, e leva só a hora | não | **Corrigir a tela** em dois pontos: o caso `user_id == changed_by_user_id` diz "X stepped down at HH:MM", e a mudança só é nomeada se for a que tirou o penúltimo administrador (retirada recente de outro admin ativo) — senão, omite. **Levar ao Design** o "a moment before this request": a tela só pode afirmá-lo se medir a distância, e a frase precisa ser a que a tela consegue sustentar. Teste novo para o item 27 · **estado**: **corrigido em `8bb5e2b`** (código): o painel guarda `aberto_em`, e só a mudança posterior é citada, com dia e hora; quem deixou o próprio papel "stepped down"; "so you are now the only one" quando quem tentou deixar é quem sobra; "a moment before this request" **não** é escrito. Testes "item 27: a recusa do último nomeia quem deixou o papel depois de o painel abrir" (a corrida) e "item 27: a mudança anterior à abertura do painel não é citada". A parte de texto — o protótipo diz "a moment before this request", que a tela não mede — **aguarda o Design** republicar a tela 5 com a frase que a tela sustenta |
| **H** | 31 | o sucesso de deixar o papel sai no toast `:info` (ícone de informação), e não como aviso de sucesso com ✓ | não | **Levar ao Product Owner / Design**: (a) aceitar o toast `:info` da casa como o idioma de confirmação depois de redirecionar, e o Design republica a tela 7; (b) um tipo de flash de sucesso, que muda o `flash_group` de todas as telas (fora do escopo da 072). **Recomendação: (a)**, com a republicação · **estado**: **decidido pela pessoa mantenedora em 2026-10-03: (a) o toast `:info` da casa é aceito**; o código fica como está. **Pendência do Design** (não bloqueia a T012): republicar a tela 7 |
| **I** | 34 | a célula dos atos empilha sem o nome da coluna (`data-label=""`, `<th>` vazio) | não | **Corrigir a tela**: `data-label="Actions"` e `<th><span class="sr-only">Actions</span></th>`, como o protótipo. Depois, a medida a 360 px num navegador, com captura · **estado**: **corrigido em `8bb5e2b`** — `data-label="Actions"` e `<th><span class="sr-only">Actions</span></th>`; teste "item 34: a célula dos atos tem o nome da coluna". A medida a 360 px num navegador continua por fazer (item 34, parte visual) |
| **J** | fora da régua | três textos sem protótipo: o sucesso de rebaixar (`papel.ex:49-56`), a nota longa (`index.ex:476-484`) e a recusa de promover conta desativada (`papel.ex:145-153`) | não | **Levar ao Design** para entrarem no protótipo (republicado no mesmo endereço). O sucesso de rebaixar é o que mais pesa: é o resultado do ato principal da tela 3 · **estado**: **decidido pela pessoa mantenedora em 2026-10-03: as três frases são aceitas** como estão no código. **Pendência do Design** (não bloqueia a T012): pô-las no protótipo, republicado no mesmo endereço |

**O que falta para a T012 fechar**: A, C, D, E, F, G (parte de código) e I são correção de tela
pelo Elixir/Phoenix Developer; B, H, P, J e a parte de texto de A e G são decisão do Product
Owner / pessoa mantenedora seguida de republicação pelo Design. Depois das duas coisas, esta
conferência é refeita item a item, **com o navegador**, para os itens 33 e 34 e para a captura da
tela real ao lado do protótipo que o `PROMPT.md` §4 pede ao Product Owner.

## Depois da correção — 2026-10-03

**Decisões da pessoa mantenedora em 2026-10-03** (decidido pela pessoa mantenedora):

| id | decisão |
|---|---|
| **B** | (b) voltar ao protótipo: "since the organisation was created ·" + ausência no administrador, "never an administrator" no membro. Contra a recomendação (a) da conferência |
| **P** | (a) a forma neutra é aceita |
| **H** | (a) o toast `:info` da casa é aceito para o sucesso de deixar o papel |
| **J** | as três frases fora do protótipo (sucesso de rebaixar, nota longa, promover conta desativada) são aceitas |

**Correção de código em `8bb5e2b`** (branch `feature/568-papel-de-administrador`): A (código), B, C,
D, E, F, G (código) e I. Cada uma com teste em `test/the_band_web/live/accounts_papel_test.exs`,
e os nove testes novos foram **vistos reprovando** contra o código anterior (`aa24588`) antes do
conserto — 9 falhas, cada uma pela asserção da divergência — e passando depois (`mix test` das três
suítes da tela e do domínio: 38 testes, código 0).

A frase de reserva também saiu: `papel.ex` não escreve mais `|| "no role change recorded"`; a
frase vem só da base, e, ausente, a tela mostra a chave `access.account_role.no_change_recorded`.
**Fica de fora**: a recusa do último ainda escreve à mão "Not changed: the organisation would have
no active administrator." (`papel.ex`, `ultimo_admin/3`), enquanto a base a declara em
`AccountRole.frase_ultimo_admin/0` — observação registrada, não tratada nesta correção.

**Pendências do Design**, que **não bloqueiam** a T012: republicar o protótipo com P (telas 2, 3 e 6),
H (tela 7) e J (as três frases), a linha do administrador desativado com a Q1 (b) (item 4 e
`PROMPT.md` §3), e a frase da recusa depois de corrida sem "a moment before this request" (tela 5).

**Confirmação**: depois das decisões e da correção, **não há divergência sem decisão** na T012. O
que resta é a republicação pelo Design e a nova conferência com navegador (itens 33 e 34, parte
visual, e a captura da tela real ao lado do protótipo).
