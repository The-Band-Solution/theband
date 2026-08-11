# Contrato — telas de issues e de quadros

O que cada tela mostra, **e o que ela não mostra**. A segunda parte é a que evita o
defeito: uma tela que exibe o que não devia é mais difícil de corrigir depois que
alguém já tomou decisão com aquilo.

---

## `/trabalho` — issues, promoções e lacunas

### O que a tela afirma

Por organização observada:

```
leds-conectafapes                                       recoletar

  repositórios ........ 8 observados, 1 excluído, 1 arquivado
  issues coletadas .... 142

  PROMOVIDAS                          124
    user story atômica ..... 71
    épico .................. 12
    tarefa pretendida ...... 33
    defeito ................. 8

  NÃO PROMOVIDAS                       18
    tipo desconhecido ...... 14   Spike (9), Chore (5)
    tipo ausente ............ 4

  DIVERGÊNCIAS                          6
    Epic sem sub-issues ..... 5   promovidas a user story atômica
    Story com partes ........ 1   promovida a épico
```

**As três seções somam o total, sempre.** 124 + 18 = 142. Se não somar, a tela
mostra o desvio em vermelho em vez de esconder — porque a diferença significa
promoção não registrada, e é defeito de coleta, não de exibição.

### O que a tela **não** mostra

| Não mostra | Por quê |
|---|---|
| um "total de user stories" somando épicos e atômicas | são coisas diferentes: tarefa se liga a atômica, e escopo se conta na folha. A soma seria contagem dupla |
| issue não promovida como se fosse escopo | ela é lacuna, e aparece na seção de lacunas |
| percentual de cobertura da promoção | um número que sobe quando alguém tipa issues, e não quando o produto melhora. Vira meta e deixa de medir |
| tipo de issue normalizado | o nome cru é o dado — "tipo desconhecido: Spike (9)" diz onde a regra precisa mudar |

### A divergência é o que a tela existe para mostrar

FR-035. Não é erro a corrigir na plataforma: é sinal sobre o processo do time.

**Epic sem sub-issues** costuma ser épico abandonado sem decomposição. **Story com
partes** costuma ser história que cresceu e ninguém retipou. As duas são
informações que só aparecem porque a estrutura vence o rótulo — e desapareceriam se
a plataforma gravasse apenas o resultado da promoção.

### Estado vazio, distinguindo três casos

Um estado vazio que diz "nenhuma issue" para os três casos abaixo faz alguém
concluir que o time não trabalha.

```
Nenhuma coleta de issues ocorreu ainda.        nunca coletou
Nenhum repositório desta organização tem issues.  coletou, e está vazio
8 repositórios observados, nenhum coletado nesta execução.  interrompida
```

FR-036 exige a distinção entre coletado-e-vazio e não-coletado.

---

## `/quadros` — quadros, campos e backlogs

### O que a tela afirma

```
The Band                                    quadro · não é um projeto

  itens ............... 107
  product backlog ..... 6      itens sem iteração
  sprint backlogs ..... 2      Sprint 001 (73), Sprint 002 (28)
  iterações futuras ... 0      planejadas, ainda não ocorridas

  CAMPOS                       17
    interpretados ....... 1    Estimate → sro.user_story.complexity
    não interpretados ... 16   Priority, Size, Status, ...

  ORDEM DO BACKLOG
    Este quadro não tem campo numérico de importância.
    A ordem do product backlog não é derivável, e nenhum
    outro campo é usado como substituto.
```

Três coisas que essa tela diz e que nenhuma outra diria:

**"quadro · não é um projeto"**, ao lado do nome. Não é ornamento: é a decisão de
2026-08-11 tornada visível. Sem isso alguém contaria dois projetos nesta
organização, que tem dois quadros.

**"não interpretados: 16"** com os nomes. FR-025. O valor está guardado e é
consultável; o que não existe é a conversão para atributo de ontologia.

**A ausência de importância, por extenso.** FR-026. Uma lista sem ordem, sem essa
frase, faz o usuário supor que a plataforma falhou em ler a ordem.

### O que a tela **não** mostra

