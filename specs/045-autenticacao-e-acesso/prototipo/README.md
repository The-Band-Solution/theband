# O protótipo da conta desativada

[`accounts-disable.html`](accounts-disable.html) — abrir no navegador. Duas telas numa página só,
separadas pelas faixas `screen 1 · accounts` e `screen 2 · what the disabled person sees`. Tudo
visível ao carregar: os formulários de desativar e de reativar aparecem **abertos**, e o de
desativar aparece duas vezes, para que a lista que a razão *suspected compromise* acrescenta
fique na página.

Desenhado em **2026-09-10**, a partir do pedido da pessoa mantenedora do mesmo dia. Publicado em
`https://claude.ai/code/artifact/3384028c-f1de-4139-8dd5-c600d5ec9a62`; **a cópia aqui é a que
vale** — o endereço publicado pode mudar, a spec não pode depender dele. Mesmo vocabulário visual
do protótipo aprovado da 060 (`specs/060-tela-da-equipe/prototipo/`).

A estrutura seção a seção — **que é a régua do QA** — está na seção 3 do
[`PROMPT.md`](PROMPT.md).

## Por que este protótipo existe, e o que ele não é

O papel de Product Owner **recusou** o entregável **D06** ao avaliar a v0.7.0
(`docs/releases/v0.7.0.md`), e uma das três coisas que sozinhas já impediriam a aceitação é
desta casa:

> **A tela mudou sem protótipo aprovado.** O próprio item de backlog tem uma seção intitulada
> *"Tem tela, logo tem protótipo"* […] **Não existe `specs/045-autenticacao-e-acesso/prototipo/`.**
> A régua da aceitação de tela desta casa é a seção *estrutura aprovada* do `PROMPT.md`, e aqui
> não há `PROMPT.md`. Sem régua não há conferência, e "ajustou na implementação" é recusa.

**O código já está em produção**, entregue na v0.7.0 com a recusa declarada. Este protótipo **não
autoriza o que existe**: ele diz o que deve existir. A diferença entre os dois está na tabela
*Where the screen shipped in v0.7.0 differs from this prototype*, no fim da página — dez linhas,
cada uma um defeito a corrigir.

**Estado**: desenhado e publicado; **aguarda a aprovação da pessoa mantenedora**. As onze
decisões abaixo foram tomadas por este papel porque o pedido mandou decidi-las com a razão
escrita; as quatro perguntas abertas são do Product Owner para levar, e este papel marca
*Decided* e republica quando a resposta vier.

## As decisões, e a razão de cada uma (2026-09-10)

