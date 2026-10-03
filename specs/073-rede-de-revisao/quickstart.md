# Validação da 073 — rede de revisão

Como provar, de ponta a ponta, que a feature faz o que a spec pede. Não é guia de implementação:
o desenho está em [data-model.md](data-model.md) e nos [contratos](contracts/). O veredito de todo
comando é o **código de saída**, lido sem pipe (`AGENTS.md` §4).

## Pré-requisitos

- `development` integrada na branch, com a #1181 (`2535f6d`): `git merge-base --is-ancestor 2535f6d HEAD; echo $?` dá `0`;
- PostgreSQL de desenvolvimento no ar (`docker compose up -d`), e `mix ecto.migrate` aplicado;
- os YAMLs aceitos a partir de [`proposta-base/`](proposta-base/) e copiados para `priv/knowledge_base/`;
- para a tela: o protótipo de [`prototipo/`](prototipo/) **aprovado** pela pessoa mantenedora.

## 1. A base

```bash
mix knowledge.validate > /tmp/kb.log 2>&1; echo "EXIT=$?"
mix knowledge.test     > /tmp/kbt.log 2>&1; echo "EXIT=$?"
```

Esperado: `EXIT=0` nos dois. O `knowledge.test` confere que as duas regras têm as chaves de
[data-model.md §3](data-model.md#3-o-que-se-declara-na-base) e que as quatro medidas respondem à
necessidade declarada.

## 2. A migração vai e volta

```bash
mix ecto.migrate; echo "EXIT=$?"
mix ecto.rollback --step 1; echo "EXIT=$?"
mix ecto.migrate; echo "EXIT=$?"
```

Esperado: os três `0`, e `\d review_network_readings` mostra o índice único e a FK composta.

## 3. Os cenários de ataque e de comportamento

```bash
mix test test/the_band/review_network/ test/the_band/jobs/compute_review_network_test.exs \
         test/the_band_web/live/review_network_live/ > /tmp/rn.log 2>&1; echo "EXIT=$?"
```

Cada cenário A1–A18 de [seguranca.md](seguranca.md#cenários-de-ataque-para-o-qa) é um teste, e
**cada guarda é vista reprovando com o defeito injetado** antes de ser aceita, com cópia do arquivo
antes de injetar. A evidência (comando e código de saída, com e sem defeito) vai na issue.

Os que não vêm da segurança:

| prova | o que se assere |
|---|---|
| invariante | pares da janela = revisões na rede + as três exclusões |
| FR-012, SC-005 | `compute/3` com o mesmo `now` dez vezes: as dez leituras são iguais, campo a campo, exceto `id` e `inserted_at` |
| US1, cenário 3 | organização sem revisão: concentração `{:ausente, :sem_revisao_na_janela}`, e o HTML não contém `0%` |
| US2, cenário 2 | Caio: `received: {:ausente, :sem_solicitacao_revisada}` |
| US3 | dois grupos sem aresta entre eles: dois tamanhos, ordenados |
| amostra pequena | uma revisão: os números aparecem, com `{:pequena, 10}` |
| FR-018a | a lista sai em ordem de nome com as medidas invertidas |
| teto de consultas | `read/4` com 5 e com 50 pessoas faz o mesmo número de consultas |

## 4. O cálculo no banco de desenvolvimento

No `iex -S mix`, com uma organização que tem revisões coletadas:

1. enfileirar `TheBand.Jobs.ComputeReviewNetwork.enqueue(tenant_id, organization_id)` e esperar o
   job terminar;
2. conferir que há **três** linhas em `review_network_readings` para a organização, e que rodar de
   novo continua deixando três, com ids novos;
3. conferir o log: uma linha por janela, sem nome, login nem `person_id`.

## 5. SC-001: a contagem manual

Para a janela de 90 dias da leitura, contar **direto nas tabelas**, só com agregados:

- pares (revisor, solicitação) distintos com estado contável, enviados na janela, nos repositórios
  observados da organização;
- quantos têm bot ou aplicativo, quantos têm conta sem pessoa, quantos são auto-revisão;
- o restante, a soma dos pesos.

Os números têm de bater **sem diferença** com a tela de quem administra. A consulta é escrita na
tarefa de aceitação, e não aqui, para não virar uma segunda implementação.

## 6. A tela

Com o servidor no ar (`mix phx.server`):

- **administração**: `/organizations/<id>/review-network` mostra total, revisores e as três frações
  sem nome, com a janela ao lado; trocar para `?window=30` recalcula sem enfileirar job (conferir
  `oban_jobs`);
- **conta de alcance parcial**: os nomes de quem está fora não aparecem em lugar nenhum do HTML, a
  tela diz a regra do recorte e não diz quantas revisões ficaram de fora;
- **`?window=36500`** volta à janela padrão;
- **organização de outro tenant**: *"Organization not found."*;
- **telefone** (375 px): tudo empilhado, sem rolagem horizontal;
- **SC-003**: alguém que coordena responde *"a revisão está concentrada?"* em menos de um minuto,
  cronometrado, na aceitação.

## 7. Os gates

```bash
mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?"
```

Esperado: `EXIT=0`. Lido depois com `tail -40 /tmp/gates.log`, e o veredito é o número acima.
