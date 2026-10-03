# Nota de riscos — 072, a marca de administrador

Escrita na T013, em 2026-10-03, a partir de `seguranca.md` ("Risco residual, mesmo com as
emendas") e do que a implementação mostrou. O que está aqui **não** é resolvido por esta feature.

## O que fica aberto

| risco | por que fica | onde se acompanha |
|---|---|---|
| **O dono das tabelas desliga trigger.** Os triggers somente-acréscimo de `account_role_changes` e o trigger adiado `users_papel_tem_episodio` fecham o acidente, e não a aplicação comprometida: o papel que serve ainda é dono das tabelas enquanto a 071 não estiver em produção | depende da 071 (#1131) e das tarefas humanas #1156–#1158 | #1131 |
| **A janela entre o `commit` e o aviso.** Um evento que já está na caixa de mensagens da tela aberta do rebaixado roda antes do aviso. A camada que vale nessa janela é o domínio: os atos de R2 conferem o ator relido (`PapelDeAdministrador.exigir_ator/2`), e devolvem `:nao_autorizado`, que a tela traduz em `/people` com a frase de hoje | inerente ao aviso por PubSub; a FR-002a fecha os atos que mudam acesso | `ator_relido_test.exs` |
| **Tokens que o rebaixado emitiu para outros donos** continuam vivos (S5). O token do próprio rebaixado perde o alcance de admin na próxima chamada, porque o veredito relê o papel | revogá-los é decisão do Product Owner, e não foi pedida nesta feature | `seguranca.md` S5 |
| **Valor de token visto por um emissor** que depois perdeu a administração volta a ter alcance se o dono for promovido (S5) | inerente a token emitido por terceiro | `seguranca.md` S5 |
| **`Bootstrap.ja_ha_administrador?/0` é global** e conta administrador desativado. Não é caminho de recuperação de uma organização sem administrador | mudá-lo é mudar o contrato da 052 | `seguranca.md` |
| **Ator e alvo do episódio sem FK composta com o tenant.** A emenda de S6 pedia que `user_id` e `changed_by_user_id` pertencessem ao mesmo tenant por FK composta. Entrou o limite da nota (`account_role_changes_nota_curta`), e não a FK: ela exige `UNIQUE (tenant_id, id)` em `users`, que é mudança de outra tabela. O domínio garante pelo guarda, que trava e relê alvo e ator **com** o tenant | mudança em `users` fora do escopo | esta nota |
| **`Access.pessoas_alcancadas/2` concede `:todas` sem comparar o tenant da conta** (S10) | fora do escopo, mesma superfície | issue própria |

## O que mudou de comportamento, e quem nota

- `disable_user/4` recusa com `:nao_autorizado` quem já não é administrador ativo, antes de olhar o
  último administrador. A segunda de duas desativações cruzadas recebe essa recusa, e não mais
  `:ultimo_admin_ativo`. A organização continua sempre com um administrador.
- Os atos de R2 recusam quem perdeu a marca com a aba aberta. Na tela, a pessoa vai para `/people`
  com *"Only organisation administrators can do that."*.
- A recusa do último administrador ao desativar passou a usar a frase do protótipo: *"Not changed:
  the organisation would have no active administrator."*
- `/accounts` empilha a tabela no telefone.

## Migrações

- `20261003100000_papel_valido`: **levanta** se houver `users.role` fora de `admin` e `member`, com
  a contagem, antes de criar o `CHECK`. Em produção, conferir antes do deploy:
  `SELECT role, count(*) FROM users GROUP BY role`.
- `20261003100100_mudancas_de_papel`: tabela nova, triggers e o trigger adiado em `users`. Aditiva.
  O `down` remove tudo.
- O trigger adiado recusa **qualquer** `UPDATE` de `users.role` sem episódio na mesma transação,
  inclusive um `UPDATE` manual no `psql`. Mudar o papel à mão em produção passa a exigir o
  episódio, ou o ato da tela.
