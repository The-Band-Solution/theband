# Data Model — Feature 058

**Nenhuma migração.** As três medidas saem de tabelas que já existem, e o achado
central da pesquisa é que **duas delas nunca tiveram consumidor**.

## Tabelas lidas (nenhuma alterada)

| Tabela | O que fornece | Estado antes desta feature |
|---|---|---|
| `collected_change_requests` | quem abriu, e quando | lida sem recorte por equipe |
| `collected_artifact_evaluations` | a revisão, com autor humano ou robô | lida sem recorte |
| `eo_team_memberships` | o vínculo, com período e invalidação | **a fonte do recorte** |
| `spo_project_teams` | equipe ↔ projeto, com `linked_at` / `unlinked_at` | **nenhuma consulta usa os períodos** |
| `spo_project_repositories` | projeto ↔ repositório, com os mesmos períodos | **nenhuma consulta usa os períodos** |
| `collected_verifications` | a execução, com fase e repositório | lida por repositório, nunca por equipe |

---

## Estruturas calculadas

### `periodo`

O tipo que atravessa as três histórias.

```text
%{inicio: DateTime.t() | nil, fim: DateTime.t() | nil}
```

Borda `[início, fim)` — a mesma da feature 057.

**`nil` é desconhecido, e nunca "aberto desde sempre".** É a distinção que
`spo_project_teams.linked_at` e `eo_team_memberships.started_at` permitem, e que
nenhuma consulta respeitava.

### `interseccao`

```text
:intersecta
| :nao_intersecta
| {:parcial, [:inicio_desconhecido | :fim_desconhecido]}
```

**Três estados, e não dois.** O terceiro existe porque tratar `nil` como aberto é
o mesmo fallback silencioso que a feature 057 corrigiu no vínculo — e repeti-lo
com a lição escrita seria reincidência.

Quem consome trata os três. É o custo de não mentir sobre o que se sabe.

### `espera_por_revisao`

```text
%{
  change_request_id, numero, titulo,
  aberta_em: DateTime.t(),
  autor_person_id: Ecto.UUID.t() | nil,
  estado: {:revisada, duracao_em_horas} | {:aguardando, ha_dias}
}
```

**`{:aguardando, _}` não é tempo zero, e não some da lista.**

As solicitações que mais interessam são justamente as que ninguém revisou.
Omiti-las faria a mediana melhorar quanto **pior** a equipe estivesse — a medida
andaria para o lado errado sem ninguém notar.

### `quem_trabalhou`

```text
%{
  person_id, name, login,
  equipes: [%{team_id, name}],
  periodo: interseccao()
}
```

`equipes` é **lista** porque a mesma pessoa pode alcançar o projeto por mais de
uma. Ela aparece **uma vez**, com todas nomeadas — duas linhas somariam a mesma
pessoa.

### `taxa_do_pipeline`

```text
{:ok, %{
   sucesso: n, falha: n,
   interrompida: n, nao_executada: n, expirada: n,
   em_andamento: n,
   execucoes_consideradas: n,
   caminho: "repositórios dos projetos desta equipe no período"
 }}
| {:sem_projeto, %{equipe: nome}}
```

**As cinco fases são campos próprios**, e nenhuma é somada a "falhou". Cancelar é
decisão humana, e contá-la como quebra inflaria a taxa com o que ninguém quebrou
— a feature 037 já estabeleceu isso, e esta consome.

`em_andamento` fica **fora** de `execucoes_consideradas`: processo que ainda não
decidiu nada não é sucesso nem falha.

`execucoes_consideradas` é obrigatório porque **a cobertura do dado é
desconhecida** (R6). Uma taxa de 100% sobre três execuções e uma sobre trezentas
não são a mesma afirmação.

`{:sem_projeto, _}` é o relator, e não `{:ok, %{sucesso: 0, ...}}`. Zero diria
que o pipeline falhou; a verdade é que a plataforma **não sabe de quais
repositórios aquela equipe cuida**.

---

## O que **não** existe como estrutura, de propósito

| Não existe | Por quê |
|---|---|
| `taxa_por_ator` | R1 — responde outra pergunta, e o nome enganaria |
| `periodo_aberto_por_padrao` | `nil` é desconhecido; não há valor que o substitua |
| `tempo_medio_de_revisao` isolado | sem as em espera, a mediana anda para o lado errado |
| soma de `espera` entre pessoa e equipe | contam a mesma solicitação de modos diferentes |

---

## Relação com a ontologia

| Conceito | O que esta feature usa |
|---|---|
| `eo.team_membership` | o relator: pessoa, papel, equipe, período |
| `spo.project` | o projeto, e seus vínculos com equipe e repositório |
| `cmpo.source_repository` | onde o código mora, e onde o pipeline roda |
| `ciro.continuous_integration_process` | a execução, com as cinco fases |
| `cmpo.change_request` | a solicitação, e a espera que ela sofre |

Os períodos vivem nos **vínculos**, nunca nas pontas — é por isso que desligar
uma equipe de um projeto não apaga o que houve, e é o que torna a interseção
possível sem tabela nova.
