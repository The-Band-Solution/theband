# Protótipo: o vínculo declarado — 055, FR-003

| | |
|---|---|
| **Endereço** | https://claude.ai/code/artifact/9645056b-9f3d-4a8a-88bf-81c09fac15d8 |
| **Arquivo que vale** | [`team-declared-link.html`](team-declared-link.html) — a spec não depende do endereço |
| **Régua do QA** | [`PROMPT.md`](PROMPT.md), seção 3 |
| **Publicado** | 2026-09-10 |
| **Aprovação** | *aguardando a pessoa mantenedora* — três perguntas abertas, duas delas mudam o que a tela desenha |
| **Detector** | `node .claude/skills/impeccable/scripts/detect.mjs specs/055-equipes-declaradas/prototipo/team-declared-link.html` → **0** |

Republicar é **sempre no mesmo endereço**. Endereço novo é protótipo novo, e protótipo novo
pede aprovação nova.

---

## O achado que originou o protótipo

FR-003 é cláusula **MUST** desde 2026-09-01 e nunca teve tela. `EO.declare_team_membership/5`
tem `@spec`, `@doc` e onze testes, e **zero chamadas em `lib/`** — nenhuma tela do produto a
alcança. Os quatro atos que a interface oferece hoje trabalham todos sobre **uma linha que já
existe**: promover evidência, declarar ou trocar o papel, registrar a saída, marcar equívoco.

**A saída era declarável e a entrada não.** Uma pessoa podia ser registrada como tendo saído de
uma equipe em que nunca poderia ser registrada como tendo entrado.

O banco de desenvolvimento confirma, em 2026-09-10: **90 vínculos vigentes, 90 evidências
apontando para eles, 0 vínculos declarados do zero** — nenhum carrega o identificador
`declared_` que o comando escreve.

---

## As decisões, numeradas, com a razão escrita

### 1. Onde o ato mora — **seção própria, entre *Roles* e *Members***

Não formulário solto acima da tabela, nem ação no cabeçalho de *Members*.

1. **O sujeito do ato é quem não está na lista.** Ação no cabeçalho da lista lê como "aja sobre
   esta lista"; este ato acrescenta a ela de fora, e ali diria que a pessoa deve ser encontrada
   entre as linhas.
2. **As recusas precisam de espaço.** A maioria das buscas cai em alguém que já tem vínculo, e
   a resposta é duas afirmações, um botão inerte com a razão ao lado e uma rota para outra
   linha. Isso não cabe num popover de cabeçalho, e encolher encolheria a razão primeiro.
3. **A ordem carrega sentido.** Squads → Roles → *Link a person* → Members: o papel precisa
   existir antes de ser declarado, e a seção que acrescenta à lista fica **imediatamente
   acima** da lista que ela muda.

Em repouso a seção mostra título, os dois números e o texto, com a busca **fechada** — fechada
não é ausente: a seção precisa dizer que o ato existe mesmo sem ninguém clicar. `060 FR-003`
(toda ação de escrita vive na Estrutura) é cumprido pelas duas alternativas; só uma tem espaço
para a recusa.

### 2. A busca — **o padrão de `/accounts`, mais o veredito**

