# Pesquisa — Fase 0

**Feature**: 001 — Coleta de pessoas e equipes do GitHub para a Enterprise Ontology
**Data**: 2026-08-09

Resolve as decisões técnicas que a especificação deixou em aberto por serem
matéria de plano. Cada uma traz a decisão, a justificativa e as alternativas
descartadas.

---

## R1 — Versões da plataforma

**Decisão**

| Componente | Versão | Verificado |
|---|---|---|
| Elixir | 1.20.2 | instalado no ambiente |
| Erlang/OTP | 29 | instalado no ambiente |
| Phoenix | `~> 1.8` | Hex |
| Ecto SQL | `~> 3.14` | Hex |
| Oban | `~> 2.23` | Hex |
| Req | `~> 0.7.2` | Hex |
| PostgreSQL | 16 | via Docker Compose |

**Justificativa.** São as versões correntes no Hex, compatíveis com o Elixir e o
OTP já instalados. Nenhuma exige backport ou fixação em versão antiga.

**Atenção ao Req.** Está em `0.x`, o que significa que mudanças incompatíveis
podem vir em versão menor. Fixar `~> 0.7.2` e não `>= 0.7` — a atualização passa
a ser ato deliberado, com leitura do changelog.

---

## R2 — Biblioteca de leitura de YAML

**Decisão**: `yaml_elixir ~> 2.12`.

**Justificativa.**

| Critério | `yaml_elixir` | `fast_yaml` |
|---|---|---|
| Último lançamento | 2.12.2, maio/2026 | 1.0.40, março/2026 |
| Cadência | 4 lançamentos em 2 anos | 4 lançamentos em 3 anos |
| Implementação | Erlang puro (`yamerl`) | NIF em C, sobre libyaml |
| Licença | MIT | — |
| Compilação | nenhuma dependência externa | exige toolchain C e libyaml |
| Falha em parse | erro no processo chamador | NIF pode derrubar a VM |

O peso decisivo é o último critério. Um NIF com falha de segmentação derruba a
máquina virtual inteira, não apenas o processo — e a base de conhecimento é lida
na inicialização, então um YAML malformado passaria de erro tratável a
indisponibilidade do sistema. O ganho de desempenho do `fast_yaml` é irrelevante
aqui: a leitura acontece uma vez por boot, sobre 80 arquivos.

**Alternativa descartada**: `fast_yaml`, pelo risco de NIF e pela dependência de
toolchain C, que complicaria a imagem de container sem contrapartida.

---

## R3 — Criptografia da credencial em repouso

**Requisitos atendidos**: FR-005, FR-005a, FR-005b.

**Decisão**: `cloak_ecto ~> 1.3`, com AES-GCM de 256 bits e chave mestra vinda de
variável de ambiente.

**Justificativa.** É a biblioteca estabelecida do ecossistema para campos Ecto
cifrados, com licença MIT e integração direta ao tipo de campo — a cifragem
acontece no `Ecto.Type`, não no código de aplicação, o que remove a possibilidade
de alguém gravar em claro por esquecimento.

**Ressalva registrada.** Último lançamento em abril de 2024. Não é abandono —
a biblioteca é pequena, estável e resolve um problema fechado —, mas exige
acompanhar avisos de segurança. Reavaliar se surgir CVE ou se o Ecto 4 quebrar
compatibilidade.

**Como cada requisito é atendido.**

- **FR-005** — o valor é cifrado pelo tipo Ecto antes de chegar ao banco; ler a
  tabela devolve texto cifrado.
- **FR-005a** — a aplicação valida a presença da chave mestra na inicialização do
  supervisor de `Cloak.Vault` e falha o boot se ausente. Recusar-se a subir é o
  comportamento correto: uma aplicação que sobe sem chave gravaria credenciais em
  claro e ninguém perceberia.
- **FR-005b** — o `Cloak` suporta múltiplas chaves com rótulo, decifrando com
  qualquer uma e cifrando sempre com a marcada como padrão. A rotação é: incluir
  a chave nova como padrão, manter a antiga para leitura, reescrever os registros
  em background, remover a antiga. Documentar como Mix task.

**Alternativa descartada**: cofre externo (Vault, AWS Secrets Manager). Passaria
a ser pré-requisito de todo ambiente, inclusive o de desenvolvimento, para uma
feature que ainda precisa provar o caminho de ponta a ponta. Decisão já
registrada em Assumptions da especificação; migrar depois seria ADR própria.

**Exibição parcial (FR-007)**. Guardar, além do valor cifrado, os quatro últimos
caracteres em claro num campo separado, para a interface distinguir uma
credencial da outra. Quatro caracteres não reduzem materialmente o espaço de
busca de um token de 40.

---

## R4 — Carregamento e cache da base de conhecimento

**Decisão**: carregar no boot, para ETS de leitura concorrente, com uma tabela
por tipo de artefato.

**Justificativa.** As três alternativas e por que esta:

| Estratégia | Descartada porque |
|---|---|
| Compile time (`@external_resource`) | mudar um YAML exigiria recompilar; a base é revisada com frequência e por quem não compila o projeto |
| Leitura por requisição | proibido por AGENTS.md, e desperdício: a base muda em deploy, não em runtime |
| **Boot para ETS** | **escolhida** |

ETS com `read_concurrency: true` dá leitura sem cópia entre processos e sem
serialização por GenServer. A base tem 80 arquivos e algumas centenas de
conceitos — cabe em memória com folga.

**Consequência operacional.** A base passa a ser lida uma vez por boot. Alterar
YAML em produção exige reinício, o que é aceitável e até desejável: a mudança
semântica passa por deploy, com validação no CI antes.

