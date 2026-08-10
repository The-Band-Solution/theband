# Research — editar e remover ferramentas conectadas

**Feature**: 003 · **Spec**: [spec.md](spec.md)

Cada decisão aqui foi tirada de medição no banco de desenvolvimento ou de decisão já
registrada no projeto. Onde a medição contrariou o que eu supunha, o que ficou é a
medição.

---

## R1 — Apagar a ferramenta destruiria os payloads preservados

**Decisão**: a linha da ferramenta conectada **não é apagada**, nunca. Encerrar é
mudança de estado, não remoção.

**O que a medição mostrou.** A recusa da feature 001 era um argumento; agora é um
fato. As chaves estrangeiras formam uma cascata:

```text
connected_tools
  └→ syncs                (ON DELETE CASCADE)
       ├→ raw_payloads     (ON DELETE CASCADE)
       └→ sync_checkpoints (ON DELETE CASCADE)
```

`DELETE FROM connected_tools` destrói, hoje, **24 payloads** de `ifesserra-lab`, **64**
de `The-Band-Solution` e **384** de `leds-conectafapes` — mais todos os checkpoints e
todo o histórico de sincronizações.

**Por que isso é decisivo e não apenas caro.** Os payloads preservados são o que
sustenta o reprocessamento de mapeamento corrigido (FR-017 da feature 001) e o
retrofito da feature 002. Apagar a ferramenta removeria a capacidade de corrigir dado
já coletado — o oposto do que aqueles requisitos existem para permitir. E removeria a
corrente `raw_payloads → syncs → connected_tools.organization_login`, que é como a
plataforma sabe de qual organização cada payload veio.

**Alternativa descartada**: trocar as cascatas para `ON DELETE RESTRICT` e permitir
apagar quando não houver dado. Rejeitada por produzir duas semânticas para a mesma
ação — apaga quando é nova, encerra quando tem dado —, e a pessoa que usa não teria
como prever qual das duas vai acontecer.

---

## R2 — A pessoa não tem proveniência por ferramenta

**Decisão**: a marcação de encerramento é **por vínculo**, e a pessoa só é marcada
quando todos os vínculos dela apontam para organizações não mais observadas.

**O que a medição mostrou.** Eu supunha que cada registro carregasse a ferramenta de
origem. Não carrega:

```text
Paulo   github   https://github.com   U_kgDOABFnGA
```

Uma linha, uma proveniência. E `source_instance` é **o mesmo** `https://github.com`
para as três organizações, porque três ferramentas observam a mesma instância. A
proveniência da pessoa não distingue ferramenta nenhuma, e não deveria: a pessoa é a
mesma conta, observada de três lugares.

**Onde a origem por ferramenta existe de verdade**:

| Registro | Como se sabe a ferramenta |
|---|---|
| equipe | pela organização — `organization_id` |
| vínculo de evidência | pela equipe, e daí pela organização |
| pessoa | **não se sabe**; só pelos vínculos dela |

**A consequência prática, com os números reais**: das 5 pessoas de `ifesserra-lab`, 4
são exclusivas e uma não — `Paulo`, que está nas três organizações. Encerrar
`ifesserra-lab` marca os 4, marca o vínculo do Paulo com a equipe daquela
organização, e **deixa o Paulo vigente**, porque `The-Band-Solution` e
`leds-conectafapes` continuam observando-o.

**Alternativa descartada**: acrescentar `connected_tool_id` em pessoas, equipes e
vínculos. Rejeitada porque uma pessoa observada por três ferramentas precisaria de três
linhas ou de uma coluna que mente escolhendo uma — e a identidade dela é a Application
Reference, que é única de propósito. É o mesmo erro que a feature 002 corrigiu ao
remover `eo_people.organization_id`.

---

## R3 — Destruir a credencial é seguro, e custa uma informação

**Decisão**: a credencial é **apagada** da base ao encerrar a observação e ao ser
removida individualmente.

**O que a medição mostrou.** A chave estrangeira que preocupava está resolvida por
construção:

```text
syncs.credential_id → tool_credentials(id)   ON DELETE SET NULL
```

Apagar a credencial **não** apaga sincronização nenhuma. O histórico de coletas
sobrevive inteiro.

**A informação que se perde, declarada.** Depois de apagar, a sincronização não
consegue mais dizer **qual** credencial usou — o campo fica nulo. Isso é perda real, e
é aceita: a credencial não existe mais, então apontar para ela responderia com um
identificador morto. O que continua respondível é o que importa para proveniência —
qual ferramenta, qual instância, quando.

