# O aviso de vencimento só alcança quem abre a tela

**Adiado em 2026-09-23**, ao aprovar as três mudanças da tela de tokens: *"e aprovado .. mas
sem email"*. Este documento existe para que o adiamento seja **decisão registrada** e não
esquecimento — e para que quem retomar não precise remedir o que já foi medido.

## O que existe hoje

A regra `api.access.token_expiry_warning` está **aplicada**: a partir de 14 dias antes da
expiração, a linha do token diz quantos dias faltam em vez de só a data. É leitura contra o
relógio, feita no render — [`api_token_live/index.ex:79`](../../lib/the_band_web/live/api_token_live/index.ex).

Não é job, de propósito: job cria janela entre o vencimento e a passagem dele, e essa janela é
acesso concedido por atraso de fila.

## O que não existe, e é o item

**O aviso não sai da tela.** Quem não abre `/api-tokens` não é alcançado por nada. Um token
vence, a integração começa a receber `401`, e a descoberta acontece pela recusa — do lado de
quem consome, não do lado de quem administra.

A tela é a única superfície, e ninguém a abre sem motivo. O motivo costuma ser a quebra.

## Por que o e-mail não coube aqui

A resposta inicial da Q6 do protótipo foi *e-mail para quem criou, 14 dias antes*.

**Medido em 2026-09-23: esta plataforma não envia e-mail.** Nenhuma dependência no `mix.exs`
(nem Swoosh, nem Bamboo), nenhum módulo `Mailer`, nenhuma variável de ambiente de SMTP ou
provedor. Confirmado por varredura, não por lembrança.

Isso torna o item uma **feature própria**, e não um ajuste de tela. Carrega:

- a dependência e o provedor de entrega;
- credencial de envio, **fora do repositório** — a chave mestra já cifra credencial em repouso,
  então há onde guardá-la;
- o que acontece quando a entrega falha: fila, reenvio, e o registro de que **não** foi
  entregue. *Um aviso que não chegou e ninguém soube é pior que nenhum aviso*, porque cria
  confiança falsa;
- o endereço de destino: a conta tem `email`, e **ninguém confirmou que ele é alcançável**;
- e a fronteira que a 061 já declarou: `email` **não sai por rota nenhuma da API**. Um canal de
  e-mail não muda isso, e o item não pode virar a porta dos fundos dessa regra.

## O passo intermediário, quando o item voltar

A opção que não foi escolhida na Q6 — **uma linha na tela de operação** — resolve a maior
parte do risco sem abrir canal nenhum: quem administra vê os tokens perto do vencimento sem
ter de lembrar de abrir a tela deles.

Continua útil depois que o e-mail existir, e é ordens de grandeza mais barata. **É por onde
recomeçar**, se a prioridade voltar a subir.

## O que mediria se isto vale a pena

Nenhum token venceu ainda — a tabela `api_access_tokens` nasceu na v0.8.0, e *"sem expiração"*
passou a ser oferecido em 2026-09-23. **Contagem de vencimentos surpresa: zero, sobre janela
nenhuma.** Não é evidência de que o risco é pequeno; é evidência de que ainda não houve tempo.

A medida que decide a prioridade é **quantos tokens venceram sem que ninguém tenha aberto a
tela nos 14 dias anteriores** — e o registro de leitura da API (v0.9.0) não responde isso,
porque ele grava leitura de API e não visita de tela.
