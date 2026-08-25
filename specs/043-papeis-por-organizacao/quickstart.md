# Quickstart: provar que os papéis e a promoção funcionam

**Feature**: 043 · **Data**: 2026-08-24

## Antes

```bash
set -a && . ./.env && set +a
mix ecto.migrate
mix phx.server
```

Uma organização com equipe observada e evidências de vínculo. No banco de desenvolvimento há
**12 equipes e 101 evidências**, todas por promover.

---

## 1. Os quatro já estão lá — `FR-002`, `SC-001`

Abra a tela de papéis de qualquer organização, **sem cadastrar nada**.

**Esperado**: Product Owner, Scrum Master, Developer e Client aparecem, cada um marcado como
**do catálogo**, com o conceito da SRO visível. Nenhum passo de ativação.

Abra outra organização. **Esperado**: os quatro aparecem lá também, independentemente.

---

## 2. Um papel declarado não vaza — `FR-001`, `SC-004`

Declare `tech_lead` na organização A.

**Esperado**: aparece na lista de A, marcado como **declarado**, com autor. Abra a
organização B: **não aparece**.

Declare `tech_lead` também em B. **Esperado**: aceito — são papéis diferentes. Isto é o que
o índice antigo `UNIQUE (tenant_id, code)` impedia.

---

## 3. Promover, sem ver o nível de acesso — `FR-011`, `SC-005`, `SC-005a`

Abra uma equipe com evidências pendentes.

**Esperado**: a lista mostra **pessoa e equipe**. O campo de papel começa **vazio**.

**E não mostra `MEMBER` nem `MAINTAINER`.** Procure na página: não deve haver.

Escolha um papel do catálogo e confirme. **Esperado**: o vínculo é criado com autor e data; a
evidência sai da lista de pendentes; a equipe passa a ter um membro.

---

## 4. A materialização acontece uma vez — decisão 1 do plano

Promova uma segunda evidência com o **mesmo** papel do catálogo.

**Esperado**: funciona, e **não** cria um segundo papel. A tela de papéis continua mostrando
quatro do catálogo, agora um deles com `2` vínculos.

---

## 5. Dois papéis, uma pessoa — `FR-006a`, `FR-006c`, `SC-008`

Vincule a mesma pessoa também como Developer na mesma equipe.

**Esperado**: os dois vínculos coexistem. **E o tamanho da equipe não sobe** — ela continua
contando uma pessoa.

Tente vincular o mesmo papel de novo. **Esperado**: recusa dizendo que já existe.

---

## 6. Papel de outra organização é recusado — `FR-008`

Numa equipe da organização A, escolha um papel declarado em B.

**Esperado**: recusa nomeada, e a frase diz **por quê** — o papel é de outra organização.

---

## 7. Ocultar não apaga — `FR-004`, `FR-015`

Tente ocultar um papel do catálogo que tem vínculos.

**Esperado**: a tela mostra **quantos vínculos** usam o papel antes de permitir, e recusa
enquanto houver vínculo vigente.

Oculte um papel sem vínculo. **Esperado**: some da lista de escolha; os vínculos históricos,
se houver, continuam válidos.

---

## 8. A equipe vazia diz por quê — `FR-014`, `SC-007`

Abra uma equipe sem nenhum vínculo, mas **com** evidências pendentes.

**Esperado**: a tela diz **quantas evidências esperam confirmação** — e não mostra a equipe
como se ninguém pertencesse a ela. São coisas diferentes, e a frase distingue.

---

## O que a suíte cobre, e o que só o passo manual cobre

| verificação | teste | manual |
|---|---|---|
| catálogo composto, materialização única | `papeis_por_organizacao_test.exs` | |
| isolamento entre organizações | idem | |
| papel de outra organização recusado | idem | |
| pessoa com dois papéis conta uma vez | idem, comparando `team_size` com `length(vinculos)` | |
| **`MEMBER`/`MAINTAINER` ausentes da promoção** | `promocao_de_evidencia_test.exs` — `refute html =~` | |
| as 101 promovíveis sem cadastro prévio (`SC-003`) | | **sim**, contra o dado real |
| a frase da equipe vazia ensinar (`SC-007`) | um teste vê que está lá | **sim**, se ela ensina |
