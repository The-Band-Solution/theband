# Sprint 026 — Review

**Período**: 2026-08-29 a 2026-09-01 — **fechado quatro dias antes** do fim
previsto (2026-09-05), porque o objetivo foi alcançado e ultrapassado: o sprint
prometia deixar a produção *a três marcos de distância*, e a produção está no ar.
**Features**: [050-em-producao](../../../specs/050-em-producao/spec.md) e
[052-primeira-conta-do-ambiente](../../../specs/052-primeira-conta-do-ambiente/spec.md),
mais a herança de [047](../../../specs/047-mensagens-internacionalizadas/spec.md) e
[051](../../../specs/051-cadastro-por-github/spec.md).
**Endereço**: <https://theband.5.189.161.85.sslip.io/sign-in> — VPS Contabo
`vmi3547213`, Dokploy, imagem `ghcr.io/the-band-solution/theband` nas tags
`v0.1.0`, `v0.2.0` e `latest`.

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 3 (050/US1–US3) | 6 avaliadas (3 da 050 + 3 da 052, esta não planejada) |
| Tarefas | 10 (3 de herança + 7 da 050) | 21 executadas (10 planejadas + 11 da 052) |
| Entregáveis aceitos | 4 | **5 de 8** |
| Releases | 0 (marco humano, fora do escopo) | **2** — v0.1.0 e v0.2.0 |

**Aceitação** ([registro completo](aceitacao.md)): 5 aceitos, 3 não aceitos.
Os três — **050/US1**, **050/US2** e os entregáveis fora de backlog — caem por
**critério sem evidência**, nunca por comportamento errado observado. Nada do que
foi medido reprovou; o que falta é medição que ninguém fez.

## O que foi feito

