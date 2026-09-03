# Decisões pendentes

O que **não pode ser implementado sem uma resposta humana**. Cada item aqui já
teve o levantamento feito: os números estão medidos, as alternativas estão
escritas, e falta só a decisão.

**Por que isto é documento e não issue aberta.** Issue aberta sem trabalho
possível polui a contagem do que está em andamento e reaparece em toda triagem
como se fosse pendência de execução. Decisão pendente é outra coisa: ela não
espera esforço, espera escolha. Movidas para cá em 2026-09-01, com as issues
encerradas apontando para este arquivo.

**Como uma volta a ser trabalho**: a decisão é tomada, e a partir dela nasce
uma spec pelo ciclo normal — `/speckit-specify`. Não se reabre a issue antiga.

---

## D1 — Qual é o quadro do projeto no Conecta Fapes

**Levantado em**: 2026-08-15 · **Issue de origem**: [#367](https://github.com/The-Band-Solution/theband/issues/367)
**Decidido em parte**: 2026-09-01 — a pergunta 1 tem resposta

### 1. Qual quadro é o quadro do projeto ✅ DECIDIDO

Há dois, e a troca não estava declarada em lugar nenhum:

| quadro | período | issues |
|---|---|---|
| `Conecta Fapes - Delivery` | jun/2025 a abr/2026 | **980 entregues** |
| `Conecta Fapes` | assume em jun/2026 | |

Lido só pelo quadro corrente, **a entrega do projeto parece começar em abril de
2026 com 4 issues** — dez meses e 980 issues somem.

**Decisão de 2026-09-01: declarar a troca, com data.** Os dois são do projeto, e
a organização declara quando um sucedeu o outro. A plataforma **não escolhe pelo
nome** e **não materializa**: resolve na leitura, como a #514 fez com o trimestre
lido como sprint. Vira feature pequena — um par (quadro, sucessor) com data de
virada, declarado por quem administra, com autor e revogação. Relator, nunca
booleano.

### 2. O que fazer com as 275 issues abertas fora do quadro ⬜ ABERTA

233 num quadro antigo, 42 sem quadro algum. **Nenhuma aparece em painel nenhum.**

### 3. Coletar a timeline do `conectafapes-project` ⬜ ABERTA

Tem **zero** eventos de status. É o que destrava homologação e cycle time — e,
por consequência, o `end_date` de que a vazão depende.

### 4. "Done" é fechar a issue ou a coluna do quadro ⬜ ABERTA

Discordam em 11% onde dá para comparar: **13 marcadas `Done` seguem abertas, 12
fechadas nunca saíram do `Backlog`**.

⚠️ **A premissa original desta pergunta venceu.** A issue dizia que a plataforma
não lê campo de quadro. **Ela lê** — a #181 entregou. Medido em 2026-08-26 sobre
3.601 itens com coluna e issue por trás: **409 marcados concluídos na coluna
seguem abertos**, 87 fechados nunca saíram de coluna de início — 496 em 2.945
comparáveis, **16,8%**, contra os 11% que a issue estimava sobre 25 itens.

A pergunta mudou de natureza: era *"a plataforma não consegue responder"*, virou
*"falta declarar qual manda, e quais colunas significam concluído"*. E a ressalva
continua: aquela medida classificou "coluna de início" **pelo nome**, que é o
erro que estas features existem para não cometer — 33 nomes de coluna em duas
línguas. É primeira medida, não resposta.

---

## D2 — Como o conector do ArgoCD entra na plataforma

**Decidido em**: 2026-08-19 — *"vamos usar o argoCD para saber o processo de deployment"*
**Issue de origem**: [#442](https://github.com/The-Band-Solution/theband/issues/442)

### Por que a fonte não pode ser o GitHub

Medido antes da decisão:

| fonte | atividades de implantação |
|---|---:|
| GitHub Deployments API | **2** |
| já no banco, derivado dos jobs de CI (feature 037) | **1.361** em 1.007 execuções |

A organização implanta chamando o Vercel dentro de um job, e o GitHub **não
registra** isso como deployment. Coletar a Deployments API traria 2 registros
onde já existem 1.361 — e a tela diria "1 implantação" onde houve centenas.

O mapeamento `github.deployment.to.cdro.deployment_activity` fica **suspenso**,
não implementado: não é lacuna de coleta, é **fonte errada**.

### O que o ArgoCD acrescenta

| conceito da CDRO | o que o ArgoCD sabe e o GitHub não |
|---|---|
| `cdro.deployment_environment` | o cluster/namespace de destino, e o estado sincronizado |
| `cdro.deployed_code` | a revisão que está **rodando agora**, não a que foi empurrada |
| `cdro.continuous_deployment_process` | a sincronização como processo, com sucesso e insucesso próprios |
| `cdro.continuous_deployment_feedback_activity` | o *drift* entre desejado e real |

O último é o que nenhuma outra fonte dá: implantação que o GitHub considera
bem-sucedida pode estar **fora de sincronia** no cluster.

### As quatro escolhas que faltam ⬜ TODAS ABERTAS

1. **Qual API do ArgoCD** — a REST do servidor, ou ler os CRDs `Application`
   direto do Kubernetes. A segunda não exige credencial do ArgoCD, mas exige
   acesso ao cluster.
2. **Como a ferramenta entra no modelo de fontes.** Hoje `connected_tools` tem
   `tool_type: "github"`. ArgoCD é o segundo tipo, e a primeira vez que a
   plataforma coleta de algo que **não é forja de código**.
3. **Onde o ambiente do ArgoCD encontra o repositório observado.** O `Application`
   aponta para um repositório git — é por ali que o rastro fecha até
   `cmpo.source_repository`.
4. **Se o `drift` vira conceito novo.** A CDRO não tem "estado divergente"; tem
   processo de feedback. Pode caber, ou pode exigir extensão da ontologia.

---

## D3 — Instalar ou não a skill de humanização

**Pedido em**: 2026-09-01 · **Issue de origem**: [#680](https://github.com/The-Band-Solution/theband/issues/680)

O pedido era passar os textos do site e do sistema por
<https://github.com/blader/humanizer>.

**O que já foi feito sem ela**: o site em `theband.dev` foi revisado em
2026-09-01 (PR #683) — ganhou a porta para a plataforma, perdeu o *"Começar pelo
README"*, e teve o número de quality gates corrigido. A copy do corpo **não foi
tocada**, porque ela já é a voz humanizada: a mesma da tela de entrada, reescrita
no PR #637 pela metáfora da tese.

**A decisão que falta**: instalar a skill de terceiro. Skill é **código que passa
a rodar na sessão**, e o critério desta casa já foi exercido — em 2026-08-27
quatro skills de deploy foram recusadas por autoria desconhecida e baixa
instalação. Se a decisão for instalar, que seja registrada com a razão, e não por
omissão.

### As três coisas que valem para qualquer revisão de texto aqui, com ou sem skill

1. **As frases do sistema vivem no catálogo**, não nas telas — a 047 tirou-as de
   lá, e `mix mensagens.verificar` reprova quem devolver frase para literal no
   HEEx. Humanizar o sistema é editar msgid e tradução;
2. **Termo normativo não se suaviza.** `sro.user_story`, proveniência, entregável
   aceito e tenant vêm da rede de ontologias e mudam de sentido se forem
   "melhorados". A lista do que **não** se traduz é escrita antes de começar;
3. **O site e o sistema falam a mesma língua.** O que a porta pública promete é o
   que a tela entrega.
