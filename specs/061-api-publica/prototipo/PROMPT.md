# O prompt do design — a tela de tokens de API (061)

Registro fiel do que produziu o protótipo [`api-tokens.html`](api-tokens.html), publicado em
`https://claude.ai/artifact/N2Ranqy14hQmgKUP1iq9vA` em **2026-09-18**.
**A implementação reproduz exatamente esta tela** — seções, ordem, textos, marcas, ações e
recusas. Mudança no protótipo é mudança de spec, e passa por aqui: republicação **no mesmo
endereço**, com a mudança registrada no `README.md`.

**A cópia que vale é a deste diretório.** O endereço publicado pode mudar; a spec não pode
depender dele.

---

## 1. Os pedidos, textuais e em ordem

**2026-09-08** — a pessoa mantenedora, abrindo a 061 (`spec.md`, campo *Input*):

> "Faça uma especificação de adicionar no The Band a funcionalidade de ser consumido via API.
> Para consumir a API o cliente precisa de um token que será gerado na área administrativa. A
> API precisa de ter Swagger."

**2026-09-09** — as oito perguntas respondidas (`spec.md`, seção *As oito perguntas,
respondidas*). Três mudam esta tela:

> **Q2** — *"Decidido: à conta, com o tenant amarrado na linha — e nenhum veredito dentro dele."*
> O que o token alcança é recomputado a cada requisição. *"O custo aceito é o que a recomendação
> original já dizia: o alcance da integração muda quando a pessoa muda de equipe, e a tela tem de
> tornar isso visível (FR-047)."*
>
> **Q6** — *"Decidido: campo, no primeiro corte, com a lacuna declarada: não haverá auditoria do
> que foi consultado, só de quando o token foi usado por último."*
>
> **Q8** — *"Decidido: tem, e vai para a base de conhecimento."* Validade máxima
> `api.access.token_lifetime` = 90 dias; expiração por desuso `api.access.token_idle_expiry` = 30
> dias; aviso de vencimento `api.access.token_expiry_warning` = 14 dias antes, *"com 'vence em N
> dias' — nunca só a data"*.

**2026-09-16** — `plan.md`, seção *A ordem da fatia — o protótipo primeiro*, e `tasks.md`, T001:

> *"a tela de tokens tem quatro momentos que só se decidem vendo, e errar qualquer um deles é
> erro de segurança, não de estética."*

**2026-09-18** — o pedido ao papel de Design, textual, resumido em cinco pontos:

1. Desenhar o protótipo da tela de tokens de API (T001 da 061), que **bloqueia todas as tarefas
   de tela da fatia 1**. A tela vive em `/api-tokens`, na área administrativa, sob o mesmo
   `require_admin` de `/accounts` e `/access-scopes`.
2. **Os quatro momentos que só se decidem vendo** — e errar qualquer um é erro de segurança:
   (i) **o valor em claro, uma vez só** (FR-006, FR-048), com aviso de que não volta, ação de
   copiar e instrução de guardar em gerenciador de segredo — *"desenhe o que a pessoa vê no
   instante seguinte ao clique, e o que ela vê se recarregar por engano"*; (ii) **a linha
   mascarada** (FR-007), que precisa distinguir dois tokens da mesma conta sem revelar nada;
   (iii) **o alcance vigente da conta dona** (FR-047), visível **antes** de ser reclamado —
   *"quem gera o token precisa ver isso na hora de gerar, não quando o painel de terceiro
   esvaziar"*; (iv) **a confirmação de revogação nomeando o rótulo** (FR-049) — *"revogar o token
   errado interrompe a integração de um terceiro que não está na sala"*.
3. **O que a lista mostra, por token** (FR-046): rótulo, a máscara, quem criou, quando, **último
   uso ou "nunca usado"**, **expiração ou "sem expiração"**, e o estado — ativo, revogado,
   expirado. *"Último uso nulo é 'nunca usado', e **nunca** a data de criação; expiração nula é
   'sem expiração', e **nunca** uma data vazia."*
