# As quatro decisões da tela de tokens, tomadas em 2026-09-23

O protótipo de `/api-tokens` foi aprovado em 2026-09-18 com **seis perguntas abertas** para
a pessoa mantenedora. Quatro tinham sido respondidas pelo código sem passar por ela; duas
continuavam abertas.

Todas foram respondidas em 2026-09-23. Duas **mudam o que já está implementado**.

## O que já estava decidido pelo código, e foi confirmado

| # | Pergunta | Resposta |
|---|---|---|
| **Q2** | qual prefixo? | `tb_api_`, em `api.access.token_prefix` |
| **Q3** | revogar exige digitar o rótulo? | não — painel de confirmação com o rótulo nomeado e o último uso |
| **Q5** | aviso de vencimento nesta fatia? | sim — a tela lê `token_expiry_warning` |

## O que mudou

### Q1 — "sem expiração" passa a ser oferecido · **reverte uma regra**

A regra `api.access.token_lifetime` dizia: *a tela oferece prazos até 90 dias e **não**
oferece "sem expiração"*, com a razão escrita — **máximo do qual se abre mão não é máximo**.

Revertido. O formulário passa a oferecer 7, 30, 90 e **sem expiração**.

**A consequência, escrita para não ser descoberta depois**: um token sem prazo só sai de
circulação por revogação deliberada. Nenhum job o encerra, e a plataforma não avisa ninguém
de que ele existe — a tela é a única superfície, e ninguém a abre sem motivo.

Duas coisas limitam o estrago, e continuam valendo: o alcance é o da **conta dona**, relido a
cada chamada; e conta desativada faz toda chamada ser recusada. Um token eterno de quem saiu
já não abre nada.

### Q4 — revogar passa a gravar o motivo

Até aqui gravava só quem e quando — e isso era **omissão, não decisão**: ninguém tinha sido
perguntado.

Quatro cláusulas, lista fechada, mais nota livre: `integracao_encerrada`,
`suspeita_de_vazamento`, `substituido_por_outro`, `outro`.

A que justifica o campo é **`suspeita_de_vazamento`**: é o único caso em que o próximo ato
muda — girar tudo o que aquela conta alcança, e não só substituir a integração.

### Q6 — o e-mail fica para depois · **decidido em 2026-09-23**

A primeira resposta foi *"e-mail avisa quem criou, 14 dias antes"*, escolhida sobre "nada" e
sobre "linha na tela de operação". **Adiada no mesmo dia**, ao aprovar as três mudanças de
tela: *"e aprovado .. mas sem email"*.

O que isso deixa no ar, escrito para ser lacuna conhecida e não surpresa: a linha marcada 14
dias antes existe, e **só quem abre a tela a vê**. Nada alcança quem não vem olhar.

**Medido em 2026-09-23: esta plataforma não envia e-mail.** Nenhuma dependência no
`mix.exs`, nenhum módulo `Mailer`, nenhuma variável de ambiente de SMTP ou provedor.

Isso **não é um ajuste na tela de tokens**. É feature própria, e carrega:

- a dependência e o provedor de entrega;
- credencial de envio, fora do repositório — e a chave mestra já cifra credencial em repouso,
  então há onde guardá-la;
- o que acontece quando a entrega falha: fila, reenvio, e o registro de que não foi entregue.
  **Um aviso que não chegou e ninguém soube é pior que nenhum aviso**, porque cria confiança
  falsa;
- o endereço de destino: hoje a conta tem `email`, e ninguém confirmou que ele é alcançável.

**Recomendação de sequência, quando o item voltar**: a linha na tela de operação resolve a
maior parte do risco sem abrir canal nenhum, e continua útil depois que o e-mail existir.

### A quinta decisão — onde o uso da API aparece

Não era uma das seis do protótipo; nasceu do PR #936, que criou o registro de leitura.

**Painel de detalhe**, e não nona coluna. Clicar numa linha abre quantas leituras na última
janela e em quais rotas. As oito colunas da **R2.1** ficam intactas, e a régua do QA continua
valendo sem emenda.

## O que isto obriga, antes do código

**Três das cinco mudam a tela**: o "sem expiração" no formulário, o motivo na revogação, e o
painel de uso.

A regra desta casa é que **mudança de tela volta ao protótipo**, e a régua da seção 3 do
`PROMPT.md` tinha 60 itens que o QA confere um a um. Republicar o protótipo mantém o endereço;
um endereço novo seria um protótipo novo, e exigiria aprovação nova.

**Feito em 2026-09-23**: protótipo republicado no mesmo endereço e aprovado, e a régua foi de
**60 para 70 itens** — entraram `R2.20`–`R2.25` (o painel), `R4.11`–`R4.13` (o motivo) e
`R5.6` (a recusa que deixou de ser recusa); `R1.2`, `R1.3`, `R2.19`, `R5.1` e `R6.5` foram
reescritos. **Nenhum item saiu**, e `R2.1` continua em oito colunas.

| Ordem | O quê |
|---|---|
| ~~1~~ | ~~republicar o protótipo com as três mudanças, e reaprovar~~ — **feito e aprovado em 2026-09-23, sem o e-mail** |
| ~~2~~ | ~~ajustar a régua do `PROMPT.md`~~ — **feito em 2026-09-23**: 60 → 70 itens, R2.1 intacta |
| ~~3~~ | ~~implementar~~ — **feito em 2026-09-23**: migração aditiva, o select com *no expiration*, a cláusula e a nota na revogação, e o painel de uso na linha. Quatro defeitos injetados, quatro reprovações — uma guarda por mudança |
| 4 | ~~o e-mail, como feature própria~~ — **adiado em 2026-09-23**, item de backlog próprio |
