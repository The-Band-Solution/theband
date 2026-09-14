# Paridade entre o `compose.yaml` e o Dokploy

**Aberto em**: 2026-09-13 · **Proposto pela pessoa mantenedora** · **Estreitado em 2026-09-14**:
a leitura (b) já estava decidida desde 2026-09-12, e este item dizia que não

**A ideia**: o que o `compose.yaml` declara deve existir também no servidor. O que roda aqui
roda lá, e a diferença entre os dois ambientes deixa de ser uma coisa que só se descobre
quando quebra.

---

## O estado, medido

| serviço | profile | no VPS |
|---|---|---|
| `postgres` | nenhum | **não vai** — é o banco de quem desenvolve |
| `postgres_prod` | `producao` | **já está** (runbook §4) |
| `app` | `producao` | **já está** |
| `minio` | `backup` | **ausente** |
| `minio_balde` | `backup` | **ausente** |

**O vão é o MinIO.** O resto já tem paridade.

---

## A tensão, e ela está escrita no próprio `compose.yaml`

`compose.yaml:106-110`:

> O backup de produção escreve num destino **fora da máquina que ele protege** — é a razão de
> ele existir. **Um MinIO no mesmo host não serviria: o incêndio que leva o banco leva o
> backup junto.**

Subir o MinIO no mesmo VPS entrega **paridade de ambiente** e **não entrega backup**. As duas
coisas são desejáveis, e essa configuração sozinha dá só uma.

### O risco de não nomear isso

Alguém abre o painel do Dokploy, vê *"MinIO — rodando"*, e conclui que o backup está
resolvido. A conclusão é silenciosamente errada, e só se descobre no dia em que o host cai —
que é o único dia em que importa.

É a mesma família do defeito que esta casa persegue no dado que coleta: **presença lida como
suficiência**.

---

## As três leituras, e o que cada uma custa

### (a) Só paridade de ambiente

MinIO no VPS, ao lado do app e do banco. O que funciona aqui funciona lá; o ensaio do §6 passa
a rodar contra o servidor.

**Não é backup.** E o custo é memória e disco no mesmo VPS que serve a aplicação.

### (b) Só o backup funcionando

MinIO — ou qualquer destino S3 — **em outro host**. **É a decisão já tomada em 2026-09-12**
pela pessoa mantenedora — *"o MinIO vira também o destino de produção, num segundo host"* —,
registrada em [MinIO como destino do ensaio e da produção](minio-como-destino-do-ensaio-de-backup.md)
(PR #914). Esta leitura não está em aberto: é o **piso**.

**Não dá paridade**: o `compose.yaml` continua declarando um serviço que o servidor não tem.

### (c) As duas, com nomes diferentes — **recomendada**

MinIO no VPS **nomeado como destino de ensaio**, e um segundo destino fora dele para o backup
de verdade.

O que faz isto funcionar não é a topologia — é o **nome**. O serviço no painel precisa se
chamar algo como `minio-ensaio`, e não `minio-backup`, para que a leitura de quem abre o
painel seja a verdadeira.

---

## O que precisa ser decidido antes de executar

A primeira versão deste item (2026-09-13) punha as três leituras em aberto. **Estava errado**: a
(b) já tinha sido decidida um dia antes, e o item de backlog do MinIO registrava isso. Duas
fontes dizendo coisas diferentes sobre a mesma decisão é o defeito que este diretório existe
para evitar. Corrigido em 2026-09-14 — o que resta decidir é menor:

1. ~~Qual das três leituras vale~~ — **(b) está decidida** (2026-09-12, #914): produção num
   segundo host. **O que resta**: se a (c) se soma a ela — um MinIO **também** no VPS, para o
   ensaio. É pergunta de paridade, não de backup;
2. **Se houver MinIO no VPS, o nome dele é `minio-ensaio`**, nunca `minio-backup`. O nome é o
   que impede quem abre o painel de ler presença como suficiência;
3. **Onde fica o segundo host, e quem paga.** Continua aberto — a decisão de 2026-09-12 diz
   *segundo host*, e não diz qual.

---

## O que já está provado, e não precisa ser refeito

O caminho completo foi exercitado localmente em 2026-09-13 e está em
`docs/seguranca/2026-09-13-o-caminho-completo-do-backup.md` — **na branch de release** (PR
#916), e chega a `development` com o bump da v0.8.0; até lá o link não resolve aqui:

```
pg_dump 259.938.022 B → varredura ANTES (0 ocorrências, controle positivo ok)
  → MinIO 248 MiB, ETag …-16 (multipart de verdade)
  → recuperado: sha256 IDÊNTICO
  → restaurado: 0 erros, 66 tabelas, contagem igual linha a linha
```

**O protocolo funciona.** O que falta é topologia e decisão, não técnica.

---

## O que fazer, quando for decidido

**Preparável agora**: um compose de produção com o MinIO e o balde, e o runbook do que colar
no painel do Dokploy.

**Não preparável por quem escreve código**: criar o serviço no Dokploy. Exige login no painel,
ou o `x-api-key` da API — e credencial não passa por chat. O caminho está em
`docs/producao/fluxo-de-release.md`.

## O que este item NÃO é

- **não é o ensaio do §6** — ele foi fechado em 2026-09-13, localmente;
- **não é a varredura da produção** — é a FR-010 da spec 064, e continua pendente;
- **não é a rotação do token `…omAX`** — adiada para 2026-10-12.
