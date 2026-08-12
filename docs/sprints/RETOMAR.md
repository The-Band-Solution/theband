# Retomar — estado em 2026-08-12, fim do sprint 011

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

## Onde o trabalho parou

**Sete sprints fechados em sequência**, todos com o ciclo Spec Kit completo antes do código:

| Sprint | Feature | Estado |
|---|---|---|
| 005 | 005 regras de mapeamento · 006 detalhe da issue | fechado |
| 006 | 007 marca de trabalho no repositório | fechado, 10 de 11 critérios |
| 007 | 008 destravar a sincronização presa | fechado, 14 de 14 |
| 008 | 009 a marca de inacessível se cura | fechado, 12 de 12 |
| 009 | 010 detalhe da pessoa | fechado **com atraso** — review escrita no sprint 010 |
| 010 | 011 de quem cada issue é parte | fechado, 12 de 13 |
| 011 | **012 o vínculo que sumiu na origem** | fechado, 14 FR e 3 de 7 SC — quatro pendem do dado real |

**Dois PRs abertos, e um depende do outro:**

| PR | O que é | Estado |
|---|---|---|
| [#264](https://github.com/The-Band-Solution/theband/pull/264) | feature 011, a coluna `part of` | `MERGEABLE · CLEAN`, CI verde, **revisão pedida e não atendida** |
| [#278](https://github.com/The-Band-Solution/theband/pull/278) | feature 012, a marca do vínculo ausente | empilhado sobre o #264, revisão pedida |

**O #278 tem base no #264, e não na `main`.** Quando o #264 for incorporado, o #278 passa a mostrar
só os commits da feature 012. Incorporar na ordem inversa não funciona.

## O que a plataforma sabe hoje

```
135 repositórios observados · 4529 issues vigentes · 3 organizações · 75 pessoas
1630 issues com pai · 1666 vínculos · 0 marcados como ausentes
52 vínculos que a última coleta não reviu — eo_lib 29, theband 15, ResearchDomain 8
atendimento 1143 · violação da sro.rule07 293 · composição 197 · não nomeada 33
```

**Os 52 são o alvo do sprint 011**: o código que os marca está pronto e testado, e o número só sai
de zero quando houver coleta com a origem respondendo.

## O que precisa de você, e eu não consigo fazer

**Quatro coisas, e todas precisam da chave mestra, de revisão humana ou de olho humano.**

### 1. Revisar os dois PRs

O #264 espera revisão desde 2026-08-12, e o #278 empilhou sobre ele. **Autor não pode revisar o
próprio PR** — não é limitação de permissão, é regra do GitHub, e já foi conferida.

### 2. A prova no dado real das features 009 e 012 — a mesma coleta serve para as duas

```bash
export THE_BAND_MASTER_KEY=...   # no seu terminal, nunca no chat
mix phx.server                   # e disparar a sincronização em /syncs
```

| O que conferir | Esperado |
|---|---|
| feature 009 | as **39** marcas de inacessível saem, e `leds-conectafapes-prestacao-de-contas` vai de 9 para **11** issues |
| feature 012 | os vínculos que a origem largou saem da vigência, e a contagem de marcados deixa de ser **0** |
| feature 012 | no `theband`, os **157** revistos continuam vigentes |
| feature 012 | o painel da `sro.rule07` cai de **293** para **281** — a consequência declarada antes de acontecer |

As consultas estão em [`specs/012-vinculo-que-sumiu-na-origem/quickstart.md`](../../specs/012-vinculo-que-sumiu-na-origem/quickstart.md).

### 3. A tela em 360 px — sexto sprint com este item

| Tela | Feature |
|---|---|
| a marca de trabalho na lista de repositórios | 007, SC-009 |
| a célula de estado que cresceu | 009, T009 |
| a página da pessoa | 010, SC-011 |
| a coluna `part of` | 011, SC-010 |

Todas asseridas em HTML, **nenhuma olhada**. Asserção em markup não substitui olhar.

### 4. Duas conferências de tela no dado real

- `/people/<id>` de `vinicius-je`: **350 e 609, nunca 959** — a soma é proibida;
- `/work/repositories/<id>` de `eo_lib`: as **29** issues dizendo, em texto, que a decomposição
  acabou — é o SC-004 da feature 012.

## Product backlog — o que está por cima

| # | O que é | Prioridade |
|---|---|---|
| [#261](https://github.com/The-Band-Solution/theband/issues/261) | `fetch_parent/2` com `limit: 1` **sem `order_by`** — pai arbitrário nas 36 issues com mais de um | P1 |
| [#262](https://github.com/The-Band-Solution/theband/issues/262) | filha promovida a defeito fora das três listas do detalhe do pai — **33 vínculos** invisíveis | P1 |
| [#99](https://github.com/The-Band-Solution/theband/issues/99), [#100](https://github.com/The-Band-Solution/theband/issues/100) | cadastrar papel e alocar pessoa a papel — **transformaria as 88 evidências em vínculos** | P1 |
| [#232](https://github.com/The-Band-Solution/theband/issues/232) | falha de rede no gate de assets, no CI | P2 |
| [#176](https://github.com/The-Band-Solution/theband/issues/176) | criar as iterações que faltam no ProjectV2 | decisão pendente desde o sprint 004 |
| [#177](https://github.com/The-Band-Solution/theband/issues/177) a [#181](https://github.com/The-Band-Solution/theband/issues/181) | validador Elixir à paridade, status derivado, comentários e timeline, quadros do Projects v2 | |
| #81, #82, #98, #104, #107, #108 | papéis Scrum, quadros, escopo de observação | |

**A #262 é a próxima candidata natural**: é a mesma família da 012 — dado que existe e não aparece
—, e a #261 pode entrar junto, porque as duas são de `fetch_parent/2` e do detalhe do pai.

**E há uma candidata nova, saída da L47**: a primeira coleta de uma organização **subconta a
decomposição**, porque o vínculo entre repositórios vira recusa `out_of_scope` e só é registrado na
coleta seguinte. Ninguém percebe — a recusa é silenciosa. Ainda não tem issue.

## Dívida conhecida, e não esquecida

| Dívida | Onde |
|---|---|
| `TeamsLive.Show` continua em português | a migração para inglês passou por ela |
| `list_parents/2` e `fetch_parent/2` coexistem | duas funções para a mesma relação vista de baixo; a antiga é a #261 |
| **quatro** funções de marcação de ausência, sem abstração comum | os cortes não são iguais — um por data, dois por lista, e agora o do vínculo |
| o total de vínculos marcados por execução só existe no log | a pergunta ainda não foi feita por ninguém; inventar o campo seria padrão sem problema |

## O que continua valendo, e não muda

- **`mix gates` é a definição única dos dez gates**, e o veredito é o código de saída;
- **nunca se apaga dado** — ausência é marcada, nunca removida. A feature 012 é essa frase virando
  código no nível do vínculo;
- **a chave mestra e o token nunca entram no chat**, nem no repositório;
- **o ciclo Spec Kit vem antes do código**, e a fase de análise achou defeito de desenho em **seis**
  features seguidas: a ordem de decisão da 007, o resgate por tempo da 008, a coluna estreita da
  009, a terceira fronteira da 010, os dois requisitos sem tarefa da 011, e — na 012 — **a
  consequência da marca em outra tela e a ordem contra a promoção**;
- **abrir um sprint novo confere o anterior**, e agora confere **onde** ele está: é a L45, e foi
  ela que mandou empilhar esta branch em vez de sair da `main`.
