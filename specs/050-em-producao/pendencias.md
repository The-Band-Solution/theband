# Pendências da 050 — o que a produção deixou em aberto

Registro do que a primeira produção revelou e **não** foi corrigido nela. Cada
item traz o que aconteceu, por que ficou de fora, e o que dispara a correção.

Pendência sem gatilho vira lista morta: quem lê não sabe quando agir.

---

## P1 — A origem do socket depende do `PHX_HOST`

**O que aconteceu.** Em 2026-09-01, o primeiro deploy subiu com
`PHX_HOST=vmi3547213.contaboserver.net` enquanto as pessoas acessavam por
`theband.5.189.161.85.sslip.io`. O HTTP respondeu 200 e a página carregou; o
socket do LiveView foi recusado com **403**, e o navegador tentou reconectar em
laço — o log registrou `_mount_attempts => "79"`, caindo para `:longpoll` a cada
falha.

**Por que isso passou.** `check_origin` não está configurado em produção. Sem
ele, o Phoenix aceita apenas a origem igual à `:url`, que vem do `PHX_HOST`. Isso
amarra duas coisas diferentes: `PHX_HOST` serve para **gerar** URLs — links,
redirecionamentos —, e a origem aceita no socket é **por onde as pessoas
chegam**. Com um endereço só, as duas coincidem e ninguém nota.

**O que o defeito custou.** A plataforma parecia no ar e não era interativa.
Nenhum LiveView funcionava — nenhuma validação em tempo real, nenhuma navegação
sem recarregar. E não havia erro visível: só uma barra de carregamento que não
terminava. É a classe do **sucesso silencioso**, na direção do falso positivo:
o HTTP verde afirmando algo que o socket contradizia.

**A correção proposta**, em `config/runtime.exs`:

```elixir
check_origin:
  ["https://" <> host] ++
    ((System.get_env("PHX_ORIGENS_EXTRAS") || "") |> String.split(",", trim: true))
```

Comportamento atual preservado sem configurar nada; passa a permitir mais de um
endereço; e a decisão fica escrita, em vez de implícita no padrão da biblioteca.

**Gatilho**: o dia em que houver um segundo endereço — domínio próprio com o
`sslip.io` ainda respondendo, ou ambiente de homologação. Nesse dia isto deixa de
ser pendência e vira bug.

**Não corrigido na 050 por quê**: o endereço único funciona, e a spec do domínio
próprio (FR-013 adiado) é onde o segundo endereço nasce. Corrigir antes seria
resolver um problema que ainda não existe — princípio VIII.

---

## P2 — `force_ssl` depende de cabeçalho de terceiro, sem teste

**O que é.** `config/prod.exs` traz `force_ssl: [rewrite_on: [:x_forwarded_proto]]`.
O comportamento correto depende de o proxy à frente enviar esse cabeçalho.

**Estado hoje**: o Traefik do Dokploy envia — conferido em 2026-09-01, com
`/sign-in` respondendo 200 e sem laço de redirecionamento.

**O risco**: é a mesma classe do P1 — comportamento nosso que depende de
configuração de outra pessoa, **sem teste que o prove**. Um proxy trocado, ou uma
configuração alterada no painel, e a plataforma entra em laço de redirecionamento
sem que nada no repositório tenha mudado.

**Gatilho**: troca de proxy, de provedor, ou primeira vez que a plataforma for
servida atrás de outra coisa que não o Traefik do Dokploy.

---

## P3 — A primeira conta não tem caminho no produto

**O que aconteceu.** A produção subiu com o banco vazio, e **ninguém conseguia
entrar**. O `seeds.exs` levanta em produção de propósito, e `/accounts`
pressupõe que já exista alguém administrando.

**Estado**: virou a **spec 052**, com plano, contrato e 15 tarefas. Enquanto ela
não entrega, o caminho é console dentro do contêiner — passo manual que o
runbook não descreve.

**Gatilho**: já disparado. É trabalho selecionado, não pendência adormecida.

---

## P4 — O runbook não cobre o primeiro acesso

**O que é.** O runbook descreve VPS, segredos, app, banco, backup, rollback e
release. Não diz como nasce a primeira conta, nem como se confere que a
plataforma está utilizável — só que ela responde.

**Estado**: T014 da 052 acrescenta o §8.

**Gatilho**: junto com a 052.

---

## O que a primeira produção provou que estava certo

Vale registrar, porque pendência sozinha dá a impressão de que tudo deu errado.

- **O entrypoint derrubou o contêiner** quando não resolveu o nome do banco, em
  vez de subir a aplicação contra um banco inacessível. Sem o `set -e`, a
  plataforma estaria no ar mostrando zero em todas as telas — indistinguível de
  "ainda não coletamos nada".
- **A migração rodou antes do endpoint**, na ordem que o contrato exige, e o log
  disse as duas coisas.
- **O CD falhou dizendo o que faltava** — `DOKPLOY_WEBHOOK_URL ausente nos
  Secrets — a imagem e a tag existem, mas NÃO houve delivery`. A falha aconteceu
  por uma corrida de 8 segundos entre o workflow ler o segredo e ele ser criado;
  a mensagem deixou claro o que existia e o que não, e o re-run resolveu.
- **Nenhum segredo na imagem**: `docker history` e `Config.Env` limpos, medidos
  antes do primeiro release.
