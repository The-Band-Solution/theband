# O fluxo de release, ponta a ponta

**Escrito em**: 2026-09-13 · Descreve o que **existe**, medido contra `.github/workflows/cd.yml`
e contra a instância em `5.189.161.85`. O que ainda não existe está marcado como tal.

---

## A pergunta que originou este documento

*"Dá para instalar serviço no Dokploy a partir da imagem local?"*

**Não.** E a razão não é limitação de ferramenta — é de arquitetura, e ela vale a pena
entender antes do resto.

O Dokploy roda em **outra máquina**. Uma imagem em `docker images` aqui existe só neste
disco. Para chegar lá ela precisa de um **registry**, e é isso que o CD já faz.

E há uma razão melhor do que a técnica: **imagem local não tem proveniência.** Ninguém sabe
de que commit ela saiu, se a suíte passou, se o `mix.exs` batia com a tag. A imagem do
registry carrega tudo isso — é o mesmo princípio que esta casa aplica ao dado que coleta.

---

## O fluxo, como ele é hoje

```
1. decisão          Product Owner avalia e decide a versão
                    ↓
2. PR de release    development → main   ·   MERGE COMMIT, nunca squash
                    ↓
3. push em main     dispara .github/workflows/cd.yml
                    ↓
4. CD, seis passos  ┌─ a versão vem do mix.exs — versão repetida FALHA nomeando
                    ├─ login no ghcr
                    ├─ build e publicação da imagem
                    ├─ a tag git vX.Y.Z nasce do merge
                    ├─ delivery no Dokploy — resposta não-2xx FALHA
                    └─ a produção confirma a versão — resposta diferente FALHA
                    ↓
5. Dokploy          puxa ghcr.io/the-band-solution/theband:vX.Y.Z e sobe
                    ↓
6. verificação      dois agentes, e eles medem coisas diferentes
```

### O passo 4 é o que impede mentira

Três dos seis passos **falham de propósito**, e cada um fecha um jeito de o deploy parecer
bem-sucedido sem ser:

| passo | o que ele impede |
|---|---|
| versão repetida FALHA | publicar duas imagens diferentes com a mesma tag |
| webhook não-2xx FALHA | a imagem existir e ninguém a implantar — silêncio lido como sucesso |
| **a produção confirma a versão** | o Dokploy aceitar o webhook e subir **outra** imagem |

O último é o achado **H7**, e ele é o mais importante. Sem `/version` respondendo, *"a release
subiu"* é opinião de quem olhou o painel.

**Medido em 2026-09-13**: `GET https://app.theband.dev/version` devolve **404** — a produção
é anterior ao PR #859, que criou o endpoint. Até a v0.8.0 subir, ninguém consegue perguntar à
produção o que ela está rodando.

---

## Quem faz o quê

Quatro papéis, e **nenhum deles faz o trabalho do outro**.

### 1. `product-owner` — decide

**Quando**: antes do PR de release.

Avalia o que está em `development` e não em `main`, decide a versão semver com justificativa,
escreve o conteúdo da release em `docs/releases/vX.Y.Z.md` com **o resumo de cada PR na
frente** — lista de números sem resumo não passa (constituição 1.6.0).

**Não executa a release.** O momento do delivery é decisão registrada dele, não ato dele.

⚠️ **Em 2026-09-13 este agente travou** — 600s sem progresso, nada escrito. A avaliação da
v0.8.0 foi feita diretamente. Se travar de novo, o caminho é medir à mão: migrações novas,
variáveis novas, e o que muda em tela já em uso.

### 2. O CD — publica e implanta

Sem agente. É `.github/workflows/cd.yml`, disparado por `push` em `main`.

### 3. `deploy-producao` — mede a infraestrutura

**Quando**: depois do deploy, ou quando ele falha.

Mede SC-001 a SC-005 contra o endereço real: entrar e ver painel, tempo de release, ensaio de
restauração, zero segredos em log, recusa sem sessão. Também faz rollback.

**Não autoriza release, não recebe segredo, não cria VPS.**

### 4. `aceitacao-em-producao` — mede a funcionalidade

**Quando**: depois do deploy, e é o único que responde *"o que foi entregue funciona?"*