**Por que apagar e não desativar.** Credencial desativada continua existindo cifrada.
Um segredo guardado que ninguém usa é superfície de ataque sem contrapartida: ele só
pode vazar. A proveniência do dado coletado não depende dele, e o cofre não precisa
guardar o que a plataforma decidiu não usar mais.

**O custo, assumido**: retomar exige credencial nova. Está em FR-013 de propósito, e a
alternativa — guardar para facilitar a retomada — troca segurança por conveniência de
um caso raro.

---

## R4 — Estado de observação é situação derivada, não coluna

**Decisão**: as transições de encerrar e retomar são gravadas como **eventos
append-only**, e o estado atual da observação é **derivado** do último evento.

**A decisão já estava tomada, na ADR 0004 D7**:

> Eventos são `append-only`; situações não são materializadas. Evento registra algo que
> ocorreu: atualizar uma falha para dizer que ela não ocorreu reescreveria o passado.
> Situação é a realidade antes e depois de um evento, integralmente derivável dos
> instantes dele; persistir em separado criaria três lugares para discordarem sobre o
> mesmo fato.

Encerrar e retomar são eventos: ocorreram, num instante, por alguém. "Está observada"
é situação, e sai do último evento.

**Por que uma coluna não serve.** O edge case "encerrar e reconectar no mesmo dia"
exige as duas transições visíveis, e FR-014 pede isso explicitamente. Um par de colunas
`encerrada_em` / `retomada_em` guarda **um** ciclo; o segundo encerramento sobrescreve o
primeiro, e o registro passa a dizer que houve uma transição onde houve três.

**Dívida existente, e não ampliada.** `connected_tools.status` já materializa uma
situação — `active` / `needs_attention`. É dívida da feature 001, e esta feature **não
a aumenta**: o estado novo não vira coluna. Unificar as duas coisas é trabalho próprio,
e fazê-lo aqui misturaria a correção de um defeito antigo com a entrega de uma feature.

**Alternativa descartada**: só a coluna, sem eventos. Rejeitada por FR-014, que existe
porque o registro precisa mostrar o que aconteceu e não onde parou — é a mesma razão
que fez o registro de aceitação do sprint 001 guardar os dois momentos de D01.

---

## R5 — Interromper a coleta em andamento tem precedente

**Decisão**: encerrar a observação de uma ferramenta com coleta em curso marca a
sincronização como `interrupted`, preservando o progresso parcial, pelo mesmo caminho
que a credencial revogada já usa.

**O precedente existe e foi verificado.** A feature 001 já trata o caso de a credencial
ser recusada no meio da coleta: a sincronização vai para `interrupted` com o motivo, o
progresso parcial permanece, e os checkpoints ficam onde estão. Encerrar a observação é
a mesma classe de evento — a coleta perdeu a razão de continuar — e reusar o caminho
evita um segundo mecanismo para o mesmo desfecho.

**O que precisa de cuidado**: a coleta roda em job, e o encerramento vem da interface.
A coleta precisa **perceber** o encerramento entre páginas, não ser morta no meio de
uma escrita. O ponto natural é o mesmo em que o checkpoint é gravado — depois de
processar a página —, porque ali o estado é consistente por construção.

**Alternativa descartada**: cancelar o job. Rejeitada porque cancelar deixa a
sincronização em `running` para sempre, e o índice que impede duas coletas simultâneas
da mesma ferramenta continuaria bloqueando — o mesmo defeito que a lição de
`finish_with_error/3` já corrigiu uma vez.

---

## R6 — A segunda causa de "não mais observado" precisa ser declarada

**Decisão**: o mapeamento de evidência passa a declarar **duas** causas para um vínculo
terminar, e cada registro marcado diz qual delas se aplicou.

**A lacuna medida.** Hoje a base declara uma única causa, em
`mappings/github/eo/team_membership_evidence.yaml`:

> Remoção de uma pessoa do time no GitHub não gera evento; só é detectável por
> comparação entre coletas.

Esta feature cria a segunda: **o tenant decidiu parar de observar**. Sem declarar, quem
lê um registro marcado não sabe qual aconteceu, e a diferença é grande — uma diz "a
origem mudou", a outra diz "nós paramos de olhar". A primeira é fato sobre o mundo; a
segunda é fato sobre a plataforma.

**Onde a distinção é usada**: ao retomar a observação, os registros marcados pela
segunda causa voltam a ser vigentes se a origem ainda os mostra. Os marcados pela
primeira só voltam se a origem passar a mostrá-los de novo. Tratar os dois iguais faria
a retomada ressuscitar vínculo que a origem já não tem.

**Alternativa descartada**: uma única causa genérica. Rejeitada por fazer a retomada
ter de escolher entre ressuscitar tudo — inventando vínculo — ou nada, contrariando
FR-007 do encerramento.