| # | decisão | a razão |
|---|---|---|
| **1** | **A razão ao desativar é lista fechada *e* nota.** Cinco cláusulas — `left_the_organisation`, `access_no_longer_needed`, `duplicate_account`, `suspected_compromise`, `other` — mais texto livre | as duas fazem trabalhos diferentes. A cláusula é o que a **plataforma lê**: *suspeita de comprometimento* muda o que a tela mostra em seguida, e é a pergunta que um incidente faz **por contagem** — texto livre não se conta nem se roteia. A nota é o que a **pessoa escreve**: uma cláusula sozinha se repete idêntica para quarenta pessoas sem dizer quem decidiu nem sobre o quê. A casa tem precedente nos dois lados, e aqui os dois cabem porque não competem |
| **2** | **A nota é obrigatória para `suspected_compromise` e `other`; opcional nas outras três** | obrigatória em toda parte produz `asdf`, que é pior que ausência porque **parece registro**. `other` não significa nada sem ela; `suspected_compromise` é a única em que quem lê depois tem de agir. Onde é omitida, o registro escreve *no note* — ausência dita, nunca campo em branco |
| **3** | **Reativar exige ator e razão, e não apaga a desativação.** Quatro cláusulas: `returned_to_the_organisation`, `disabled_by_mistake`, `investigation_closed_no_compromise` (só contra desativação por suspeita), `other` | reativar é o **mais sensível dos dois atos** — acrescenta alguém ao conjunto de quem lê a organização — e hoje é o que tem menos registro. A desativação passa a ser **episódio**: aberto com autor, instante e razão; fechado com autor, instante e razão. O estado da conta é **derivado** de "há episódio aberto?", e a linha mostra as duas metades |
| **4** | **Duas colunas, e não uma célula com precedência.** `Account` e `Sign-in credential` | são dois fatos. A tela em produção põe `desativada` **primeiro dentro da célula da senha**, o que é precedência e não separação: o fato da credencial **desaparece** quando a conta é desativada, e é exatamente o fato de que se precisa no dia em que alguém pede a conta de volta. Uma célula para dois fatos é a forma que fez um desligamento parecer um primeiro dia |
| **5** | **As duas temporárias se distinguem em palavras**: `temporary · from creation · never signed in` contra `temporary · from a reset · last signed in 2 Sep` | separar a coluna da conta resolve metade do achado; isto resolve a outra metade. As duas parecem iguais hoje e pedem atos **opostos** — entregar esta, não entregar aquela —, e os dois fatos já estão no banco (`password_set_at`, `logged_in_at`, `must_change_password`) |
| **6** | **Ação recusada aparece recusada, nunca escondida.** `Reset password` numa conta desativada e `Disable` na própria conta ficam no lugar, inertes, com a razão ao lado | botão que some é a ausência muda que a casa recusa — e aqui é pior que muda, porque quem procura conclui que **a plataforma não sabe fazer**. A recusa do reset ainda nomeia a **ordem certa**: reativar primeiro, e reativar não devolve a senha, então o reinício vem depois e não no lugar. A da própria conta nomeia `:nao_pode_desativar_a_si` **antes** de ser disparada |
| **7** | **A linha carrega o histórico**: quem desativou, quando, por quê, com a nota; quem reativou, quando, por quê; e `last signed in` | `ScopeGrant` é o precedente — *a revogação é marca com autoria, nunca delete*. `last signed in` é o que diz se havia sessão viva a cortar. Conta que nunca foi desativada escreve `no disablement recorded` |
| **8** | **O procedimento escrito fica na tela**: três cartões — *Disable account*, *Reset password*, *Revoke GitHub link* — com o que cada um faz **e o que não faz**, acima da tabela, sempre visíveis | `docs/producao/desligar-alguem.md` existe **porque** o ato que funcionava não estava escrito em lugar nenhum. Procedimento que vive só num documento é o que este achado já provou falhar: quem administra faz o que a interface oferece |
| **9** | **Desativar não toca em mais nada**: a senha não muda, o elo não é revogado, os escopos não são removidos — ficam mantidos e **inertes**, e a linha diz isso | juntar qualquer um deles num ato só é o erro que a `FR-012f` já separou, e faria a reativação **adivinhar** o que restaurar. E o roster, as medidas e o histórico da pessoa não se movem: isto é afirmação sobre entrar, não sobre o passado |
| **10** | **Conta desativada fica na mesma tabela, por último, e nunca é filtrada por omissão** | conta que não se vê é conta que não se audita, e uma segunda tela de "contas antigas" é onde o registro vai para ser esquecido. O filtro existe e começa em *all*; a contagem fica no cabeçalho |
| **11** | **Marcas: cinza cheio para `disabled`, clay hachurado para `mistake`, palavra sem badge para `active`** | **nenhuma matiz nova** — a decisão de 2026-09-08 achou nenhuma livre nesta paleta, e continua valendo. Cinza cheio é a marca da casa para *acabou, e o registro fica*, que é o que uma desativação correta é; clay é gravidade e equívoco, que é o que uma desativação por engano é; âmbar fica com a temporária pendente, onde já mora. `active` não ganha badge nenhum: é o caso comum, e badge que toda linha carrega deixa de ser sinal |

## As perguntas que ficaram abertas, para a pessoa mantenedora

| # | pergunta | opções | recomendação |
|---|---|---|---|
| **12** | **Onde o vocabulário das razões é declarado.** As nove cláusulas são vocabulário declarado, e pelo princípio IV nada vai à tela sem declaração | (a) um arquivo de regra ao lado de `team.dashboard.thresholds`, que já é decisão de tela morando na base com `provider: platform`; (b) fora de `priv/knowledge_base/`, porque aquela base é a rede SEON sobre dado de engenharia observado, e o ciclo de vida de uma conta é administração da plataforma | **(a)** — o precedente existe, o validador já é gate, e "declarado, versionado, revisável" é a propriedade que importa. Se for (b), precisa das mesmas três propriedades noutro lugar, e não de nenhuma |
| **13** | **Se a desativação pode nomear quem assumiu.** O exemplo diz *"handover to Marina done"* em texto livre | (a) deixar na nota; (b) um campo opcional apontando outra conta, para que *"quem assumiu isto"* seja consultável | **(a) por ora** — (b) é uma segunda relação a manter verdadeira, e ninguém ainda fez a pergunta que ela responde |
| **14** | **Onde aparece uma organização suspensa.** `tenants.status` existe e ninguém o lê, então o `4 can sign in today` do cabeçalho é afirmação sobre contas e não sobre a porta | (a) faixa nesta tela quando a organização não estiver ativa; (b) tela própria, por ser afirmação sobre a organização; (c) a coluna sai, se suspender organização nunca foi a intenção | **(a) e (c) decidida noutro lugar** — esta tela não pode afirmar que alguém entra quando a organização está fechada, e coluna que parece controle e não é é pior que coluna nenhuma |
| **15** | **Quanto histórico a linha mostra antes de precisar de porta.** Quatro episódios leem bem; uma conta de cinco anos com uma dúzia abriria a tabela ao meio | (a) mostrar todos, sempre; (b) o episódio aberto mais o último fechado, e um link para o resto; (c) tela própria de registro de acesso por conta | **(b)**, com a contagem sempre escrita — *"2 earlier disablements"* — para que o que não é mostrado continue sendo dito |

