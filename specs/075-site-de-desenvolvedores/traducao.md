# Plano de tradução: o site inteiro em inglês, por lotes

A base (este sprint) prepara a estrutura; a tradução é feita depois, por outros agentes, um lote por
vez. Este arquivo é o que eles leem antes de começar.

## A convenção do arquivo

| regra | exemplo |
|---|---|
| a tradução mora **ao lado** do original, com o sufixo `.en.md` | `docs/adr/0008-vinculo-observado.md` → `docs/adr/0008-vinculo-observado.en.md` |
| o `README.md` de uma pasta vira `README.en.md` | `docs/ontology/README.en.md` |
| o **nome do arquivo não se traduz**: a URL EN é a PT sob `/en/` | `/developers/en/adr/0008-vinculo-observado/` |
| **PT primeiro, sempre**: não existe `.en.md` sem o `.md` | o teste `test/site/` reprova `.en.md` órfão |
| links internos apontam para o **arquivo PT** (`0003-…md`); o plugin resolve para o EN quando ele existe | nunca escrever `0003-….en.md` num link |
| âncoras: o slug do título EN muda; link com `#âncora` para outra página precisa da âncora EN | o build estrito reporta a âncora que falta |
| o título no `nav` se traduz em `nav_translations` do `mkdocs.yml`, não no arquivo | `Decisões: Decisions` |
| páginas geradas (`ontology/`, `integrations/mappings.md`, `metrics/README.md`) **não se traduzem à mão**: o gerador `scripts/generate_docs.py` ganha a saída EN numa tarefa própria | lote 2 tem essa tarefa, e não a tradução manual |
| **feito no L02 (T028)**: `python3 scripts/generate_docs.py` escreve PT e EN. A moldura sai em inglês; o texto da base sai em inglês onde a base tem `en`, e senão em português **marcado `pt-BR`**, com a contagem num aviso no topo. Traduzir esse texto é escrever o `en` **na base**, não na página | `test/site/test_gerador_en.py` reprova página gerada divergente da base |

## A ausência nomeada enquanto a tradução não chega

1. **Agora**: `fallback_to_default: true`. A página sem `.en.md` é servida em `/en/` com o texto em
   português, e o hook injeta no topo a marca de ausente **"translation pending"** com a frase *"This
   page has not been translated yet. The text below is the Portuguese original."* Nunca 404, nunca
   texto PT fingindo ser EN.
2. **O build conta**: todo `mkdocs build` escreve no log `tradução: N de M páginas sem versão EN`, com a
   lista em `site/traducao-pendente.txt` (fora da navegação).
3. **Depois do último lote**: `extra.traducao.exigir: true` no `mkdocs.yml`. A partir daí o build
   **reprova** página PT sem EN, com a lista. Página nova passa a nascer nos dois idiomas.
4. **Tradução desatualizada** (o PT mudou depois do EN): fora do alcance desta base. O lote final
   abre um item para comparar a data do último commit de cada par.

## O glossário

**Termos de domínio da ontologia ficam como na ontologia.** As ontologias de referência (UFO, SEON,
Continuum) têm nome em inglês; a tradução EN usa esse nome, e não uma tradução livre do português.

