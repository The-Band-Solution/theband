# Validação da 076 — análise de rede

Como provar, de ponta a ponta, que a feature faz o que a spec pede. Não é guia de implementação: o
desenho está em [data-model.md](data-model.md) e nos [contratos](contracts/). O veredito de todo
comando é o **código de saída**, lido sem pipe (`AGENTS.md` §4): redirecione para arquivo, leia o
`$?` do próprio `mix`, e só depois leia o arquivo.

## Pré-requisitos

- `development` integrada na branch;
- PostgreSQL de desenvolvimento no ar (`docker compose up -d`) e `mix ecto.migrate` aplicado;
- os YAMLs de [`proposta-base/`](proposta-base/), com as emendas do plano revisadas, em
  `priv/knowledge_base/` (T007);
- a A7 decidida (T002) antes das tarefas que dependem dela.

## 1. A base

```bash
mix knowledge.validate > /tmp/076-kb.log 2>&1; echo "EXIT=$?"
mix knowledge.graph    > /tmp/076-kbg.log 2>&1; echo "EXIT=$?"
mix knowledge.test     > /tmp/076-kbt.log 2>&1; echo "EXIT=$?"
```

Esperado: `EXIT=0` nos três; o `knowledge.test` roda as perguntas de competência de
`network.structure`. **Defeito**: apagar `size_limit` de `network.analysis.parameters` faz
`NetworkAnalysis.Parameters.fetch!/0` levantar no teste da regra.

## 2. As migrações vão e voltam

```bash
mix ecto.migrate > /tmp/076-m1.log 2>&1; echo "EXIT=$?"
mix ecto.rollback --step 4 > /tmp/076-m2.log 2>&1; echo "EXIT=$?"
mix ecto.migrate > /tmp/076-m3.log 2>&1; echo "EXIT=$?"
```

Esperado: os três `0` (o `--step` é o número de migrações da feature: leituras, contas da
organização, tipo da conta, preenchimento; mais uma com a A7).

## 3. Os algoritmos contra as cinco redes conhecidas (SC-002)

```bash
mix test test/the_band/network_analysis/algorithms/ > /tmp/076-alg.log 2>&1; echo "EXIT=$?"
```

Estrela de 6, caminho de 4 (distância média 5/3, diâmetro 3, eficiência 13/18), dois grupos com uma
ponte, bipartida (autovetor converge por A + I), desconexa. Tolerância 1e-9, e 1e-6 relativo no
autovetor ([research.md R6](research.md#r6--os-algoritmos-em-elixir-puro)).

## 4. Reprodutibilidade (SC-003)

O teste de `compute/4` calcula a mesma leitura **10 vezes** e compara as dez, incluindo comunidades,
σ, Q_rand e posições, com `==`.

## 5. Os cenários de ataque

```bash
mix test test/the_band/network_analysis/ test/the_band/jobs/compute_network_analysis_test.exs \
         test/the_band_web/live/network_analysis_live/ > /tmp/076-sec.log 2>&1; echo "EXIT=$?"
```

Cada cenário A1–A22 de [seguranca.md](seguranca.md#cenários-de-ataque-para-o-qa) é um teste, e
cada guarda é vista **reprovando** com o defeito injetado (cópia do arquivo antes de injetar, `diff`
depois de restaurar). A evidência — comando e código de saída, com e sem defeito — vai na issue.

## 6. A tela, contra o protótipo

1. `mix phx.server`, entrar como administração: o menu tem **Network analysis**, marcado nas páginas
   da área; `/organizations/<id>/review-network` leva à área;
2. a rede de revisão da área tem os mesmos números da página da 073 na mesma janela;
3. trocar para *assignment*: as contagens, a frase do que a aresta é, o grafo, as comunidades, os
   hubs, a distância, σ, as posições e um perfil;
4. entrar com uma conta de alcance parcial (só vínculo de equipe): nomes só dos alcançados,
   agregados *"People outside your reach — community N (k)"* com k ≥ 3, hubs *"Among the people you
   reach"* (e, pela DS1, sem papéis de colegas), perfil de pessoa de fora dá *"not found"*;
5. conta sem alcance: só medidas da rede e o próprio perfil (DS5);
6. largura de telefone: sem rolagem lateral, o grafo vira lista (SC-007);
7. o QA confere item a item contra `prototipo/PROMPT.md` §3, com as divergências de R21.

## 7. Contra a origem (SC-001) 👤

Para uma organização real e uma janela, contar à mão na origem as issues abertas na janela, as
designações e as exclusões por motivo, e comparar com a tela. Só agregados.

## 8. Os gates

```bash
mix gates > /tmp/076-gates.log 2>&1; echo "EXIT=$?"
```

Esperado: `EXIT=0`. `mix.lock` e `assets/package.json` sem diferença contra `development` (R22).
