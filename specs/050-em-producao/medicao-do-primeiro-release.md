# Medição do primeiro release — 050

**Medido em**: 2026-09-01, contra `https://theband.5.189.161.85.sslip.io`,
servindo `v0.1.0` (`ghcr.io/the-band-solution/theband`, digest
`sha256:e4acfdd…`), VPS Contabo `vmi3547213` com Dokploy.

Os critérios da spec 050 só podiam ser medidos no endereço real. Isto é esse
registro — **o que foi medido, o que não foi, e por quê**.

## Os critérios

| | critério | medido | veredito |
|---|---|---|---|
| **SC-001** | pessoa de fora entra e vê painel em menos de 2 min | `/sign-in` **200** em 0,67–0,73s, três medidas; HTTPS Let's Encrypt válido | **parcial** — a porta responde, mas **não há conta** para entrar (P3) |
| **SC-002** | release em menos de 15 min de procedimento, menos de 2 min de janela | CD: build+push+tag em **1m43s**; entrega pelo webhook em **11s** no re-run | **atendido** para o pipeline; a janela de indisponibilidade não foi cronometrada |
| **SC-003** | restauração ensaiada, com os números conferidos | ensaio **local** em 2026-08-31: origem `eo_people=88 eo_teams=12 eo_organizations=3` → restaurado 88/12/3, conferido pela própria imagem lendo o banco restaurado | **não atendido em produção** — o backup do Dokploy ainda não foi ensaiado |
| **SC-004** | zero segredos no repositório, na imagem e nos logs | `docker history` e `Config.Env`: **0** ocorrências; log do contêiner: **0** | **atendido** |
| **SC-005** | 100% das rotas de dados recusam sem sessão | **19 de 21** devolvem 302; as 2 restantes são `/sign-in` e `/set-password`, públicas por desenho | **atendido** |
| **SC-006** | rotina de cópia roda 7 dias seguidos | — | **não medível ainda** — precisa de sete dias |

## O que a medição encontrou e a suíte não encontraria

**O socket do LiveView estava recusado, e nada dizia.** Com
`PHX_HOST=vmi3547213.contaboserver.net` e acesso por `sslip.io`, o `check_origin`
padrão do Phoenix recusava a conexão com **403**. O HTTP respondia 200, a página
carregava — e nenhum LiveView funcionava. O log registrou `_mount_attempts =>
"79"`: setenta e nove tentativas de montar, caindo para `:longpoll` a cada falha.

Para quem olhava a tela, isso aparecia como uma barra de carregamento que não
terminava. Nenhuma medida de HTTP pegaria: o 200 estava correto e afirmava algo
que o socket contradizia.

Corrigido trocando o `PHX_HOST`. Depois da troca, a mesma requisição sai de 403
para 400 — e 400 é o handshake incompleto do `curl`, não recusa de origem. A
fragilidade que sobrou está registrada em [pendencias.md](pendencias.md) P1.

**A distância entre "o painel diz Done" e "a plataforma responde".** O Dokploy
marcou dois deploys como `Done` enquanto o contêiner morria em laço: `Done`
significa que ele criou o serviço, não que o processo sobreviveu. Só a medição de
fora distingue as duas coisas.

**Um release pela metade, dito por inteiro.** O CD falhou no passo do webhook
porque o segredo `DOKPLOY_WEBHOOK_URL` foi criado **8 segundos depois** de o
workflow o ler. A mensagem foi a que o contrato pedia — *"a imagem e a tag
existem, mas NÃO houve delivery"* — e por causa dela ninguém procurou a imagem no
lugar errado. O re-run resolveu em 11s.

## O que falta para a 050 fechar

1. **Uma conta para entrar** (P3 → spec 052). Sem ela, SC-001 fica parcial: a
   plataforma responde e não é utilizável.
2. **O ensaio de restauração em produção** (SC-003, FR-008). O dry-run local
   provou o procedimento; falta executá-lo contra o backup do Dokploy, **antes**
   de haver dado real — que é justamente a janela em que estamos.
3. **Sete dias de rotina de cópia** (SC-006). Só o tempo resolve.
