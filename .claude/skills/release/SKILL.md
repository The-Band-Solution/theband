---
name: release
description: Avalia e prepara uma release de development para main — audita contra a origem, chama o Product Owner para decidir a versão, mede os três riscos que sempre importam (migração destrutiva, variável obrigatória nova, mudança em tela em uso), atualiza o mix.exs e confere que atualizou. Para antes de publicar; o momento do delivery é decisão da pessoa mantenedora. Com --executar, abre o PR de release.
---

# `/release`

Prepara a release. **Não a executa** — o momento do delivery é do Product Owner (FR-016), e
quem clica o merge é quem decide.

```
/release              avalia e prepara
/release --executar   abre o PR, depois de a avaliação ter sido lida
```

O fluxo completo está em `docs/producao/fluxo-de-release.md`. Esta skill é o passo humano
antes do CD — o que hoje se faz à mão, e por isso esquece coisas.

---

## 1. Auditoria contra a origem — **primeiro, e nesta ordem**

Constituição 1.8.0, princípio VII.

```bash
git fetch origin --prune
git status --short                              # 1. NADA modificado fora de commit
git log --oneline origin/development..HEAD      # 2. o que realmente vai
git log --oneline origin/<branch>..HEAD         # 3. nada por empurrar
```

**A ordem não é arbitrária.** Arquivo modificado e não commitado é a forma mais barata de a
árvore local divergir do que os outros recebem, e a que mais engana — `mix gates` roda sobre
ele e fica verde.

> Em 2026-09-13 um PR reprovou no CI com um teste que já passava localmente: a correção estava
> no diretório e não no commit. A auditoria daquele dia conferia commits e issues, e não
> conferia isto.

**Se houver qualquer arquivo modificado, pare.** Não commite por conta própria — mostre o que
está pendente e pergunte.

## 2. O que vai na release

```bash
git log origin/main..origin/development --format='%s' | grep -oE "\(#[0-9]+\)|#[0-9]+ from"
```

**Use `(#NNN)` das mensagens, não `--merges`.** Squash merge não deixa commit de merge, e
`--merges` perde metade.

> Em 2026-09-13 contei 10 PRs com `--merges`. Eram 15.

## 3. Os três riscos — sempre estes, sempre medidos

### Migração nova, e se é destrutiva

```bash
git diff --name-only origin/main..origin/development -- priv/repo/migrations/
```

Para cada uma, leia o corpo e classifique: **`add` e `create table` são aditivos** e o
rollback não perde dado; **`drop`, `remove` e `modify` não são**, e a release precisa dizer
isso em voz alta.

### Variável de ambiente nova, e se é obrigatória

```bash
git diff origin/main..origin/development -- .env.example | grep -E "^\+[A-Z_]+="
```

Uma variável só é **obrigatória** se o `compose.yaml` a exige sem padrão (`${VAR:?…}`).
Com padrão (`${VAR:-valor}`) ou em profile que a produção não usa, ela é opcional — e dizer
que é obrigatória faria alguém procurar configuração que não falta.

### Mudança de comportamento em tela já em uso

Coluna nova, estado que passa a ser distinguido, campo que aparece. **Não é defeito** — é o
que quem usa vai notar sem ter pedido, e precisa estar escrito.

## 4. O Product Owner decide a versão

Chame o agente `product-owner`. Ele escreve `docs/releases/vX.Y.Z.md` com um bloco por PR e
**o resumo do que entregou na frente** — lista de números sem resumo não passa (constituição
1.6.0, padrão do PR #543).

**Se ele travar** — já aconteceu, 600s sem escrever nada — faça a avaliação com as medições
dos passos 2 e 3, e **diga no documento que foi feita assim**.

A regra de versão: **MINOR** quando funcionalidade nova chega à tela sem quebrar contrato;
**PATCH** quando é só correção; **MAJOR** quando rota sai, campo público muda de significado,
ou migração destrói dado.

## 5. O `mix.exs`, e **confira que mudou**

```bash
grep -n 'version: "' mix.exs
```

**Leia a saída antes de seguir.**

> Em 2026-09-13 o `sed` falhou por causa de uma vírgula no fim da linha, o `grep` de
> verificação estava no mesmo comando e mostrou o valor antigo — e o commit saiu dizendo que
> a versão tinha mudado. A verificação rodou, deu a resposta certa, e ninguém a leu.

## 6. Pare e mostre

Entregue: a versão proposta com a razão, os PRs com resumo, os três riscos medidos, e **o que
a release não carrega** e alguém pode esperar que carregue.

**Não abra o PR sem `--executar`.**

---

## Com `--executar`

```bash
gh pr create --base main --head development --title "Release vX.Y.Z" --body-file <arquivo>
```

O corpo sai do template — `.github/pull_request_template.md` —, e **`--body` substitui o
template inteiro**, então preencha o arquivo a partir dele.

**Tipo de merge: merge commit.** Nunca squash. L83: squash faz as duas linhas divergirem, e a
divergência não se desfaz. Isso é obrigatório para `main`, e o check `pr-tipo-de-merge`
reprova se declarar squash.

Na seção **Issues que este PR FECHA**: uma release normalmente não fecha issue — ela entrega
o que já foi mergeado. Escreva **"Nenhuma"** com a razão.

---

## O que esta skill NUNCA faz

- **não faz merge** — quem clica é quem decide;
- **não cria a tag** — ela nasce do CD, e criá-la antes faz o passo *"versão repetida FALHA"*
  reprovar o próprio deploy;
- **não toca no Dokploy** — o webhook é do CD;
- **não recebe segredo**, nem para "só configurar".

## Depois do merge

O CD faz seis passos, e três **falham de propósito**: versão repetida, webhook não-2xx, e
**a produção confirmando a versão**.

A primeira medida depois do deploy é sempre:

```bash
curl -s "$PRODUCAO_URL/version"
```

Depois, dois agentes medem coisas diferentes: `deploy-producao` mede a **plataforma**;
`aceitacao-em-producao` mede se **quem usa** vê o que a spec prometeu.
