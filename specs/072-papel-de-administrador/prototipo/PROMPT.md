# PROMPT — protótipo da marca de administrador (072, issue #568)

Arquivo: [`accounts-admin-role.html`](accounts-admin-role.html) · publicado em
<https://claude.ai/artifact/2r84DDZBXBRPN7NzXCVpon> · decisões e perguntas em
[`README.md`](README.md).

## 1. O pedido, textual e em ordem

### 1.1 Pedido de 2026-10-02 (via o ciclo da spec 072)

> Você é o Design do The Band. Protótipo da tela para a spec 072 (issue #568):
> `specs/072-papel-de-administrador/spec.md` no worktree […] (branch
> feature/568-papel-de-administrador). NÃO edite lib/ nem test/, NÃO troque de branch, NÃO faça
> commit — eu commito.
>
> A tela existente é `/accounts` (lib/the_band_web/live/accounts_live/index.ex, ~800 linhas): leia
> como ela é hoje (colunas, a marca `administrator`, a coluna da conta, desativar/reativar com
> razão, os avisos) e o design system (docs/design-system.md, DESIGN.md). Desenhe o protótipo
> navegável das MUDANÇAS: o ato "promover" no membro ativo, "rebaixar" no administrador, nenhum ato
> na conta desativada nem para quem não é admin; a confirmação (rebaixar a si mesmo precisa de
> confirmação explícita; a casa já usa digitar o slug/identificador para atos sérios — decida e
> justifique); a recusa do último administrador ("the organisation would have no active
> administrator") como estado; a recusa por estado que mudou (outra aba); o registro de mudanças de
> papel (quem, quando, de→para, nota opcional) — onde ele aparece na tela de contas; o travessão `—`
> atual para não-admin viola a regra de ausência nomeada? proponha. Inglês na tela. Mobile-first.
>
> Publique como artifact (siga suas instruções/skills de artifact) e guarde em
> `specs/072-papel-de-administrador/prototipo/` o HTML, um README.md com as decisões (D1..) e as
> perguntas abertas (Q1..) para a pessoa mantenedora, e o PROMPT.md com a régua seção a seção para
> o QA. Responda com a URL publicada, as decisões e as perguntas.

## 2. O brief de design seguido

- **Escopo**: só as mudanças de `/accounts`. O resto da tela (painéis "what this screen is" e
  "Removing someone's access", criação de conta, colunas GitHub, Account, Sign-in credential e
  ações, formulários de desativação e reativação, "What disabling does not touch") **fica como
  está**; aparece no protótipo só como contexto.
- **Herdado**: tokens de `DESIGN.md` (papel, tinta, verdete, azul de informação, âmbar, barro,
  cinza de "acabou e ficou"), as três vozes do sistema sem webfont, a ramp de dez passos, os quatro
  raios, plano sem sombra, **nenhuma borda colorida de um lado só**. Marcas: declarado azul cheio,
  `disabled` cinza cheio, ausência tracejada, recusa barro hachurado — sempre com texto.
- **Regras da casa visíveis**: ausência escrita; nada apagado (o registro é somente-acréscimo, com
  autor e instante); a recusa fica no lugar com a razão; cada ato diz o que faz **e o que não faz**;
  "not found" para outra organização (não há tela para isso — a conta de outra organização não
  aparece na lista).
- **Confirmação** (decidida em D3): painel para promover e para rebaixar outro; painel + digitar o
  próprio e-mail para deixar o papel.
- **Mobile-first**: tabela `stacked` com `data-label` abaixo de 40rem (Q4); alvo de toque de 44px
  em ponteiro grosso.

## 3. A estrutura aprovada, seção por seção — a régua do QA

> **Estado**: **versão 2, aprovada.** A versão 1 foi aprovada pela pessoa mantenedora em
> 2026-10-03 com as recomendações Q1 (b), Q2 (a), Q3 (a), Q4 (a), Q5 (b), Q6 (a). A conferência do
> QA (`conferencia.md`) levou quatro perguntas novas, **decididas pela pessoa mantenedora em
> 2026-10-03**: **B** (b) as frases desenhadas para a linha sem episódio ficam; **P** (a) a forma
> sem pronome é aceita; **H** (a) o sucesso de deixar o papel sai no toast `:info` da casa; **J** as
> três frases que a tela tinha sem protótipo são aceitas. A versão 2, republicada no mesmo endereço
> pelo Design em 2026-10-03, desenha a tela com todas elas, e os itens 4, 13, 14, 17, 19, 20, 27,
> 29, 31 e 34 abaixo estão no texto novo. O item 21a e os itens 36 a 38 são as frases de J. Nenhuma
> pergunta está aberta.

Para cada item, a tela entregue precisa: existir, na ordem, com o texto, com a marca, com a ação e
com a recusa.

### Tela 1 — `/accounts` em repouso (administrador, dois administradores ativos)

1. A linha de contagem do cabeçalho termina com `· N active administrators` (singular
   `1 active administrator`), em mono, `tabular-nums`.
2. Abaixo do cabeçalho, antes da tabela, o bloco **"Who administers this organisation"** com o texto:
   *"An administrator connects tools, manages their credentials, runs syncs, and creates, disables
   and reactivates accounts on this screen, including making someone else an administrator or
   removing the role. The organisation always keeps at least one active administrator: the last one
   cannot step down or be disabled until someone else is made administrator."*
3. A tabela mantém as seis colunas, na ordem de hoje: Person, GitHub, **Management**, Account,
   Sign-in credential, ações. O cabeçalho continua `Management`.
4. Célula `Management`, por caso:

   | conta | marca | linha de baixo | ato |
   |---|---|---|---|
   | administrador ativo, outra pessoa | `administrator`, azul cheio | `since DD Mon · by <autor>` | botão **"Remove admin role…"** |
   | administrador ativo, a própria conta | `administrator`, azul cheio | idem, ou ausência (item 5) | botão **"Step down…"** |
   | membro ativo | palavra `member`, sem marca | `never an administrator` ou `administrator DD Mon – DD Mon · removed by <autor>` | botão **"Make administrator…"** |
   | administrador desativado | `administrator`, azul cheio | `since … · by …` (ou a forma do item 5) `· not counted while the account is disabled` | botão **"Remove admin role…"** (Q1 (b)); **nunca** "Make administrator" |
   | membro desativado | `member` | `never an administrator` (ou o período) e `Role changes wait for reactivation.` | **nenhum** |

   `Role changes wait for reactivation.` aparece **só** na linha do membro desativado. O membro que
   deixou o próprio papel lê `… · stepped down` no lugar de `removed by <autor>`; sem a promoção
   registrada, o período é `administrator until DD Mon`.

5. Administrador sem mudança registrada (a primeira conta): `since the organisation was created ·`
   seguido da marca tracejada **"no role change recorded"**.
6. **Nenhum `—`** na coluna `Management`.
7. A legenda sob a tabela ganha três entradas: `administrator` (marca), `member` (palavra) e
   *"the last active administrator cannot step down or be removed — make someone else administrator
   first"*.
8. Abaixo da tabela, a seção **"Administrator changes"** com o subtítulo *"every time someone was
   made administrator or had the role removed · newest first · nothing here is deleted"*. Cada
   entrada: instante `DD Mon HH:MM` (mono), `<autor> made <conta> administrator` ou `<autor> removed
   the administrator role from <conta>`, o de→para em mono (`member → administrator`), e a nota
   entre aspas ou **"no note"** em itálico. Mais recente primeiro. Limite: Q5.
9. Sob a lista, a frase de que a marca da primeira conta é anterior ao registro, e de que
   desativar/reativar não são mudança de papel.

### Tela 2 — painel "Make administrator" aberto

10. Abre **abaixo da tabela**, no lugar onde abrem desativar e reativar. Borda azul.
11. Eyebrow `Make an account administrator`; título `Make <nome> administrator — <e-mail>`.
12. De→para: `member → administrator` (marca).
13. Bloco "what happens when you confirm", **sem pronome** (P): *"<nome completo> can connect and
    disconnect tools, manage their credentials, run syncs, and manage the accounts on this screen.
    That includes removing **your** administrator role."*; *"It takes effect at their next action.
    They do not need to sign in again."*; *"The change is recorded with **your name, this instant**
    and the note below, under “Administrator changes”."*
14. Bloco "what it does not do": *"Their password, their GitHub link and their open sessions do not
    change."*; *"Their teams, their work and every measure about them do not change. This is about
    what they can manage, not about what they did."*
15. Campo `Note — optional · kept on the record, not written to the log`.
16. Botão primário **"Make <nome> administrator"** e **"Cancel"**. **Sem campo de digitar** (Q2).
17. Depois do ato, no lugar do painel: aviso de sucesso com ícone ✓ — *"<nome> is now an
    administrator. Recorded at DD Mon HH:MM, by you. The row and “Administrator changes” show it;
    the header now reads N active administrators."*, com N depois do ato (singular *"… reads 1
    active administrator."*); a linha, a seção de mudanças e a contagem refletem a mudança.

### Tela 3 — painel "Remove admin role" (outra pessoa) aberto

18. Abaixo da tabela, borda barro. Título `Remove the administrator role from <nome> — <e-mail>`;
    de→para `administrator → member`.
19. "what happens", sem pronome (P): *"<nome completo> stops managing tools, credentials, syncs and
    accounts. A screen they have open stops acting as administrator **at their next action**,
    without waiting for them to reconnect."*; *"The organisation keeps N active administrator(s):
    <quem>."*, onde quem está olhando é escrito **"you"**, e não pelo nome; *"The change is recorded
    with **your name, this instant** and the note below."*
20. "what it does not do": *"**It does not remove access.** <nome completo> keeps signing in, as a
    member. If they left the organisation, disabling the account is the act."*; *"Their sessions,
    password and GitHub link do not change. Nothing they did is erased."*
21. Nota opcional; botão barro **"Remove <nome>'s administrator role"** e "Cancel". Sem digitar.

    21a. Depois do ato, no lugar do painel: aviso de sucesso com ✓ — *"<nome> is no longer an
    administrator, and keeps signing in as a member. Recorded at DD Mon HH:MM, by you. The row and
    “Administrator changes” show it; the header now reads N active administrators."* (J; o mesmo
    final do item 17).

### Tela 4 — painel "Step down" (a própria conta) aberto

22. Título `Step down as administrator of <organização> — your account, <e-mail>`.
23. "what happens" inclui **"You cannot give the role back yourself."** e nomeia quem pode.
24. Campo **"Type your e-mail to confirm"**, com o e-mail mostrado como dica. O botão
    **"Step down as administrator"** não fica desabilitado enquanto se digita.
25. E-mail errado: o painel continua aberto com a nota preservada; aviso de recusa hachurado com
    *"Not changed. That is not the e-mail of your account. You are still an administrator."*

### Tela 5 — o último administrador

26. Com um só administrador ativo: a contagem diz `1 active administrator`; a célula dele diz
    `the only active administrator`; o ato fica **no lugar, tracejado e inerte**, com
    *"The organisation would have no active administrator. Make someone else administrator first."*
27. Recusa depois de corrida: aviso hachurado com ícone —
    *"Not changed: the organisation would have no active administrator."*, depois a mudança que a
    causou, e por fim *"Your role is unchanged."* (ou *"<nome>'s role is unchanged."* quando o ato
    recusado era rebaixar outra pessoa). A marca continua; o painel fecha. A mudança:
    - é citada **só se aconteceu depois de o painel abrir**; se é anterior, não é citada, e o aviso
      fica com a primeira e a última frase;
    - leva **data e hora**, `DD Mon HH:MM`;
    - quem deixou o próprio papel lê *"<nome> stepped down at DD Mon HH:MM."*; as demais, *"<autor>
      removed the administrator role from <conta> at DD Mon HH:MM."* ou *"<autor> made <conta>
      administrator at DD Mon HH:MM."*;
    - *", so you are now the only one."* só quando a mudança foi alguém deixar o próprio papel **e**
      o ato recusado é deixar o papel. Exemplo: *"Ana Example stepped down at 02 Oct 14:02, so you
      are now the only one."*;
    - **não** se escreve "a moment before this request": a tela não mede essa distância.
28. A mesma frase recusa desativar o último administrador.

### Tela 6 — estado que mudou em outra aba

29. Aviso hachurado: *"Not changed: <nome> is already an administrator. <autor> made the change at
    HH:MM."* (espelho: *"Not changed: <nome> is already a member. <autor> removed the role at
    HH:MM."*). Sem pronome (P), e sem frase depois. A linha re-renderiza com o papel atual; o painel
    fecha.

### Tela 7 — perdeu o papel com a tela aberta

30. Rebaixado por outro: a próxima ação não roda; redireciona para `/people` com
    *"Only organisation administrators can do that."* (Q3).
31. Deixou o papel: redireciona para `/people` com o **toast `:info` da casa** (H: o flash de
    informação de todas as telas, com o ícone dele, e não aviso com ✓): *"You stepped down as
    administrator of <organização>. Recorded at DD Mon HH:MM. <nome> can give the role back."* A
    recusa do item 30 sai no toast `:error` da casa, como hoje.
32. Membro nunca vê `/accounts`; nenhum controle de papel aparece para quem não é administrador.

### Em todas as telas

33. Toda marca tem texto; tudo lê em escala de cinza.
34. A 360 px, sem rolagem lateral; a tabela empilha com o nome da coluna em cada célula (Q4),
    **inclusive a dos atos**: o cabeçalho das ações tem o texto *"Actions"* só para leitor de tela
    (`<span class="sr-only">Actions</span>`) e a célula leva `data-label="Actions"`.
35. Inglês na tela.

### Frases que a tela tem e a versão 1 não desenhava (J, aceitas em 2026-10-03)

36. O sucesso de rebaixar outra pessoa — item 21a (tela 3).
37. Nota com mais de 2000 caracteres, em qualquer dos três painéis: aviso hachurado *"Not changed:
    the note is longer than 2000 characters."* acima do painel, que **continua aberto com a nota**
    como foi digitada (tela 2).
38. Promover conta que foi desativada depois de o painel abrir: aviso hachurado *"Not changed:
    <nome>'s account is disabled. Role changes wait for reactivation."*; o painel fecha e a linha
    re-renderiza como membro desativado, sem ato (tela 6).

## 4. Como cada papel usa este arquivo

- **Product Owner**: leva as perguntas Q1–Q6 do `README.md` à pessoa mantenedora; registra no item
  do backlog (`docs/backlog/`) o endereço e este prompt; cita os dois na spec; aceita a entrega
  conferindo a seção 3 item a item, com captura da tela real ao lado.
- **Design**: marca as respostas como *Decided <data>*, ajusta a seção 3 e republica **no mesmo
  endereço**.
- **Elixir/Phoenix Developer**: implementa a seção 3 como está. Se algo não for possível ou não for
  honesto com o dado, volta ao protótipo — não improvisa no código.
- **QA**: confere cada item da seção 3 na tela entregue — existe, na ordem, com o texto, a marca, o
  ato e a recusa. Divergência é defeito.
- **Knowledge Base**: declara `access.active_administrators` e `access.account_role` antes do
  código (nomes no `README.md`).
