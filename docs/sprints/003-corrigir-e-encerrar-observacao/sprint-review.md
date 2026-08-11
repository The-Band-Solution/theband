# Sprint Review 003 — Corrigir a marca de ausência, e encerrar observação

**Período**: 2026-08-11 a 2026-08-17 · **Encerrado em**: 2026-08-10
**Backlog**: [sprint-backlog.md](sprint-backlog.md) · **Aceitação**: [aceitacao.md](aceitacao.md)

Separa o que foi entregue do que não foi. Nada marcado como pronto sem evidência.

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| Fases | F0 e F4 (MVP) | **2** |
| Fases herdadas, já feitas | F1, F2, F3 | 3 |
| Testes | — | 129 → **172** |
| Lições novas | — | 4 — L19 a L22 |

## O que foi feito

### F0 — a correção da L19

`mark_evidence_no_longer_observed` filtrava por tenant, sem escopo de organização.
Coletar uma organização marcava os vínculos das outras: elas não haviam aparecido
*naquela* coleta, e nunca apareceriam.

A função passou a exigir a organização, e a coleta devolve **qual organização observou**
em vez de só dizer que terminou.

**Prova nos dois sentidos.** Com o escopo removido, **quatro testes reprovam**, um deles
dizendo o motivo por extenso:

```text
coletar alfa marcou o vínculo de beta — é a L19 de volta
```

Os testes usam a forma que os 151 anteriores não tinham: **duas organizações e duas
coletas em sequência**. Era o que o banco de desenvolvimento tinha e a suíte não.

### F4 — retomar a observação encerrada

Reusa a ferramenta existente, exige credencial nova, e **não desmarca nada por si**. Seis
testes, um deles conferindo exatamente que a equipe e a pessoa continuam marcadas depois
da retomada — só a coleta devolve vigência.

**E, depois, o botão.** O `resume_observation/3` passava nos testes desde F4 e a tela
tinha zero ocorrências dele: encerrar era possível pela interface, retomar só pelo
console. Virou a [L21](../licoes-aprendidas.md).

Exercitar o caminho pela tela achou dois defeitos que os testes de domínio não achavam,
porque eles sempre passavam atributos completos:

- **rótulo vazio não pegava o padrão** — o formulário manda `label: ""`, não campo
  ausente, e o padrão só valia para o ausente. Mesma classe da L13;
- **changeset inválido derrubava o processo** — `{:ok, _} = Repo.insert()` virava
  `MatchError` dentro da transação, e a LiveView morria em vez de dizer o que estava
  errado. Agora é `Repo.rollback(changeset)`.

**Histórico das transições**, exigido pelo AC4 da US2. Depois de retomada, a ferramenta
volta a parecer ativa e o cartão não diria que houve encerramento; sendo append-only, o
histórico nunca encolhe.

### Duas correções fora do escopo previsto

**Ordem definida dos eventos.** `ended` e `resumed` no mesmo segundo empatavam, e o
estado voltava "encerrada" depois de uma retomada bem-sucedida. `inserted_at` passou a
microssegundo. Virou a [L20](../licoes-aprendidas.md).

**Um selo por ferramenta.** A tela mostrava "ativa" e "observação encerrada" ao mesmo
tempo, afirmando duas coisas contrárias sobre a mesma ferramenta.

## Evidência

### A aplicação, no ar

Servidor de desenvolvimento em `http://localhost:4000`, com o dado real:

```text
The-Band-Solution   ativa                  [encerrar observação]
ifesserra-lab       observação encerrada   encerrada em 2026-08-10 23:23
leds-conectafapes   ativa                  [encerrar observação]
```

Conferido no HTML servido: 2 botões de encerrar, 1 selo de encerrada, **0 tokens
completos**, e o que aparece é `••••••••••••••••slKb`.

### Encerrar, de ponta a ponta

```text
IMPACTO, antes de confirmar
  equipes .......... 1  (1 derivada pela plataforma)
  vínculos ......... 5
  pessoas só daqui . 4
  PERMANECEM ...... 1 → Paulo
  payloads APAGADOS  0 (dos 24 preservados)

confirmação errada       → {:error, :confirmation_mismatch}
confirmação certa        → 4 pessoas, 1 equipe, 5 vínculos marcados
                            1 credencial destruída

ANTES   72 pessoas · 12 equipes · 82 vínculos · 472 payloads
DEPOIS  72 pessoas · 12 equipes · 82 vínculos · 472 payloads
IDÊNTICO? true

coleta seguinte         → {:error, :observation_ended}
credenciais restantes   → 0
```

### Estado final

```text
pessoas 72 · equipes 12 · vínculos 82 · payloads 472
eventos de observação: 5, append-only
```

## Quality gates

