# O caminho completo do backup, exercitado — 2026-09-13

**O que se fechou**: o §6 do runbook — *"o backup só existe depois de restaurado uma vez"* —
estava bloqueado desde 2026-09-08. Hoje o caminho inteiro rodou, **passando pelo destino
remoto**, e não de arquivo local.

---

## O que já tinha sido feito, e o que faltava

Em 2026-09-12 o ensaio cobriu `pg_dump → varredura → restauração`. **Nada disso passou pelo
MinIO.** O que existia no balde era um `ensaio.txt` de **44 bytes**, provando que o protocolo
respondia.

44 bytes não exercitam **multipart** — e é justamente com arquivo grande, não com arquivo
pequeno, que uma configuração errada de destino S3 falha.

## O caminho, hoje

```
pg_dump                       259 938 022 bytes
  │  sha256 734bca76…86bfa84
  ↓
VARREDURA ANTES DA CÓPIA      0 ocorrências        ← FR-010
  │  marca de redação presente: 1
  │  controle positivo: com plantio 1 · sem plantio 0
  ↓
MinIO  s3://the-band-backup/theband-20260913T191328Z.sql     248 MiB
  │  ETag 737f8652…-16        ← 16 partes: multipart de verdade
  ↓
recuperado do balde
  │  sha256 734bca76…86bfa84   IDÊNTICO
  ↓
restaurado em banco novo
     0 erros · 66 tabelas · contagem igual linha a linha
```

## As três coisas que este ensaio prova e o anterior não provava

1. **Multipart funciona.** O `-16` no ETag é a evidência: 16 partes enviadas, montadas, e o
   checksum voltou igual. O objeto de 44 bytes nunca chegou perto disso.
2. **O que volta do balde é o que foi.** Mesmo sha256, mesmo tamanho em bytes.
3. **Restaurar do destino remoto funciona** — e é o que o §6 pede. Antes, a restauração tinha
   sido feita de arquivo local, o que prova o `pg_dump` e não prova o destino.

## A ordem, que é o requisito mais frágil

A varredura rodou **antes** do envio, e a linha da marca de redação prova que ela olhou o
lugar certo — sem ela, "zero ocorrências" poderia significar que a varredura procurou onde não
havia nada.

**O que passa para uma cópia não se desfaz.** A varredura de hoje só devolveu zero porque a
linha `oban_jobs` #697 já tinha sido redigida em 2026-09-12. Se o ensaio tivesse acontecido um
dia antes, o token estaria no balde — e apagar o objeto depois não desfaria o que já tinha
sido copiado.

---

## ⚠️ O que está no balde agora

O objeto contém o **banco de desenvolvimento inteiro**, e nele os **dois tokens de sessão em
claro** — `users.session_token` segue em `character varying`, que é o achado da spec 064
ainda não corrigido.

É de desenvolvimento, e serve para provar o caminho. Mas o objeto existe, e o precedente
importa: **para produção, varrer antes, sempre.**

## O que este ensaio NÃO prova

- **Não é o destino de produção.** MinIO local, na mesma máquina do banco. O backup de
  produção precisa de destino **fora** dela — o incêndio que leva o banco leva o MinIO junto;
- **Não exercita o agendamento.** A rotina do Dokploy (runbook §4) não rodou; foi um ensaio
  manual;
- **Não prova os 7 dias seguidos** do SC-006;
- **Não mediu tempo de restauração sob carga** — o banco estava ocioso.

## Como repetir

```bash
docker compose --profile backup up -d
docker exec the_band_postgres pg_dump -U postgres -d the_band_dev > /tmp/d.sql
# varrer ANTES de enviar
docker cp /tmp/d.sql the_band_minio:/tmp/d.sql
docker exec the_band_minio mc cp /tmp/d.sql l/the-band-backup/d.sql
```

Console: <http://localhost:9001/browser/the-band-backup> — `theband` / `theband-ensaio-local`.

As credenciais estão em claro no `compose.yaml` **de propósito**: são de ensaio local, e a
produção nunca as lê daí. As variáveis `MINIO_*` do `.env.example` são **opcionais** — este
ensaio rodou num `.env` que não tinha nenhuma delas.
