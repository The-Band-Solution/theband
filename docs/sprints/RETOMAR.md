# Retomar — estado em 2026-08-29 (noite), sprint 025 implementado e a produção reaberta

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

## Onde o trabalho parou

**Sprint 025 implementado inteiro; falta o fechamento — e a produção (050) reabriu.**

| PR | O que é | Estado |
|---|---|---|
| [#612](https://github.com/The-Band-Solution/theband/pull/612) | **051** — /accounts cadastra a pessoa e associa o GitHub num fluxo só | **ABERTO** — 14 gates verdes, revisão pedida ao abrir (Adylla027/EduardoNFraiz), no board; CI em curso no fim da sessão |
| PR desta escrita | RETOMAR + Contabo/CD registrados na spec 050 | abrir/mergear |

Mergeados nesta sessão (autorização "pode fechar"): #607 (flake da API_KEY), #608
(fechamento do sprint 024), #611 (retrabalho da 047 — classe assign), #596 (spec 051,
pela pessoa mantenedora).

## O que fazer ao retomar, na ordem

1. **Merge do #612** (e deste PR de docs) — conferir CI; a revisão foi pedida ao
   abrir; se ninguém revisou, a decisão é da pessoa mantenedora (o resíduo do 024
   está registrado e não pode virar rotina).
2. **Fechar o sprint 025**: aceitação do PO (agente com a REGRA de não trocar de
   branch — L79), issues #597–#606 e #609–#610 fechadas APÓS a aceitação (ordem
   certa desta vez, DoD do backlog), sprint-review, lições.
3. **Produção (050) — reaberta em 2026-08-29**: "vamos preparar para enviar o
   contabo.com". Decisões tomadas e REGISTRADAS na spec: VPS **Contabo** com Docker
   (FR-012), endereço do provedor sem domínio próprio por ora (FR-013), backup do
   provedor + restauração ensaiada (FR-014), e **FR-015 novo: publicar e atualizar é
   CD no GitHub** — workflow de Actions que builda a imagem e atualiza o VPS por SSH
   (chave em GitHub Secrets, NUNCA no repositório), migração antes de atender. O
   "agente de publicação" pedido = o workflow + runbook. **Refinado no mesmo dia**:
   a camada de operação no VPS é o **Dokploy** (TLS/Traefik, env vars, Postgres com
   backup agendado, histórico de imagens), com o auto-deploy-on-push DESLIGADO — o
   deploy é o Actions verde publicando em `ghcr.io` e chamando o webhook. E a
   release ganhou dona (**FR-016**): o Product Owner define a versão (semver sobre
   entregáveis ACEITOS), propõe a tag após a aceitação confirmada, e decide o
   MOMENTO do delivery — tag não é deploy; alçada registrada em
   `.claude/agents/product-owner.md`, seção "A release é sua". Próximo passo:
   `/speckit-plan` da 050 → sprint 026. O deploy real espera a pessoa mantenedora
   criar o VPS na Contabo, instalar o Dokploy e colocar webhook/segredos nos GitHub
   Secrets — pedir quando o plano chegar lá (motivo legítimo de parada: credencial).
4. Depois da produção: **049** (entrar com GitHub — depende de endereço público),
   e **#568** (gestão da marca de admin, precisa de spec).

## O sprint 025 até aqui (evidência nos PRs)

- **Retrabalho da 047 (mergeado, #611)**: verificador v2 com o ralo `assign` de
  mensagem (13 pontos achados por AST onde a leitura estimou 9 — L76), todos
  migrados; pendências refeitas com amostragem independente (L80); US3 alinhada.
  As US #573/#574 recusadas no 024 têm agora o retrabalho ENTREGUE — a aceitação
  do 025 decide se fecham.
- **051 (PR #612)**: `cadastrar_conta/3` transacional (temporária no ato; duplicado
  não cria nada), `user_of_person/2` nomeando a dona do conflito,
  `EO.person_logins/2` (lista em duas consultas fixas), tela com busca por evento,
  associação pela identidade estável, revogação com auditoria. O teste da 045
  "nasce sem senha" mudou COM o requisito (L71, razão no próprio teste). Captura
  olhada: os dois estados ao vivo.

## Operação local

- Dev server: `set -a && source .env && set +a && mix phx.server` (chave mestra no
  `.env`, fora do repositório — nunca no chat). **L74**: a árvore decide o que ele
  serve. Login dev: `senha-de-dev` (seeds; recusada em :prod).
- Gates: `mix gates > log 2>&1; echo "EXIT=$?" >> log` — veredito DENTRO do log
  (L60). São 14.
- **L75 vale sempre**: antes de declarar mergeado ou apagar branch, conferir por
  CONTEÚDO; e nunca empurrar em branch cujo PR já fechou.
- **L79**: agente que toca o repositório recebe ordem explícita de NÃO trocar de
  branch; ao retomar de qualquer agente, conferir `git branch --show-current`.
- Env var em teste: restauração SIMÉTRICA sempre (o flake do #607).
