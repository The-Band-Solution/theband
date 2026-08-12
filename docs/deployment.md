# Deployment e variáveis de ambiente

Como colocar o The Band em execução — local, CI e produção — e o que cada variável faz.

**Estado deste documento**: escrito em 2026-08-11, a partir de `config/runtime.exs`,
`compose.yaml`, `.github/workflows/ci.yml` e das 22 migrações que existem no repositório.

---

## 1. A variável que decide se a aplicação sobe

`THE_BAND_MASTER_KEY` — a chave que cifra as credenciais das ferramentas conectadas.

**A aplicação recusa o boot sem ela**, e isso vale para **todos** os ambientes. Não há
chave de desenvolvimento embutida: uma chave no repositório é uma chave vazada.

```
Defina THE_BAND_MASTER_KEY com 32 bytes em Base64:

    export THE_BAND_MASTER_KEY=$(mix the_band.gen_key)
```

O único fallback está em `config/runtime.exs`, e vale **apenas** quando
`config_env() == :test`: uma chave fixa e assumidamente pública, que cifra somente dados
de fixture num banco descartado no fim da execução.

```elixir
case {System.get_env("THE_BAND_MASTER_KEY"), config_env()} do
  {blank, :test} when blank in [nil, ""] -> Base.encode64(<<0::size(256)>>)
  {value, _} -> value
end
```

### Por que `nil` e `""` são tratados como a mesma coisa

Porque distingui-los custou um CI vermelho. Um workflow que referencia
`secrets.THE_BAND_MASTER_KEY` **sem o secret estar cadastrado** define a variável como
**string vazia**, não a deixa ausente. A versão anterior só cobria `{nil, :test}`, e a
ausência do secret desligava o fallback: `mix test` falhava sem haver nada errado com o
código.

**Referenciar secret que não existe é pior que não referenciar nenhum.** Está registrado
como [L13](sprints/licoes-aprendidas.md).

### Se a chave for perdida

As credenciais cifradas com ela ficam **ilegíveis para sempre**. Não há recuperação — é o
ponto de cifrar. Aconteceu neste projeto: a chave original do banco de desenvolvimento não
existe mais.

O caminho é limpo, e são três passos:

```bash
export THE_BAND_MASTER_KEY=$(mix the_band.gen_key)   # 1. chave nova, guardada
mix phx.server                                        # 2. sobe
```

3. Em `/tools`: **encerrar observação** na ferramenta afetada — o que destrói a
   credencial ilegível — e depois **retomar observação** com um token novo, que é validado
   contra a origem antes de ser gravado.

**Nada além da credencial é perdido**: pessoas, equipes, issues e payloads não são
cifrados.

### Rotação, quando a chave precisa mudar sem perder dado

O Cloak decifra com **qualquer** cipher configurado e cifra sempre com o marcado como
`:default`. A ordem importa:

```bash
export THE_BAND_PREVIOUS_MASTER_KEY=$THE_BAND_MASTER_KEY   # 1. a antiga passa a ser leitura
export THE_BAND_MASTER_KEY=$(mix the_band.gen_key)          # 2. a nova entra como default
mix the_band.rotate_key                                     # 3. recifra os registros
unset THE_BAND_PREVIOUS_MASTER_KEY                          # 4. só então remove a antiga
```

Trocar a variável **sem** o passo 3 deixa os registros antigos ilegíveis. A antiga só sai
do ambiente depois de nenhum registro depender dela.

---

## 2. Todas as variáveis

| Variável | Onde é obrigatória | Padrão | O que faz |
|---|---|---|---|
| `THE_BAND_MASTER_KEY` | **dev, prod** (fallback só em test) | — | cifra credenciais; sem ela a aplicação recusa o boot |
| `THE_BAND_PREVIOUS_MASTER_KEY` | durante rotação | — | leitura da chave antiga enquanto os registros são recifrados |
| `DATABASE_URL` | **prod** | `ecto://postgres:postgres@localhost/the_band_dev` em dev | conexão com o Postgres |
| `SECRET_KEY_BASE` | **prod** | gerado em dev | assina sessões e cookies |
| `PHX_HOST` | **prod** | `example.com` ⚠ | host público; ver a armadilha abaixo |
| `PHX_SERVER` | **release** | — | sem ela o endpoint **não** sobe num release |
| `PORT` | — | `4000` | porta HTTP |
| `POOL_SIZE` | — | `10` | conexões do pool do Ecto |
| `DNS_CLUSTER_QUERY` | — | — | descoberta de nós para cluster |
| `MIX_TEST_PARTITION` | CI particionado | — | sufixo do banco de teste por partição |

