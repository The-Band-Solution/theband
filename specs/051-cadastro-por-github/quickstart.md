# Quickstart — validar a 051 de ponta a ponta

Pré: dev server no ar, login de admin.

## 1. Cadastrar a pessoa (US1)

`/accounts` → nome + e-mail → cadastrar. Esperado: a conta na lista, a temporária
visível UMA vez (some no evento seguinte), e a linha dizendo "no GitHub account
linked" (ausência nomeada).

## 2. Associar o GitHub (US2)

Na linha recém-criada → associar → buscar por nome ou login (ex.: "vinicius").
Esperado: resultados com nome, login e organização; escolher; a linha passa a
mostrar o login observado.

## 3. Entrar pelo username (US2 cenário 2)

Sair; entrar com o USERNAME do GitHub + a temporária. Esperado: entra e cai na
troca forçada de senha (045 intacta).

## 4. As violações (SC-003)

- Associar OUTRA conta à mesma pessoa: recusa nomeando a conta dona (o e-mail dela
  na frase).
- Cadastrar com e-mail já usado: recusa; contagem de contas inalterada.

## 5. Revogar na área (US2 cenário 4)

Revogar o elo na linha. Esperado: a linha volta à ausência nomeada; login por
username recusa (recusa única); login por e-mail segue.

## 6. Gates

```bash
mix gates > /tmp/gates_051.log 2>&1; echo "EXIT=$?" >> /tmp/gates_051.log
tail -2 /tmp/gates_051.log   # 14 verdes, EXIT=0
```