| Tarefa | Issue | PR | Entregável | Aceito |
|---|---|---|---|---|
| 047/T014 | [#617](https://github.com/The-Band-Solution/theband/issues/617) | [#630](https://github.com/The-Band-Solution/theband/pull/630) | D1 — as frases de função-origem passam pela borda | sim |
| 047/T015 | [#634](https://github.com/The-Band-Solution/theband/issues/634) | [#635](https://github.com/The-Band-Solution/theband/pull/635) | D2 — o verificador salta um nó, e a classe morre inteira | sim |
| 051/T009 | [#618](https://github.com/The-Band-Solution/theband/issues/618) | [#631](https://github.com/The-Band-Solution/theband/pull/631) | D3 — a busca diz a organização e a observação terminada | sim |
| 050/T001–T007 | [#623](https://github.com/The-Band-Solution/theband/issues/623)–[#629](https://github.com/The-Band-Solution/theband/issues/629) | [#632](https://github.com/The-Band-Solution/theband/pull/632) | D4 — imagem, CI, CD e runbook | sim |
| — (marcos humanos) | — | [#636](https://github.com/The-Band-Solution/theband/pull/636), [#641](https://github.com/The-Band-Solution/theband/pull/641), [#639](https://github.com/The-Band-Solution/theband/pull/639) | D5 — a produção no ar, e sua medição por critério | **não** — 050/US1 e US2 com critério sem evidência |
| 052/T001–T014 | **sem issues** | [#640](https://github.com/The-Band-Solution/theband/pull/640) | D6 — a primeira conta nasce do ambiente | sim |
| — | — | [#637](https://github.com/The-Band-Solution/theband/pull/637) | D7 — a porta pública fala pela metáfora | não classificável — sem user story |
| — | — | [#642](https://github.com/The-Band-Solution/theband/pull/642) | D8 — a barra não diz 100% durante a coleta | não classificável — é defeito, não user story |

## O que não foi feito

| O que | Motivo | Destino |
|---|---|---|
| SC-003 — ensaio de restauração **em produção** | o dry-run local provou o procedimento; o backup do Dokploy nunca foi restaurado | **primeira da fila do sprint 027**, com bloqueador nomeado: acesso ao painel |
| SC-006 — 7 dias de rotina de cópia | a rotina começou em 2026-09-01 | vence sozinho em 2026-09-08 |
| AS4/AS5 e SC-001 da 050/US1 | ninguém cronometrou o release nem o primeiro acesso | tarefa nova de medição no próximo release |
| Issues da 052 no GitHub | o ciclo pulou `/speckit-taskstoissues` | criar antes de encerrar a 052 |
| Encerramento de #620–#629 | correto pela DoD — só depois da aceitação | depende da confirmação do [registro](aceitacao.md) |

## Entregáveis não aceitos

**D5 — a produção no ar**, pelas user stories 050/US1 e 050/US2.

**050/US1** falha em três critérios *não avaliados*: a sessão sobreviver ao
release (AS4), a janela de indisponibilidade ser curta (AS5) e o percurso de
entrar e ver painel em menos de dois minutos (SC-001). Os outros quatro
critérios conformes, dois deles medidos nesta avaliação: HTTP simples devolve
**301** para HTTPS, e `/sign-in` responde **200 em 0,65s**. A US volta ao product
backlog como **tarefa nova de medição** — nunca reabrindo a #620.

**050/US2** falha em AS1 (não há evidência de que a cópia exista **fora** da
máquina de produção) e AS3 (nunca se provocou uma falha de backup para ver se ela
aparece), e AS2 só tem a metade local: origem `88/12/3` restaurada em `88/12/3`,
conferida pela própria imagem. **A janela para ensaiar está se fechando** — a
produção já tem 4895 issues coletadas, e o ensaio era barato enquanto não havia
dado que importasse.

**D7 e D8 não são recusas**: são entregáveis sem user story no sprint backlog.
Pelo axioma `sro.rule01`, escopo que entrou sem passar pelo planejamento. D8 é
defeito de produção — `osdef.defect`, não user story.

## Evidências

- **Gates**: `mix gates` → **14/14 verdes**, `CODIGO_DE_SAIDA_DO_GATE=0`, lido em
  comando separado (L60), em 2026-09-01 na `development`.
- **Produção, medida de fora nesta avaliação** (2026-09-01 11:52 UTC):
  `http://…/sign-in` → **301** com `Location: https://…`; `https://…/sign-in` →
  **200 em 0,650s**; sete rotas de dados sem sessão (`/people`, `/teams`,
  `/organizations`, `/work`, `/syncs`, `/accounts`, `/roles`) → **302 em todas**.
- **SC-004 da 052, medido aqui**: dez chamadas seguidas de
  `Bootstrap.criar_primeira_conta/1` → **1 administrador e 1 organização**, com
  `%{criada: 1, ja_existe: 9}`. O teste entra no repositório neste fechamento.
- **Duas injeções na 052**, feitas para provar o teste novo: a primeira
  (verificação de administrador desligada) foi pega pelo teste do e-mail
  diferente; a segunda (leitura da corrida perdida desligada) **passou nos 16
  testes** e revelou teste fraco — o da corrida contava só o vencedor. Com a
  asserção do perdedor acrescentada, a mesma injeção reprova: **15/16**.
- **Coleta conferida contra a origem**: 125 repositórios, 4895 issues, 15
  quadros, 3981 itens de quadro.
- **Medição por critério da 050**:
  [medicao-do-primeiro-release.md](../../../specs/050-em-producao/medicao-do-primeiro-release.md).
- **CI**: verde nos nove PRs do sprint, com os três workflows (quality-gates, a
  imagem de produção builda, cobertura).

## Dívida gerada

**Segurança — rotações pendentes**, todas nascidas de coisas que passaram pelo
chat durante a implantação:

1. o `Webhook URL` do Dokploy apareceu legível num print — regenerar e refazer
   `gh secret set DOKPLOY_WEBHOOK_URL`;
2. cinco senhas foram coladas na conversa, uma delas com forma de senha pessoal
   reutilizada — trocar onde valerem;
3. a senha do banco `theband-postgres` foi colada junto da `DATABASE_URL` — o
   banco nasceu vazio, e rotacionar é barato;
4. `THE_BAND_ADMIN_SENHA` continua no painel do Dokploy — removê-la; no boot
   seguinte o log dirá `já existe administrador`, e a conta continua.

**Técnica**, registrada em [pendencias.md](../../../specs/050-em-producao/pendencias.md):

- **P1** — a origem do socket depende do `PHX_HOST`; vira bug no dia em que
  houver um segundo endereço;
- **P2** — `force_ssl` depende de cabeçalho de terceiro, sem teste;
- **P4** — o runbook não cobria o primeiro acesso (fechado pela 052/T014).

**De processo**: as issues da 052 não existem, seis PRs foram mergeados sem
revisor pedido, e nenhum PR do sprint tem revisão registrada. Detalhado em
[aceitacao.md](aceitacao.md), seção "Lacunas de processo".

## Lições deste sprint

Oito, consolidadas em [licoes-aprendidas.md](../licoes-aprendidas.md):

| # | Lição |
|---|---|
| L83 | Squash-merge no release diverge os históricos |
| L84 | O painel dizer `Done` não significa aplicação no ar |
| L85 | Um 200 de HTTP pode afirmar o que o socket contradiz |
| L86 | Denominador móvel mente igual a denominador inventado |
| L87 | Fase invisível faz trabalho parecer travado |
| L88 | Um segredo de 8 segundos — e o contrato que salvou o diagnóstico |
| L89 | PR sem revisor pedido não é PR revisado, e o merge não sabe disso |
| L90 | Contar só o vencedor da corrida não prova o perdedor |

E uma **reincidência**, a quinta: substituição de texto sem asserção passando em
silêncio — o `mix format` quebrou a linha de uma chamada, a substituição não
casou, e o teste seguiu reprovando enquanto se procurava a causa em outro lugar.

## O que a produção provou estar certo

Vale o registro porque foi decisão de desenho, tomada antes e contra a
conveniência:

- **o entrypoint derrubou o contêiner** ao não resolver o banco, em vez de servir
  zero em toda tela;
- **a migração rodou antes do endpoint** atender;
- **o CD falhou dizendo o que faltava** — *"a imagem e a tag existem, mas NÃO
  houve delivery"* —, e por isso ninguém procurou a imagem no lugar errado;
- **a imagem não carrega segredo nenhum**, medido antes do primeiro release.
