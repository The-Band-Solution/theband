# O prompt do design — a conta desativada em `/accounts`

Registro fiel do que produziu o protótipo [`accounts-disable.html`](accounts-disable.html),
publicado em `https://claude.ai/code/artifact/3384028c-f1de-4139-8dd5-c600d5ec9a62` em
**2026-09-10**. **A implementação reproduz exatamente esta tela** — seções, ordem, textos,
marcas, ações e recusas. Mudança no protótipo é mudança de spec, e passa por aqui.

> **Este protótipo nasce de uma recusa, e a recusa é a razão de ele existir.** O papel de
> Product Owner **não aceitou** o entregável D06 da v0.7.0, e uma das três coisas que sozinhas
> já impediriam a aceitação é desta casa: *"a tela mudou sem protótipo aprovado"*. O código já
> está em produção. **Este protótipo não autoriza o que existe: diz o que deve existir**, e a
> diferença entre os dois é trabalho, listada na tabela *Where the screen of 9 Sep differs from
> this prototype*, no fim da página.

## 1. Os pedidos da pessoa mantenedora, textuais e em ordem

**2026-09-10** — o pedido que abriu este desenho:

1. "Desenhe o protótipo da **conta desativada** em `/accounts`."

E, no mesmo pedido, as seis coisas que este papel foi mandado **decidir com a razão escrita**:

2. "**como a razão é capturada** ao desativar: lista fechada, texto livre, ou as duas? Lista
   fechada é comparável e o texto livre é honesto — e esta casa tem precedente nos dois lados
   (o equívoco do vínculo pede razão em texto; a promoção usa vocabulário declarado)"
3. "**se reativar exige razão**, e o que ela precisa registrar"
4. "**como a tela distingue os quatro estados** de uma conta — ativa com senha, ativa com
   temporária pendente, ativa sem senha, e desativada —, sem que o desligamento se confunda com
   nenhum outro, que foi o achado"
5. "**o que acontece com `Reset password` numa conta desativada.** Hoje o botão desaparece.
   Desaparecer sem dizer por quê é a ausência muda que esta casa recusa"
6. "**como a linha mostra o histórico**: quem desativou, quando, e — se houver — quem reativou.
   `ScopeGrant` é o precedente: *'a revogação é marca com autoria, nunca delete'*"
7. "e **onde o procedimento escrito entra na tela.** `docs/producao/desligar-alguem.md` existe
   porque o gesto que funcionava não estava escrito. Um procedimento que vive só na documentação
   é o que este achado já provou não funcionar."

E as regras da casa que o pedido reafirmou: *nada é apagado*; *ausência é dita, nunca zero e
nunca botão que some sem explicação*; *recusa é estado de primeira classe, com a razão anexada*;
*matiz pertence à origem e ao estado — e a decisão de 2026-09-08 já recusou matiz nova por não
haver livre nesta paleta*; *copy em inglês*; *mostrado em repouso*.

### 1.b O achado que deu origem a tudo, e que o desenho tinha de resolver

Antes da coluna de estado existir, o desligamento era **implícito**: quem administra reiniciava
a senha e não entregava a temporária. E:

> A conta desligada aparecia como **`temporária pendente`** — **igual à recém-criada** — e o ato
> de rotina para a segunda (reiniciar a senha) **reativava** a primeira.

O estado do desligamento era indistinguível do estado de quem acabou de entrar na organização.

### 1.c As três razões da recusa do Product Owner, e as duas primeiras são de desenho

1. **falta a RAZÃO ao desativar.** O ato grava quem e quando, e não por quê. *"Saiu da
   organização"*, *"conta duplicada"* e *"suspeita de comprometimento"* levam a decisões
   diferentes de quem lê o histórico depois — e a terceira exige agir sobre mais coisas;
2. **`enable_user/2` reativa sem ator e sem razão.** Desativar registra `disabled_by_user_id`;
   reativar apaga a marca e não diz quem a apagou. **Reativar é o ato mais sensível dos dois**, e
   é o que tem menos registro;
3. o texto do *revogar elo* continua sem dizer que ele **não** remove acesso — o H3 mediu que não
   remove, e a tela oferece os dois lado a lado.

## 2. O brief de design que o agente seguiu

- **Design system existente, não inventado.** Os tokens do protótipo aprovado da 060
  (`specs/060-tela-da-equipe/prototipo/team-dashboard-structure.html`), do `assets/css/app.css`
  e do `DESIGN.md`: papel `#f7f8f7`/`#0e1413`, tinta, **verdete** `#1f6f68`/`#5cbcb2` como
  primária, `info` azul para o declarado, `amber` para derivado e aviso, `clay` para equívoco e
  gravidade; corpo em serif, títulos em grotesk, números e rótulos em mono com `tabular-nums`;
  dois temas por tokens, com `[data-theme]` e `prefers-color-scheme`. **Nenhuma família baixada**
  (a regra do `DESIGN.md`), e **nenhuma matiz nova** — a decisão de 2026-09-08 já registrou que
  não há livre nesta paleta.
