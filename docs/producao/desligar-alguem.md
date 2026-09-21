# Desligar alguém da plataforma — o procedimento que funciona hoje

**Escrito em 2026-09-09**, a partir do achado **H3** da avaliação de segurança
(`docs/seguranca/2026-09-09-o-que-consertar-agora.md`).

> **Este documento existe porque o gesto que parece desligar não desligava, e o que
> desligava não parecia desligar.** Ele nasceu como o único controle que a organização
> tinha — e um controle que ninguém sabe usar não é um controle.

> **ATUALIZADO EM 2026-09-10.** O conserto entrou: `/accounts` tem o ato de desativar, ele
> **exige razão**, e a tela carrega o procedimento. O que segue é a versão longa; a versão
> curta está na própria tela, no ponto de agir — que é onde este documento provou que ela
> precisava estar.

---

## O que fazer, hoje

**Em `/accounts`, `Disable…` na linha da pessoa.** Escolha a razão e confirme.

A razão é **lista fechada**: `left_the_organisation`, `access_no_longer_needed`,
`duplicate_account`, `suspected_compromise`, `other`. Ela é o que a plataforma **lê** — a
suspeita de comprometimento muda o que a tela mostra em seguida, e é a pergunta que um
incidente faz por contagem. A **nota** é o que você escreve, e é obrigatória para
`suspected_compromise` e `other`.

Isso corta o acesso, e corta de verdade: `desativar_changeset/2` gira o `session_token`, e
o giro derruba **todas** as sessões abertas daquela conta na ação seguinte. A entrada passa
a recusar com a mensagem única, e o registro guarda o motivo interno.

**Não é preciso anotar nada fora da plataforma.** Era a parte mais frágil do procedimento
antigo, e deixou de existir: o ato grava **quem, quando, por quê** e a sua nota, num
episódio que a reativação **fecha** em vez de apagar. A linha da conta mostra as duas
pontas.

### Reativar

`Reactivate…` na linha, com ator e razão. `disabled_by_mistake` marca o episódio como
equívoco — ele **deixa de contar** como desligamento e continua visível.

**Reativar não devolve a senha.** Se o desligamento foi feito do jeito antigo — um reinício
cuja temporária ninguém entregou —, a senha continua sendo aquela temporária, e o reinício
vem **depois** da reativação, nunca antes. A tela recusa o reinício na conta desativada e
diz essa ordem.

---

## O jeito antigo, e por que não usar mais

**Reiniciar a senha e não entregar a temporária.** Funcionava — o giro do token derruba as
sessões — e era frágil por três razões, todas medidas:

1. **não estava escrito em lugar nenhum**, e dependia de quem administra saber;
2. **era indistinguível de um reinício legítimo**: a conta desligada aparecia como
   `temporária pendente`, **igual à recém-criada**, e o ato de rotina para a segunda
   **reativava** a primeira;
3. **para de funcionar no dia em que existir token de API** — o token não é a senha, e
   trocar a senha não o invalida.

As duas colunas de `/accounts` fecham a segunda: `Account` responde *pode entrar?* e
`Sign-in credential` responde *entraria com o quê?*, e as duas temporárias se distinguem em
palavras — `from creation` contra `from a reset`.

---

## O que **não** fazer, e por que parece certo

### Revogar o elo não desliga

`revogar_elo` é o que a tela oferece ao lado do nome da pessoa, e é o gesto que
qualquer pessoa faria. **Ele não remove acesso.** Medido em 2026-09-09:

| depois de revogar o elo | resultado |
|---|---|
| o painel da própria pessoa | **fecha** — `pode_ver/3` passa a recusar |
| entrar com e-mail e senha | **continua funcionando** |
| `/people`, `/teams`, o trabalho do tenant | **continuam abrindo** |

O login por identificador do GitHub passa a recusar; o login por **e-mail** não exige
elo. Então quem tem a senha continua entrando.

**Revogar o elo continua sendo o gesto certo para o que ele significa** — a conta deixa
de ser aquela pessoa. Ele só não é desligamento, e a tela não diz isso.

### ~~Marcar a organização como suspensa não faz nada~~ — corrigido em 2026-09-09

`tenants.status` existia, aceitava `"suspended"` e **nenhum código o lia**: um tenant
suspenso autenticava e abria as telas normalmente. Era uma coluna que parecia um controle.

**Desde a v0.7.0 a porta lê.** `Auth.verificar/2` recusa a entrada quando a organização não
está ativa, e `/accounts` mostra uma faixa dizendo que ninguém entra hoje. Suspender a
organização **é** um controle — e continua não sendo o ato para desligar **uma** pessoa.

---

## O que faltava, e o que entrou

O item `conta-desativada` do product backlog tinha duas partes, e as duas entraram:

1. **`tenants.status` passa a ser lido** — entrou na **v0.7.0**. Organização não ativa não
   autentica, e `/accounts` mostra a faixa.
2. **`users.disabled_at`** com o ato em `/accounts` — entrou na **v0.7.0**, e a entrega foi
   **recusada** pelo papel de Product Owner por três razões: o ato não gravava razão,
   `enable_user/2` reativava sem ator nem razão, e a tela mudou sem protótipo aprovado. O
   protótipo veio em **2026-09-10**
   ([`accounts-disable.html`](../../specs/045-autenticacao-e-acesso/prototipo/accounts-disable.html)),
   e o conserto das três é o que este documento passou a descrever: razão de lista fechada
   mais nota (FR-025), episódio com as duas pontas (FR-026), e a recusa que fica na tela
   (FR-028).

**O que continua em aberto tem prazo, e não é escolha nossa.** Conta desativada **não
autentica por senha** — medido, com teste. **Por token, não se pode afirmar ainda**: o token
não existe ([spec 061](../../specs/061-api-publica/spec.md)). No dia em que existir,
desativar tem de fechá-lo também; até então, a linha da tela que promete isso é **promessa e
não controle**, e está escrita assim.

---

## E enquanto isso, o que a organização deve assumir

Uma pessoa desligada pelo procedimento acima **não entra**. Mas:

- **não há registro** de que ela tentou, nem de quando. Nenhum evento de autenticação
  ou de autorização é gravado hoje — é o achado **H4**, e é por isso que não se sabe se
  algum acesso indevido já aconteceu;
- **o que ela leu antes de sair, ela sabe.** Nada disto é retroativo;
- **o procedimento depende de quem administra saber dele.** É a razão de este documento
  existir, e a razão de ele não substituir o conserto.

---

## Referências

- `docs/seguranca/2026-09-09-o-que-consertar-agora.md` — achado H3, com as três partes
  medidas e o cenário para o QA;
- `docs/backlog/conta-desativada.md` — o item, com a posição na fila e a razão dela;
- `specs/061-api-publica/spec.md` — a FR-074 (revogação em massa por conta) e a
  limitação declarada;
- `docs/producao/runbook.md` — o resto da operação.
