# Contrato — regra de associação na transformação

**Feature**: 002 · **Achado**: F5 da [análise ontológica](../ontology-analysis.md) · **Base**: [ADR 0004](../../../docs/adr/0004-modelo-de-informacao-one-table-per-kind.md)

## O que existe hoje

`derive_information_model.py` gera chave estrangeira em exatamente dois casos:

| Origem | Resultado |
|---|---|
| `part_whole` entre duas tabelas | FK na tabela da parte |
| relação cujo *source* é `relator` | FK na tabela do relator |

Uma `association` de subkind elevado para kind **não produz nada**. Declarar a
relação equipe↔organização sem tocar no derivador não faz a coluna aparecer.

## A regra nova

> Associação com destino em kind e cardinalidade `many → one` vira chave
> estrangeira na tabela do kind de origem.

Com duas qualificações:

| Origem da relação | Coluna gerada |
|---|---|
| kind | FK `NOT NULL` quando a cardinalidade do destino é `one` |
| **subkind elevado** | FK **anulável**, mais `check_constraint` ligando a obrigatoriedade ao valor do discriminador |

A segunda qualificação é o que o caso concreto exige. A relação parte de
`eo.organizational_team`, elevado a `eo.team`; uma FK obrigatória forçaria toda
equipe de projeto a ter organização, o que é falso — projeto entre organizações
não tem uma só.

```text
eo_teams.organization_id  uuid NULL  → FK (association)
check: organization_id IS NOT NULL OR type <> 'organizational_team'
```

## Onde a regra é declarada

Em `transformations/ontology_to_information_model.yaml`, junto das demais — o
artefato existe para que a transformação seja **declarada e revisável**, não
escondida no script. O script implementa o que o artefato diz.

## Garantias

**A saída anota a origem de cada FK**, como já faz para parthood e mediação. Sem
isso, quem lê o modelo derivado não sabe qual regra produziu qual coluna, e a
terceira regra torna a saída ambígua.

**Nenhuma FK existente muda.** A regra é aditiva: relações `part_whole` e de
relator continuam gerando exatamente o que geram hoje. A derivação de todas as
outras ontologias tem de sair idêntica — é o teste de regressão da mudança.

## O que esta regra NÃO faz

| Ausente | Razão |
|---|---|
| gerar FK para associação `many → many` | exigiria tabela associativa, que é decisão de modelagem, não de tradução. Quando aparecer, entra como regra própria com sua justificativa |
| gerar FK para associação cujo destino é subkind | o destino tem de ser kind; subkind não tem tabela para a FK apontar |
| inferir `check_constraint` para relações que não partem de subkind | não há discriminador a que ligar a obrigatoriedade |
| substituir `part_whole` por associação | são relações diferentes. Escolher associação por conveniência do gerador seria modelar de trás para frente — risco R1 da análise |
