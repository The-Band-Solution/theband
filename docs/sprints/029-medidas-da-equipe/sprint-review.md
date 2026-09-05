# Sprint 029 — Review

**Período**: 2026-09-02 a 2026-09-09 · encerrado em 2026-09-03
**Feature**: [058 — as medidas que faltam na tela da equipe](../../../specs/058-medidas-da-equipe/spec.md)

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 3 | 3 |
| Tarefas | 21 | 20 |
| Suíte | — | **1 704 testes, verde** |
| `mix gates` | — | **código de saída 0** · 14 gates |

As três user stories estão completas. A tarefa não entregue é a mesma de sempre,
e está dita abaixo sem rodeio.

## O que foi feito

| User story | Issue | Tarefas | O que chegou à tela |
|---|---|---|---|
| US2 — quem trabalhou neste projeto, e quando | [#766](https://github.com/The-Band-Solution/theband/issues/766) | T004–T007 | a seção por projeto, com as equipes por onde cada pessoa chegou e a marca do período parcialmente desconhecido |
| US1 — o tempo até a primeira revisão | [#765](https://github.com/The-Band-Solution/theband/issues/765) | T008–T011 | a mediana da equipe, a espera em curso contada ao lado, e a mesma medida por pessoa |
| US3 — a taxa do pipeline | [#767](https://github.com/The-Band-Solution/theband/issues/767) | T012–T016 | a taxa com o caminho e o tamanho da amostra, ou a recusa nomeando o elo que falta |

T001–T005 vieram do PR [#789](https://github.com/The-Band-Solution/theband/pull/789),
antes da v0.4.0. T006–T019 são deste trabalho.

## O Cenário 0 — a cobertura do dado, medida

A T020 existe porque a pesquisa **não conseguiu** medir: a aplicação não subia
com `:missing_master_key`, e uma taxa sobre amostra desconhecida não sustenta
decisão.

Agora subiu. A chave está no `.env` do ambiente de desenvolvimento, e os números,
medidos em 2026-09-03 contra `the_band_dev`:

```sql
select 'collected_verifications='||(select count(*) from collected_verifications)
    ||' spo_project_teams='||(select count(*) from spo_project_teams)
    ||' spo_project_repositories='||(select count(*) from spo_project_repositories);
```

| tabela | linhas |
|---|---:|
| `collected_verifications` | **0** |
| `spo_project_teams` | **0** |
| `spo_project_repositories` | **0** |
| `collected_change_requests` | **0** |
| `eo_team_memberships` | **0** |

**O que estes números queriam dizer, e o que não queriam.** O banco de
desenvolvimento estava **vazio** — 12 MB, só esquema. A medição não era da cobertura:
era da ausência de dado local.

### A medição de verdade, com dado coletado

Em 2026-09-04 a pessoa mantenedora cadastrou a credencial e a coleta rodou contra a
organização real **`leds-conectafapes`**. Foram **sete tentativas** até uma terminar em
`completed` — as seis primeiras morreram, e cada morte virou uma correção (ver adiante).

Os números da coleta completa:

| tabela | linhas |
|---|---:|
| `eo_people` | **80** |
| `eo_teams` | **9** |
| `eo_team_membership_evidence` | **90** |
| **`eo_team_memberships`** | **0** |
| `observed_repositories` | **125** |
| `collected_issues` | **4 971** |
| `collected_change_requests` | **5 466** |
| `collected_artifact_evaluations` | **4 634** |
| `collected_verifications` | **5 311** |
| **`spo_project_teams`** | **0** |
| **`spo_project_repositories`** | **0** |

### A conclusão sobre a US3, agora com dado real dos dois lados

**A taxa do pipeline tem numerador e não tem caminho.** Há 5 311 execuções de verificação
coletadas — o dado que faltava na primeira medição. E há **zero** vínculos equipe ↔
projeto e **zero** projeto ↔ repositório.

O caminho que a US3 declara é `repositório → projeto → equipe`, e ele está cortado nos
dois elos. A entrega contra dado real é **exatamente o ramo da recusa** — `{:sem_projeto,
_}`, com o elo que falta nomeado na tela.

É o que a T020 previu, e agora é resultado **medido**: não faltava dado de CI; falta a
declaração que liga repositório a projeto e projeto a equipe. Nenhuma linha de código
resolve isso — é trabalho de quem administra a organização.

**Zero vínculos promovidos, com 90 evidências esperando.** A plataforma observa o vínculo
e exige confirmação humana do papel. Enquanto ninguém confirma, toda medida de nível
`team` fica sem base, e as nove equipes disparam
`structure.ap02.team_with_no_members` — o antipadrão declarado neste sprint, valendo
contra dado real no primeiro contato.

### A cobertura das verificações, e o que não sei explicar

**23 dos 125 repositórios** têm `verifications_collected_at`, e só **16** têm execuções no
banco — os outros 7 foram percorridos e não têm CI.

Os 102 restantes **não** têm explicação no resumo da coleta: `unreachable: 0`,
`without_ci: 0`, `rate_limited: 0`. Nenhum dos motivos que o código sabe registrar
aparece.

**Investigado em 2026-09-05, e explicado**: 98 dos 102 falharam com `{:rate_limited, _}`
— cota, não problema do repositório. O resumo dizia `rate_limited: 0` porque o estado
`:sem_janela` existia no contador e **nada o produzia** — o rate limit reativo caía no
ramo geral e virava `:inalcancavel`. Corrigido no PR #806, com a etapa ganhando os
primeiros testes que já teve.

E as execuções gravadas **sem jobs** — 418 de 6 168 — têm a mesma causa, e só ela: os
586 registros de *"jobs não coletados"* no log são todos `{:rate_limited, _}`. Não são
jobs expirados nem defeito de coleta. Com o `snooze` corrigido, a próxima coleta espera a
janela e preenche; o checkpoint bloqueado nesses repositórios está fazendo exatamente o
que a L29 manda.

A cobertura real da taxa do pipeline segue sendo **16 repositórios com dado, sobre 125
observados** — e agora com a causa da diferença nomeada, em vez de declarada como
desconhecida.

### Os 37 inacessíveis sumiram

Na primeira coleta, 37 repositórios foram marcados com *"the tool refused the credential"*.
Na coleta completa são **zero** — a plataforma limpou a marca ao alcançá-los. Confirma que
a marca é sobre o **momento**, e não sobre o repositório, que é o que
`clear_inaccessible/2` existe para fazer.

### O defeito que a coleta real encontrou

A primeira execução terminou em `failed` **depois** de gravar 69 pessoas, 936 issues e
598 solicitações: o upsert da equipe derivada consultava a Application Reference e
inseria, e entre as duas coisas coube outra coleta — o segundo insert bateu no índice
único. A etapa dos vínculos nunca rodou, e a tela mostraria nove equipes vazias sem que
nada dissesse por quê.

Corrigido e fechado como [#800](https://github.com/The-Band-Solution/theband/issues/800):
o conflito da Application Reference passou a ser **reconhecimento**, e não erro. Foi
preciso rodar contra origem real para encontrá-lo — 1 704 testes verdes não o pegaram.

## Evidências

| O quê | Medida |
|---|---|
| `mix gates` | **código de saída 0** · 14 gates |
| suíte completa | **1 704 testes**, 187 s |
| código e teste acrescentados | **2 577 linhas** em 14 arquivos (937 em `lib/`) |
| testes novos | **37** — 13 da tela, 8 da espera, 8 da taxa, 7 do isolamento, 1 do teto |
| arquivos de teste novos | 2 |
| teto de consultas da tela | 17 → **19**, e as três seções somam **6** com projeto |

## O que os testes encontraram, e o código não dizia

Quatro defeitos nasceram e morreram dentro do sprint. Ficam registrados porque a
lição está no **como** foram achados, e não em que existiram:

1. **`list_team_projects/2` apagava o passado.** A seção da US2 usava a listagem
   da associação, que filtra `is_nil(unlinked_at)`. O projeto de que a equipe saiu
   sumia da tela **junto com todo mundo que trabalhou nele** — contra a FR-008.
   Achado pelo teste do intervalo encerrado, e corrigido com
   `team_projects_ever/2`;

2. **a consulta sobre tabela devolve `NaiveDateTime`.** Sem `type/2` no select, a
   conta de dias da espera em curso quebrava com `FunctionClauseError`. Errar
   assim é sorte: um número errado teria passado;

3. **o teto de consultas fez o trabalho dele três vezes.** Cada seção nova o
   reprovou, e cada subida está escrita com o motivo. A terceira levou a
   compartilhar a lista de vínculos entre duas seções, em vez de subir o número;

4. **o Credo estava certo sobre a complexidade.** A consulta do recorte, num
   `from` só, passou de 12. Quebrá-la em `abertas_por_quem_pertencia/2` e
   `com_primeira_revisao_humana/1` não foi obediência ao gate: o recorte pela data
   de abertura **é** a regra da medida, e lia-se melhor sozinho.

## A revisão independente, e o que ela achou

**O PR #798 foi incorporado em 2026-09-04 às 02:58 com `reviews: []`.** Perguntado
se alguém havia lido, a pessoa mantenedora respondeu que **não há como saber** — e
por isso o registro diz **revisão não registrada**, e não *atestada sem registro*.
`reviews: []` prova ausência de registro, não ausência de leitura; afirmar a segunda
seria inventar.

Foi a terceira reincidência da L95. O que mudou desta vez veio **depois** do merge:
três revisões independentes por agente, e as três acharam coisa que os gates não
pegam.

### Revisão de segurança (OWASP) — 7 achados

| # | Achado | Estado |
|---|---|---|
| 1 | `project_repositories_with_period_many/2` sem teste do filtro de tenant | corrigido |
| 2 | três joins não amarravam `tenant_id` entre as tabelas | corrigido |
| 3 | **dois casos do teste de isolamento comparavam `[] == []`** | corrigido |
| 4 | `:vinculos` e `:nome` — garantia morando no chamador | **opções removidas** |
| 5 | o Sobelow **não enxerga `raw/1` dentro de `~H`** | gate novo |
| 6 | leitura individual sem veredito de acesso | FR-024 |
| 7 | corte em 200 solicitações, silencioso | a tela diz que cortou |

O achado 5 foi **medido, e não deduzido**: XSS injetado numa seção que mostra título
vindo do GitHub, e o scan saiu limpo com código 0; um defeito que o Sobelow reconhece
foi injetado em seguida, e aí ele reprovou. *"Sobelow limpo"* nesta base significa
"nenhum padrão conhecido **fora dos templates**", e toda a superfície de renderização
é LiveView.

O achado 3 é o mais desconfortável: **com o filtro de tenant removido, a suíte inteira
passava — 1 711 testes.** O arquivo cujo nome afirma provar SC-010 não provava.

### Revisão de QA — 8 achados

Os cinco testes que sustentam o núcleo da feature **reprovam quando o código erra**,
provados por injeção. Mas quatro asserções da suíte de tela celebravam o que não
mediram — também provadas por injeção:

- `assert secao =~ "interrupted"` casava com o **cabeçalho** da tabela, e passava com
  "0.0%" na tela — o defeito que o teste diz impedir;
- `assert html =~ "start date"` tinha **três fontes** na página;
- `assert secao =~ "run(s) that"` media a legenda, não o número que ela qualifica;
- o `refute` da permissão passava com a guarda de admin removida: a fixture não
  deixava o formulário renderizar **para ninguém**.

E o teto das seções era **estimativa** (6); medido, era 3. Estimativa deixa folga, e
folga é onde consulta nova entra sem ninguém ver.

### Decisão do Product Owner — FR-024 e FR-025

O achado 6 não era decisão nova: **a pergunta "quem vê o trabalho de alguém" foi
respondida em 2026-08-26** (spec 023, FR-012), e a tela da equipe restabelecia por
omissão o regime revogado. SC-011, como estava escrito, **exigia o vazamento** — uma
conta sem relação nenhuma também é "uma pessoa sem permissão de administrar equipes".
O critério voltou emendado, com SC-012 ao lado.

A equipe de uma pessoa foi decidida pela pessoa mantenedora no mesmo dia: **é
anomalia, e anomalia se identifica** — nem risco aceito, nem piso de pessoas, que
seria vocabulário que a base não tem.

## O que não foi feito

| Tarefa | Issue | Motivo | Destino |
|---|---|---|---|
| T021 (parte) | [#788](https://github.com/The-Band-Solution/theband/issues/788) | gates verdes ✅, PR aberto ✅, **revisão humana não registrada** | mecanismo, e não outro registro |

**É a terceira vez seguida**, e a L98 descreve o padrão: lição que não vira regra
reincide. Uma lição que reincide três vezes não precisa de outro registro — precisa
de um mecanismo.

O que este sprint acrescentou como mecanismo, e não como promessa: a revisão
independente **por agente**, com injeção de defeito como prova, achou 15 problemas
que 1 711 testes verdes e 14 gates não pegaram. Não substitui leitura humana de
desenho; cobre a parte que a leitura humana também costuma não pegar.

## O que continua aberto no épico [#504](https://github.com/The-Band-Solution/theband/issues/504)

Depois deste sprint, o épico **não fecha**, e por dois motivos que não são de
implementação:

1. **as perguntas do painel não vieram** — decisão de quem mantém, declarada como
   pendência no próprio épico desde 2026-08-25;
2. **`flow.throughput` e `flow.wip.count` dependem da feature 042** (critério de
   início), especificada, com 24 issues e sem código.

Escrever o painel antes das perguntas produziria a medida do que é fácil medir.

## Dívida gerada

**A marca de período parcial continua pessimista.** `Periodos.interseccao/1`
marca qualquer início nulo, mesmo quando a sobreposição é certa pelos outros
períodos — está documentado no próprio módulo desde a 057, e esta feature
**consome** o comportamento sem corrigi-lo. A consequência aparece agora que há
tela: uma equipe cujos vínculos não têm `started_at` verá a marca em toda linha,
e a marca deixa de distinguir.

Corrigir muda o que a função devolve para casos que já têm chamador, e é decisão
em aberto — não um esquecimento.