- **Marcas** herdadas: `declared` (info azul cheio), `observed` (verdete cheio), `absent`
  (tracejado), `left` (cinza cheio), `mistake` (clay hachurado) — todas com o quadrado de
  0.6 rem, que é o canal da família e o que faz a distinção não depender de cor.
- **As regras da casa que a tela obedece**: nada é apagado — desativação é episódio com autor,
  data e razão, e reativar **fecha** o episódio em vez de o apagar; ausência escrita, nunca zero
  nem célula vazia (`no disablement recorded`, `no password`, `no GitHub account linked`);
  recusa como estado de primeira classe, com a razão ao lado do botão inerte; as duas afirmações
  lado a lado quando a porta e o registro dizem coisas diferentes; toda ação diz o que faz **e o
  que não faz**; copy em inglês.
- **Dado**: as contagens vêm do banco de desenvolvimento medido em **2026-09-10** — 3 contas, 2
  com senha definida, 1 sem senha, 0 desativadas, 0 com elo vigente, 2 administradoras, 2 tenants
  (`The Band Solution` e `Outra Organização`, ambos `active`), 80 pessoas coletadas. **Nenhuma
  linha da tabela usa dado real**: os e-mails de conta são dado pessoal, e as seis linhas são
  fictícias e marcadas `example`, uma por estado que o desenho precisa exercitar.
- **Mostrado em repouso**: nada depende de clique. As duas telas ficam empilhadas numa página só
  (`/accounts` não tem abas, e o protótipo não inventa nenhuma); os dois formulários — desativar
  e reativar — aparecem **abertos**, e o de desativar aparece **duas vezes**, com o segundo
  estado mostrando a lista que a razão *suspected compromise* acrescenta.

## 3. A estrutura aprovada, seção por seção

**É contra esta seção que o QA confere, item a item: existe, na ordem, com o texto, com a marca,
com a ação e com a recusa.**

### Cabeçalho

Migalha `Settings › Accounts`; `h1` **Accounts**; a linha de identidade com duas marcas —
`everything here is declared by the administration` (info, cheio) e `the GitHub login comes from
collection` (verdete, cheio) — e a **composição**: `6 accounts · 4 can sign in today · 1 disabled
· 1 has no password`. Parágrafo dizendo que não há auto-registro, que a conta se cria e se
desativa aqui, e **de onde vêm os números**: o banco de desenvolvimento de 10 Sep tem 3 contas, e
as linhas abaixo são `example` porque cada estado precisa de uma.

### `screen 1 · accounts`

1. **Nota da tela** (caixa verdete) — o achado escrito: o desligamento implícito, a conta
   desligada lendo `temporary pending` igual à criada ontem, o reinício de rotina trazendo a
   primeira de volta. E as três coisas que decorrem dele e sustentam a tela: **duas colunas para
   dois fatos**; **todo ato diz o que faz e o que não faz**; **nada é apagado**.

2. **Removing someone's access** — o procedimento **na tela**. Três cartões lado a lado, cada um
   com `what it does` e `what it does not do`:
   - **Disable account** (borda superior clay): para de entrar por senha hoje e por token quando
     houver; a sessão aberta cai na ação seguinte; a linha fica com quem, quando e por quê.
     *Não* apaga nada, *não* tira a pessoa do roster nem de medida nenhuma, *não* muda a senha;
   - **Reset password**: emite temporária nova, mostrada uma vez, e derruba as sessões. *Não é
     desligamento* — a conta continua podendo entrar, e o próximo reinício a devolve; não
     entregar a temporária é hábito, não controle;
   - **Revoke GitHub link**: a conta deixa de ser aquela pessoa observada, o painel dela fecha, a
     entrada por username do GitHub para. ***Não remove acesso*** — entrar por e-mail não exige
     elo, e as telas da organização continuam abrindo. *Medido em 9 Sep.*

   Abaixo, o aviso `why this panel is on the screen and not only in a document`: o procedimento
   escrito existe **porque** o ato que funcionava não estava escrito, e procedimento que vive só
   na documentação é o que este achado já provou não funcionar.

3. **Create an account** — o formulário de hoje (nome, e-mail, `Create`) e a caixa da
   **temporária mostrada uma vez**, com a frase de que ela não é gravada em claro nem logada e
   que sair da tela a perde.

