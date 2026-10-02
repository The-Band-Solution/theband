# O protótipo da marca de administrador na tela de contas (072, issue #568)

[`accounts-admin-role.html`](accounts-admin-role.html) — abrir no navegador. Sete telas, separadas
pelas faixas `screen N · nome`, e a seção final `Decisions and open questions`. Tudo visível ao
carregar; os únicos controles são *View in greyscale* e *Phone width (360 px)*.

Desenhado em **2026-10-02** pelo agente Design, a pedido do ciclo da spec 072.
Publicado em **<https://claude.ai/artifact/2r84DDZBXBRPN7NzXCVpon>** (versão 1); **a cópia aqui é a
que vale** — o endereço pode mudar, a spec não pode depender dele.

**Estado: versão 1, aguardando a aprovação da pessoa mantenedora.** As decisões D1–D9 são
*propostas* até a aprovação; as perguntas Q1–Q6 vão à pessoa mantenedora pelo Product Owner.
Republicação é sempre no mesmo endereço.

A estrutura seção a seção — **a régua do QA** — está na seção 3 do [`PROMPT.md`](PROMPT.md).

## O dado que a tela mostra

**Todo de exemplo**, marcado `example` na página: organização `Acme Labs`; contas `Ana Example`
(a primeira, criada administradora), `Rui Example`, `Bia Example`, `Caio Example`, `Dora Example`
e `Edu Example`, e-mails `@example.org`; datas de setembro e outubro de 2026 e notas inventadas.
Nenhuma consulta ao banco: o registro de mudança de papel não existe ainda, e a tela mostra nomes
de pessoas — o protótipo não publica dado pessoal real.

## A tela de hoje, medida

| fato | onde |
|---|---|
| a coluna se chama `Management`; administrador é `badge badge-primary` (verdete), e quem não é recebe `—` com opacidade | `lib/the_band_web/live/accounts_live/index.ex:693-696` |
| a legenda do cabeçalho diz *azul = declarado pela administração*, *verdete = o login do GitHub vem da coleta* | `index.ex:558-566` |
| desativar e reativar abrem formulário **abaixo da tabela**, com "what happens when you confirm" | `index.ex:1146`, `:1293` |
| a recusa fica no lugar, botão `btn-dash` com a razão ao lado | `index.ex:955-1004`, legenda `:1110` |
| a tabela tem seis colunas e rola de lado, sem `stacked` | `index.ex:675` |
| quem não é administrador não alcança `/accounts`: vai para `/people` com *"Only organisation administrators can do that."* | `lib/the_band_web/live/hooks.ex:102-116` |

## As premissas que o protótipo herda da spec

| de onde | o que fixa na tela |
|---|---|
| US1, US2, FR-001 | promover só conta ativa; rebaixar administrador; ninguém mais |
| FR-004, US2 cenário 2 | a frase *"the organisation would have no active administrator"*, para o último, inclusive ele mesmo |
| edge case "rebaixar a si mesmo" | permitido com outro administrador ativo, com confirmação |
| edge case "outra aba" | promover quem já é administrador, ou rebaixar quem já é membro, é recusa de estado que mudou |
| FR-005, FR-007, Assumptions | registro de quem, quando, de→para e nota livre opcional; a nota não vai ao log; sem razão de lista fechada |
| FR-008 | rebaixado com tela aberta não age como administrador na próxima ação |
| US3 cenário 1 | conta desativada sem nenhum dos dois atos (ver Q1) |

## As decisões de desenho — *propostas em 2026-10-02*

| # | decisão | a razão |
|---|---|---|
| **D1** | O ato vive na célula `Management`, ao lado da marca, e não na coluna das ações | papel e entrada são dois fatos independentes — a tela já tem "duas colunas para dois fatos"; a coluna das ações fica com os atos de acesso |
| **D2** | O `—` vira `member` em palavra simples; `administrator` passa de verdete a **azul cheio** (declarado) | o travessão viola a regra, e pior que ausência sem nome: **não falta nada ali**, a conta tem papel e o travessão o esconde. O comum é palavra, como `active`. Azul porque a própria legenda da tela diz que azul é o que a administração declara, e verdete é o que a coleta observa |
| **D3** | Confirmação por **painel** sob a tabela (pessoa e e-mail nomeados, o que faz e o que não faz, nota opcional, botão que repete o nome). **Digitar o próprio e-mail só para deixar o papel** | deixar o papel é o único ato que o autor não desfaz — depois dele não abre mais a tela. É para isso que a casa reserva digitar o identificador (070, Q2). Digitar em toda mudança treinaria a digitar sem ler; promover e rebaixar outro qualquer administrador desfaz em segundos |
| **D4** | O último administrador é recusado **em repouso** (botão tracejado no lugar, com a frase) e **depois de corrida** (aviso com a mesma frase), e a marca continua. O cabeçalho conta `N active administrators` | a razão fica visível antes de ser preciso; o mesmo guarda e a mesma frase valem para desativar o último |
| **D5** | Recusa por estado que mudou nomeia **a mudança que chegou antes**: "Not changed: Bia Example is already an administrator. Rui Example made her one at 14:02." A linha re-renderiza e o painel fecha | sem quem e quando, a pessoa não distingue aba velha de botão quebrado |
| **D6** | Conta desativada: nenhum ato; a célula escreve "Role changes wait for reactivation". Administrador desativado leva "not counted while the account is disabled" | US3; e o guarda conta só administrador **ativo**, o que a tela precisa dizer |
| **D7** | O registro aparece em dois lugares: **uma linha por conta** na célula (desde quando, por quem) e a seção **"Administrator changes"** abaixo da tabela, da organização inteira, mais recente primeiro. Marca mais velha que o registro escreve "no role change recorded" | a linha responde "desde quando"; a seção responde a pergunta de auditoria — quem teve o papel e quem deu. Desativar e reativar não entram: ficam no histórico de acesso da linha |
| **D8** | Nota opcional, guardada no registro, nunca no log; ausência escrita "no note", a frase já declarada em `access.account_lifecycle` | FR-007 e Assumptions |
| **D9** | Perder o papel com a tela aberta leva a `/people` com a frase que as telas de admin já usam. Deixar o papel leva ao mesmo lugar com confirmação que nomeia quem pode devolver | FR-008; a ação não roda, e quem deixou o papel sabe a quem pedir |

