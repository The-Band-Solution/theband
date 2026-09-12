# MinIO como destino do ensaio de backup

**Decisão da pessoa mantenedora em 2026-09-12**: o ensaio do §6 do runbook deixa de esperar
uma conta em provedor de S3. O destino passa a ser **MinIO**, que fala o mesmo protocolo.

> **~~O que este item NÃO decide~~: ~~o destino de produção~~** — o texto original dizia que a
> produção ficava de fora. **DECIDIDO em 2026-09-12 pela pessoa mantenedora: o MinIO vira
> também o destino de produção, num SEGUNDO HOST.**
>
> A regra que não muda é a que dá sentido ao backup: **fora da máquina que ele protege**. O
> incêndio que leva o banco não pode levar o backup junto — e é por isso que a decisão diz
> *segundo host*, e não *outro contêiner*.

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

## A decisão de 2026-09-12: produção também, num segundo host

O que isto acrescenta ao item, e **nada disto o ensaio local resolve**:

| o que | por quê |
|---|---|
| **um segundo host** | é a dependência nova, e é do mesmo tipo da que travava antes: infraestrutura que ainda não existe. A diferença é que agora é um host, e não uma conta em provedor |
| **TLS no transporte** | o backup atravessa a rede. O `compose.yaml` de hoje sobe `http://minio:9000` — correto para o ensaio local, **errado** para produção: seria o dump em claro no caminho |
| **credenciais de produção fora do repositório** | as do `.env.example` são explicitamente de desenvolvimento (`theband` / `theband-ensaio-local`). As de produção entram no Dokploy, como a chave mestra já entra |
| **a credencial que escreve não apaga** | o job precisa **escrever**; não precisa ler nem apagar. Credencial que apaga o balde transforma um comprometimento da produção em **perda do caminho de volta** — o oposto do que o backup garante |
| **retenção declarada** | quantas cópias, por quanto tempo, e o que acontece quando o host encher |
| **o caminho de volta do próprio destino** | se o host de backup morrer, o que se perde e o que se faz |

### A pergunta que a decisão deixa aberta, e é de topologia

*Segundo host* tem leitura **fraca** e **forte**:

- **fraca**: outra máquina, mesmo provedor, mesma conta, mesma região;
- **forte**: outro **domínio de falha** — outro provedor, outra conta, outra credencial.

A leitura fraca protege de *o disco do banco morrer*. **Não protege** de a conta ser suspensa,
de a região cair, nem de a credencial do provedor vazar — e nos três o backup vai junto. Qual
das duas vale é decisão de operação, e está sendo avaliada pelo papel de Security junto do
resto da superfície de risco.

### O que o host guarda, e por que a pergunta acima não é teórica

Um dump do banco de produção é **tudo**: contas, `password_hash`, `session_token`, o elo
conta↔pessoa, os escopos de acesso, e as credenciais de ferramenta cifradas. Comprometer o
destino de backup é comprometer a produção inteira — com o agravante de que **ninguém
percebe**: não há sessão, não há log de aplicação, não há tela.

## Uma pergunta para a pessoa mantenedora

**O MinIO vira também o destino de produção, num segundo host?** Se sim, é infraestrutura
nova para operar — e a regra de estar **fora** da máquina protegida continua valendo. Se não,
ele fica só como destino de ensaio, e a conta no provedor volta a ser necessária **para
produção** — mas deixa de bloquear o ensaio, que é o que estava travado.