4. **Regras da casa que a tela toca de frente**: ausência escrita nunca zero; **revogação marca,
   nunca apaga** — a linha revogada continua na lista, com data e quem revogou, e **não existe
   ação de reativar**; as duas afirmações lado a lado, nunca somadas; o design system existente
   (verdete, serif/grotesk/mono, marcas observado/declarado/derivado/ausente). **Dado real** do
   banco de desenvolvimento para nomes de conta e de organização, em vez de inventar.
5. **O que não entra, e a tela deixa claro por quê se alguém esperar**: autoatendimento (só
   administração gera), edição de token depois de criado, e qualquer coisa que mostre **o que** a
   integração consultou — *"Q6 decidiu campo e não série, e essa lacuna é declarada"*.

---

## 2. O brief de design que o agente seguiu

- **Nenhuma matiz nova, nenhuma forma nova.** Os tokens são os de `DESIGN.md` e do último
  protótipo aprovado (`specs/066-pronto-declarado/prototipo/board-declarations.html`):
  papel/tinta, verdete para observado, `info` para declarado, âmbar para derivado, clay para
  recusa e gravidade. As marcas mantêm forma **e** texto: `observed` (verdete cheio), `declared`
  (azul cheio), `derived` (âmbar hachurado), `absent` (tracejado), `revoked` (cinza cheio), e
  `refused` (clay hachurado) para a recusa que não é estado do token.
- **A ramp de dez passos**, as três vozes (grotesca escaneia, serifa lê, mono compara),
  `tabular-nums` em toda contagem e em toda data, plano por doutrina, **sem borda de acento**.
- **Inglês na tela**, como todo o produto — com uma exceção deliberada: **o rótulo do token é a
  palavra de quem o criou** (*painel do diretor*, *planilha do RH*) e nunca é traduzido, pela mesma
  razão que os nomes de estágio ficam em português na 066.
- **Mostrado em repouso**: o formulário de criação aparece aberto, o painel do valor em claro
  aparece aberto, e a confirmação de revogação aparece aberta. Nada depende de clique para ser
  lido, e não há uma linha de JavaScript.
- **Quatro faixas numa página**: `screen 1 · the list at rest`, `screen 2 · the value, shown
  once`, `screen 3 · revoking, with the label named`, `screen 4 · what this screen refuses, and
  why`, mais `decisions and open questions`.
- **Dado real do banco de desenvolvimento**, lido em **2026-09-18** (ver `README.md`): tenant
  *The Band Solution*; contas `admin@the-band-solution.example` e
  `consulta@the-band-solution.example`; equipes *IA*, *PLATAFORMA*, *LEDS - ConectaFapes* e as
  demais; projetos *ConectaFapes* e *Valida*; o vínculo real equipe *IA* → os dois projetos. O que
  é invenção — os tokens, seus rótulos, instantes e a conta `ana.vieira@…` — leva a marca
  `example`, porque a tabela `api_access_tokens` **ainda não existe**.

---

## 3. A estrutura aprovada, seção por seção — a régua do QA

**É contra esta seção que o QA confere, item a item: existe, na ordem, com o texto, com a marca,
com a ação e com a recusa.** Divergência é defeito, não "melhoria de implementação". Cada item
abaixo separa aprovado de reprovado por algo observável na tela entregue ou no HTML servido.

> **Revisada em 2026-09-23**, depois de o protótipo ser republicado no mesmo endereço e
> **aprovado com três mudanças**: *sem expiração* passa a ser oferecido, revogar grava o
> motivo, e a linha abre um painel de uso. A régua foi de **60 para 70 itens**. Entram
> `R2.20`–`R2.25` (o painel), `R4.11`–`R4.13` (o motivo) e `R5.6` (a recusa que deixou de ser
> recusa); `R1.2`, `R1.3`, `R2.19`, `R5.1` e `R6.5` foram reescritos. **Nenhum item saiu, e
> `R2.1` continua em oito colunas** — o uso vive num painel, nunca numa nona coluna.
>
> O aviso por e-mail da Q6 foi **adiado na mesma decisão**, e por isso não gera item nenhum
> aqui. O que a tela faz continua sendo `R2.12`, e o alcance dele é esta tela e nada mais —
> declarado em `api.access.token_expiry_warning` e em
> [`docs/backlog/aviso-de-vencimento-do-token.md`](../../../docs/backlog/aviso-de-vencimento-do-token.md).