## As perguntas abertas — para a pessoa mantenedora, pelo Product Owner

| # | pergunta | opções | recomendação |
|---|---|---|---|
| **Q1** | Administrador **desativado** pode ter o papel retirado? A spec discorda de si: FR-001 diz "rebaixar um administrador da sua organização", sem "ativo"; US3 diz que conta desativada não tem nenhum dos atos. Hoje, quem saiu com o papel o mantém, e reativar a conta devolve a administração junto | (a) como desenhado: nenhum ato em conta desativada; (b) "Remove admin role…" também no administrador desativado, nunca "Make administrator"; o guarda não muda, porque desativado não conta | **(b)** — tirar um poder que ninguém exerce não custa nada e fecha o caso em que uma reativação de rotina devolve administração que ninguém quis dar. Se (b), emenda o cenário 1 da US3 e a linha de Edu ganha o ato |
| **Q2** | Promover também exige digitar o e-mail de quem é promovido? | (a) não, só painel, como desenhado; (b) sim | **(a)** — conceder é o ato mais forte, mas é o reversível, e o painel já nomeia pessoa e e-mail. Digitar paga o custo quando o autor não pode desfazer |
| **Q3** | O que lê quem perdeu o papel com a tela aberta? | (a) a frase existente, "Only organisation administrators can do that.", como desenhado; (b) frase específica: "Your administrator role was removed by Ana Example at 14:02." | **(a)** — a conferência vive no hook comum e não sabe por que falta o papel; ensiná-la é ler o registro em toda recusa, e é mudança de contrato do hook |
| **Q4** | A tabela empilha no telefone nesta feature? Hoje tem seis colunas e rola de lado; o design system (§5) exige `stacked` + `data-label` acima de três colunas. O protótipo desenha empilhada | (a) sim, nesta feature; (b) não, issue separada, e o protótipo é republicado com a rolagem de hoje | **(a)** — é a mesma tabela e o mesmo template, e §11.1 torna mobile-first normativo para toda mudança de tela |
| **Q5** | Quanto mostra "Administrator changes"? | (a) tudo, sempre; (b) as 20 mais recentes, com "N earlier changes, all kept" escrito | **(b)** — é o que o histórico de acesso da linha já faz; no tamanho de hoje mostra tudo |
| **Q6** | Os administradores de hoje ganham entrada no registro? | (a) não: a linha escreve "no role change recorded", como desenhado; (b) sim: uma migração grava uma entrada por administrador atual | **(a)** — entrada precisa de autor e instante, e a migração não sabe nenhum dos dois: seria registro fabricado apresentado como genuíno |

## Nomes para a base de conhecimento, antes do código

O protótipo mostra uma contagem nova e frases novas. Princípio IV: nada na tela sem declaração.

| nome proposto | o que é | onde aparece |
|---|---|---|
| `access.active_administrators` | contagem de contas `admin` **ativas** da organização — a mesma que o guarda confere | cabeçalho ("2 active administrators"), célula do último ("the only active administrator") |
| `access.account_role` (regra) | os dois papéis e seus rótulos (`admin` → "administrator", `member` → "member"); a frase da recusa do último, "the organisation would have no active administrator"; a frase de ausência "no role change recorded" | célula `Management`, avisos, legenda |

A frase "no note" já está em `access.account_lifecycle` (`note_required.absent_phrase`) e é
reaproveitada.

## O que o protótipo descobriu e a implementação precisa saber

- **A spec se contradiz sobre conta desativada** (FR-001 × US3) — é a Q1.
- **A recusa por estado velho precisa de quem e quando**: o ato que recusa precisa devolver, ou a
  tela precisa ler, a última mudança de papel da conta. É detalhe de contrato.
- **Deixar o papel exige comparar o e-mail digitado no servidor**, como o `confirm_slug` da 070.
  O campo e a recusa entram no contrato do ato ou do evento da LiveView.
- **A tabela empilhada** é mudança de template que vai além da célula — é a Q4.