**`PHX_HOST` tem armadilha.** Sem ela, o padrão em produção é `example.com`, e a
aplicação sobe: os links gerados apontam para um domínio que não é seu, e nada falha.
Defina-a sempre em produção.

**`SOME_APP_SSL_KEY_PATH` e `SOME_APP_SSL_CERT_PATH` não são usadas.** Aparecem
**comentadas** em `config/runtime.exs`, geradas pelo Phoenix. Um grep no repositório as
encontra, e é por isso que estão declaradas aqui: para ninguém as configurar esperando
efeito.

**`PHX_SERVER` só importa em release.** `mix phx.server` sobe o endpoint por conta
própria; `bin/the_band start` não, e o sintoma é uma aplicação de pé que não atende
requisição nenhuma.

---

## 3. Desenvolvimento local

```bash
docker compose up -d                                  # Postgres 17-alpine
export THE_BAND_MASTER_KEY=$(mix the_band.gen_key)
mix setup                                             # deps, banco, assets
mix phx.server                                        # localhost:4000
```

**O volume do compose tem dado real.** O banco de desenvolvimento deste projeto guarda
4455 issues, 135 repositórios e centenas de payloads preservados, coletados da origem.

```bash
docker compose down          # para os containers, PRESERVA o volume
docker compose down -v       # APAGA o volume — a coleta inteira se perde
```

O `-v` não avisa. Recoletar exige credencial válida e uma janela de consumo da origem.

### A base de conhecimento é lida uma vez, no boot

Os 94 artefatos YAML de `priv/knowledge_base/` são carregados para ETS quando a aplicação
sobe. **Alterar YAML não tem efeito sem reiniciar.**

Isso morde de um jeito que não parece bug. Aconteceu neste projeto: uma regra de
mapeamento criada **depois** do boot não valia, e a tela de trabalho mostrava três
divergências que desapareceriam com um restart. Ninguém suspeita da tela — suspeita da
regra.

```bash
# depois de mexer em priv/knowledge_base/
# Ctrl-C duas vezes, e:
mix phx.server
```

Em produção: **um mapeamento novo exige restart**. Planeje isso como parte do deploy de
conhecimento, e não como detalhe operacional.

---

## 4. Quality gates

Os nove, num comando:

```bash
mix gates                  # na ordem do CI, abortando no primeiro que reprovar
mix gates --list           # os nomes
mix gates --from testes    # retoma de um gate
```

`mix gates` é a **única definição** deles: o `ci.yml` chama a mesma task, e por isso não
existe uma segunda lista para ficar desatualizada.

**Ela provisiona `.venv` na primeira execução, e isso não é conveniência.** Sem o venv, o
validador Python **não valida a forma** dos YAML: ele avisa que pulou, registra a falha e
sai diferente de zero. Quem lê a saída com `| tail` vê o aviso como nota de ambiente e
conclui que passou — foi o que aconteceu dez vezes seguidas, até o CI reprovar seis
mapeamentos ([L23](sprints/licoes-aprendidas.md)).

**Nunca `| tail` num gate.** Rode, confira o código de saída, e só então resuma.

### Rodar o workflow inteiro na máquina

```bash
brew install act
docker stop the_band_postgres    # o serviço do workflow publica a 5432
act -j quality-gates             # configuração em .actrc, versionada
docker start the_band_postgres
```

O `docker stop` é necessário: sem liberar a porta, o `act` falha em *Set up job* com
`port is already allocated` — que parece erro de workflow e é conflito de porta.

**`act -n` não funciona neste workflow.** A versão 0.2.89 tem um `nil pointer dereference`
ao inspecionar containers de serviço em modo dry-run. Rode sem `-n`.

---

## 5. Migrações

22 no total, e **nenhuma remove coluna**. O round trip é parte do gate:

```bash
mix ecto.migrate
mix ecto.rollback --step 1
mix ecto.migrate
```

Toda migração deste projeto traz um `@moduledoc` explicando **por que** a forma é aquela —
inclusive as ausências deliberadas. Duas que valem ler antes de acrescentar coluna:

