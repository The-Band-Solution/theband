# Contrato — EO.organization_overview/1

**Módulo**: `TheBand.Ontology.SEON.EO` (fachada, defdelegate → `EO.Queries`)

**Escrito antes da implementação** (constituição, princípio VI). Se a implementação
mostrar que este contrato está errado, ele é corrigido **no mesmo commit**, com a
razão.

## Assinatura

```elixir
@spec organization_overview(Tenant.t()) :: [overview()]

@type overview :: %{
        organization: Organization.t(),
        teams: [Team.t()],
        responsibles: [%{person: Person.t(), role_name: String.t()}],
        projects: [ObservedProject.t()]
      }
```

- Recebe o **tenant** como primeiro argumento — toda consulta é escopada (princípio V).
- Devolve uma lista, uma entrada por organização observada do tenant, ordenada por
  nome.
- `teams`: equipes com vínculo à organização, vigentes (sem `no_longer_observed_at`).
- `responsibles`: pessoas com papel cuja concessão de visibilidade tem escopo
  organização (definição única de "responsável" — a mesma da regra de visibilidade
  #369). Cada entrada nomeia o papel pelo qual a pessoa responde.
- `projects`: projetos observados cujo `source_instance` casa com o login da
  organização. Projetos sem organização identificada não entram em nenhuma entrada —
  vivem na função irmã abaixo.

## Função irmã

```elixir
@spec projects_without_organization(Tenant.t()) :: [ObservedProject.t()]
```

Projetos observados do tenant cujo `source_instance` não casa com organização
nenhuma. A tela os exibe num grupo próprio, nomeado ("sem organização identificada")
— ausência nomeada, nunca omitida.

## Sucesso e erro

- Tenant sem organização observada → `[]` (lista vazia; a tela nomeia o estado).
- Organização sem equipe/responsável/projeto → listas internas vazias (a tela nomeia
  cada ausência; a organização **não** some).
- Não há caso de erro: leitura escopada; tenant inválido é bug do chamador
  (FunctionClauseError, não `{:error, _}`).

## O que esta API NÃO expõe, e por quê

- **Não expõe contagens armazenadas** — qualquer contagem exibida deriva do tamanho
  das listas devolvidas (regra da casa: contagens derivam de entradas).
- **Não expõe membros das equipes** — a página da equipe já faz isso; incluir aqui
  duplicaria consulta e responsabilidade (princípio X).
- **Não expõe "responsável" por inferência de nome de papel** — só concessão
  declarada (regra #369).
- **Não recebe `opts` de paginação** — o piloto tem ~3 organizações por tenant;
  paginar aqui seria estrutura sem problema (princípio VIII). Se um tenant real
  passar de dezenas, o contrato ganha `opts` por emenda.