| Gate | Resultado |
|---|---|
| `mix format --check-formatted` | passou |
| `mix compile --warnings-as-errors` | passou |
| `mix credo --strict` | passou — `found no issues` |
| `mix dialyzer` | passou |
| `mix test` | passou — **172 testes** |
| `mix knowledge.validate` | passou |
| `mix knowledge.graph` | passou |
| validador Python | passou |
| derivação reproduzível | passou — **e desta vez de verdade**, ver abaixo |

### O gate que eu reportei verde e estava vermelho

O passo "derivação reproduzível" está vermelho na `main` desde o PR #93, e eu o
reportei como passando nas reviews dos sprints 002 e 003. Ele roda o script duas vezes
e compara: a derivação da SRO falhava **igual** nas duas, e o `diff` passava.

A causa: 43 conceitos da SRO sem `ontouml_stereotype`. Anotados — 36 por consequência
direta de `ufo_category` e do pai, 7 decididos com a pessoa mantenedora.

E anotar expôs um defeito que existia antes da SRO: a guarda da ADR 0004 D5 —
`role` materializa por relator, nunca por discriminador — só valia quando o alvo do
lifting estava na mesma ontologia. **CMPO e SPO já produziam a violação**, impressa na
saída, verde no CI:

```text
eo.person.type    += {project_person_stakeholder}
ufo.agent.type    += {change_implementer}
spo.artifact.type += {configuration_item}
```

Nenhuma chegou ao banco. Virou a [L22](../licoes-aprendidas.md).

## O que **não** foi feito

| Item | Por quê |
|---|---|
| **US3 — renomear e remover credencial, limpar atenção** | fora do escopo declarado do sprint |
| **Retomada contra o GitHub real** | exige credencial válida, e a chave mestra que decifra o banco de desenvolvimento é da pessoa mantenedora — não está no meu ambiente. Na aplicação no ar foram verificados o botão, o formulário e o histórico; a retomada bem-sucedida está provada em teste, com a borda HTTP simulada |
| **Telas T019 a T022** | fora do escopo. A tela de encerramento **existe** — veio com F3 —, então o caminho principal está coberto. Falta distinguir "nunca conectou" de "encerrou tudo", e explicar o que não é editável |
| **Reparo do dado histórico da L19** | a correção vale para coletas futuras. Os vínculos marcados antes seguem marcados, e **não foram desmarcados por decisão**: não se sabe o que a origem mostrava naquele instante, e desmarcar afirmaria observação que não ocorreu — o próprio erro da L19. O reparo acontece na próxima coleta real de cada organização |
| **Corrigir a janela da iteration do sprint 002** | exige mexer na configuração de iterations, que causou a L11. Decisão pendente |
| **Anotar RSRO e SYS_SWO** | 16 conceitos sem estereótipo, em duas ontologias fora do escopo. Ao fazer, reavaliar se `sro.user_story` é `subkind` de `rsro.requirements_artifact` — a decisão de hoje foi `kind` para a SRO fechar sozinha |

## Duas coisas que eu fiz errado

**Implementei a feature 003 sem abrir sprint.** A skill `sprint-backlog` diz na primeira
linha que ela é obrigatória antes de implementar, e fui de `tasks.md` direto para o
código. O sprint foi aberto depois, trazendo o trabalho para dentro e declarando o que já
estava feito.

**A janela do sprint 002 ainda não fechou.** A iteration diz 10 a 16/08, e ele foi
aceito no primeiro dia. Segunda vez que a duração declarada não corresponde à ocorrida.

## Dívida gerada e mantida

| O quê | Situação |
|---|---|
| `connected_tools.status` materializa situação | **mantida**, contra a ADR 0004 D7. Esta feature não a ampliou, e parou de exibi-la em contradição com o estado derivado |
| Paridade Elixir/Python | mantida: 4 verificações contra 12 |
| 10 vínculos sem lastro | fechada por limitação declarada |
| Aprovação de revisão registrada | bloqueada por ferramenta: com uma identidade, o autor não aprova |

## Lições deste sprint

**L19** — marcar ausência por tenant marca o que é de outra organização. O que a torna
maior que o defeito: a feature 002 deu o vocabulário que faltava e **não revisitou quem
já decidia sem ele**.

**L20** — estado derivado do "último" precisa de desempate determinístico. Reincidência do
defeito de escolha de credencial do sprint 001, e reincidiu porque aquela lição foi
registrada sobre **credenciais** em vez de sobre **derivar estado de conjunto ordenado**.

**L21** — função pública testada e sem consumidor não é funcionalidade entregue. O
`resume_observation/3` tinha seis testes verdes e nenhuma pessoa conseguia chamá-lo.
Também é o que a fatia vertical existe para impedir.

E duas observações que atravessam as três:

**Os 161 testes passavam com os dois selos contraditórios na tela.** Olhar a aplicação
achou o que a suíte não achava.

**Percorrer os critérios de aceitação um a um achou três lacunas** — o histórico sem
consumidor, a SC-007 sem teste e a SC-010 sem teste — todas fechadas antes do registro de
aceitação. É o que separa aceitar de conferir se parecia pronto.