### 3.0 Onde a tela vive

| # | o item | aprovado quando | reprovado quando |
|---|---|---|---|
| **R0.1** | rota `/api-tokens` dentro do escopo `require_admin` do `router.ex`, na `live_session :admin` | a rota está no mesmo bloco de `/accounts` e `/access-scopes` | está em qualquer outro bloco, ou tem guarda própria |
| **R0.2** | entrada no menu *Settings*, grupo **Contas**, depois de *Accounts* e *Access scopes*, com o texto **API tokens** | o item aparece para conta com `role == "admin"` e **não** aparece para as demais | não há item de menu, ou ele aparece para conta comum |
| **R0.3** | título da tela `API tokens` (`h2`) e o parágrafo que diz que o token **não carrega permissão própria** e que o alcance é lido **a cada chamada** | as duas afirmações estão no texto | o texto diz só "gerencie seus tokens" |

### 3.1 `screen 1 · the list at rest` — o formulário de criação

| # | o item | aprovado quando | reprovado quando |
|---|---|---|---|
| **R1.1** | cartão **New token** com três campos, nesta ordem: **Label** (obrigatório), **Owner account** (select de contas do tenant), **Expires in** (select), e o botão primário **Create token** | os três campos e o botão existem, nessa ordem | falta um campo, a ordem muda, ou o rótulo não é obrigatório |
| **R1.2** | o select de expiração oferece **quatro** opções, nesta ordem: **90 days — suggested**, **30 days**, **7 days**, **no expiration** | as quatro existem, 90 dias é a primeira e vem rotulada *suggested*, e *no expiration* é a última | falta *no expiration*; ou ela vem primeira; ou 90 dias ainda se diz *the declared maximum*, que a decisão de 2026-09-23 desfez |
| **R1.3** | caixa âmbar **"«No expiration» is offered, and it is a choice with a cost"**, citando `api.access.token_lifetime`, com a consequência escrita e a reversão datada | a caixa traz as três partes: sai de circulação **só por revogação deliberada** e nada anuncia que existe; o alcance é o da **conta dona**, relido a cada chamada, e conta desativada tem toda chamada recusada; e a linha *reverted on 23 Sep 2026* com a regra anterior citada | a opção está no select sem caixa nenhuma; ou a caixa mostra a consequência sem a reversão datada; ou ainda diz que "sem expiração" não é oferecido |
| **R1.4** | **o alcance da conta dona aparece dentro do formulário**, abaixo do select de conta, como *what this token will see today*, com a marca `derived` | o bloco existe, nomeia pessoa/equipes/projetos da conta selecionada e diz *no granted scope* quando não há concessão | o alcance só aparece na lista, ou não aparece antes de criar |
| **R1.5** | o mesmo bloco diz que **este é o alcance de hoje, não do token**, e as duas consequências: sair da equipe devolve menos; conta desativada faz toda chamada ser recusada | as duas frases estão lá | o bloco mostra o alcance sem dizer que ele muda sozinho |
| **R1.6** | linha final do cartão: o que a plataforma **guarda** (rótulo, hash, quatro últimos, autor, instante, expiração) e que **não guarda o valor** | a frase existe, com "does not store the value" | a frase não distingue o que é guardado do que não é |

### 3.2 `screen 1` — a lista

