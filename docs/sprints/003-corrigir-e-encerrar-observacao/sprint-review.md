# Sprint Review 003 — Corrigir a marca de ausência, e encerrar observação

**Período**: 2026-08-11 a 2026-08-17 · **Encerrado em**: 2026-08-10
**Backlog**: [sprint-backlog.md](sprint-backlog.md)

Separa o que foi entregue do que não foi. Nada marcado como pronto sem evidência.

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| Fases | F0 e F4 (MVP) | **2** |
| Fases herdadas, já feitas | F1, F2, F3 | 3 |
| Testes | — | 129 → **161** |
| Lições novas | — | 2 — L19 e L20 |

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
| `mix test` | passou — **161 testes** |
| `mix knowledge.validate` | passou |
| `mix knowledge.graph` | passou |
| validador Python | passou |
| derivação reproduzível | passou |

## O que **não** foi feito

| Item | Por quê |
|---|---|
| **US3 — renomear e remover credencial, limpar atenção** | fora do escopo declarado do sprint |
| **Telas T019 a T022** | fora do escopo. A tela de encerramento **existe** — veio com F3 —, então o caminho principal está coberto. Falta distinguir "nunca conectou" de "encerrou tudo", e explicar o que não é editável |
| **Reparo do dado histórico da L19** | a correção vale para coletas futuras. Os vínculos marcados antes seguem marcados, e **não foram desmarcados por decisão**: não se sabe o que a origem mostrava naquele instante, e desmarcar afirmaria observação que não ocorreu — o próprio erro da L19. O reparo acontece na próxima coleta real de cada organização |
| **Corrigir a janela da iteration do sprint 002** | exige mexer na configuração de iterations, que causou a L11. Decisão pendente |

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

E uma observação que atravessa as duas: **os 161 testes passavam com os dois selos
contraditórios na tela.** Olhar a aplicação achou o que a suíte não achava.