**Falha no carregamento é falha de boot.** Base inválida não pode gerar aplicação
funcionando com modelo pela metade.

---

## R5 — Checkpoint de paginação

**Decisão**: registro por `(fonte, tipo de entidade)` com cursor opaco, contagem
e instante, atualizado ao fim de cada página processada com sucesso.

```text
sync_checkpoints
  source_id, entity_type          identificam o ponto
  cursor                          cursor opaco da fonte, como recebido
  page_count, record_count        progresso
  last_page_at                    quando a última página fechou
  status                          running | completed | failed
```

**Justificativa.** O cursor do GraphQL é opaco e só faz sentido para a própria
API — não interpretá-lo é o que mantém o mecanismo válido se o formato mudar.

Gravar **depois** de processar a página, e não antes, garante que uma
interrupção reprocesse no máximo a última página. Reprocessar é seguro porque a
ingestão é idempotente (FR-014); perder não seria.

**Atende SC-006**: no máximo uma consulta a mais, por página, em relação à
execução não interrompida.

---

## R6 — Respeito ao rate limit do GraphQL

**Decisão**: pedir `rateLimit { cost remaining resetAt }` em toda consulta e
pausar antes do limite, com margem.

**Justificativa.** O limite do GraphQL do GitHub é por **complexidade da
consulta**, não por número de requisições — uma consulta pesada pode custar
centenas de pontos. Reagir ao erro 403 significa perder a janela inteira e
esperar o reset; a informação para evitar isso vem na própria resposta.

**Regra**: se `remaining < cost × 2`, aguardar até `resetAt` antes da próxima
página. A margem de duas vezes cobre a variação de custo entre páginas.

**Não confundir com retry.** Backoff exponencial continua valendo para erro de
rede e 5xx. Rate limit não é erro — é informação de capacidade.

---

## R7 — Onde vive o vínculo observado sem papel

**Decisão**: tabela própria, `eo_observed_team_links`, distinta de
`eo_team_memberships`.

**Justificativa.** `eo.team_membership` é o relator que aloca pessoa, equipe **e
papel**. O GitHub fornece dois dos três (ADR 0004, D5/D6). Gravar membership com
papel nulo violaria o modelo e faria toda consulta de papel precisar tratar o
caso nulo — espalhando pela aplicação a consequência de uma limitação da fonte.

Em tabela separada, o vínculo observado é dado de primeira classe, contável e
consultável, e o modelo permanece íntegro.

```text
eo_observed_team_links
  person_id, team_id              o que a fonte informa
  platform_access_level           MAINTAINER | MEMBER — acesso, não papel
  observed_at, last_observed_at   quando foi visto pela primeira e última vez
  promoted_membership_id          preenchido quando vira membership
```

**Promoção.** Fora de escopo desta feature, mas a coluna existe desde já para
que a promoção futura não exija migração de dados. Quando o tenant atribuir o
papel, cria-se a membership e registra-se aqui o vínculo — preservando a
evidência que a originou.

**Métrica de lacuna (FR-021)**: contagem de linhas com `promoted_membership_id`
nulo.

---

## R8 — Views derivadas: migração ou artefato à parte

**Decisão**: migração, gerada a partir da base de conhecimento.

**Justificativa.** As alternativas:

| Opção | Problema |
|---|---|
| Artefato aplicado fora da migração | o banco passa a ter estado que o histórico de migrações não descreve; um ambiente novo pode ficar sem as views |
| Migração escrita à mão | reintroduz a divergência que a derivação existe para evitar (ADR 0002) |
| **Migração gerada** | **escolhida** |

A view é parte do esquema e precisa estar no mesmo histórico das tabelas. Sendo
gerada, uma mudança conceitual regenera tabela e view na mesma passagem.

**Consequência.** É preciso um passo que compare o esquema derivado com o atual e
produza a migração. Nesta feature o passo é manual — rodar o derivador, conferir,
escrever a migração. Automatizá-lo é trabalho posterior, registrado no backlog da
biblioteca (L4).

**Escopo nesta feature.** Apenas a view `eo_team_members`, sobre `eo_people` e
`eo_team_memberships`. As demais views de EO só fazem sentido quando houver
papéis cadastrados.

---

## R9 — Estrutura dos módulos Elixir de EO

**Decisão**: conforme ADR 0003 — API pública no módulo raiz por `defdelegate`,
schemas privados ao módulo.

```text
lib/the_band/ontology/seon/eo/
├── eo.ex              API pública; só defdelegate
├── schemas/           privados — não saem do módulo
├── commands/          escritas: {:ok, struct} | {:error, changeset}
├── queries/           leituras, com tenant explícito
└── constraints/       invariantes das regras da base
```

**Justificativa.** É o que sustenta a autonomia entre módulos ontológicos sem
processos separados. A ingestão chama `TheBand.Ontology.SEON.EO.upsert_person/2`,
nunca `Repo.insert` sobre o schema — o que mantém a fronteira verificável em
revisão.

**`upsert_from_source` em vez de `create`.** Entidade ingerida não é criada por
alguém: é observada. A função recebe o tenant e os atributos com proveniência,
resolve a Application Reference e decide entre inserir e atualizar. Não existe
`create_person/1` público, porque não há caso de uso de criar pessoa à mão nesta
feature.

---

## Pendências que não bloqueiam

**Reconciliação de identidade** — fora de escopo por decisão da especificação.
Duas contas da mesma pessoa geram duas linhas em `eo_people`, o que é registrado
como limitação conhecida.

**Promoção automática de vínculo a membership** — fora de escopo. A coluna existe;
o fluxo não.

**Demais views de EO** — dependem de papéis cadastrados, que esta feature não
entrega.
