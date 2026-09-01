# Retomar — estado em 2026-09-01 (madrugada), a plataforma EM PRODUÇÃO

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

## O que mudou nesta sessão, em uma frase

**A plataforma saiu do repositório e foi para produção**: v0.1.0 e v0.2.0
publicadas, VPS Contabo com Dokploy, banco, backup, e a primeira conta nascendo
do ambiente — com alguém de fato entrando e a coleta trazendo as 4895 issues da
`leds-conectafapes`.

## O endereço

| o quê | onde |
|---|---|
| **a plataforma** | https://theband.5.189.161.85.sslip.io/sign-in |
| painel do Dokploy | https://vmi3547213.contaboserver.net/ |
| VPS | Contabo `vmi3547213`, IP `5.189.161.85`, Cloud VPS 4, 100 GB |
| imagem | `ghcr.io/the-band-solution/theband` — tags `v0.1.0`, `v0.2.0`, `latest` |

## PRs abertos ao fim da sessão

| PR | O que é | Estado |
|---|---|---|
| [#642](https://github.com/The-Band-Solution/theband/pull/642) | a barra não diz 100% enquanto a coleta anda; fase de quadros na tela; linha de atividade | **ABERTO** — 14 gates verdes, 9/9 testes |
| PR desta escrita | este RETOMAR | abrir/mergear |

Mergeados nesta sessão: #635 (047/T015), #636 (release v0.1.0), #637 (porta
pública fala pela metáfora), #638 (spec+plan+tasks 052), #639 (medição da 050),
#640 (implementação da 052), #641 (**release v0.2.0**).

## PENDÊNCIAS DE SEGURANÇA — fazer primeiro

Estas nasceram de coisas que passaram pelo chat e **precisam ser rotacionadas**:

1. **O `Webhook URL` do Dokploy** apareceu legível num print
   (`.../api/deploy/LYja3JJLgxtIPSgCHfwAx`). Regenerar pelo ícone de recarregar
   na aba `Deployments` da aplicação, e depois `gh secret set DOKPLOY_WEBHOOK_URL`.
2. **Cinco senhas foram coladas na conversa** durante a tentativa de acesso SSH,
   incluindo uma com forma de senha pessoal reutilizada. Trocar onde valerem.
3. **A senha do banco** (`theband-postgres`) foi colada junto com a
   `DATABASE_URL`. O banco nasceu vazio; rotacionar é barato.
4. **`THE_BAND_ADMIN_SENHA`** continua no painel do Dokploy. Removê-la — no boot
   seguinte o log dirá `já existe administrador`, e a conta continua.

## O que fazer ao retomar, na ordem

1. **As quatro rotações acima.**
2. **Merge do #642** e deste PR.
3. **Fechar o sprint 026** — `sprint-review.md` e as lições. Esta sessão produziu
   pelo menos seis, listadas abaixo.
4. **A tela de issue** — pedido novo, ainda sem spec (ver adiante).
5. **O ensaio de restauração em produção** (SC-003) — o dry-run local provou o
   procedimento; falta executá-lo contra o backup do Dokploy, **antes** de haver
   dado que importe. A janela é agora.

## Pedido novo, ainda sem spec

**A discussão de uma issue vai para o lado esquerdo, e a distribuição da página
melhora.** Pedido da pessoa mantenedora em 2026-09-01, sobre a tela de detalhe de
issue. Não há spec, plano nem tarefa — começar pelo `/speckit-specify`.

## Lições que esta sessão produziu

Para entrarem em `licoes-aprendidas.md` no fechamento do sprint:

**L83 — Squash-merge no release diverge os históricos.** O #636 entrou na `main`
por squash, criando um commit que a `development` não conhecia. O merge de volta
abriu 6 conflitos, todos de conteúdo idêntico. Resolvido com back-merge (a árvore
resultante era idêntica à da `development`). Sem ele, o release seguinte abriria
os mesmos conflitos, maiores. *Ação: back-merge após cada release, ou trocar o
squash por merge commit em `development → main`.*

**L84 — O painel dizer `Done` não significa aplicação no ar.** O Dokploy marcou
dois deploys como concluídos enquanto o contêiner morria em laço: `Done` é "criei
o serviço", não "o processo sobreviveu". *Ação: a prova é sempre a medição de
fora.*

**L85 — Um 200 de HTTP pode afirmar o que o socket contradiz.** Com o `PHX_HOST`
apontando para o host do painel, o `check_origin` recusava o WebSocket com 403
enquanto a página respondia 200. O log registrou `_mount_attempts => "79"`. Para
quem olhava, era uma barra de carregamento que não terminava. *Ação: medir o
socket, e não só o HTTP.*

**L86 — Denominador móvel mente igual a denominador inventado.** A barra de
`/syncs` marcava 100% durante a coleta inteira porque o total crescia junto com o
coletado. Enganou inclusive a investigação. *Ação: sem total fechado, contagem —
nunca percentual.* Corrigido no #642.

**L87 — Fase invisível faz trabalho parecer travado.** A coleta de quadros roda
depois da promoção e não tinha linha na tela nem checkpoint. Com as sete fases
cheias e o sync `running`, a conclusão natural era que travara — quando faltavam
15 quadros e 3981 itens. Corrigido no #642.

**L88 — Um segredo de 8 segundos.** O CD da v0.1.0 falhou porque leu
`DOKPLOY_WEBHOOK_URL` oito segundos antes de o segredo ser criado. A mensagem do
contrato salvou o diagnóstico: *"a imagem e a tag existem, mas NÃO houve
delivery"*. *Ação: nenhuma — o contrato já fazia o certo. Registrar como
confirmação.*

E a **reincidência da L-do-`replace`-sem-`assert`**, quinta ocorrência: o
`mix format` quebrou a linha de uma chamada, a substituição não casou, e o teste
seguiu reprovando enquanto eu procurava a causa em outro lugar.

## O que a produção provou estar certo

Registrado em [pendencias.md](../../specs/050-em-producao/pendencias.md) e vale
repetir: o entrypoint derrubou o contêiner ao não resolver o banco, em vez de
servir zero em toda tela; a migração rodou antes do endpoint; o CD falhou dizendo
o que faltava; e a imagem não carrega segredo nenhum — medido antes do primeiro
release.

## Estado da 050 e da 052

**050** — [medição](../../specs/050-em-producao/medicao-do-primeiro-release.md)
com veredito por critério. SC-004 e SC-005 atendidos, SC-002 atendido, SC-001 era
parcial por falta de conta (a 052 fechou), SC-003 falta em produção, SC-006
precisa de sete dias. Quatro pendências com gatilho.

**052** — implementada e em produção. 15 testes, as violações primeiro. Uma
tarefa em aberto: T015 (gates e PR), que este próprio ciclo cumpriu.

## Sobre a coleta da leds-conectafapes

Números conferidos contra a origem, para não reabrir a dúvida: **125
repositórios, 4895 issues, 15 quadros, 3981 itens de quadro**. A coleta trouxe
125 e 4895 — nada faltou. O `666` que assustou era leitura parcial de um
denominador que ainda crescia.