## O que foi decidido e implementado em 2026-09-10

A pessoa mantenedora respondeu **"pode implementar"**. As quatro perguntas abertas foram
fechadas **pelas recomendações deste documento**, e as recomendações estão registradas acima —
quem discordar de alguma discorda de uma escolha escrita, e não de uma omissão.

| # | fechada como | onde vive agora |
|---|---|---|
| **12** | **(a)** — arquivo de regra na base de conhecimento | `priv/knowledge_base/rules/access_account_lifecycle.yaml`, id `access.account_lifecycle`, `provider: platform`. Lido por `TheBand.Tenants.AccountLifecycle`, que **não tem lista nenhuma escrita dentro** |
| **13** | **(a)** — fica na nota | nenhum campo de sucessor; a recusa está registrada em `refuses:` no próprio YAML, para não ser reproposta como novidade |
| **14** | **(a)** — faixa nesta tela | `faixa_da_organizacao/1` aparece quando `tenants.status != "active"` |
| **15** | **(b)** — o aberto mais o último fechado, e a contagem do resto sempre escrita | `Tenants.historico_de_acesso/2` devolve `aberto`, `ultimo_fechado`, `anteriores` e `desligamentos`; a linha escreve *"N earlier disablements not shown here"* |

### Duas coisas que a implementação descobriu, e que corrigem este protótipo

A regra da casa é que quem implementa **volta ao protótipo** quando descobre que algo aqui não
é possível ou não é honesto com o dado. As duas voltas:

1. **`tenants.status` passou a ser lido.** Este protótipo escreveu que ele *"existe, aceita
   `"suspended"` e **não é lido em lugar nenhum**"*, medido em 9 Sep. Desde a v0.7.0
   `Auth.verificar/2` recusa a entrada quando a organização não está ativa — o H3 parte A foi
   fechado entre o desenho e a implementação. A tela **não** repete a frase antiga: diz que a
   contagem é sobre contas e que a porta também pergunta pela organização, e a faixa aparece
   quando as duas discordam. Afirmar na tela um defeito já corrigido seria o mesmo erro de
   sinal, do outro lado.

2. **`issued 9 Sep by Paulo` não tinha o Paulo, e `from creation` × `from a reset` não tinha
   como se distinguir.** `reset_password/3` recebia `actor_id` e o **descartava**, e nada no
   banco dizia de qual ato a temporária veio. Derivar de `logged_in_at` acerta na maioria e
   erra no reinício de quem nunca entrou; derivar de `password_set_at ≈ inserted_at` é
   heurística com cara de fato. Duas colunas novas gravam a proveniência **no momento em que
   se sabe**: `users.password_source` (`creation` / `reset` / `self`) e
   `users.password_set_by_user_id`.

   E disso nasceu um **quinto** estado de credencial, declarado como os outros:
   `temporary_source_not_recorded` — a temporária pendente emitida antes da coluna existir.
   Chamá-la de `from creation` seria afirmar o que ninguém registrou. Some sozinho conforme as
   contas antigas reiniciam a senha.

### O que ficou onde

| coisa | arquivo |
|---|---|
| o vocabulário (nove cláusulas, os cinco estados de credencial, os dois de conta, quem exige nota) | `priv/knowledge_base/rules/access_account_lifecycle.yaml` |
| o leitor, sem lista dentro | `lib/the_band/tenants/account_lifecycle.ex` |
| o episódio — aberto e fechado, nunca apagado | `lib/the_band/tenants/account_disablement.ex` |
| a migração: a tabela, o índice de **um aberto por conta**, o backfill com `not_recorded`, e as duas colunas da credencial | `priv/repo/migrations/20260910050000_episodio_de_desativacao.exs` |
| `disable_user/4` e `enable_user/4` — ator, razão e nota, as duas escritas numa transação | `lib/the_band/tenants.ex` |
| a tela | `lib/the_band_web/live/accounts_live/index.ex` |
| os testes, com os três defeitos reinjetados e pegos | `test/the_band/tenants/conta_desativada_test.exs` |