4. **The accounts** — a tabela. Cabeçalho da seção: `6 rows · disabled last, and never hidden`.
   Parágrafo: `Account` responde *pode entrar?*; `Sign-in credential` responde *entraria com o
   quê?*; era uma célula só, e uma célula só é o que fez um desligamento parecer um primeiro dia.
   Filtro segmentado `all 6 · can sign in 4 · disabled 1`, com `all` ligado, e a frase de que uma
   conta desativada **nunca** sai da lista por omissão.

   Colunas: `Person` · `GitHub` · `Management` · **`Account`** · **`Sign-in credential`** ·
   `Actions`. As seis linhas, nesta ordem:

   | # | linha | `Account` | `Sign-in credential` | ações e recusas |
   |---|---|---|---|---|
   | a | Paulo Junior · admin · elo `paulossjunior` | `active` · `no disablement recorded` | `password set · 26 Aug` / `last signed in 10 Sep 09:12` | `Reset password`; **`Disable` recusado** — *"This is your own account — ask another administrator. The platform refuses it too, so that one administration cannot lock the organisation out of itself."* |
   | b | Marina Alves · sem elo | `active` · `no disablement recorded` | **`temporary · from creation`** / `issued 10 Sep by Paulo · never signed in` | `Reset password` · `Disable…` |
   | c | Ana Vieira · admin · elo `anavieira` | `active` · `disabled once before, on 2 Sep — reactivated the same day` | **`temporary · from a reset`** / `issued 9 Sep by Paulo · last signed in 2 Sep` | `Reset password` · `Disable…` |
   | c' | **linha de histórico de Ana Vieira**, aberta | quatro episódios: reativação de 2 Sep (*investigation closed, no compromise found*), desativação de 2 Sep (*suspected compromise*), e o par de 12 Ago marcado `mistake` — desativação por engano e a reativação que a marca | | |
   | d | Rafael Duarte · elo `rafduarte` mantido | **`disabled`** (marca cinza cheia) · `since 9 Sep 14:20 · by Paulo Junior` · `left the organisation` | `password set · 14 Aug` / `kept, and it opens nothing while the account is disabled · last signed in 8 Sep 17:44` | **`Reset password` recusado** — *"Reset is unavailable while the account is disabled. Reactivate first — and reactivating does not hand the password back, so a reset comes after, not instead."*; `Reactivate…` |
   | d' | **linha de histórico de Rafael Duarte**, aberta | o episódio **aberto**, com a nota, e a frase de que a sessão caiu na ação seguinte; e o que a conta alcançava, **mantido e inerte**: 1 escopo de organização, concedido 14 Ago | | |
   | e | Beatriz Nunes · sem elo | `active` · `no disablement recorded` | **`no password`** / `sign-in refuses · account created 9 Aug, before passwords existed` | `Issue a temporary` · `Disable…`; nota em tinta-2: *"This account cannot sign in and it is **not** disabled — nobody decided anything about it. Disabling it is how the decision gets recorded."* |
   | f | Caio Ferreira · **elo revogado 1 Sep** | `active` · `no disablement recorded` | `password set · 3 Sep` / `last signed in 10 Sep 08:30` | `Reset password` · `Disable…`; nota em tinta-2: *"The link was revoked and this account **still signs in**. That is the pair the finding measured — if the intent was to remove access, disable is the act."* |

   A linha de histórico é ligada à linha da pessoa por uma barra vertical e pelo rótulo
   `access history · <nome> — nothing here is deleted`.

   **Legenda**, seis itens: `disabled` (cinza cheio, e a razão: é a marca da casa para *ended and
   stayed on the record*); `active` (palavra, sem badge — marcar o raro, não o comum); `mistake`
   (clay hachurado); `temporary` (âmbar, e **o texto diz qual** — de criação ou de reinício);
   `no password` (ausência escrita); `refused` (botão tracejado inerte, com a razão ao lado).
   Fecha com a frase de que **todo estado sobrevive impresso em preto e branco**.