| # | o item | aprovado quando | reprovado quando |
|---|---|---|---|
| **R2.1** | as **oito colunas**, nesta ordem: `label` · `token` · `owner account · what it sees today` · `created` · `last used` · `expires` · `state` · ação | as oito existem, na ordem | falta qualquer uma, ou a ordem difere |
| **R2.2** | **a máscara** é `••••••••••••••••` — **dezesseis** — seguida dos **quatro últimos caracteres**, em mono | contar os bullets dá 16, e os quatro caracteres seguem colados | são quatro bullets (o `masked/1` da casa), ou a quantidade varia com o comprimento do valor |
| **R2.3** | dois tokens da mesma conta se distinguem **pelo rótulo e pelos quatro últimos** — e as linhas 1 e 2 da lista provam isso (mesma conta dona, quatro últimos diferentes) | há duas linhas com a mesma conta dona e caudas distintas | as duas linhas são indistinguíveis sem revelar algo |
| **R2.4** | a célula de alcance traz **duas linhas por origem**, `derived` e `granted`, **nunca somadas num total** | as duas marcas aparecem separadas; quando não há concessão, a segunda linha escreve a ausência | há um número único ("3 scopes") ou a concessão some quando é zero |
| **R2.5** | conta sem elo de pessoa escreve **"sees nothing today — no person declared for this account"** e diz o que a API faz: chamada **aceita**, coleção **vazia** | a frase está na linha, com as duas partes | a célula fica vazia, mostra "—", ou diz "sem permissão" |
| **R2.6** | a linha da conta administradora escreve **"administering is not seeing"** quando ela não tem elo nem concessão | a frase está lá | a tela sugere que administrar concede visão |
| **R2.7** | `created` traz **quem** e **quando** | os dois | traz só a data |
| **R2.8** | `last used` nulo escreve **"never used"** com a marca `absent` | o texto é exatamente *never used* | a célula mostra a data de criação, um traço, um vazio ou "0" |
| **R2.9** | `last used` presente traz data **e hora** com a marca `observed` | os dois, com a marca | traz só a data, ou sem marca |
| **R2.10** | `expires` nulo escreve **"no expiration"** com a marca `absent` | o texto é exatamente *no expiration* | célula vazia, traço, ou data inventada |
| **R2.11** | `expires` presente traz a data **e** a distância — *"in 84 days"*, *"15 days ago"* | os dois | traz só a data |
| **R2.12** | dentro de 14 dias do vencimento, a célula diz **"expires in N days"** em âmbar (ver Q5) | o texto traz o N e a cor âmbar acompanha texto, nunca sozinha | só a data, ou só a cor |
| **R2.13** | o estado é um dos três — `active`, `expired`, `revoked` — e **carrega a proveniência**: `active`/`expired` com marca **derivada** (hachura), `revoked` com marca **cinza cheia** mais `declared` | as três formas conferem | todo estado usa a mesma marca, ou o estado vira coluna do banco |
| **R2.14** | a linha `revoked` traz **instante e autor** da revogação | os dois, na célula de estado | traz só "revoked" |
| **R2.15** | **não existe botão de reativar em lugar nenhum** — a linha revogada mostra *"no way back"* | `grep` no HTML renderizado não acha reactivate/unrevoke/restore | há qualquer ação que devolva um token revogado |
| **R2.16** | a linha revogada e a expirada **continuam na lista** por padrão, e o filtro diz *"revoked and expired are never hidden"* | as duas linhas estão visíveis sem filtro | a lista esconde revogado/expirado por padrão |
| **R2.17** | token de conta desativada mostra **duas marcas na mesma célula** — `active` e `calls refused` — com a frase de que uma não resume a outra | as duas marcas e a frase | a célula mostra só "active", ou só "refused" |
| **R2.18** | o segmentado de contagens (`all` · `active` · `expired` · `revoked`) e a nota de que **as contagens não se somam** ("um dos quatro ativos é recusado hoje") | contagens e nota | uma contagem só, ou um total que mistura as populações |
| **R2.19** | caixa **"the gap this list used to declare, and no longer has"**: o que cada integração leu **é** registrado desde 2026-09-23 — credencial, rota, alvo e instante —, o **corpo** da resposta não é, e o registro é guardado **indefinidamente** (`api.access.access_log_retention`) | as três partes: o que passou a ser gravado, o que continua não sendo, e a retenção sem prazo | a caixa ainda declara a lacuna que foi fechada; ou anuncia o registro sem dizer que o corpo fica de fora; ou omite a retenção |
| **R2.20** | **clicar na linha abre um painel de uso** — e `R2.1` continua com **oito** colunas | o painel abre a partir da linha, e a tabela tem oito colunas | o uso virou nona coluna; ou o painel é outra tela, que troca o contexto de quem investiga |
| **R2.21** | o painel traz a **janela escolhida e mostrada** — `last 24 h` · `last 7 days` · `last 30 days` —, com a frase de que contagem sem janela é número sem denominador | o segmentado existe, a janela ativa está visível no painel, e a frase está lá | há contagem sem janela dita; ou a janela é fixa e não aparece |
| **R2.22** | o painel conta **por rota, nunca um total** — `route` · `reads` · `last one`, com a marca `observed` na última leitura | as três colunas, e nenhum total somando as rotas | há um número único de leituras; ou a última leitura vem sem marca de proveniência |
| **R2.23** | caixa **"what this panel does not show, and why"**, com as duas: **não é o que foi lido** (rota e alvo, nunca o corpo — segunda cópia do dado, com a mesma sensibilidade e sem o veredito na frente) e **não é chamada recusada** (recusa já está no log interno, com o motivo) | as duas, cada uma com a razão | o painel mostra corpo de resposta; ou mistura aceita e recusada na mesma contagem; ou a caixa não existe |
| **R2.24** | caixa **"why this panel exists"**: quatro chamadas que respeitam o veredito podem, juntas, responder o que nenhuma responderia sozinha — **o veredito não enxerga acumulação; este painel enxerga** | a frase está lá, ligando o painel ao risco de agregação (FR-024) | o painel aparece como conveniência, sem a razão que o motiva |
| **R2.25** | caixa cor de barro: **o painel é, ele mesmo, registro sobre pessoas** — mostra que a credencial de alguém leu o painel de outra pessoa, quando e quantas vezes, guardado **indefinidamente**, e quem abre passa por `require_admin` | as três partes: o que o painel revela, a retenção sem prazo com a data da decisão, e a porta | o painel existe sem essa declaração; ou a porta fica implícita |