O **backfill não inventa razão**: cada conta hoje desativada ganha um episódio aberto com
`disable_reason = 'not_recorded'`, uma cláusula que existe no vocabulário e **não é oferecida no
formulário**. E `disabled_by_user_id` do episódio aceita nulo, porque o backfill pode não ter
autor — `COALESCE(disabled_by_user_id, user_id)` faria a plataforma afirmar que a pessoa se
desativou a si.

## Onde a tela da v0.7.0 diverge deste protótipo

Dez linhas, na tabela do fim do protótipo. São **defeitos a corrigir**, e não ajustes a adotar —
a regra da casa é que a tela implementada é exatamente a tela aprovada. As de maior peso:

1. desativar grava **quem** e **quando**, e **nenhuma razão** (recusa 1 do Product Owner);
2. `enable_user/2` recebe tenant e id — **sem ator e sem razão** (recusa 2);
3. `reativar_changeset/1` faz `disabled_at: nil, disabled_by_user_id: nil` — **a marca é
   apagada**. É um `delete` escrito como `update`, e *nada é apagado* não é preferência aqui;
4. o estado mora numa **célula só**, com `desativada` tomando a frente da credencial;
5. `Reset password` **desaparece** da linha desativada, e `Desativar` **desaparece** da própria
   linha — as duas ausências mudas;
6. o texto do *revoke* não diz que **não remove acesso** (recusa 3);
7. as duas temporárias continuam com as mesmas palavras;
8. a copy da tela está em **português** — `desativada`, `Desativar`, `Reativar`, `definida`,
   `temporária pendente`, `sem senha — a entrada recusa` —, e o produto é em inglês.

## Os nomes que a base precisa antes do código

Nenhum é medida nova sobre dado observado: são vocabulário e estado que **esta tela mostra**, e o
princípio IV pede que sejam declarados, versionados e validados do mesmo jeito. Onde eles moram é
a pergunta aberta 12.

| nome proposto | o que é |
|---|---|
| `access.account_lifecycle.disable_reasons` | as cinco cláusulas da razão de desativar, cada uma com o que significa e o que muda em seguida |
| `access.account_lifecycle.enable_reasons` | as quatro cláusulas da razão de reativar, incluindo a que só é oferecida contra uma desativação por suspeita de comprometimento |
| `access.account_lifecycle.states` | os dois estados da conta e os quatro da credencial, declarados como **vocabulários separados** — para que a colisão que esta tela existe para consertar não possa ser recriada por um template |
| `access.account_lifecycle.note_required` | quais razões exigem nota escrita, e a frase que diz por quê quando não há uma |

## Premissas que a spec carrega até serem contestadas

- **Os números do cabeçalho são reais; as linhas da tabela não são.** O banco de desenvolvimento
  medido em 2026-09-10 tem 3 contas (2 com senha definida, 1 sem senha, 0 desativadas, 0 com elo
  vigente, 2 administradoras), 2 tenants ambos `active` e 80 pessoas coletadas. E-mail de conta é
  dado pessoal: as seis linhas são fictícias, marcadas `example`, uma por estado que o desenho
  precisa exercitar.
- A desativação é **episódio com autor, instante e razão nas duas pontas**, na forma de
  `ScopeGrant`. Se a implementação escolher guardá-la em colunas da própria `users`, o histórico
  de mais de um episódio deixa de caber — e é a decisão 1 do item de backlog, que recomendava
  relator próprio e que o código de v0.7.0 tomou sozinho.
- Conta desativada **não autentica por token** continua sendo critério que **não se pode avaliar
  ainda**: o token não existe (spec 061 sem código). O protótipo escreve isso na tela em vez de o
  omitir, e a linha é promessa e não controle até lá.
- O registro de acesso **começa em 9 Sep** — antes disso não há evento nenhum (achado H4). A tela
  diz isso onde oferece o registro, em vez de mostrar lista vazia.
- Desativar a conta **não** muda o roster, as medidas nem o histórico da pessoa. É a decisão 4 do
  item de backlog, e o critério que a v0.7.0 registrou como **sem evidência**: nenhum teste
  compara medida da pessoa antes e depois. O protótipo o afirma na tela; o teste continua a
  faltar.
