# Contrato — EO.organization_overview/1

**Módulo**: `TheBand.Ontology.SEON.EO` (fachada, defdelegate → `EO.Queries`)

**Escrito antes da implementação** (constituição, princípio VI).

> **Correção de 2026-08-28, no commit da implementação.** A versão anterior deste
> contrato incluía `projects` no retorno e uma função irmã
> `projects_without_organization/1`. A implementação mostrou o erro: projetos
> pertencem ao contexto **Projects**, e a EO consultá-los furaria a fronteira de
> módulo (AGENTS §7.1) para poupar um `Enum.group_by` na camada de apresentação. A
> tela compõe os dois contextos — `EO.organization_overview/1` +
> `Projects.list_projects/1` — e agrupa por `source_instance` ↔ `login`, com o grupo
> "sem organização identificada" nomeado (research R3).

## Assinatura

```elixir
@spec organization_overview(Tenant.t()) :: [overview()]

@type overview :: %{
        organization: Organization.t(),
        teams: [Team.t()],
        responsibles: [%{person: Person.t(), role_name: String.t()}]
      }
```

- Recebe o **tenant** como primeiro argumento — toda consulta é escopada (princípio V).
- Devolve uma lista, uma entrada por organização observada do tenant, ordenada por
  nome.
- `teams`: equipes com vínculo à organização, vigentes (sem `no_longer_observed_at`).
- `responsibles`: pessoas com vínculo vigente cujo papel carrega concessão de
  visibilidade com escopo `organization` não revogada — a definição única de
  "responsável", a mesma da regra de visibilidade #369. Cada entrada nomeia o papel
  pelo qual a pessoa responde. Uma passada por coleção, nunca consulta por linha
  (lição L38).

## Sucesso e erro

- Tenant sem organização observada → `[]` (lista vazia; a tela nomeia o estado).
- Organização sem equipe/responsável → listas internas vazias (a tela nomeia cada
  ausência; a organização **não** some).
- Não há caso de erro: leitura escopada; tenant inválido é bug do chamador
  (FunctionClauseError, não `{:error, _}`).

## O que esta API NÃO expõe, e por quê

- **Não expõe projetos** — são do contexto Projects (correção acima); a composição é
  da tela.
- **Não expõe contagens armazenadas** — qualquer contagem exibida deriva do tamanho
  das listas devolvidas (regra da casa: contagens derivam de entradas).
- **Não expõe membros das equipes** — a página da equipe já faz isso; incluir aqui
  duplicaria consulta e responsabilidade (princípio X).
- **Não expõe "responsável" por inferência de nome de papel** — só concessão
  declarada (regra #369).
- **Não recebe `opts` de paginação** — o piloto tem ~3 organizações por tenant;
  paginar aqui seria estrutura sem problema (princípio VIII). Se um tenant real
  passar de dezenas, o contrato ganha `opts` por emenda.