### 3.3 `screen 2 · the value, shown once`

| # | o item | aprovado quando | reprovado quando |
|---|---|---|---|
| **R3.1** | logo após criar, um painel **Token created · <rótulo>** com o rótulo do token criado e a etiqueta **shown only now** | o painel aparece com o rótulo exato | o valor aparece numa mensagem genérica sem o rótulo |
| **R3.2** | o **valor em claro** em mono, em tamanho legível, quebrando em telas estreitas e selecionável inteiro | o valor aparece uma vez, e só nesse painel | aparece em dois lugares, ou fica cortado |
| **R3.3** | ação **Copy value** | o botão existe e copia o valor | não há ação de copiar |
| **R3.4** | bloco **do this now**: guardar em **gerenciador de segredo** ou no ambiente do deploy, e entregar pelo canal por onde se entrega uma senha | a instrução nomeia o gerenciador de segredo | diz só "guarde em lugar seguro" |
| **R3.5** | bloco **it will not come back**: sair da tela apaga o valor; a plataforma guardou hash e quatro últimos; **não há tela, exportação, endpoint nem pedido de suporte** que o recupere; o caminho é revogar e criar outro | as quatro afirmações | falta o caminho de volta, ou o aviso é uma frase vaga |
| **R3.6** | as **três partes do valor** anotadas — prefixo público, id público, segredo — cada uma com o que faz | as três caixas | o valor aparece sem explicação das partes |
| **R3.7** | exemplo de chamada com `Authorization: Bearer` lendo de **variável de ambiente**, e a frase de que query string cai em log de proxy e histórico de navegador | o exemplo usa `$TB_API_TOKEN` e a frase está lá | o exemplo tem o token literal, ou mostra o token em query string |
| **R3.8** | **o que se vê ao recarregar**: o painel **não volta** — nem por recarga, nem por navegação, nem pelo voltar do navegador | recarregar a tela não mostra o valor em lugar nenhum | o valor sobrevive a `handle_params`, a um patch, ou volta pelo histórico |
| **R3.9** | no lugar dele, **uma linha quieta** dizendo que o token foi criado há N minutos, que o valor foi mostrado uma vez e **não pode ser mostrado de novo**, com o caminho: revogar e criar outro | a linha existe com as três partes | a tela volta em branco, ou finge que o valor está em algum lugar |
| **R3.10** | **SC-013**: o HTML renderizado depois da recarga tem **0** ocorrências do valor e **0** do hash | a varredura no HTML servido não acha nenhum dos dois | qualquer ocorrência, inclusive em atributo, em `data-*`, em comentário ou no socket |
| **R3.11** | a linha recém-criada na lista mostra a máscara, `never used` e a expiração calculada | os três | a linha mostra o valor, ou "último uso = data de criação" |

