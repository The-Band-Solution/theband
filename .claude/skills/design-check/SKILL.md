---
name: "design-check"
description: "Revisa o desenho de um diff, módulo ou proposta contra os padrões e antipadrões do The Band. Verifica se cada padrão introduzido tem problema que o justifique, e procura os antipadrões que a arquitetura deste projeto atrai — booleano no lugar de relator, consulta sem tenant, fallback silencioso, mock de domínio, configuração que enfraquece gate, acoplamento temporal. Use antes de abrir PR, ao revisar código de outra pessoa ou agente, e sempre que uma mudança introduzir abstração, camada ou interface nova. Dispara com 'revisar desenho', 'design check', 'isso é over-engineering?', 'que padrão usar aqui', 'antipadrão'."
user-invocable: true
disable-model-invocation: false
---

# Revisão de desenho

Aplica o princípio VIII da constituição — **desenho que o problema justifica** — e
os padrões e antipadrões de `AGENTS.md` §7.7 a um alvo concreto.

Isto **não** é uma revisão de estilo. Formatação e nomes de variável são trabalho
do Credo e do formatador, que já rodam nos gates. Aqui se olha estrutura: o que
foi separado, o que foi abstraído, o que foi escondido, e o que isso custa.

## Alvo

Sem argumento, revise o diff da branch contra `main`. Com argumento, revise o que
ele indicar: caminho de arquivo, módulo, ou uma proposta ainda não escrita.

```bash
git diff main...HEAD --stat
git diff main...HEAD
```

Para proposta ainda não escrita, pule a coleta e vá direto às três perguntas.

## Passo 1 — As três perguntas, por padrão introduzido

Identifique **cada** abstração, camada, interface, behaviour, macro, callback ou
módulo de indireção que a mudança introduz. Para cada um:

| Pergunta | O que aceita | O que recusa |
|---|---|---|
| Qual problema concreto resolve? | um problema nomeado, presente no código | uma categoria: "flexibilidade", "desacoplamento", "caso futuro" |
| O problema existe agora? | segunda ocorrência já no repositório | previsão, "quando tivermos outro provedor" |
| O que fica pior? | um custo nomeado — um salto a mais para ler, um lugar a mais para procurar | "nada" (quem não sabe o custo não entendeu o padrão) |

Uma resposta que falha em qualquer das três é achado, não observação. O padrão
sai, ou a justificativa entra no `plan.md`.

**Padrões já justificados no projeto** estão na tabela de `AGENTS.md` §7.7 —
fachada por `defdelegate`, comando/consulta, porta e adaptador na borda HTTP,
estratégia declarativa em YAML, data mapper, upsert por chave natural, relator e
discriminador. Esses não precisam ser rejustificados a cada uso; usar **fora** do
problema que os motivou, sim.

## Passo 2 — Caça aos antipadrões

Percorra a lista de `AGENTS.md` §7.7. Estes são os que rendem mais achado neste
repositório, com o que procurar:

| Antipadrão | Onde procurar |
|---|---|
| Consulta sem tenant | `Repo.` sem `tenant_id` na cláusula; função pública de leitura sem `%Tenant{}` na assinatura |
| Fallback silencioso | `rescue`, `|| 0`, `|| []`, `_ -> :ok`, `catch` — cada um esconde uma falha |
| Booleano no lugar do relator | campo `is_*` ou `*_at` único onde o conceito tem contexto, período ou acúmulo |
| Mock de domínio próprio | `defmock` para módulo que não é borda de I/O |
| Configuração que enfraquece gate | mudança em `.credo.exs`, `.formatter.exs`, `dialyzer:`, `@dialyzer`, `--exclude`, `@tag :skip` |
| Acoplamento temporal | efeito registrado **antes** do trabalho que ele descreve — checkpoint, contador, log de sucesso |
| Estado como string livre | campo de status sem `check_constraint` ou `Ecto.Enum` |
| Primitivo no lugar do conceito | `tenant_id` cru cruzando fronteira de módulo, onde `%Tenant{}` diria mais |
| Exceção como fluxo | `raise` em caminho de negócio previsto |
| N+1 | `Enum.map` sobre resultado de query que consulta de novo |
| Generalidade especulativa | behaviour com uma implementação; parâmetro que só recebe um valor; `case` com um ramo real |
| Número mágico | literal numérico em condição, sem nome nem comentário do porquê |

Para cada achado, produza: **onde**, **qual antipadrão**, **o que quebra na
prática**, e **a correção mínima**. "Poderia ser melhor" não é achado.

## Passo 3 — O que a mudança apagou

Duas perguntas que a lista não cobre e que costumam render:

- **Alguma distinção semântica foi achatada?** Papel virando coluna, planejado
  virando executado, evidência virando fato. Confira contra a tabela de distinções
  de `AGENTS.md` §6.
- **Alguma ausência virou zero?** Contagem, `default: 0`, `||`, campo preenchido
  onde a informação não existe. Ausência é nula — a diferença entre "não sei" e
  "é zero" é a diferença entre lacuna e mentira.

## Saída

Uma tabela, do mais grave para o menos:

| # | Onde | Achado | O que quebra | Correção mínima |
|---|---|---|---|---|

Depois dela, duas seções curtas:

- **Padrões introduzidos e suas justificativas** — a tabela das três perguntas, com
  o veredito de cada um;
- **O que foi verificado e está bem** — nomeie o que passou. Uma revisão que só
  lista problema não distingue código bom de código não lido.

Sem achado, diga isso e mostre o que foi conferido.

## O que esta revisão não faz

- **não sugere padrão que o código não pediu.** A pergunta "que padrão caberia
  aqui?" é a origem do problema que este skill existe para evitar;
- **não pede refatoração fora do escopo da mudança.** Código feio que a feature
  não toca fica onde está — refatoração oportunista tem critério de revisão
  próprio e não entra neste diff (`AGENTS.md` §17);
- **não repete o Credo.** Se o gate pega, não é achado aqui.