| português no texto | em inglês | origem |
|---|---|---|
| vínculo (de equipe) | team membership | `eo.team_membership` |
| membro de equipe | team member | EO, papel |
| pessoa | person | `eo.person` |
| organização | organization | `eo.organization` |
| atividade executada / planejada | performed / intended activity | SPO |
| solicitação de mudança (PR) | change request | `cmpo.change_request` |
| merge | merge | CMPO |
| história de usuário (atômica) | (atomic) user story | `sro.user_story` |
| épico | epic | `sro.epic` |
| defeito, falta, falha | defect, fault, failure | OSDEF |
| necessidade de informação | information need | SMPO |
| medida | measure | SMPO |
| observado / declarado / derivado / ausente | observed / declared / derived / absent | `docs/design-system.md` |
| proveniência | provenance | — |
| vigente / revogado(a) | in force / revoked | `revoked_at IS NULL` (L03) |
| declaração revogável | revocable declaration | `estados/declaracao-revogavel.md` (L03) |
| equívoco (do vínculo) | mistake | `invalidated_at`, como no L02 (L03) |
| saída (declarada) | (declared) departure | `ended_at`, como no L02 (L03) |
| elo (projeto ↔ equipe, quadro, repositório, organização) | link | `spo_project_*` (L03) |
| quadro | board | `observed_projects`; o *project* do GitHub (L03) |
| projeto declarado | declared project | `spo_projects` (L03) |
| execução (da coleta) / rodada (de perfis) | run / round | `syncs`, `profile_runs` (L03) |
| ferramenta (conectada) | (connected) tool | `connected_tools` (L03) |
| cota / balde | quota / bucket | `Ingestion.Cota` (L03) |
| etapa (da coleta) | stage | `sync_github_eo.ex` (L03) |
| payload cru / coluna crua | raw payload / raw column | `raw_payloads`; `:binary_id` sem FK (L03) |
| índice parcial | partial index | (L03) |
| censo | census | `mapa-*.md` (L03) |
| recorte (de um ERD) | slice | `banco/mapa-das-tabelas.md` (L03) |
| contexto de escrita | write context | `banco/mapa-das-tabelas.md` (L03) |
| o nulo que significa | the null that means something | (L03) |
| sucesso silencioso | silent success | (L03) |
| desfecho (`outcome`) | outcome | campo virtual (L03) |
| promoção / complementação | promotion / complementation | `:promoted` / `:completed` (L03) |
| episódio (de suspensão, de desativação) | episode | `tenant_suspensions`, `account_disablements` (L03) |
| código de definição / de cadastro / de guarda | setup / enrollment / safekeeping code | `setup_code_*`, `enrollment_code_*`, `ack_code_*` (L03) |
| travado (segundo fator) | locked | `second_factor_failures` (L03) |
| reinício (da credencial) | reset | `reiniciar_credencial/2` (L03) |
| aresta de realimentação | feedback edge | DSM (L03) |
| chamada de fronteira / alias de schema | boundary call / schema alias | DSM, marcas `F` / `S` (L03) |
| achado | finding | (L03) |
| organização (tenant) | tenant, quando o texto fala da plataforma | AGENTS §7.4 |
| pessoa mantenedora | maintainer | — |
| lições aprendidas | lessons learned | — |
| base de conhecimento | knowledge base | `priv/knowledge_base/` (L01) |
| pergunta de competência | competency question | (L01) |
| coleta | collection | (L01) |
| encerrar / retomar observação | end / resume observation | `/tools` (L01) |
| tela | screen | (L01) |
| a régua (de uma página de funcionalidade) | the yardstick | `funcionalidades/` (L01) |
| recusa (nomeada) | (named) refusal | (L01) |
| limiar | threshold | `team.dashboard.thresholds` (L01) |
| trabalho parado | stopped work | `stale_open_work` (L01) |
| equipe composta / subequipe | composite team / sub-team | 057 (L01) |
| papel (organizacional) | (organizational) role | `eo.organizational_role` (L01) |
| conta | account | `users` (L01) |
| operador da plataforma | platform operator | 070 (L01) |
| credencial | credential | (L01) |
| derivador | deriver | `scripts/derive_information_model.py` (L01) |
| relator | relator | UFO (L01) |
| perdurante / endurante | perdurant / endurant | UFO (L01) |
| sortalidade / rigidez | sortality / rigidity | UFO (L01) |
| aceitação | acceptance | (L01) |
| ponta (do ramo, no merge) | tip | (L01) |
| vínculo observado | observed team membership | ADR 0008 (L02) |
| evidência de vínculo | team membership evidence | `github.team_membership_evidence` (L02) |
| declarar papel / papel não declarado | declare role / role not declared | rótulo da tela (L02) |
| saída declarada, equívoco | declared departure, mistake | 055/060 (L02) |
| concessão | grant | `eo.role_*_grant` (L02) |
| elo (conta ↔ pessoa) | link | AGENTS, tela de contas (L02) |
| veredito (de acesso) | verdict | `Tenants.Access` (L02) |
| alcance | reach | `Tenants.Access` (L02) |
| desligamento (de alguém) | offboarding | ADR 0009 (L02) |
| coleta, etapa | collection, stage | ingestão (L02) |
| verificações (execuções de CI) | checks | ADR 0006/0007 (L02) |
| cota, balde, gestor de cotas | quota, bucket, quota manager | ADR 0007 (L02) |
| hibernar sem dormir | hibernate without sleeping | ADR 0006 (L02) |
| em voo | in flight | ADR 0007 (L02) |
| camada fundacional / core / de domínio | foundational / core / domain layer | ADR 0004 (L02) |
| kind, subkind, role, phase, relator, qua-entity | iguais | OntoUML: não se traduzem (L02) |
| Proposta, Aceita, Emenda (ADR) | Proposed, Accepted, Amendment | (L02) |
| tese | thesis | (L02) |