### 3.4 `screen 3 · revoking, with the label named`

| # | o item | aprovado quando | reprovado quando |
|---|---|---|---|
| **R4.1** | a confirmação traz **o rótulo exato do token** no título | o título é `Revoke “<rótulo>”?` com o rótulo daquela linha | a confirmação diz "revogar este token?" |
| **R4.2** | **o botão de confirmar também nomeia o rótulo** | o botão lê `Revoke “<rótulo>”` | o botão lê só "Revoke", "OK" ou "Confirm" |
| **R4.3** | a confirmação identifica o token pela **máscara**, pela **conta dona** e pela **data de criação** | os três | identifica só pelo rótulo (dois tokens podem ter rótulos parecidos) |
| **R4.4** | a confirmação traz **quando o token foi aceito pela última vez** — *"last accepted call 14 minutes ago"* — e a frase de que algo está chamando com ele | os dois; quando nunca foi usado, escreve *never used* | o dado não aparece, e quem confirma não sabe se quebra algo vivo |
| **R4.5** | bloco **what it does**: a próxima chamada é recusada **imediatamente**, sem cache e sem atraso; a linha **fica** na lista, marcada, com instante e autor | as duas partes | promete "em alguns minutos", ou não diz que a linha fica |
| **R4.6** | bloco **what it does not do**: não apaga nada, não afeta os outros tokens da mesma conta, **não pode ser desfeito**, não há reativar, e o caminho é criar outro | as cinco negativas | falta a irreversibilidade, ou sugere pausa |
| **R4.7** | bloco **what the client sees**: o mesmo `401` de um token que nunca existiu, e o motivo real fica no log interno, pelo id da requisição | as duas partes | a tela promete mensagem específica ao cliente |
| **R4.8** | ação de **Cancel** ao lado, sem consequência | existe | só há o botão de confirmar |
| **R4.9** | depois de confirmar, **a mesma quantidade de linhas** na lista, uma delas marcada revogada com instante e autor | a contagem `all` não muda; `active` cai 1 e `revoked` sobe 1 | a linha some, ou a contagem total cai |
| **R4.10** | a ação de revogar **não aparece ativa** numa linha já expirada ou já revogada — e a razão fica visível | botão inerte com a razão, ou o texto *no way back* | o botão some sem explicação, ou funciona de novo e reescreve o autor |
| **R4.11** | a confirmação traz **o motivo**: um select de **quatro cláusulas**, lista fechada — *integration ended* · *suspected leak* · *replaced by another token* · *other* —, mais um campo de **nota livre, opcional** | as quatro opções, nessa ordem, e a nota ao lado marcada *optional* | o motivo é só texto livre; ou a lista tem outras cláusulas; ou a nota é obrigatória |
| **R4.12** | a razão do campo está escrita: a cláusula que o justifica é **suspected leak**, o único caso em que o próximo ato muda — **girar tudo o que aquela conta alcança**, não só substituir a integração; e a lista é fechada para que *"quantas revogações foram por vazamento neste trimestre?"* seja contagem e não leitura de texto livre | as duas frases | o campo aparece sem razão nenhuma, e vira burocracia que alguém preenche por hábito |
| **R4.13** | a linha revogada mostra **a cláusula e a nota** junto do instante e do autor (`R2.14`), e a tela diz que até 2026-09-23 gravava só quem e quando — **omissão, não decisão** | a célula de estado traz os quatro: instante, autor, cláusula, nota | a cláusula fica só no banco e não volta à tela; ou a nota some |

### 3.5 `screen 4 · what this screen refuses, and why`

