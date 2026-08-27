# Quickstart: conferir a feature 044 na tela

**Feature**: 044 · **Date**: 2026-08-27

Este percurso é feito **na tela**, com navegador, contra o banco de desenvolvimento. Os
números abaixo foram medidos em 2026-08-27 e servem para conferir: se a tela mostrar outro
número, ou o dado mudou, ou a leitura está errada.

---

## Antes de começar

```bash
set -a; . ./.env; set +a
MIX_ENV=dev mix phx.server
```

⚠️ **A aba de trabalho só abre para quem a regra da #369 permite.** Entrar como `admin`
faz a aba abrir para qualquer pessoa; entrar como `member` sem elo declarado a fecha. Os
dois casos são parte do percurso.

---

## Percurso 1 — os três papéis, na pessoa com mais participação

Abrir `/people` e buscar por **`vinicius-je`**.

Na aba de trabalho, conferir:

| o que a tela deve mostrar | valor esperado |
|---|---:|
| solicitações que **abriu** | **793** |
| solicitações que **integrou** | **844** |
| solicitações que **revisou** | **627** |

**E conferir que a soma dos três NÃO aparece em lugar nenhum.** Abrir, revisar e integrar
são participações distintas, e `793 + 844 + 627` não significa coisa alguma.

---

## Percurso 2 — o veredito das revisões

Na mesma pessoa, na seção de revisão:

| veredito | valor esperado |
|---|---:|
| endossou | **634** |
| objetou | **57** |
| absteve | **30** |

Três coisas a conferir, e cada uma corresponde a um requisito:

1. **os nomes são da rede**, e não do GitHub — não deve aparecer `APPROVED` nem
   `CHANGES_REQUESTED` na tela (FR-007);
2. **`634 + 57 + 30 = 721` é maior que `627`**, e isso está certo: são avaliações contra
   solicitações distintas. Quem revisou duas vezes a mesma conta uma vez em "revisou";
3. **a tela não diz "sem problemas encontrados"** no endosso (FR-011). A rede declara que
   aprovar é ausência de bloqueio, e não de não conformidade.

---

## Percurso 3 — a verificação dos commits

Na mesma pessoa:

| desfecho | valor esperado |
|---|---:|
| passou | **985** |
| quebrou | **79** |
| outras | **6** |

E, **ao lado**: a parcela do tenant sem autoria identificada — **7.313 de 15.671, 47%**.

Conferir que ela **não** foi descontada nem somada (FR-010): é contexto sobre o alcance da
medida, e não parte da contagem da pessoa.

---

## Percurso 4 — a ausência nomeada

Abrir uma pessoa **sem** solicitação alguma. Uma boa candidata é qualquer uma fora dos 63
com trabalho designado.

Conferir que a tela **diz** que a plataforma não a viu abrir nenhuma, e **não** mostra um
zero solto (FR-012).

---

## Percurso 5 — a aba fechada não carrega nada

1. Sair, e entrar como `consulta@the-band-solution.example` (papel `member`).
2. Abrir a página de qualquer pessoa.
3. Conferir que a aba de trabalho está **fechada**, com a frase da #369.
4. Conferir que **nenhuma** das seções desta feature aparece.

E o que o teste automatizado prova, e o percurso não consegue: que as consultas **não são
disparadas**. A recusa acontece antes da carga (FR-015).

---

## Conferir contra a origem

Os números da tela podem ser verificados contra o GitHub:

```bash
gh api "search/issues?q=is:pr+author:vinicius-je+org:The-Band-Solution" --jq '.total_count'
```

⚠️ **Divergência é esperada, e não é defeito.** A plataforma conta o que **coletou**, em
160 repositórios observados; o GitHub conta tudo. A pergunta certa diante de uma diferença
é *"a coleta alcançou aquele repositório?"*, e a resposta está em `/syncs`.

---

## O que este percurso NÃO cobre

- **`PENDING`**: não existe no banco (0 de 4.233), porque a API só devolve rascunho para
  quem o escreveu. O caminho existe no código e é exercitado por teste, não aqui.
- **Valor de estado não mapeado**: exigiria o GitHub inventar um sexto estado. Coberto por
  teste com valor forjado.
- **A recoleta**: não acontece. Esta feature não dispara coleta alguma (SC-006).
