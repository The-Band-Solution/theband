# O dump varrido e restaurado — 2026-09-12

**O que se ensaiou**: tirar uma cópia do banco, procurar segredo em claro **dentro dela**, e
restaurá-la num banco separado para ver se ela abre.

**Por que**: até aqui a varredura tinha olhado o **banco vivo**, não uma cópia. São coisas
diferentes, e é a cópia que viaja para o segundo host. E o §6 do runbook diz que *um backup só
existe depois de restaurado uma vez* — nunca tinha sido feito.

---

## 1. A cópia

```
pg_dump -U postgres -d the_band_dev --format=plain
259 824 062 bytes · 227 789 linhas · banco de 220 MB
```

## 2. A varredura da cópia

| o que se procurou | achados |
|---|---|
| padrão do token vazado (40 caracteres terminando no `last_four` da credencial) | **0** |
| a marca `REDIGIDO-2026-09-12-SPEC-064` | **1** |

A segunda linha é o que dá sentido à primeira. Ela prova que o dump **contém** a linha 697 —
sem isso, "zero ocorrências" poderia significar apenas que a varredura olhou o lugar errado.

**Controle positivo**: numa cópia do dump, plantei um valor de 40 caracteres com a mesma
forma. A varredura achou **1**; no dump original, **0**. Uma varredura que nunca acha nada não
distingue *limpo* de *cego*.

## 3. A restauração

```
createdb the_band_restore_teste
psql -d the_band_restore_teste -f dump.sql
```

**0 erros.** Comparando origem e restaurado com contagem exata — não `reltuples`, que é
estimativa do planejador e divergia em 30 tabelas sem nenhuma diferença real:

| medida | origem | restaurado |
|---|---|---|
| tabelas | 66 | 66 |
| contagem linha a linha | — | **idêntica nas 66** |
| índices | 200 | 200 |
| chaves estrangeiras | 193 | 193 |

A linha 697 sobreviveu redigida: existe, marca presente, token ausente. A credencial voltou
cifrada — `bytea`, e sem a chave mestra ela não abre, que é o comportamento correto.

---

## 4. O que este ensaio ACHOU, e não era o que eu procurava

**Os tokens de sessão estão em claro no dump.** Medido: dos 3 usuários, 2 têm
`session_token` preenchido, e os dois prefixos aparecem no arquivo — legíveis, sem chave
nenhuma.

É o achado 1 da [spec 064](../../specs/064-segredo-em-repouso/spec.md), até aqui verificado
só no banco. Agora está verificado **onde importa**: na cópia que a decisão de 2026-09-12
manda para um segundo host.

Quem lê esse arquivo entra como aquelas pessoas. Sem senha, sem segundo fator.

## 5. O que este ensaio NÃO prova

- **Não é o backup de produção.** Rodou contra o banco de desenvolvimento, na mesma máquina.
  A produção não foi varrida, e a FR-010 exige que ela seja — **antes** da primeira cópia
  para o destino novo.
- **Não passou pelo MinIO.** O dump não foi escrito no destino S3-compatível nem lido de
  volta de lá. O caminho `pg_dump → varredura → restauração` está provado; o caminho
  `→ destino remoto →` não.
- **Não subiu a aplicação contra o banco restaurado.** As contagens, índices e chaves batem;
  se a plataforma sobe e opera contra ele, ninguém verificou.
- **Não diz o que acontece com as sessões vivas numa restauração real** — é a FR-013, e
  continua sem resposta escrita no runbook.

## 6. O que fazer com o banco de ensaio

`the_band_restore_teste` ficou criado na instância local e **carrega os mesmos segredos** do
original, incluindo os dois tokens de sessão em claro. Apagá-lo é parte do ensaio:

```
dropdb the_band_restore_teste
```

Restaurar um backup num ambiente menos protegido move o risco junto — vale para esta máquina
e vale para qualquer ambiente de teste que receba uma cópia de produção.
