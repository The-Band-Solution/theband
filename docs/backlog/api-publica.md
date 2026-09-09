# A API pública com token — o The Band consumido de fora

Pedido da pessoa mantenedora em 2026-09-08. A spec existe:
[061](../../specs/061-api-publica/spec.md), rascunho, com **oito perguntas
abertas** e **três delas bloqueando** o `/speckit-plan`.

> *"Faça uma especificação de adicionar no The Band a funcionalidade de ser
> consumido via API. Para consumir a API o cliente precisa de um token que será
> gerado na área administrativa. A API precisa de ter Swagger."*

O `router.ex` já declara a pipeline `:api`, e **nenhuma rota passa por ela**. A
pipeline está lá desde o gerador; a porta nunca foi aberta. Hoje a única forma de
sair com um número do The Band é o olho de quem olha a tela.

## O que muda de estado no projeto

Esta é a **primeira vez que o The Band tem contrato público**. Até aqui, toda
mudança de rota, de serialização e de nome de campo era assunto interno. Depois
desta feature, cada um deles tem alguém do outro lado que quebra quando muda — e é
por isso que a [ADR](../adr/README.md) é obrigatória: *"alterar contratos
públicos"* está na lista de gatilhos, e criar o primeiro é o caso mais forte dela.

## Por que não é "expor o banco por JSON"

A plataforma existe para separar o **observado** do **derivado** e do
**declarado**. Uma resposta que entrega número sem essa marca destrói a distinção
no ponto de entrega — e o consumidor pode ser um modelo, que vai afirmar o número
sem a ressalva. É o mesmo argumento de [`servidor-mcp.md`](servidor-mcp.md), e vale
igual aqui: **proveniência e limitações declaradas viajam no mesmo objeto da
medida**, e ausência vem nomeada, nunca como `0`.

## Por que não é um segundo modelo de acesso

`TheBand.Tenants.Access` é o veredito único — `scopes/2`, `pode_ver/3`,
`pode_ver_equipe/3` — e resolve o problema. A proposta é que **o token pertença a
um tenant e a uma conta**, e que alcance exatamente o que aquela conta alcança, sem
nenhum ramo condicional novo para a origem API.

O custo é real e está registrado: **a integração pode parar de ver dado sem que
nada nela mude**, porque `Access` lê as relações vigentes a cada chamada. A
alternativa — token do tenant com escopo próprio — dá alcance estável e **é** o
segundo modelo de acesso, que divergiria do primeiro. É a pergunta Q2 da spec.

## O que desbloqueia

[`servidor-mcp.md`](servidor-mcp.md) está marcado **bloqueado** no
[README](README.md) com a razão exata: *"depende de decidir autenticação e
tenant"*. É a decisão 1 daquele documento, e é o que esta feature decide. O
servidor MCP continua fora de escopo — mas deixa de estar bloqueado por ela.

## O primeiro corte

Somente leitura, e só consultas **que já existem e já são apresentadas em tela**:
equipes, membros da equipe, medidas da equipe, pessoas, projetos, sincronizações.
Nenhum endpoint para dado que a plataforma não tem.

**Somente leitura não é cautela, é a proveniência.** Toda escrita nesta plataforma
registra *quem declarou* — `declared_by_user_id`, proveniência declarada. Um token
não é uma pessoa, e atribuir a escrita à conta dona registraria como declaração
humana algo que nenhuma pessoa declarou. É o mesmo raciocínio da decisão 2 do
servidor MCP.

Fora do primeiro corte, com a razão de cada um: contas e concessões (administrar
acesso pela API amplia a superfície no recurso que **governa** o acesso),
credenciais e chaves de AI (são segredo), dados brutos (volume de outra ordem),
mudanças e verificações (nenhuma demanda observada), previsão (número derivado com
limitação forte, antes de a tela estabilizar).

## Ordem proposta, e o que trava o quê

| Fase | O que é | Depende de |
|---|---|---|
| 1 | o token: esquema, geração, hash, revogação | **Q1** (função de hash) e **Q2** (dono do token) respondidas |
| 2 | a tela de tokens na área administrativa | **protótipo aprovado pelo Design** |
| 3 | a autenticação por token e o primeiro endpoint | fase 1 |
| 4 | os demais endpoints de leitura, com proveniência e limitações | fase 3 |
| 5 | Swagger / OpenAPI | **ADR** com a decisão da dependência |
| 6 | limite de taxa | fase 3 |

**As fases 3 e 4 não têm tela e não dependem do protótipo.** É por elas que o
trabalho começa se a priorização decidir começar antes de o Design desenhar.

## O que trava, hoje

| Trava | Quem resolve |
|---|---|
| **ADR do contrato público** — versionamento, recusa uniforme, somente leitura, herança de alcance | Software Architect |
| **protótipo da tela de tokens** — a spec com tela não é decomposta sem ele | Design, depois pessoa mantenedora |
| **Q1** — que função de hash guarda o token, e o custo por requisição | Security, com o Architect |
| **Q2** — o token pertence à conta ou ao tenant | pessoa mantenedora |
| **Q3** — latência aceitável entre revogar e recusar | pessoa mantenedora |
| **avaliação de segurança** — 14 pontos listados na spec, de canal lateral de tempo a exposição do Swagger | Security |

## Sobre o limite de taxa: doutrina reusável, mecanismo novo

A [ADR 0007](../adr/0007-gestor-de-cotas.md) governa a cota que o The Band
**consome** do GitHub, e a decisão central dela **não transporta**: lá, *"a origem
conta por nós"* — os cabeçalhos `x-ratelimit-*` vêm em toda resposta, e o gestor lê
em vez de contar. Aqui **o The Band é a origem**: ninguém conta por nós, e contar é
o problema todo.

O que se reusa é a doutrina, e vale reusar: **decidir antes, e num só lugar** — o
inventário da 0007 achou seis portas de saída com quatro políticas, e a API nasce
com uma porta e uma política; **informar o saldo em cabeçalho em toda resposta**,
tratando quem nos consome como queremos ser tratados; e **teto de concorrência, não
só taxa por janela**, porque cem chamadas simultâneas dentro do limite ainda
derrubam a aplicação.

## Estado

**Ainda não implementada.** Spec [061](../../specs/061-api-publica/spec.md) em
rascunho, sem protótipo, sem ADR, sem plano.