| Não mostra | Por quê |
|---|---|
| o quadro como projeto de software | quadro é planejamento e visualização |
| "projeto Scrum" | adotar Scrum não é observável; iteração pode ser recorte de Kanban |
| `Priority` como importância | mapeamento por semelhança de nome é antipadrão declarado |
| ordem inventada a partir de outro campo | FR-026 proíbe substituto |
| iteração futura como sprint | um sprint que não começou não ocorreu |
| item de rascunho como escopo | é intenção de alguém, não requisito do produto |

### Iteração futura, exibida pelo que é

```
  iterações futuras ... 2

    Sprint 004    início 18/08    planejada, ainda não ocorrida
    Sprint 005    início 25/08    planejada, ainda não ocorrida
```

Nunca sob o rótulo "sprint". Elas são `spo.specific_intended_project_process` —
intenção —, e o texto diz isso em português comum: *planejada, ainda não ocorrida*.

**E uma iteração que começou hoje pode aparecer aqui até a próxima coleta.** A tela
mostra a data da última coleta ao lado, para que a diferença fique atribuível ao que
ela é — a plataforma afirma o que observou — e não a atraso da tela.

---

## Repositórios, e os três estados que não se confundem

Na lista de repositórios de uma organização:

```
theband                    observado          142 issues
eo_lib                     observado           18 issues
libbase                    arquivado           7 issues   arquivado na origem
experimentos               excluído            — decisão do tenant, 03/09
infra-antiga               inacessível         — credencial não alcança desde 11/08
```

| Estado | O que é | Coleta? | Marca ausência? |
|---|---|---|---|
| observado | normal | sim | sim, quando a issue não reaparece |
| arquivado | fato da origem — o GitHub diz | sim | sim |
| excluído | decisão do tenant | **não** | **não** — FR-005 |
| inacessível | credencial perdeu alcance | **não** | **não** — FR-006 |

**Os dois últimos não marcam ausência, e a tela precisa deixar isso legível.** Quem
vê "excluído" e depois vê as issues daquele repositório sem marca de ausência tem de
entender que é assim de propósito: a plataforma parou de olhar, e isso não é o mesmo
que o dado ter sumido.

`inacessível` também aparece como motivo de atenção na ferramenta conectada, nomeando
o repositório.

---

## Isolamento

Toda tela filtra por tenant. Recurso de outro tenant devolve **"não encontrado"**,
nunca "sem permissão" — dizer "sem permissão" já entrega que o recurso existe.

Verificado pela violação: dois tenants povoados, e nenhum dado de um aparece na tela
do outro por nenhum caminho (SC-012).

---

## Sem segredo em tela

Nenhuma destas telas exibe credencial. As de ferramenta conectada já cobrem esse
caso, e o teste que vale é o da violação: procurar o segredo no HTML e exigir não
encontrar.

---

## `/ferramentas/nova` e `/ferramentas/:id/mapeamento`

**Não é tela própria: é parte de definir a ferramenta.** Decisão da pessoa
mantenedora em 2026-08-11 — o mapeamento entre os conceitos da organização e os da
ontologia é configurado **ao conectar**, e vale **por organização**.

Duas razões, e a segunda é a que muda o desenho:

**Configurar ao definir evita coletar sabendo que vai errar.** Perguntar depois da
primeira coleta significa classificar errado e reprocessar. Perguntar antes exige uma
consulta à origem no momento da conexão — e é o que permite a plataforma **mostrar os
tipos que encontrou** em vez de pedir para a pessoa digitar nomes.

**O escopo é a organização, não o tenant.** Uma organização usa `Feature`, outra usa
`História`, outra criou `Spike`. Um mapeamento por tenant obrigaria todas a
concordarem, e a primeira divergência viraria lacuna sem culpado — porque nenhuma das
duas estaria errada.

### O passo novo no fluxo de conexão

```
1. instância e organização        já existe
2. credencial                     já existe — validada antes de gravar
3. MAPEAMENTO                     ← o passo novo, com os tipos já descobertos
4. confirmar
```

O passo 3 só tem o que mostrar porque o 2 passou: a consulta que descobre os tipos
usa a credencial recém-validada. Colocá-lo antes exibiria campos vazios.