| # | o item | aprovado quando | reprovado quando |
|---|---|---|---|
| **R5.1** | **seis cartões**, cada um escrito como o que a pessoa esperaria encontrar: autoatendimento · editar/estender · **ver o que a integração leu (já não é recusa — ver `R5.6`)** · reativar · dar escopo ao token · rever o valor | os seis existem, cada um com a expectativa e a resposta, e **cinco** deles são recusa | falta qualquer um; ou a tela só omite o controle; ou o terceiro cartão continua escrito como recusa |
| **R5.2** | a recusa do autoatendimento diz que **só administração gera**, e que é decisão posterior, não botão faltando | as duas partes | diz apenas "não disponível" |
| **R5.3** | a recusa de escopo próprio diz que **acesso se concede à conta**, em `/access-scopes`, e que escopo no token seria uma segunda verdade que **envelhece no bolso de quem saiu** | as duas partes | a tela oferece editar escopo do token |
| **R5.4** | a recusa de rever o valor diz que a guarda é **hash de mão única**, não cópia cifrada, **porque a plataforma nunca precisa do valor de volta** | a frase com a razão | diz só "não é possível" |
| **R5.5** | **a recusa de quem não administra**: a tela nega com **motivo nomeado** e caminho — pedir a quem administra | motivo e caminho no texto | página em branco, 404 mudo, ou redirecionamento silencioso |
| **R5.6** | o cartão *"Show me what this integration read"* está marcado **`now answered`** em verdete, diz o que ele afirmava antes (*"only when, never what"*), **quando deixou de ser verdade** (2026-09-23, com o registro de leitura da v0.9.0) e que o corpo da resposta continua fora | as quatro partes, e a marca `observed` no título | o cartão foi **apagado** — apagar a recusa apaga que ela existiu, e a tela deixa de ensinar que a lacuna foi fechada; ou continua escrito como recusa, afirmando o que já não é verdade |

### 3.6 O que vale em toda a tela

| # | o item | aprovado quando | reprovado quando |
|---|---|---|---|
| **R6.1** | **nenhuma ausência como zero, traço ou célula vazia** | toda ausência tem texto e dono | existe qualquer `—`, `0` ou vazio no lugar de uma ausência |
| **R6.2** | **cor nunca é canal único**: toda marca tem forma (cheio/hachurado/tracejado) **e** texto | remover a cor mantém a informação | um estado se distingue só por cor |
| **R6.3** | **inglês na tela**; o rótulo do token é a palavra de quem criou e não é traduzido | as frases do produto em inglês, rótulos preservados | português na interface, ou rótulo traduzido |
| **R6.4** | `tabular-nums` em datas e contagens; tabela `stacked` com `data-label` abaixo de 52rem | as colunas alinham e a tela estreita vira cartão | rolagem horizontal do corpo da página |
| **R6.5** | **nenhum número nem vocabulário no código**: 90/30/14 dias vêm de `api.access.thresholds`; as quatro cláusulas de revogação vêm de `api.access.token_revocation_reason`; a retenção do registro de uso vem de `api.access.access_log_retention` | `grep` por `90`/`14` no módulo da tela e da fronteira não acha o prazo, e as cláusulas não são literais de módulo | qualquer prazo como constante; ou as cláusulas escritas à mão na tela, o que faz a contagem por cláusula divergir do vocabulário |
| **R6.6** | a tela **não mostra e não loga** valor nem hash em nenhuma renderização | a varredura de SC-001 dá zero nos quatro lugares | qualquer ocorrência |

---

## 4. Como cada papel usa este arquivo

| Papel | O que faz com ele |
|---|---|
| **Product Owner** | registra no item de backlog o endereço do protótipo e este `PROMPT.md`; leva as seis perguntas abertas do `README.md` à pessoa mantenedora e traz as respostas; **aceita a tela conferindo a seção 3 item a item**, com captura da tela real ao lado |
| **Elixir/Phoenix Developer** | implementa **exatamente** esta tela (T009 a T013). Quando algo daqui não for possível ou não for honesto com o dado, **volta ao protótipo** — não improvisa no LiveView |
| **QA** | confere a seção 3, linha a linha, contra a tela entregue. Divergência é defeito, não melhoria |
| **Design** | republica **no mesmo endereço** quando uma decisão muda a tela, e registra a mudança no `README.md` |
