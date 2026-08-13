# Tarefas — Validador Elixir à paridade com o Python (#177)

**Spec**: [spec.md](./spec.md) · **Plano**: [plan.md](./plan.md)

## Fase 1 — Fundação

- [x] T001 Indexar conceitos, relações e dependências
  - **Pronta quando**: nada além do repositório
  - **Descrição**: `indexar/1` em `lib/the_band/ontology/yaml_validator.ex` monta, numa
    passada, o mapa de conceitos, o de relações e o de dependências declaradas. A dependência
    sai do `ontology.yaml`, chave `dependencies` na **raiz** — deduzi-la dos usos faria cada
    referência autorizar a si mesma. Plano D1
  - **Feita quando**: o mapa de dependências tem as 12 ontologias; nenhuma verificação varre a
    lista de artefatos mais de uma vez
  - **Teste**: `validador_a_paridade_test.exs` — "a dependência declarada autoriza a
    referência", que reprova um validador que reprove toda referência entre ontologias

- [x] T002 Corrigir o tipo do artefato no carregador
  - **Pronta quando**: T001
  - **Descrição**: `classify/2` em `yaml_loader.ex` escolhe a chave de topo pela **precedência
    declarada** e pelo valor ser conteúdo (mapa ou lista), não pela ordem das chaves do YAML.
    `kind_from/1` passa a usar tabela literal. Plano D4
  - **Feita quando**: as 12 ontologias são classificadas como `:ontology`; os 4 arquivos de
    perguntas de competência viram `:competency_questions`; o resultado é o mesmo antes e
    depois de `app.config`
  - **Teste**: `validador_a_paridade_test.exs` — "as doze ontologias são reconhecidas como
    ontologia" e "o arquivo de perguntas de competência não é confundido com ontologia"

## Fase 2 — As nove verificações que faltavam (US1, US2)

- [x] T003 [US1] Id no padrão `ontologia.conceito`
  - **Pronta quando**: T001
  - **Descrição**: `ids_fora_do_padrao/1`, minúsculas, um ponto. Id é contrato — mapeamentos,
    regras e perguntas apontam para ele
  - **Feita quando**: um id como `UFO::Agent` reprova nomeando o arquivo
  - **Teste**: "id fora do padrão `ontologia.conceito`"

- [x] T004 [US1] `parent` e `is_role_of` existem e respeitam a direção
  - **Pronta quando**: T001
  - **Descrição**: `referencias_de_conceito/1`; os dois lados pelo prefixo do id. Plano D3
  - **Feita quando**: pai inexistente reprova; uso sem dependência declarada reprova; uso **com**
    dependência declarada passa
  - **Teste**: "conceito aponta para pai inexistente", "conceito usa outra ontologia sem
    declarar a dependência", "a dependência declarada autoriza a referência"

- [x] T005 [US1] Origem e destino de relação existem
  - **Pronta quando**: T001
  - **Descrição**: `referencias_de_relacao/1`, mesma regra de dependência
  - **Feita quando**: `target` inexistente reprova nomeando o conceito
  - **Teste**: "relação aponta para conceito inexistente"

- [x] T006 [US1] Papel alcança o tipo rígido que o fundamenta
  - **Pronta quando**: T001
  - **Descrição**: `papel_sem_fundamento/1` — `role` sem `is_role_of` nem `parent` não tem
    identidade, e a tabela derivada dele não sabe a quem pertence
  - **Feita quando**: um `role` solto reprova
  - **Teste**: "papel sem `is_role_of` nem `parent` não tem identidade"

- [x] T007 [US1] Módulo listado tem arquivo
  - **Pronta quando**: T001
  - **Descrição**: `modulos_ausentes/1` — módulo prometido no `ontology.yaml` e sem arquivo é
    promessa sem lastro
  - **Feita quando**: módulo inexistente reprova nomeando o `ontology.yaml`
  - **Teste**: "módulo listado no `ontology.yaml` e sem arquivo"

- [x] T008 [US1] Pergunta de competência referencia o que existe
  - **Pronta quando**: T002 — sem o tipo correto a verificação não roda
  - **Descrição**: `perguntas_de_competencia/2`. **Antes de T002 esta verificação existia e
    nunca executava**, porque nenhum artefato tinha o tipo que ela filtra
  - **Feita quando**: pergunta que aponta para conceito inexistente reprova
  - **Teste**: "pergunta de competência referencia conceito inexistente"