**Conectar não é bloqueado por mapeamento pendente** (FR-041c). "Usar o padrão" é uma
saída legítima do passo 3, e os tipos não reconhecidos aparecem como lacuna — que é o
que a tela de issues já mostra.

### O que a tela afirma

```
The-Band-Solution                          tipos de issue desta organização

  TIPOS USADOS
    Feature ......  15 issues   →  épico OU user story atômica
                                   a ESTRUTURA decide: com partes que são user
                                   stories é épico; sem partes, ou com partes que
                                   são tarefas, é atômica
    Task ......... 128 issues   →  tarefa pretendida
                                   exige pai atômico (sro.rule07); 1 sem pai
    Bug ..........   1 issue    →  defeito

  PREVISTOS PELA REGRA GLOBAL, NÃO USADOS AQUI
    Epic                            não usado — `sro.epic` é derivado da estrutura
    User Story                      não usado — `Feature` cumpre o papel

  NÃO RECONHECIDOS                  0
    (quando houver: o nome, a contagem, e o botão de declarar o destino)

  CAMPOS DO QUADRO                 17
    interpretados ...... 1     Estimate → sro.user_story.complexity
    não interpretados .. 16    Priority, Size, Status, ...

    sro.user_story.importance      NENHUM campo mapeado
      Nenhum campo numérico de importância existe neste quadro. A ordem do
      product backlog não é derivável, e nenhum outro campo é usado como
      substituto.
```

**"não usado aqui" é o ponto da tela.** `Epic` e `User Story` não existem nesta
organização, e isso **não é erro nem falta de configuração** — a regra global os
lista porque outras organizações os criam. Sem essa distinção, quem abrisse a tela
concluiria que falta configurar algo.

### O que a tela **não** faz

| Não faz | Por quê |
|---|---|
| criar tipo de issue na organização | alteraria a configuração da organização para casar com um documento, invertendo a precedência que a própria regra declara |
| aceitar `Priority` → `importance` | escala ordinal para atributo decimal; é o antipadrão de mapeamento por semelhança de nome |
| aceitar declaração que contraria axioma | mapear um tipo para `sro.epic` sem exigir partes contraria `sro.rule05`, e a recusa nomeia o axioma |
| esconder tipo desconhecido | é a lacuna, e é o dado que diz onde a regra precisa mudar |
| editar a regra global | a declaração é **do tenant**, e sobrescreve sem alterar o padrão de ninguém |

### Três níveis de precedência, e a tela mostra de onde veio

```
regra global da rede                    padrão de todas as organizações
  └─ regra do tenant, em YAML           padrão deste tenant
       └─ configuração desta ferramenta  vale só para esta organização
```

| Origem | Como aparece |
|---|---|
| regra global | *padrão da rede* |
| YAML do tenant, em `rules/tenants/` | *declarado no repositório*, com a versão |
| configuração desta organização | *declarado por <pessoa>, em <data>* |

As duas têm o mesmo efeito na promoção. **A diferença é auditável de propósito**: uma
passou por revisão de código, a outra não — e quem lê uma medida derivada precisa
poder saber qual das duas a sustenta.

### O que a recusa precisa dizer

Recusa que só diz "inválido" faz a pessoa tentar de novo igual. As três recusas
possíveis nomeiam a causa:

```
Priority → sro.user_story.importance
  Recusado. `importance` é decimal com escala declarada — quão valiosa a user
  story é para a organização. `Priority` é seleção única, e os valores P0, P1 e P2
  foram escolhidos por esta organização. Converter um no outro atribuiria escala
  a um rótulo.

Chore → sro.epic
  Recusado por sro.rule05: épico tem ao menos uma parte, e ser épico é
  consequência de ter partes — não um destino que se escolhe. Se as issues de
  tipo Chore têm partes que são user stories, elas já são promovidas a épico
  pela estrutura.

Spike → sro.user_story
  Aceito com ressalva: `sro.user_story` é abstrato na promoção — o destino
  concreto sai da estrutura, entre épico e atômica. A declaração é gravada como
  rota para user story, e a estrutura decide qual.
```
