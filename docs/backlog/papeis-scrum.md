# Papéis Scrum: cadastro declarado e alocação

Papel Scrum não vem do GitHub. Vem de declaração do tenant — e a decisão de
cadastrar manualmente foi tomada pela pessoa mantenedora em 2026-08-10.

| Item | Issue | Prioridade |
|---|---|---|
| Épico — papéis cadastrados e alocados | [#98](https://github.com/The-Band-Solution/theband/issues/98) | P1 |
| Cadastrar os papéis reconhecidos pelo tenant | [#99](https://github.com/The-Band-Solution/theband/issues/99) | P1 |
| Alocar uma pessoa a um papel, com período | [#100](https://github.com/The-Band-Solution/theband/issues/100) | P2 |

Estão no product backlog — itens do Projects v2 **sem iteration atribuída**. É o
que os distingue de trabalho puxado.

## De onde veio a necessidade

`github-to-sro.md`, linha 39, já registrava a lacuna quando o mapeamento foi
escrito:

| Conceito | Observável no GitHub? | Por quê |
|---|---|---|
| `sro.product_owner` | ❌ | não há papel Scrum no GitHub |
| `sro.scrum_master` | ❌ | idem |
| `sro.developer` | ⚠️ por regra | assignee de issue ou autor de PR — **papel presumido, não declarado** |

Presumir Developer a partir de atividade responde a pergunta errada. Quem abriu
PR trabalhou no projeto; não decorre que a organização o reconheça como
desenvolvedor daquele time, nem desde quando. A presunção continua sendo item
próprio — G4.7 — e exige proveniência de inferência.

**Cadastro manual não é contorno da lacuna. É a resposta certa para um conceito
que existe por declaração**, e a proveniência é `project_decision`, como já
acontece com Product Owner na skill do papel.

## O que a derivação já decidiu, e o backlog não pode contrariar

Rodando `scripts/derive_information_model.py --ontology sro`, os doze papéis da
SRO aparecem assim — e a frase é do próprio derivador:

```text
sro.product_owner:      role elevado a eo.person [outra ontologia];
                        materializa pelo relator, não por discriminador
sro.product_owner_role: role elevado a eo.organizational_role [outra ontologia];
                        materializa pelo relator, não por discriminador
```

### Papel não é coluna

Uma coluna `type` em `eo_people` com valor `product_owner` diria que ser Product
Owner é propriedade da pessoa. Não é. Ela responderia "qual o papel desta
pessoa" e perderia três coisas:

| Perde | Por que importa |
|---|---|
| **em qual contexto** | a mesma pessoa é PO num time e desenvolvedora em outro |
| **desde quando** | "quem era o PO no sprint 3" é pergunta legítima, e a coluna só sabe o hoje |
| **se há mais de um** | uma coluna guarda um valor; alocações são várias |

É a ADR 0004 D5. E ela quase foi violada em silêncio: até 2026-08-10 o derivador
só aplicava essa guarda quando o alvo do lifting estava na **mesma** ontologia,
e CMPO e SPO já produziam `eo.person.type += {project_person_stakeholder}` com o
CI verde. Ver [L22](../sprints/licoes-aprendidas.md).

### Papel e agente no papel são conceitos distintos

| Conceito | O que é | Onde materializa |
|---|---|---|
| `sro.product_owner_role` | o papel organizacional | linha em `eo_organizational_roles` |
| `sro.product_owner` | quem o desempenha | não materializa sozinho — é role |
| `sro.product_owner_membership` | a alocação | **tabela própria**, relator |

O terceiro é o que torna os dois primeiros úteis. Sem ele, o catálogo é uma lista
que ninguém referencia.

## Ordem, e por que ela não é preferência

Alocar exige que o papel exista. Não é sequência escolhida por conveniência: a
alocação tem chave estrangeira para o papel, e construir na ordem inversa
produziria uma tela de alocação com um campo que não tem para onde apontar.

## Fatia vertical nas duas

Cada uma entrega tela junto. Um catálogo sem tela é infraestrutura sem
consumidor, que é a [L21](../sprints/licoes-aprendidas.md) — registrada porque
`resume_observation/3` passou um sprint testado, verde e inalcançável por
qualquer pessoa.

## Limitação declarada do Projects v2

`sro.user_story.importance` é decimal, e o projeto não tem campo numérico de
importância — só `Priority`, que é seleção única de P0 a P2. A ordem do backlog
é registrada nessa escala, com a perda de granularidade que ela impõe.

Improvisar com label trocaria um dado ordenável por um rótulo que não ordena. A
alternativa correta é criar o campo numérico, e isso mexe na configuração do
projeto — o que causou a [L11](../sprints/licoes-aprendidas.md) e custou
reatribuir 96 itens. **Fica declarado, não improvisado.**

## O que estes itens não fazem

| Não faz | De quem é |
|---|---|
| inferir papel a partir de atividade no GitHub | G4.7, em `github-to-sro.md` |
| criar papel fora do catálogo da ontologia | papel inventado não responde CQ15 nem CQ16 |
| guardar papel como atributo da pessoa | ADR 0004 D5 — e agora o derivador impede |
| anotar RSRO e SYS_SWO | pendência própria, 16 conceitos sem estereótipo |
