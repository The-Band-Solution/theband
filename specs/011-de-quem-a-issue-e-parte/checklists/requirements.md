# Specification Quality Checklist: de quem cada issue é parte

**Purpose**: Validar completude e qualidade da especificação antes do planejamento
**Created**: 2026-08-12
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Sem detalhe de implementação (linguagem, framework, API)
- [x] Focada em valor para quem usa
- [x] Escrita para quem decide, não para quem implementa
- [x] Todas as seções obrigatórias completas

## Requirement Completeness

- [x] Nenhum marcador `[NEEDS CLARIFICATION]` restante
- [x] Requisitos testáveis e sem ambiguidade
- [x] Critérios de sucesso mensuráveis
- [x] Critérios de sucesso independentes de tecnologia
- [x] Cenários de aceitação definidos para as três user stories
- [x] Casos de borda identificados — seis
- [x] Escopo delimitado, com o que fica fora e por quê
- [x] Dependências e premissas declaradas

## Feature Readiness

- [x] Cada requisito funcional tem critério de aceitação
- [x] Os cenários cobrem o fluxo principal
- [x] A feature atende aos resultados mensuráveis
- [x] Nenhum detalhe de implementação vazou

## A medida mudou o pedido, e é o que esta validação registra

O pedido foi *"coloque o seu US ou EPIC, se existir"*. Medir as duplas de conceito mostrou que **"US
ou EPIC" não cobre os casos**, e que a coluna carrega mais informação do que o pedido supunha:

| o que a medida mostrou | o que entrou na spec |
|---|---|
| **12** issues têm pai que é **defeito** | FR-003: a linha diz o **conceito** do pai, não uma de duas palavras |
| **293** têm tarefa direto sob **épico** — violação da `sro.rule07` | FR-005: a linha diz que a relação **viola a regra**, com texto próprio |
| atender e compor são **duas** relações, e a 006 as separou | FR-004: as duas nunca são chamadas pelo mesmo nome |
| **36** issues têm mais de um pai | FR-008 e FR-009: dizer que há mais de um, e ser determinístico |
| **57** vínculos têm pai em outro repositório | FR-010: identificar o repositório, porque `#12` existe em vários |

**Ampliar o pedido aqui não é inflar a spec** — é o oposto do que aconteceu na feature 007, onde eu
inventei quatro estados para um símbolo. A diferença: cada requisito acima tem um **número medido** que
o exige. Sem FR-003, doze linhas ficariam erradas; sem FR-005, 293 esconderiam um sinal que a
plataforma já produz.

## Os dois defeitos que a medida achou fora da feature

**1. `fetch_parent/2` com `limit: 1` sem `order_by`.** Usada no detalhe da issue. Para as **36** issues
com mais de um pai, devolve um pai arbitrário, e o resultado pode mudar entre execuções.

É a família da **L20**: estado derivado do "um" precisa de desempate determinístico. A lista herdaria o
defeito se reusasse a função como está, e FR-009 existe por causa disso.

**2. Filha promovida a defeito não aparece no detalhe do pai.** `list_composition/2` filtra épico e
user story, `list_attendance/2` filtra tarefa, e `list_unpromoted_parts/2` filtra quem **não tem**
conceito. Defeito não cai em nenhuma: **33 vínculos** invisíveis na tela do pai, sem erro nenhum.

É a família do **sucesso silencioso**. Achado ao decidir a FR-004b, e é a razão de a coluna ter um
quarto caso em vez de três.

**As duas vão para o backlog com número.** Nenhuma das duas é corrigida nesta feature: as duas são de
outra tela.

## Notes

Nenhum item incompleto.

**Medido antes de escrever**, com a promoção **vigente** de cada issue: 4 529 issues vigentes,
**1 630 com pai**, **2 899 sem**, e **1 666 vínculos**. As duplas: 1 136 tarefa sob user story, 293
tarefa sob épico, 178 user story sob épico, 21 defeito sob épico, 14 épico sob épico, 7 defeito sob
user story, 7 tarefa sob defeito, 5 user story sob user story, 5 defeito sob defeito.

**A soma fecha em 1 666 exatamente** — e foi isso que provou que o "545 sem conceito" da primeira
medida era artefato de juntar o histórico de promoções em vez da vigente.

**E a primeira versão desta spec errou aqui**: escreveu "1 666 issues com pai" e derivou 2 863 como
complemento. 1 666 é a contagem de **vínculos**; as issues são **1 630**, e a diferença de 36 são
exatamente as issues com mais de um pai. Corrigido antes do plano, e registrado porque é a **L30**
cometida dentro do documento que existe para medir — duas grandezas com nomes parecidos, somadas sem
conferir contra a origem.