| Migração | O que ela declara |
|---|---|
| `create_issue_promotions` | **não** cria `sro_user_stories.status`, apesar de o derivador imprimir essa coluna. A classificação é situação, e situação é derivada |
| `create_decomposition_links` | **não** tem `check_constraint` de aciclicidade: o axioma `sro.rule04` registra que constraint de banco não pega ciclo transitivo |

Sem esses parágrafos, a ausência de uma coluna que o derivador imprime parece esquecimento,
e a próxima pessoa a acrescenta.

---

## 6. Filas de trabalho

Oban, com **duas** filas configuradas em `config/config.exs`:

```elixir
queues: [ingestion: 5, transformation: 5]
```

**Declarar um worker numa fila que não existe faz o job ficar `available` para sempre.**
Oban só executa fila configurada, e não há erro: o job simplesmente nunca roda. Aconteceu
neste projeto com uma fila `:sync` inexistente, e o sintoma foi uma coleta que "completou"
sem coletar nada.

Ao acrescentar worker, use `ingestion` ou `transformation` — ou acrescente a fila à
configuração, com o motivo escrito.

---

## 7. Produção

### Release

```bash
MIX_ENV=prod mix release
```

```bash
export THE_BAND_MASTER_KEY=...        # do cofre da infraestrutura
export SECRET_KEY_BASE=$(mix phx.gen.secret)
export DATABASE_URL=ecto://usuario:senha@host/banco
export PHX_HOST=seu.dominio
export PHX_SERVER=true                # sem ela o endpoint não sobe

bin/the_band eval "TheBand.Release.migrate"   # se houver módulo de release
bin/the_band start
```

### Ordem do deploy, e por que ela é essa

1. **migrar** — as migrações não removem coluna, então a versão antiga continua
   funcionando sobre o esquema novo;
2. **subir a aplicação nova**;
3. **reiniciar**, se a base de conhecimento mudou — YAML é lido no boot.

O passo 3 é o que se esquece. Um deploy que altera mapeamento e não reinicia entrega
código novo com semântica antiga, e a diferença aparece como dado errado em vez de erro.

### O que precisa estar no cofre, e não no ambiente do repositório

| Segredo | Consequência de vazar |
|---|---|
| `THE_BAND_MASTER_KEY` | todas as credenciais de todas as ferramentas de todos os tenants |
| `SECRET_KEY_BASE` | sessões forjáveis |
| `DATABASE_URL` | acesso direto ao banco |

**A chave mestra nunca entra no repositório**, e o CI não a referencia — ele usa o fallback
de teste, que é público por decisão.

---

## 8. Problemas conhecidos, e o que cada mensagem significa

| Mensagem | Causa | O que fazer |
|---|---|---|
| `:missing_master_key` | variável ausente ou vazia | `export THE_BAND_MASTER_KEY=$(mix the_band.gen_key)` |
| `:invalid_master_key` | não são 32 bytes em Base64 | gere com a task; `1234` não serve |
| `AES.GCM...` ao decifrar | chave diferente da que cifrou | rotacione, ou refaça a credencial pelo encerrar/retomar |
| `port 4000 already in use` | já há servidor de pé | `lsof -nP -iTCP:4000 -sTCP:LISTEN` |
| `port is already allocated` no `act` | Postgres local na 5432 | `docker stop the_band_postgres` |
| job Oban em `available` para sempre | fila não configurada | use `ingestion` ou `transformation` |
| `[schema] jsonschema não instalado` | venv ausente | `mix gates` o provisiona; **o gate reprovou**, não avisou |
| tela mostra classificação inesperada | YAML alterado sem restart | reinicie a aplicação |

---

## O que este documento não cobre

| Não coberto | Onde procurar |
|---|---|
| Modelo de dados e schemas | [architecture/modelo-de-dados.md](architecture/modelo-de-dados.md) |
| Arquitetura e fronteiras internas | [architecture/overview.md](architecture/overview.md) |
| Observabilidade e telemetria | `AGENTS.md` §15 |
| Provisionamento de infraestrutura | não existe: sem Terraform, Helm nem manifesto de Kubernetes no repositório |
| Backup e restauração do banco | não há procedimento escrito. É lacuna declarada, e o volume do compose guarda dado que uma recoleta custaria caro |

## Manutenção deste documento

Reescrever quando: uma variável for acrescentada ou deixar de ser lida; a ordem do deploy
mudar; uma fila do Oban for acrescentada; ou o fallback de teste da chave mudar.

O critério é: **se alguém seguir este documento e a aplicação não subir, ele está
errado.** As contagens citadas são de 2026-08-11.
