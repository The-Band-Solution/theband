# ADR 0008 — O vínculo observado: a participação que a ferramenta mostra conta como membro, e o papel é o que se declara

## Status

Aceita — 2026-09-06 (decisão da pessoa mantenedora: "2 e 3").

Depende de: [ADR 0003](0003-organizacao-por-ontologias.md) — o conceito é da EO e a coleta continua passando pela API pública do módulo
Emenda: specs 055 (FR-013 a FR-018, SC-007 a SC-009) e 058 (FR-026, SC-013 e SC-014); regra `github.team_membership_evidence` v2
Reverte, em parte: spec 043, FR-007 ("a plataforma não promove sozinha") — a **participação** passa a ser automática; o **papel** continua humano

## Contexto

### O que a medida mostrou, em 2026-09-06

A coleta trazia as 8 equipes do GitHub da organização `leds-conectafapes` com 59 evidências de
vínculo (49 pessoas) — número conferido contra a origem no mesmo dia: 3, 7, 19, 4, 7, 6, 8 e 5
membros por time, exatamente o que a API devolve. Pela regra da feature 055, evidência não
era vínculo até alguém confirmar com papel. Ninguém confirmou.

| o que a tela dizia | medido |
|---|---|
| equipes do GitHub com algum vínculo vigente | **0 de 8** |
| evidências à espera de confirmação | 59 (49 pessoas) |
| solicitações dos últimos 56 dias de autores só com evidência pendente | **838 de 1 077 — 78%** — fora de toda medida por equipe |
| única equipe com medidas | a derivada, com 31 pessoas que não estão em nenhum time observado |

Para a equipe PLATAFORMA (19 pessoas na origem) a tela mostrava "Equipe sem nenhum vínculo
vigente", "19 participações aguardando confirmação" e todas as medidas da feature 058 vazias.
Coerente com a regra; inútil para a pergunta que a tela existe para responder.

### A regra que estava em vigor, e por quê

A regra `github.team_membership_evidence` v1 dizia: `eo.team_membership` é o relator que aloca
uma pessoa a um papel numa equipe; o GitHub fornece pessoa e equipe e não fornece papel; logo
o vínculo não é materializado, e a participação fica como evidência "consultável, contável e
explicitamente incompleta" até o tenant declarar o papel. A spec 043 (FR-007) fixou: a
plataforma não promove sozinha.

A razão era boa — inventar papel a partir de `MAINTAINER`/`MEMBER` produziria um catálogo
falso. A consequência prática não foi medida antes: **a declaração manual não acontece**, e
sem ela nenhuma medida por equipe existe.

## Decisão

Três saídas foram apresentadas à pessoa mantenedora, com o exemplo de uma pessoa num time do
GitHub:

1. **Confirmar na mão** — 59 escolhas de papel agora, e uma a cada pessoa nova. Regra intacta.
2. **A coleta cria o vínculo** como *observado*, com o papel declaradamente ausente; quem
   administra declara o papel depois, no mesmo vínculo.
3. **Só as medidas usam a evidência** quando não há declaração, com etiqueta — duas
   definições de "membro" no sistema.

A decisão foi **2 como regra e 3 como transparência**: uma única definição de membro (o
vínculo), e a tela dizendo sobre quantos observados e quantos declarados cada medida foi
calculada.

### O que passa a valer

1. **A participação observada vira vínculo na coleta.** `eo.team_membership` com
   `organizational_role_id` nulo ("papel não declarado"), `declared_by_user_id` nulo e
   `started_at` nulo (a origem não diz desde quando — e nunca é `observed_at`). A evidência
   continua existindo e aponta para o vínculo.
2. **Declarar é completar o mesmo vínculo.** A ação "confirmar" da tela passa a chamar-se
   "declarar papel": preenche papel, autor e, se informado, início — no vínculo observado, e
   não num segundo. `allocate/2` faz o mesmo quando chamado diretamente. Dois vínculos
   vigentes para a mesma pessoa na mesma equipe dobrariam a contagem de membros, e o índice
   parcial `eo_team_memberships_observado_vigente_index` impede o observado duplicado.
3. **A ausência na origem encerra o observado — e só ele.** Quando a coleta deixa de ver a
   pessoa no time, o vínculo puramente observado (sem papel, sem autor) ganha `ended_at` no
   instante da ausência. Nunca é apagado. O vínculo com qualquer declaração não é tocado.
4. **Onde a organização já declarou algo, a coleta não cria vínculo.** Se existe para aquela
   pessoa e equipe um vínculo declarado — vigente, encerrado ou invalidado como equívoco —,
   a evidência fica sem vínculo e a tela mostra as duas afirmações lado a lado (055,
   FR-012). A observação só preenche onde ninguém disse nada.
5. **Quem saiu e voltou ganha vínculo novo.** O antigo fica encerrado; o período é
   preservado.
6. **A declaração continua exigindo papel.** Vínculo com autor e sem papel é recusado pelo
   changeset: é a alocação incompleta que a ontologia recusa. O observado é a exceção
   nomeada, e nomeada é a palavra: a tela o rotula.
7. **Migração de dados**: as 59 evidências vivas sem vínculo passam a vínculos observados, com
   `internal_id` determinístico (`observed_<id da evidência>`). Evidências já encerradas
   ficam como estão — não se cria vínculo para afirmar que alguém esteve.
8. **A equipe derivada** (`github.default_team`) segue o mesmo caminho: a evidência dela
   também vira vínculo observado.
9. **`memberships_pending_role`** passa a contar vínculos vigentes sem papel — é o que
   "pendente" significa agora.