Reusado literalmente: nome + login + **organização observada** em cada resultado, a marca *no
longer observed*, no máximo 8 resultados, consulta **no evento da digitação** e nunca no
`mount`. O caso dos homônimos já custou uma US (051/T009, PR #618), e nome+login+organização é
a forma que a corrigiu. E-mail **não é buscado nem exibido** — é dado pessoal, e a busca do
domínio casa `name` ou `login`, nunca e-mail.

**O que foi acrescentado, e é o coração do protótipo: o veredito vem antes do botão.** A razão
é medida — **0 das 80 pessoas coletadas estão fora de toda equipe**. Uma lista de botões
"link" pelados ofereceria um ato recusado na maior parte das vezes, e a razão chegaria só
depois do clique.

### 3. Papel **obrigatório**, data de início **opcional**

**A data**: em branco fica **desconhecida**, e o campo **nunca vem preenchido com hoje** —
060 FR-016, 043 FR-019, 055 FR-013c. A plataforma já lê início desconhecido corretamente: 87
dos 90 vínculos têm um.

**O papel**: obrigatório, e a razão não é de formulário. Um vínculo **vigente, sem papel e sem
origem** é a única forma que a plataforma **não distingue** de um vínculo materializado pela
coleta — e o índice parcial
`eo_team_memberships_observado_vigente_index (tenant, person, team) WHERE ended_at IS NULL AND
invalidated_at IS NULL AND organizational_role_id IS NULL` prova por que isso importa: um
vínculo declarado sem papel **ocupa a vaga do vínculo observado**, e a coleta não conseguiria
mais materializar a observação daquele par (055 FR-013, FR-013a). A ausência de papel é a
assinatura do vínculo observado; ela não pode ser também a do declarado.

FR-003 pede os dois ("com papel e data de início"); esta decisão mantém o papel como FR-003
pede e substitui a data pela leitura mais nova (060 FR-016), que é a que vale.

### 4. A pessoa que a origem já mostra — **recusa que nomeia, e oferece o ato certo**

Botão **inerte**, com a razão **ao lado**: *já é membro desta equipe; o que falta no vínculo
dela é o **papel**, não o vínculo*. Ao lado da recusa, a ação certa: **`Declare her role ↓`**,
que leva à linha dela em *Members* e abre o formulário de papel de lá — **um comando só**, pelo
ponto de entrada que 060 FR-015 já aprovou. A tela diz o que não faz: **não cria um segundo
vínculo** (055 FR-014).

É o caminho **frequente**, não a borda: 56 dos 90 vínculos do banco têm exatamente essa forma.

### 5. O que a pessoa já tem, **antes** de o ato acontecer — sempre

Três formas, cada uma com a consequência escrita:

- **Em subequipe desta** — permitido, com aviso. Vínculo direto e vínculo via squad são
  **afirmações diferentes**, e a linha passa a mostrar `direct` ao lado do chip da squad. **A
  contagem de membros da equipe não muda** — a pessoa já era contada uma vez, pela squad
  (060 FR-009). *Forma real*: os 17 do banco que estão nas três squads de Conecta Fapes **não
  têm** vínculo direto com ela.
- **Em outra equipe que não faz parte desta** — permitido, sem aviso. Pessoa pode estar em mais
  de uma equipe; as contagens de cada uma valem sozinhas e **nunca somam** (057 FR-008,
  FR-009).
- **Com vínculo encerrado ou marcado equívoco aqui** — permitido: nasce vínculo **novo**, os
  dois períodos coexistem (055 US2 cenário 4), e o equívoco **não é apagado nem contradito** —
  ele diz que um vínculo determinado nunca vigeu.

### 6. A assimetria, escrita na tela

A tela 3 põe os **quatro atos de um vínculo** em linha — *begins declared*, *begins observed*,
*role declared*, *ends*, *never was* — cada um com quem pode ser autor, o que o registro guarda
e **o que havia antes deste protótipo**. Só a primeira fase leva `before this prototype: no
screen`.

Sobre o vínculo observado, que continua nascendo sem autor de declaração: o quadro *what each
kind of link keeps* escreve a ausência com dono — **"absent — and it is not a gap to fill:
nobody declared it"** — e a tela diz que a coluna de autor de um vínculo observado lê
`observed at the source`, **nunca o nome de uma pessoa**: preenchê-la com a conta que rodou a
coleta transformaria uma observação na afirmação de alguém.

---

## As perguntas abertas — do Product Owner para levar

### P1. O vínculo **registra** a sua origem, ou a origem é **derivada**?

Hoje nada no vínculo diz se a **existência** dele foi observada ou declarada: um vínculo
observado cujo papel foi declarado e um vínculo declarado do zero **carregam os dois** autor de
declaração. A origem só sai da **ausência** de evidência apontando para ele.

- **Opção A — registrar** (⭐ recomendação): o vínculo carrega a própria origem, como a equipe
  já carrega (`eo_teams.source_instance = 'declared'`, 1 das 10 equipes do banco). Derivar de
  "nenhuma evidência aponta aqui" faz a marca depender da retenção da tabela de evidências, e
  ela viraria sozinha se evidência algum dia for podada.
- **Opção B — derivar**: a marca `declared` da lista de membros passa a ser
  **`derived`** (hachurada) e a linha precisa dizer de que foi derivada.

**Muda o que a tela desenha.** O protótipo está desenhado na opção A.

### P2. Precisa de um estado próprio para o vínculo **declarado nas duas pontas**?

Depois deste ato um vínculo pode começar por declaração e terminar por declaração, sem coleta
em ponto nenhum.

- **Opção A — não** (⭐ recomendação): as duas marcas já ficam lado a lado na linha.
- **Opção B — sim**: um estado `declared at both ends`, que acrescenta vocabulário para dizer o
  que duas marcas já dizem.

Não muda o desenho.

### P3. E quando a coleta passa a observar uma pessoa que **já tem vínculo declarado** ali?

A coleta vai materializar **o vínculo dela**, porque o declarado é intocável (055 FR-016). O
par fica com dois vínculos vigentes: um declarado, um observado.

- **Opção A — permitir, e mostrar os dois na mesma linha** (⭐ recomendação): é o que a regra
  das duas afirmações já pede.
- **Opção B — deixar a coleta pendurar a evidência no vínculo declarado**: reescreveria a
  afirmação de alguém com a observação de uma ferramenta.

**Muda o que a tela desenha** se a resposta for B.

---

## Medidas novas que precisam de nome no YAML **antes do código**

Constituição, princípio IV: nada na tela sem declaração na base de conhecimento. Três medidas
novas aparecem no protótipo, e uma mudança de ontologia:

| nome proposto | o que conta | onde aparece |
|---|---|---|
| `structure.memberships_declared_from_zero.count` | vínculos vigentes cuja **existência** foi declarada, não observada | quadro do topo (`0` de 90) |
| `structure.people_linkable_to_team.count` | pessoas coletadas do tenant **sem** vínculo vigente com esta equipe nem com as subequipes vigentes dela | cabeçalho da seção nova (`32 of 80`) |
| `structure.people_without_any_team.count` | pessoas coletadas **sem** vínculo vigente com equipe alguma | quadro do topo (`0` de 80) |

E, na ontologia (não é medida): **`eo.team_membership` ganha `origin`**, com valores
`observed` / `declared`, espelhando o que `eo.team` já faz — **se** a resposta de P1 for a
opção A. As três medidas acima **dependem dessa decisão**: sem `origin`, a primeira delas é
derivada da ausência de evidência e a sua declaração YAML precisa dizer isso em `limitations`.

---

## Quatro mudanças no domínio que a tela aprovada exige

Achadas ao desenhar, e nenhuma é cosmética. `lib/the_band/ontology/seon/eo/commands.ex`:

1. **A recusa derruba a tela em 87 dos 90 vínculos do banco.** A cláusula de recusa é

   ```elixir
   %TeamMembership{started_at: desde} ->
     {:error, "esta pessoa já tem vínculo vigente nesta equipe desde #{DateTime.to_date(desde)}"}
   ```

   e `started_at` é **nulo** em 87 dos 90 vínculos vigentes — `DateTime.to_date(nil)` levanta.
   O caminho mais frequente da recusa (decisão 4) é justamente esse. Além de não levantar, a
   recusa precisa **nomear a forma do vínculo** — observado sem papel → rota para declarar o
   papel — e não uma data que ela não tem.

2. **`started_at` em branco não pode virar hoje.** Hoje o comando faz
   `Map.get(attrs, :started_at, DateTime.utc_now())`. A tela aprovada exige **nulo** quando o
   campo fica vazio (060 FR-016, 043 FR-019).

3. **Papel nulo tem de ser recusado com razão nomeada**, e a razão é a do índice parcial
   (decisão 3) — não uma violação de constraint traduzida.

4. **A frase da recusa está em português** dentro do domínio, e a tela fala inglês. A LiveView
   não pode imprimir a string do domínio crua.

---

## Premissas que a spec carrega até serem contestadas

1. **Vincular do zero é para quem a origem não mostra** naquela equipe — para quem a origem
   mostra, o ato é declarar o papel (emenda de 2026-09-06).
2. **Nenhuma pessoa é criada por esta tela.** Pessoa existe porque uma coleta a viu; não achar
   ninguém é resposta, e a tela diz o que faria a busca achar alguém.
3. **A busca casa nome ou login do GitHub**, nunca e-mail, e é escopada ao tenant. Recurso de
   outra organização é **`not found`**, nunca "sem permissão".
4. **Quem pode escrever** são as duas contas de 060 FR-006: a administradora do tenant e a
   conta cuja pessoa desempenha papel com a concessão *gerir estrutura da equipe* com alcance
   sobre esta equipe. Esconder o botão **não é autorização** — o evento também recusa, com a
   razão.
5. **O vínculo declarado nasce vigente e sem fim.** A coleta nunca o cria, encerra ou altera
   (055 FR-016).
6. **Nada é apagado.** Saída tem data e autor; equívoco tem razão e autor; e vincular depois de
   um equívoco não o remove.

---

## Divergência deliberada dos protótipos anteriores

Este arquivo põe o cabeçalho de coluna (`th`) em **0.6875rem** (`micro`), e não em 0.625rem
(`tick`) como `team-people.html` e `team-dashboard-structure.html` ainda fazem: a One-Ramp Rule
de 2026-09-10 reserva `tick` para **rótulo de eixo dentro de gráfico SVG**, e esta tela não tem
gráfico. Quem normalizar os outros dois tem aqui o valor certo.

A única borda colorida acima de 1px num lado só é o **indicador de aba** (2.5px), herdado
literalmente da tela aprovada: aba não é cartão, item de lista, aviso nem chamada, e mudá-la
faria a aba desta tela divergir da aba da tela que o QA usa como referência.