- [x] T009 [US1] Medida responde a necessidade declarada, e declara limitações
  - **Pronta quando**: T001
  - **Descrição**: `medidas_sem_necessidade/1`; o campo é `answers_information_need`, e
    `limitations` é parte da medida — número sem o que ele não cobre é usado como se cobrisse
    tudo
  - **Feita quando**: necessidade inexistente reprova; medida sem `limitations` reprova
  - **Teste**: "medida responde a necessidade de informação inexistente", "medida sem
    `limitations` é número usado como se cobrisse tudo"

- [x] T010 [US1] Mapeamento declara equivalência, justificativa e limitações
  - **Pronta quando**: T001
  - **Descrição**: `mapeamentos_incompletos/1`
  - **Feita quando**: as três ausências aparecem juntas, e não uma por vez
  - **Teste**: "mapeamento sem equivalência, justificativa e limitações"

- [x] T011 [US1] Vínculo prometido por mapeamento tem lastro
  - **Pronta quando**: T001
  - **Descrição**: `vinculos_sem_lastro/2` — três lastros aceitos: relação declarada
    (considerando supertipos), `derivation.rule_id`, ou limitação que **nomeie o conceito**.
    Frase genérica não serve, senão o gate vira carimbo. É o achado F6 da feature 002:
    `eo_people.organization_id` nula em 100% dos registros
  - **Feita quando**: vínculo sem lastro reprova; cada um dos três lastros faz passar
  - **Teste**: "vínculo prometido por mapeamento sem lastro na ontologia", "relação declarada é
    lastro", "limitação que nomeia o conceito é lastro; frase genérica não"

## Fase 3 — Forma (US1)

- [x] T012 [US1] Artefato contra o JSON Schema do tipo
  - **Pronta quando**: T002
  - **Descrição**: `lib/the_band/ontology/schema_check.ex`, subconjunto `type`, `properties`,
    `required`, `additionalProperties`, `enum`, `pattern`, `minItems`, `minimum`, `anyOf`,
    `items`, `$ref` para `common`. Construto não implementado **reprova**. Plano D2
  - **Feita quando**: campo inventado, campo obrigatório ausente, tipo errado e valor fora do
    enum reprovam; a base do repositório passa; base sem schema carregado diz que a verificação
    não rodou
  - **Teste**: describe "forma do artefato contra o JSON Schema" — sete casos

## Fase 4 — Paridade nos dois sentidos (US3)

- [x] T013 [US3] Segredo em YAML também no Python
  - **Pronta quando**: nada além do repositório
  - **Descrição**: `check_secrets` em `scripts/validate_knowledge_base.py`, com os mesmos
    marcadores da constante do Elixir. Existir só de um lado faria o veredito depender de qual
    validador rodou
  - **Feita quando**: um YAML com `ghp_` reprova no Python
  - **Teste**: rodar o validador Python contra uma cópia da base com um token injetado

- [x] T014 [US3] Gate de concordância entre os dois validadores
  - **Pronta quando**: T012, T013
  - **Descrição**: `validators_agree/0` em `lib/mix/tasks/gates.ex`, décimo terceiro gate,
    depois do gate do Python porque é ele quem provisiona o `.venv`. Compara **veredito**, não
    texto — mensagem é escrita em cada linguagem. Plano D5
  - **Feita quando**: os dois aprovam a base íntegra; os dois reprovam o segredo injetado; os
    dois reprovam o conceito inexistente injetado; discordância nomeia quem aprovou e quem
    reprovou
  - **Teste**: `mix gates --from "validador Python"` — o gate falha se um dos lados divergir

## Fase 5 — Fechamento

- [x] T015 Corrigir o `mix knowledge.validate` que media código velho
  - **Pronta quando**: T002
  - **Descrição**: a task rodava `app.config` sem compilar, e validava os beams da compilação
    anterior. Acrescentar `Mix.Task.run("compile")` antes
  - **Feita quando**: editar o validador e rodar a task reflete a edição
  - **Teste**: `mix knowledge.validate` depois de uma edição no validador reporta o
    comportamento novo, não o antigo

- [x] T016 Atualizar a contagem de gates
  - **Pronta quando**: T014
  - **Descrição**: `mix gates` passa de doze para treze; corrigir `@shortdoc`, moduledoc,
    `docs/sprints/RETOMAR.md` e o comentário do `ci.yml`. Documento de sprint encerrado é
    registro, e não se reescreve
  - **Feita quando**: nenhuma referência viva diz "dez gates"
  - **Teste**: `grep -rn "dez gates" lib docs/sprints/RETOMAR.md .github` não devolve nada