10. **Transparência (a parte 3):** a tela da equipe diz, junto de cada medida, *medido sobre N
    membros — X observados na ferramenta sem papel declarado, Y com papel declarado*. Uma
    definição de membro; a transparência é sobre a origem de cada um.

### O que isto faz à ontologia

`eo.membership_to_play_role` tem cardinalidade `one` na SEON EO: todo vínculo tem papel. A
plataforma passa a materializar o relator com o papel **declaradamente ausente**. É um desvio
da ontologia de referência, e é registrado como tal: a coluna admite nulo, a regra v2 diz por
quê, e CQ14/CQ16 (perguntas sobre papel) continuam sem resposta para o vínculo observado —
a limitação é da fonte, e a tela a apresenta. O que a decisão recusa é a alternativa que
"respeitaria" a cardinalidade inventando um papel: seria dado falso com aparência de dado.

## Alternativas consideradas

**Confirmar em lote na tela (saída 1).** Não muda regra nem código. Recusada pela prática:
59 escolhas agora e uma por pessoa nova para sempre; enquanto isso, nenhuma medida existe.
A medida mostrou que a confirmação não acontece.

**Medidas sobre evidência quando não há declaração (saída 3 sozinha).** Menos código, mas duas
definições de membro — uma para a estrutura, outra para as medidas — que podem discordar. Foi
o tipo de dupla definição que a 055 gastou um sprint eliminando. Ficou só a transparência.

**Papel genérico do catálogo para o observado** ("participante"). Respeitaria a cardinalidade
com um papel que não responde nenhuma pergunta sobre papel — o catálogo falso que a regra v1
recusou. Preferiu-se o nulo declarado.

**Vínculo observado que também vale por cima de declarações.** Recusado: criar "está na
equipe" por cima de "saiu" ou "nunca esteve" faria a coleta vencer a organização, e a 055
decidiu o contrário (FR-012).

## Consequências

- As 8 equipes deixam de disparar `structure.ap02.team_with_no_members`; a mediana de espera,
  a participação em projetos e a taxa do pipeline passam a existir para elas. **A medir depois
  da migração** — é o SC-008 da emenda da 055, e não uma presunção.
- `count_evidence_pending_role/2` (evidência sem vínculo) passa a ser quase sempre zero; quem
  precisa de "pendente de papel" usa `count_memberships_pending_role/2`.
- A spec 043 FR-007 fica revertida na participação. O papel continua não sendo inferido.
- A spec 057 (FR-005, "evidência não promovida não entra nas contagens") fica vácua por
  construção — verdadeira, sem instâncias. Não foi editada.
- Testes antigos que codificavam "a equipe tem zero membros até confirmar" foram ajustados
  para "a equipe tem N membros observados e N pendentes de papel". O teto de consultas da
  tela subiu de 22 para 23, declarado: a composição custa uma consulta.

## Verificação

1. Evidência nova → um vínculo vigente sem papel; a pessoa conta em `count_team_members_at`.
2. Reobservar não duplica; declarar completa o mesmo vínculo (mesmo `id`).
3. Ausência encerra o observado; contagem em data anterior não muda (SC-002 da 055).
4. Vínculo declarado sobrevive à ausência; declaração de saída ou equívoco não recebe vínculo
   observado por cima, e a discordância aparece.
5. **Medida real, depois da migração em desenvolvimento:** as 8 equipes sem `ap02`, e a
   contagem de solicitações de autores sem nenhum vínculo — hoje 838 — medida de novo.

## Emenda de 2026-09-08 — a regra v3, e o item 5 estendido

O **item 5** desta decisão diz: *quem saiu e voltou ganha vínculo novo*. A feature 060
estendeu-o à **saída declarada** e ao **equívoco**, e a regra
`github_team_membership_evidence.yaml` subiu para a **versão 3**.

O que faltava era uma lacuna que esta ADR criou sem ver. A guarda da coleta reconhecia
declaração por três sinais — papel, autor da declaração e equívoco. Numa **saída declarada
sobre vínculo observado** não há nenhum dos três: não há papel, não há autor de declaração,
só o autor da saída. A coleta seguinte não via declaração alguma e criava outro vínculo —
**desfazendo a saída**. Quem declarava via a pessoa voltar sozinha à equipe.

`ended_by_user_id` entrou na guarda. E como uma guarda permanente impediria o retorno de
existir, a exceção é uma só e é a desta ADR, estendida: a observação **nova depois de
ausência constatada** é retorno, e nasce vínculo novo; o antigo permanece com o seu fim. A
marca de ausência é lida **antes** do update que a apaga.

Detalhe medido em 2026-09-08: o mesmo commit descobriu que `count_team_members_at/3` contava
**vínculos** onde prometia pessoas. Com o vínculo observado convivendo com o declarado, e
FR-018 permitindo dois papéis, quem desempenha dois contava duas vezes. Corrigido para
`count(distinct person_id)` — e `team_size/2` já contava distinto, o que mostra qual era a
intenção desde o início.

## Referências

- Specs 055 e 058 (emendas de 2026-09-06), 043 (FR-007), 057 (FR-005), **060 (FR-026,
  FR-027)**.
- `priv/knowledge_base/rules/github_team_membership_evidence.yaml` **v3** (2026-09-07);
  `docs/backlog/vinculo-observado-sem-papel.md` (a nota para a base).
- Medida de 2026-09-06: `sonda_times` contra a origem; `eo_team_membership_evidence` e
  `eo_team_memberships` no banco de desenvolvimento; solicitações dos últimos 56 dias.