Lê os **SC e FR da spec** e os mede no ar, tela a tela. A primeira medida dele é sempre
`/version` — sem isso o relatório erra do pior jeito possível: *"a feature não está lá"*
quando a verdade é *"a release não subiu"*.

**Regra do relatório**: critério não medido **nunca** vira ✅. Vai para a seção do que não foi
medido, com a razão.

### A diferença entre os dois últimos, que é fácil de perder

| | mede |
|---|---|
| `deploy-producao` | que a **plataforma** sobe, guarda e restaura |
| `aceitacao-em-producao` | que **quem usa** vê e consegue fazer o que a spec prometeu |

Os gates verdes não provam nem um nem outro: entre o merge e o ar há release, build,
publicação e deploy — e cada um já falhou em silêncio neste projeto.

---

## O comando que vamos criar: `/release`

**Ainda não existe.** O que existe é o CD; o que falta é o passo humano antes dele, que hoje
é feito à mão e por isso esquece coisas.

### O que ele faz

```
/release                    avalia e prepara — NÃO publica
/release --executar         abre o PR de release, depois da aprovação
```

Em ordem:

1. **audita contra a origem** — constituição 1.8.0, princípio VII. Diretório limpo **primeiro**,
   depois commits, depois issues. Em 2026-09-13 um PR reprovou no CI porque a correção estava
   no diretório e não no commit, e a auditoria daquele dia não olhava isso;
2. **chama o `product-owner`** para decidir a versão e escrever `docs/releases/vX.Y.Z.md`;
3. **mede os riscos**, e são sempre os mesmos três:
   - migrações novas desde a última release — e se alguma é **destrutiva**;
   - variáveis de ambiente novas — e se alguma é **obrigatória**;
   - mudança de comportamento em tela já em uso;
4. **atualiza o `mix.exs`** — e **confere que atualizou**. Em 2026-09-13 o `sed` falhou por
   causa de uma vírgula, o `grep` de verificação mostrou o valor antigo na mesma saída, e o
   commit saiu dizendo que a versão tinha mudado;
5. **para**, e mostra o que encontrou. O momento do delivery é da pessoa mantenedora.

Com `--executar`: abre o PR `development → main`, **merge commit** declarado, com a tabela de
PRs e o que a release não carrega.

### O que ele nunca faz

- **não faz merge** — quem clica é quem decide;
- **não cria tag à mão** — a tag nasce do CD, e criá-la antes faria o passo *"versão repetida
  FALHA"* reprovar o próprio deploy;
- **não toca no Dokploy** — o webhook é do CD;
- **não recebe segredo.**

---

## Se a via da API do Dokploy for mesmo desejada

A API existe e responde:

```
http://5.189.161.85:3000/api/health   → 200 {"ok":true}
http://5.189.161.85:3000/api/swagger  → 401   (existe, exige autenticação)
```

Autenticação por cabeçalho **`x-api-key`**, com token gerado em *Settings → API/CLI*. Com ele
dá para `application.update` (trocar a tag da imagem) e `application.deploy` (reimplantar).

**Mas isso duplica o que o webhook já faz**, e acrescenta um segredo a guardar. O webhook não
precisa de token novo, está no CD, e **falha ruidosamente** se a resposta não for 2xx.

Se ainda assim for a escolha: o token vai para `DOKPLOY_API_KEY` no ambiente, lido sem ser
impresso — como a chave mestra e como a senha de aceitação.

**Fonte**: <https://docs.dokploy.com/docs/api> e <https://docs.dokploy.com/docs/core/registry>.
A documentação lista os provedores — GitHub, Git, Docker, webhook — e o provedor Docker fala
com **registry**. Ela **não diz** que imagem local não funciona; ela simplesmente não oferece
esse caminho, e estou registrando isso como ausência na documentação, não como proibição.

---

## O que este documento NÃO cobre

- **a instalação do Dokploy** — é o §1 do runbook, e já foi feita;
- **os segredos do painel** — vivem lá e nos GitHub Secrets, colados por uma pessoa;
- **rollback** — é do `deploy-producao`, e tem procedimento próprio;
- **se `DOKPLOY_WEBHOOK_URL` está configurado** — não verifiquei. O CD declara a falta se ele
  não existir, e essa declaração é a evidência a procurar no primeiro deploy.
