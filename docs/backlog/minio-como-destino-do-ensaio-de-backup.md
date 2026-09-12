# MinIO como destino do ensaio de backup

**Decisão da pessoa mantenedora em 2026-09-12**: o ensaio do §6 do runbook deixa de esperar
uma conta em provedor de S3. O destino passa a ser **MinIO**, que fala o mesmo protocolo.

> **O que este item NÃO decide**: o destino de **produção**. Ele continua sendo o do runbook
> §4 — agendado no Dokploy, e **fora da máquina que ele protege**. Um MinIO no mesmo host não
> serviria: o incêndio que leva o banco leva o backup junto.

## O que estava travado, e por quê

O item [o backup restaurado de verdade](backup-restaurado-de-verdade.md) está **alto e
bloqueado desde 2026-09-08** por uma razão que nunca foi técnica: *"tenho que criar a conta na
S3 ainda para isso"*.

E o que ele protege é o caminho de volta. O runbook é explícito: **o backup só existe depois
de restaurado uma vez.** Um backup nunca restaurado é um arquivo — não se sabe se está
completo, se o formato abre, nem se o comando escrito é o que restaura.

## O que já está feito, e medido

`compose.yaml` ganhou dois serviços no profile **`backup`**, e o profile existe pela mesma
razão do `producao`: quem desenvolve não paga por serviço que só o ensaio usa.

```bash
docker compose --profile backup up -d
```

| medido em 2026-09-12 | resultado |
|---|---|
| o MinIO sobe e fica saudável | **sim** — `the_band_minio Healthy` |
| o balde nasce sozinho | **sim** — `Bucket created successfully local/the-band-backup` |
| e nasce **privado** | **sim** — `Access permission ... is set to private` |
| escrever um arquivo e lê-lo de volta | **sim**, e o conteúdo volta **idêntico** |

**Duas coisas que a primeira tentativa errou, e ficam registradas para não voltarem**:

1. **as imagens não estão no Docker Hub.** `minio/minio` de lá devolve
   `pull access denied ... repository does not exist`. A distribuição oficial é o
   **quay.io**;
2. **a tag é imutável, e não `latest`.** Mesma razão do achado H7: `latest` responde *"o que
   foi publicado por último"*, que não é *"o que está rodando"*.

E o balde **nasce no compose**, e não à mão: MinIO não cria bucket no boot, e sem esse passo o
ensaio falharia no primeiro `put` com `NoSuchBucket` — **depois** de o `pg_dump` ter rodado,
que é o pior lugar para descobrir que falta configuração.

## O que falta para executarmos o ensaio

Nada disto é sobre o MinIO: é o ensaio do §6, que agora tem para onde escrever.

1. **o `pg_dump` do banco de produção** chega ao balde — prova que o job escreve onde se pensa
   que escreve;
2. **restaurar num banco vazio e novo**, e nunca por cima do que existe;
3. **a aplicação sobe contra o restaurado** e serve as telas;
4. **conferir número contra número** — pessoas, equipes, itens de trabalho —, e não *"abriu,
   então está certo"*;
5. **cronometrar**, porque o tempo do ensaio é o tempo do desastre;
6. **registrar** em `docs/producao/`: a data, o tamanho do arquivo, o tempo, e o que falhou.

**Falhou qualquer passo, o backup não existe de verdade** — e é o texto do runbook, não uma
paráfrase.

## O que este item destrava, e o que continua aberto

**Destrava**: o ensaio pode rodar hoje, localmente, contra um destino S3 real.

**Continua aberto**: o destino de produção. O ensaio contra MinIO prova o **formato, o
comando e o tempo**; não prova que o job do Dokploy escreve no lugar certo nem que o lugar
certo sobrevive ao host. São duas afirmações diferentes, e só a primeira fica provada aqui.

## Uma pergunta para a pessoa mantenedora

**O MinIO vira também o destino de produção, num segundo host?** Se sim, é infraestrutura
nova para operar — e a regra de estar **fora** da máquina protegida continua valendo. Se não,
ele fica só como destino de ensaio, e a conta no provedor volta a ser necessária **para
produção** — mas deixa de bloquear o ensaio, que é o que estava travado.
