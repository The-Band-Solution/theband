# Research — spec 065, o rótulo como campo do item de trabalho

**Data**: 2026-09-13 · **Branch**: `065-rotulos-no-item`

Cada decisão foi tomada depois de medir. Duas delas **reduzem** o escopo que o pedido sugeria,
e as duas estão aqui com o número que as sustenta.

---

## R1 — A identidade da issue já está correta. O defeito é de leitura.

**O que foi apontado**: o `number` é por repositório, e a identificação deveria ser
organização + repositório + número.

**O que a medição diz**: no armazenamento **isso já vale**.

| medida | valor |
|---|---|
| issues | 5 033 |
| `external_id` distintos | **5 033** |
| pares (repositório, número) distintos | **5 033** |
| números distintos | **2 699** |

O índice `collected_issues_application_reference_index` é único em
`(tenant_id, source_system, source_instance, external_id)` — a colisão de número **não pode**
produzir duas linhas confundidas. A rota também está certa: `/work/issues/:id` usa o
identificador interno, não o número.

O uso de número em `changes.ex:690` é **filtro de busca**, não identidade. Digitar `42` e
receber todos os `#42` é comportamento defensável de busca; trocá-lo por identidade tiraria
uma função que funciona.

**Onde o defeito está**: `list_issues` devolve `observed_repository_id` — um identificador
interno — e não o nome do repositório. **A tela mostra `#2` sem dizer de qual repositório.**
Duas issues diferentes ficam indistinguíveis para quem lê, mesmo o banco sabendo que são
duas.

**Decisão**: acrescentar à spec um requisito de **leitura**, não de armazenamento. Nenhuma
migração, nenhum índice, nenhuma mudança de identidade.

### O caminho até o nome, e o que ele custa

Medido: `collected_issues → observed_repositories → cmpo_source_repositories → eo_organizations`.
**Três junções** para chegar ao nome.

E o nome qualificado **já contém a organização**: `leds-conectafapes/conectafapes-project`. Os
maiores repositórios, com o que a colisão realmente significa:

| repositório | issues | números distintos |
|---|---|---|
| `leds-conectafapes/conectafapes-project` | 2 669 | 2 669 |
| `leds-conectafapes/plataformas-project` | 713 | 713 |
| `leds-conectafapes/agentes-project` | 593 | 593 |

Dentro de um repositório o número **nunca** colide. A colisão é **entre** repositórios, e é
exatamente o que o nome ao lado do número resolve.

**Decisão**: mostrar o nome qualificado, que já traz a organização. Um campo, não dois — e a
junção até `eo_organizations` **não é necessária**, o que tira uma das três.

---

## R2 — O alcance: duas consultas, não nove

**Medido**: nove consultas montam item de trabalho com conceito derivado. Duas já trazem
rótulo (`fetch_issue`, `current_promotions`).

**Decisão**: `list_issues` e `list_divergences`. As cinco de hierarquia ficam de fora.

**Por quê**: é o escopo do protótipo aprovado, e a razão está no próprio desenho — rótulo ao
lado de uma árvore de pai e partes lê como ruído. A tela de hierarquia responde *"o que compõe
o quê"*, e o rótulo não participa dessa pergunta.

`promotion_history` fica de fora por razão diferente: ela mostra **como a decisão mudou ao
longo do tempo**, e o rótulo de hoje ao lado de uma decisão de julho seria comparar coisas de
instantes diferentes.

---

## R3 — De onde vem a lista de prefixos

**Decisão**: da declaração que **já existe** —`not_type_patterns` em
`github_issue_pattern_catalog.yaml`. A consulta **lê** essa lista; não a repete.

**A razão de não duplicar não é elegância**: duas listas divergem, e a divergência aparece
como **ausência silenciosa** na que ficou para trás. Alguém acrescenta `[Infra]` na base, a
tela continua sem mostrar, e ninguém nota — porque ausência de rótulo é estado legítimo.

**Verificado contra o dado real**: `[Portal ADM]` tem 68 issues, **não está na lista**, e
portanto **não vira rótulo**. Rodei a consulta e ele saiu como ausente. É a FR-004
funcionando antes de existir código.

**Alternativa descartada**: aceitar qualquer texto entre colchetes. Transformaria erro de
digitação em caracterização, e 248 das 500 issues do repositório têm título livre.

---

## R4 — Por que as duas origens não se juntam

**Decisão**: rótulo do campo e rótulo do título aparecem **os dois**, sem deduplicar e sem
normalizar grafia.

**O caso real**: a issue `[Back-end] Permitir importação de subrubricas` tem `backend` no
campo e `Back-end` no título.

Juntá-las exigiria decidir que `backend` e `Back-end` são a mesma coisa — e essa é uma
**interpretação**, exatamente o que a FR-009 proíbe aplicada ao nome. São dois atos de escrita
diferentes, em dois lugares diferentes, possivelmente por pessoas diferentes. Que signifiquem
o mesmo é provável; que a plataforma **afirme** isso é outra coisa.

E há o efeito colateral útil: mostrando as duas, quem lê vê que o time diz em dois lugares e
escreve de dois jeitos — que é informação sobre o time, e some no momento em que se
normaliza.

---

## R5 — Uma consulta, não uma por linha

**Decisão**: junção lateral com agregação — `array_agg(nome ORDER BY nome)` —, nunca
carregamento associado por linha.

**Por quê**: é a L38. Uma listagem de 100 itens com carregamento por linha faz 101 consultas, e
a medida de custo da tela deixa de valer.

**O `ORDER BY` dentro do agregado não é preferência.** Sem ordenação declarada, a ordem vem do
plano de execução e **muda entre execuções** — o teste passa hoje e falha na semana que vem,
sem ninguém tocar em nada. Já aconteceu neste repositório.

**Alternativa descartada**: guardar os rótulos desnormalizados numa coluna de arranjo em
`collected_issues`, no molde de `project_titles`. Duplicaria o que `issue_labels` já guarda
**com mais informação** — cor e a data em que o rótulo deixou de ser observado —, e criaria
duas verdades que divergem na primeira coleta que falhar no meio.

---

## R6 — O prefixo é lido, não coletado

**Decisão**: o rótulo vindo do título é derivado **no momento da leitura**, a partir do título
já guardado.

**O que isso evita**: coluna nova, migração, recarga de 5 033 linhas, e um segundo lugar onde
o mesmo fato passa a existir.

**O que isso custa**: o custo de derivar é pago em toda leitura em vez de uma vez na coleta.
Para um prefixo no começo de uma cadeia curta, é barato — e a alternativa custaria uma
recoleta a cada mudança da lista de prefixos.

**Consequência declarada**: acrescentar um prefixo à lista muda a tela **imediatamente**, sem
recoletar nada. É a propriedade que torna a lista editável na prática.
