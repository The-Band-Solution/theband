# Desligar alguém da plataforma — o procedimento que funciona hoje

**Escrito em 2026-09-09**, a partir do achado **H3** da avaliação de segurança
(`docs/seguranca/2026-09-09-o-que-consertar-agora.md`).

> **Este documento existe porque o gesto que parece desligar não desliga, e o que
> desliga não parece desligar.** Enquanto o conserto do H3 não entrar, ele é o único
> controle que a organização tem — e um controle que ninguém sabe usar não é um
> controle.

---

## O que fazer, hoje

**Reinicie a senha da conta e não entregue a temporária.**

Em `/accounts`, ação **`reset`** na conta da pessoa. A temporária aparece **uma vez**
para quem administra. Não a passe a ninguém.

Isso corta o acesso, e corta de verdade: `gravar_temporaria` gira o `session_token`, e
o giro derruba **todas** as sessões abertas daquela conta na ação seguinte. A pessoa
não entra mais porque não sabe a senha nova, e as sessões que ela tinha abertas param
de valer.

**Registre em outro lugar que este reinício foi um desligamento.** No histórico da
plataforma ele é indistinguível de um reinício legítimo — alguém que esqueceu a senha
recebe exactamente o mesmo registro. Sem uma anotação fora da plataforma, ninguém
reconstrói depois o que aconteceu.

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

### Marcar a organização como suspensa não faz nada

`tenants.status` existe, aceita `"suspended"`, e **nenhum código o lê**. Medido: um
tenant marcado como suspenso autentica e abre as telas normalmente. É uma coluna que
parece um controle.

---

## O que falta, e é o conserto de verdade

Está na fila do product backlog como **`conta-desativada`**, e tem duas partes:

1. **`tenants.status` passa a ser lido** — organização não ativa não autentica. Sem
   migração: a coluna já existe. (Ou a coluna sai, se suspensão de organização nunca foi
   a intenção — as duas saídas são melhores que a de hoje.)
2. **`users.disabled_at`** — coluna nova, em **marca** e nunca `delete`, com o ato
   correspondente em `/accounts` e a regra de que conta desativada **não autentica nem
   por senha nem por token**. Esta tem migração.

**A segunda parte tem prazo, e não é escolha nossa.** Hoje o desligamento implícito
funciona porque quem não sabe a senha não entra. No dia em que a API com token existir
([spec 061](../../specs/061-api-publica/spec.md)), **o token não é a senha** — reiniciar
a senha deixa de invalidá-lo, e o único caminho passa a ser achar e revogar cada token,
um a um. É por isso que a spec 061 registra `users.disabled_at` como item **anterior**
a ela.

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