Regras que acompanham o glossário:

- **identificador nunca se traduz**: `eo.team_membership`, `disable_user/4`, `users.role`, nome de
  tabela, de arquivo e de rota ficam como estão;
- **rótulo da tela** já está em inglês e fica igual (`Make administrator…`);
- **citação de lição, de decisão e da pessoa mantenedora**: traduzir, e manter o original em português
  numa nota quando a frase for a decisão em si;
- **número e data** ficam como na origem; a data continua `AAAA-MM-DD`.

## Os lotes

Contagem de 2026-10-03 em `development`, mais as quatro páginas de funcionalidade desta base. Não se
traduz o que não é publicado: `site-developers/prototipo/` e o que [seguranca.md](seguranca.md) tirou do site.

| lote | seção | páginas | o que entra |
|---|---|---:|---|
| **L01** | entrada e arquitetura | 20 | `README.md`, `design-system.md`, `deployment.md`, `architecture/` (2), `api/` (2), `funcionalidades/` (6; a 073 e a 074 entram com o merge dos PRs), `processes/` (1), `research/` (1), `rfc/` (2), `metrics/` (1, gerada: só conferir), `integrations/` (2, uma gerada) |
| **L02** | ontologias e decisões | 27 | `ontology/` (16, geradas: a tarefa é o gerador EN), `adr/` (11) |
| **L03** | modelos | 30 | `modelos/` inteiro: classes, banco, estados, DSM, arquitetura |
| **L04** | operação e releases | 24 | `producao/` (9: sem `prototipo-fila-parada/seguranca.md`, excluído por E1), `releases/` (15) |
| **L05** | backlog, parte 1 | 25 | `backlog/`, os 25 primeiros em ordem alfabética. `seguranca/` sai do site (E1) e não se traduz |
| **L06** | backlog, parte 2 | 20 | o resto de `backlog/` |
| **L07** | sprints, parte 1 | 25 | `sprints/RETOMAR.md`, `licoes-aprendidas.md`, e os sprints 001 a 012 |
| **L08** | sprints, parte 2 | 25 | sprints 013 a 027 |
| **L09** | sprints, parte 3 | 25 | sprints 028 a 037 e os que chegarem até lá |

**Total**: 221 páginas, nove lotes, mais a 073 e a 074 quando entrarem. O L01 vem primeiro porque é a porta de quem chega pela landing em
inglês. `licoes-aprendidas.md` é grande (centenas de âncoras): se passar de um dia de trabalho, vira
lote próprio.

## Como um lote é feito, e como se prova

1. Uma issue por lote, `075/L0N: …`, filha da #1267, com a lista exata de arquivos.
2. Cada arquivo traduzido entra como `.en.md`, e o `nav_translations` ganha os títulos da seção.
3. **Prova**: `mkdocs build --strict` sai 0; a contagem do log cai exatamente o número de páginas do
   lote; a varredura de links sai 0 nos dois idiomas. O comentário na issue traz os três comandos e os
   códigos de saída.
4. Revisão por quem não traduziu, conferindo o glossário.