5. **Disable an account** — o formulário aberto, sobre a linha de Rafael Duarte.
   - subtítulo *"Disabled, not deleted. The row stays, and so does everything this person did."*;
   - **`Why` — required**, cinco cláusulas de rádio, cada uma com o código: `left_the_organisation`
     (marcada), `access_no_longer_needed`, `duplicate_account`, `suspected_compromise` (com o
     aviso de que ela **acrescenta uma lista abaixo**), `other` (com o aviso de que a nota passa a
     ser obrigatória);
   - **`Note`** — opcional aqui, obrigatória para `suspected_compromise` e `other`; preenchida no
     exemplo com *"last day was 8 Sep; handover to Marina done"*;
   - **`what happens when you confirm`**, cinco itens, os dois últimos em tinta-2 e negativos: a
     senha **não** muda, o elo **não** é revogado, os escopos **não** são removidos — ficam
     mantidos e inertes; e o roster, as medidas e o histórico da pessoa **não** mudam;
   - botões `Disable the account` (clay) e `Cancel`.

   **E o mesmo formulário aparece uma segunda vez**, com `Suspected compromise` escolhido, para
   que a lista fique na página: a sessão aberta (fechada por este ato), a senha (inalterada, e
   reiniciar **depois** de qualquer reativação, nunca antes), **os tokens de API** (âmbar — *"the
   platform has none yet"*, e até existirem a linha é promessa e não controle), o que a pessoa já
   leu (nada é retroativo), e o registro de acesso (que **começa em 9 Sep**, e antes dessa data
   não há nada — e a tela diz isso em vez de mostrar lista vazia).

6. **Reactivate an account** — o formulário aberto, em azul `info`.
   - abre nomeando o episódio que vai fechar: *"disabled 9 Sep 14:20 by Paulo Junior, left the
     organisation"*;
   - **`Why` — required**, quatro cláusulas: `returned_to_the_organisation` (marcada),
     `disabled_by_mistake` (que marca o episódio `mistake` e **para de contá-lo como
     desligamento**, sem o apagar), `investigation_closed_no_compromise` (**oferecida só** contra
     uma desativação por suspeita de comprometimento), `other`;
   - **`Note`** — opcional, obrigatória para `other`;
   - **`what happens when you confirm`**: entra de novo com a credencial que já tinha; os escopos
     voltam a valer, e **nada novo é concedido**; o episódio fecha com nome, instante e razão, e
     **a desativação acima fica exatamente como estava**; e o item negativo — reativar **não**
     devolve a senha, e se o desligamento foi feito do jeito antigo a senha continua sendo a
     temporária que ninguém entregou.

7. **What disabling does not touch** — duas afirmações lado a lado: *a pessoa, nos dados da
   organização* (roster, vínculos, itens, perfil e toda medida ficam — quem trabalhou aqui em
   julho continua contando em julho) e *a conta, nesta tela* (linha, elo, escopos inertes e
   credencial ficam; o único que muda é a resposta a *"pode entrar?"*, com autor, instante e
   razão). E o aviso final: **`4 can sign in today` só é verdade enquanto a organização estiver
   ativa** — `tenants.status` existe, aceita `"suspended"` e **não é lido em lugar nenhum**
   (H3 parte A). Onde isso aparece é a pergunta aberta 14.

### `screen 2 · what the disabled person sees`

Nota da tela: a recusa da porta **nunca nomeia o estado da conta** — quem não entrou não pode
aprender da resposta se o endereço existe, se a senha estava errada ou se a conta foi desativada.
A tela de entrada com a mensagem única **`Invalid credentials.`** e os campos preenchidos.

**The two statements** — duas afirmações lado a lado: *o que a porta diz* (`"Invalid
credentials."`, byte a byte a mesma de senha errada e de endereço inexistente, construída num
ponto só para não se partir em três) e *o que o registro guarda* (`sign-in refused · reason:
account_disabled · user … · tenant …`, no log de acesso, onde reconstruir um incidente precisa
dela). E o aviso: nada nesta página diz *"sua conta foi desativada"*, e nada deve dizer — a
pessoa fica sabendo por um ser humano, e **é por isso que o formulário pede uma nota**.

### `Decisions and open questions`

Onze decisões numeradas com a razão de cada uma, quatro perguntas abertas com opções e
recomendação, a tabela **`Where the screen shipped in v0.7.0 differs from this prototype`** (dez
linhas — cada uma um defeito a corrigir, não um ajuste a adotar), e a tabela dos **nomes que a
base precisa antes do código**.

## 4. Como usar este arquivo

- O **Design** (`.claude/agents/design.md`) parte daqui para qualquer mudança na tela e
  **republica no mesmo endereço**. Endereço novo é protótipo novo, e protótipo novo pede
  aprovação nova.
- O **Product Owner** (`.claude/agents/product-owner.md`) registra o endereço e este prompt no
  item `docs/backlog/conta-desativada.md` e os cita na spec, leva as quatro perguntas abertas à
  pessoa mantenedora, e **só aceita a entrega da tela conferida contra a seção 3**.
- O **QA** confere a tela entregue contra a seção 3, item a item — existe, na ordem, com o texto,
  com a marca, com a ação e com a recusa. Divergência é defeito, não melhoria de implementação.
- O **Elixir/Phoenix Developer** implementa exatamente esta tela, e quando descobrir que algo
  aqui não é possível ou não é honesto com o dado, **volta ao protótipo** em vez de improvisar no
  código.
