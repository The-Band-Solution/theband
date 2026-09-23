# Quickstart — como provar que a feature 062 funciona

Não é tutorial de uso: é o roteiro que **prova** a fatia, e o que cada passo tem de mostrar.

---

## Pré-requisitos

1. `mix deps.get` com `{:ex_mcp, "~> 1.5"}` já no `mix.exs`;
2. um token da 061 — gerado na tela `/api-tokens`, e **copiado no momento da criação**: ele
   não é reexibível;
3. uma equipe com trabalho de verdade. Na base local, `LEDS - ConectaFapes` serve: 31
   membros, 23 abertas, 18 paradas, 102 esperas.

> **Não coloque o token em arquivo do repositório, nem no histórico do terminal.** Onde ele
> fica é responsabilidade de quem usa (FR-007), e a plataforma só tem um controle sobre um
> token que já saiu: a revogação.

---

## 1. O servidor enumera exatamente quatro ferramentas

```bash
mix test test/the_band_web/mcp/protocolo_test.exs
```

**Tem de mostrar**: `tools/list` devolve `team_roster`, `team_open_work`,
`team_review_wait` e `team_stale_work` — nem mais, nem menos. Ferramenta nova sem entrada no
registro reprova aqui.

**E cada descrição diz o que a ferramenta NÃO responde** (FR-022). Descrição sem essa frase
reprova.

---

## 2. Toda medida carrega a ressalva — SC-001

```bash
mix test test/the_band/mcp/envelope_test.exs
```

**Tem de mostrar**: o teste **percorre todas as ferramentas registradas**, e não uma amostra.
Para cada uma, o objeto tem `composition`, `window` (ou `null` dito), `origin`,
`limitations`, `misinterpretations` e `collected_at`.

**A guarda que prova que não é vazia**: ao menos uma ferramenta tem de devolver
`misinterpretations` **não vazia**, lida da base. Se todas vierem `[]`, o teste passou sem
ler a base, e isso é o que ele existe para pegar.

---

## 3. As duas medianas não viram uma — o número que justifica a feature

```bash
mix test test/the_band/mcp/ferramentas_test.exs
```

**Tem de mostrar**, em `team_review_wait`:

| | Esperado |
|---|---|
| `reviewed` | `count` e `median_hours`, com denominador próprio |
| `waiting` | `count` e `median_days`, com denominador próprio |
| campo único de espera | **não existe** |

Contra a base local, a rota HTTP equivalente deu **23 revisadas com mediana de 0,2 h** e
**79 aguardando com mediana de 46 dias**. Uma mediana só responderia *"doze minutos"*.

**Estes testes exercitam as funções SEM subir a biblioteca MCP.** É o que prova que a camada
é fina e que a dependência é trocável — e se algum deles precisar do servidor para rodar, a
camada deixou de ser fina.

---

## 4. Ausência tem três estados, e nenhum é zero — SC-002

```bash
mix test test/the_band/mcp/ausencia_test.exs
```

**Tem de mostrar** os três distinguíveis no campo `state`, e nunca pelo valor:

- `checked` com `value: 0` — conferiu e achou zero;
- `not_checked` com `missing:` dizendo **o que** falta;
- `refused` com `reason:`.

**A guarda contra o teste vazio**: uma equipe sem coleta de comentários tem de produzir
`not_checked`, e não `checked` com zero. Se os três estados não aparecerem na execução, o
teste não os está exercitando.

---

## 5. A recusa é resposta, e é a mesma das outras portas — SC-003, SC-004

```bash
mix test test/the_band/mcp/paridade_test.exs
```

**Tem de mostrar**: para os **quatro** caminhos de `pode_ver_equipe/3` — `admin`,
`escopo_de_equipe`, `escopo_da_organizacao`, `vinculo_vigente` — e para `fora_do_alcance`, a
tela, a API e o MCP concordam.

E a recusa vem como **resposta com razão**, nunca como exceção nem como lista vazia.

---

## 6. Nada de segredo sai — SC-005

```bash
mix test test/the_band_web/mcp/segredo_nao_vaza_test.exs
```

**Tem de mostrar**: a varredura olha o **objeto inteiro serializado**, e não os campos
esperados — campo novo que vaze não estaria na lista de esperados.

Procura: o valor do token, o segredo dele isolado, `platform_access_level`, e qualquer
endereço de e-mail.

**A guarda contra a varredura vazia**: ela tem de **encontrar** algo que está lá de propósito
— o `team_id`, por exemplo. Uma varredura que não acha nada pode estar olhando para o lugar
errado e passando.

---

## 7. A fronteira: nenhum módulo de MCP toca o banco

```bash
mix test test/the_band/mcp/fronteira_test.exs
```

**Tem de mostrar**: nenhum arquivo de `lib/the_band/mcp/` referencia `TheBand.Repo` ou
`Ecto.Query`. É o que torna a extração posterior um **mover**, e não um reescrever.

O teste lê o código-fonte com comentários e `@moduledoc` **removidos** — a prosa que explica
a proibição contém as palavras proibidas, e já reprovou por isso duas vezes neste repositório.

---

## 8. O custo é o mesmo da rota HTTP

```bash
mix test test/the_band_web/mcp/custo_test.exs
```

**Tem de mostrar**: `team_roster` custa as mesmas consultas que `GET /api/v1/teams/:id/members`.
Duas portas para o mesmo dado com custos diferentes significam que uma delas tem consulta a
mais — e a que tem a mais está fazendo trabalho que a outra provou desnecessário.

---

## 9. Ponta a ponta, com um cliente de verdade

Configure o cliente MCP apontando para `https://<instância>/mcp`, com o token no cabeçalho
`Authorization`.

**Tem de mostrar**, e isto **não é verificável por `curl` de código de status**:

1. o cliente lista as quatro ferramentas;
2. `team_review_wait` devolve as **duas** leituras, e o agente que as lê consegue dizer
   *"23 revisadas em 0,2 h; outras 79 esperam há 46 dias"* — não *"12 minutos"*;
3. um token revogado é recusado **na chamada seguinte**, sem reiniciar nada (SC-006).

> Conferir código de status não prova que a página funciona. Foi o que aconteceu com o
> Swagger da 061: `HTTP 200`, tela em branco, política bloqueando o script. O passo 9 existe
> para ser feito **com o cliente**, e não com `curl`.

---

## 10. Os gates

```bash
mix gates; echo "EXIT=$?"
```

**O veredito é o código de saída**, e qualquer comando depois dele substitui o que vale. Em
execução de fundo, o código tem de ser escrito **dentro** do próprio log.

> Isto já falhou nesta feature anterior: `mix gates > log; echo "EXIT=$?"` devolveu `0`
> porque o `echo` sempre devolve 0 — e um teste estava reprovando.
