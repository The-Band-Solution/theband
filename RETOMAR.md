# Retomar — estado em 2026-09-24: a v0.9.1 no ar e conferida, a v0.10.0 esperando, e a 062 por começar

**Este é o único documento de estado.** `docs/sprints/RETOMAR.md` aponta para cá (AGENTS.md §5).

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

---

## Onde parei, em uma frase

**A v0.9.1 está no ar e foi conferida do lado anônimo**. `development` já carrega o que vai
ser a **v0.10.0**. O próximo trabalho é a **062 (servidor MCP)**: o plano foi
reconciliado com o código (#944), e a primeira tarefa é a **revisão independente** (T009),
antes de qualquer código (ver §2).

## O primeiro comando

```bash
git fetch origin --prune && git status --short     # 1. NADA fora de commit — antes de tudo
git checkout development && git pull
mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?"    # o veredito é o CÓDIGO DE SAÍDA, colado
```

A suíte inteira é inviável com o servidor dev de pé. Para conferir: `pgrep -fl phx.server`.
A base de conhecimento **só carrega no boot**. Regra nova na base exige reiniciar o servidor,
ou ela não existe para quem está rodando.

---

## O que está no ar

A **v0.9.1** (tag em `679c2d7`), desde 2026-09-24. O CD fechou **verde pela primeira vez em
três releases**, e `/version` devolve `0.9.1`. O secret `PRODUCAO_URL` existe no GitHub.

**O número está errado**: a carga é MINOR, porque o #939 entrou no PR de release depois da
avaliação. A tag **não foi mexida**, de propósito, e a próxima é `0.10.0`. A história inteira
está em `docs/releases/v0.9.1.md`. A lição: um PR `development → main` carrega o que
`development` tiver **no instante do merge**. Reabra a medida antes de clicar.

O back-merge da v0.9.1 foi feito (`1ed4b17`), e `main` não tem commit fora de `development`.

### A conferência em produção

`docs/producao/aceitacao/2026-09-24-v0.9.1.md`. **Só o lado anônimo**: a pessoa mantenedora
decidiu que **não haverá conta de aceitação** (`PRODUCAO_TESTE_EMAIL`/`SENHA`) por enquanto.

| satisfeito | não medível sem conta |
|---|---|
| `/version`, `401` uniforme nas 8 rotas, `/api-tokens` redireciona sem sessão, nenhum vazamento de token | tela autenticada, migração do #939 vista na tela, token válido, revogado e expirado, o código `405`, cabeçalhos de limite |

"Não medível" **não é aceito**. O SC-004 (o motivo da recusa no log) fica para o agente
`deploy-producao`, e os `request_id` estão no relatório.

`PRODUCAO_URL` também está no `.env` local, que é de onde o agente lê. É uma variável
**separada** de `PHX_HOST`, de propósito: são perguntas diferentes que hoje têm a mesma
resposta.

---

## O que fazer, em ordem

### 1. Decidir a v0.10.0 — é da pessoa mantenedora

`development` à frente de `main`, sem os merges:

| commit | o que traz |
|---|---|
| #941 | **o botão `Copy value` passa a copiar** — em produção ele não copia desde a v0.8.0, sem mostrar erro. É o único defeito conhecido que faz alguém perder uma credencial |
| #942 | guardas da régua, e o SC-013, que antes não media nada. Só teste |
| docs | a nota da v0.9.1, a conferência, e a ordem 401→405 escrita em `contracts/erro.md` |

**Candidato a entrar antes**: o #943 (abaixo). O conserto é pequeno.

O `mix.exs` já diz `0.10.0`. Use `/release`, e **meça de novo antes de mergear o PR de
release**, que foi o que faltou na v0.9.1.

### 2. A 062 — o plano foi reconciliado; falta a revisão independente

`specs/062-servidor-mcp/`: spec, plano, pesquisa, contratos, `seguranca.md` e **26 tarefas
abertas**. Reconciliado contra o código em 2026-09-24, no **#944**.

O que a reconciliação achou: o #936 e o #938 já tinham criado o registro de leitura e o limite
que o plano mandava criar. **E reusá-los como estão traz dois defeitos altos**:

- **A6**: o registro grava o molde da rota e `params["id"]`. No MCP, toda linha diria só `/mcp`;
- **A7**: o registro grava todo `2xx`, e a recusa do MCP sai em `200`. A recusa seria gravada
  como leitura.

Os dois viraram T021 e T022, e exigem mexer no `ApiReadLog`, que é código da 061 em produção.

**A próxima tarefa é a T009, e não a T001**: o agente `security` avalia o desenho reconciliado
e o código que ele reusa. A autoavaliação errou justamente no A7.

### 3. Depois da 062: tracing com SigNoz

Decisão da pessoa mantenedora em 2026-09-24. O terreno já existe:

- o épico #802, em `docs/backlog/observabilidade-com-opentelemetry.md`. O eixo é **a jornada
  de quem usa**, e não a métrica do servidor. O exemplo original: *"quem deu erro ao fazer
  login ou logout"*;
- a ADR 0005, `docs/adr/0005-telemetria-da-jornada.md`, ainda em **Proposta**. O SigNoz fecha
  a escolha de backend que o épico deixava aberta. **Emende a ADR antes de qualquer código.**

**Meça primeiro**: o SigNoz roda sobre ClickHouse, que pede vários GB de RAM, no mesmo VPS da
aplicação e do Postgres. Se não couber, as saídas são o SigNoz Cloud ou um segundo VPS. A
primeira fatia é uma jornada visível (login/logout), e não a infraestrutura sozinha.

---

## Abertos que não são da fila principal

- **#943** — caminho inexistente em `/api/v1` devolve `404` com a **página HTML do site**, e
  não o erro JSON único. Reproduzido em produção. O Product Owner decide se é defeito ou
  lacuna da spec. O conserto provável é um `match :*, "/*path"` no fim do escopo, e está na
  issue;
- ~~**o token de produção que passou por um proxy que intercepta TLS**~~ — **Revogado em 2026-09-24 pela pessoa mantenedora** — declarado, e não medido: pela SC-003 um token revogado e um inexistente respondem igual, então a revogação não se confere de fora. O que
  sobra: conferir no painel de uso (#939) se esse token leu algo **depois** das medições;
- **a variável `PRODUCAO_URL` foi posta também no painel do servidor**. A aplicação não a lê.
  Não atrapalha, mas pode confundir. Pode tirar;
- **o `main` local deste checkout está em `0.2.0`**. Compare sempre contra `origin/main`;
- **worktrees antigas** em `~/projects/theband-*`, a maioria de releases já publicadas. Apague
  as que estiverem limpas, conferindo antes, porque `git checkout` apaga trabalho não
  commitado;
- o branch `061-api-fundacao` já está mergeado e ainda existe no remoto.

---

## O que se aprendeu e não se deve redescobrir

**Uma avaliação de release envelhece sozinha.** A v0.9.1 foi avaliada como PATCH com um
commit, e saiu com três commits, uma migração e três mudanças de tela. Nada avisou.

**Sem credencial, `401` vem antes de `405`**, por construção, porque a autenticação roda
antes dos `match :*`. Agora está escrito no contrato. Não é defeito.

**Caminho sem rota não passa pela pipeline.** É por isso que o `404` sai em HTML: o formato
da API nunca é aplicado a quem não casou rota nenhuma.

**Guarda que lê o próprio código reprova a prosa** (duas vezes em setembro). Teste o controle,
não a palavra, e ao ler fonte tire comentário e documentação antes.

---

## O que NÃO foi feito, e é honesto dizer

- **nada autenticado foi conferido em produção** — e não vai ser, enquanto não houver conta;
- **o botão `Copy value` copiando de fato** não se verifica em produção sem gerar um token,
  mesmo com conta. Só se confirmou que o ouvinte não está no JS servido;
- **a v0.10.0 não foi preparada** — nem nota, nem avaliação de riscos;
- **as decisões antigas da 066** (entregue ou pela metade, as três tabelas de declaração
  zeradas, as 377 entregas do quadro 43 fora do gráfico) **não foram reconferidas** desde
  2026-09-18.
