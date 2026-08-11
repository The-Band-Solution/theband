# Implementation Plan: Editar e remover ferramentas conectadas

**Branch**: `feature/003-editar-remover-ferramentas` · **Date**: 2026-08-10 · **Spec**: [spec.md](spec.md)
**Input**: [spec.md](spec.md) · [research.md](research.md)

## Summary

A plataforma passa a saber desfazer o que sabe fazer. Encerrar a observação de uma
organização **marca** o que dependia dela, **destrói** a credencial, e **preserva**
tudo o mais — porque a linha da ferramenta é o que liga os payloads preservados à
organização de origem, e apagá-la destruiria em cascata a capacidade de corrigir dado
já coletado.

O núcleo técnico é uma distinção que a medição impôs: **a marcação é por vínculo, não
por pessoa.** Uma pessoa observada em três organizações tem uma linha e uma
proveniência; o que pertence a cada ferramenta é o vínculo dela com as equipes daquela
organização.

## Technical Context

**Language/Version**: Elixir 1.20.2 / OTP 29
**Primary Dependencies**: Phoenix 1.8.9 + LiveView, Ecto + PostgreSQL 17, Oban 2.23,
cloak_ecto 1.3
**Storage**: PostgreSQL 17, tabelas compartilhadas com `tenant_id` explícito
**Testing**: ExUnit, Mox na borda HTTP
**Target Platform**: monólito modular, web
**Project Type**: web — LiveView servindo a interface
**Performance Goals**: o cálculo de impacto antes da confirmação responde em tempo de
interação para as três organizações atuais; a maior tem 64 membros e 384 payloads
**Constraints**: nenhum registro observado é apagado; nenhuma coleta consulta origem
encerrada
**Scale/Scope**: 3 organizações, 72 pessoas, 12 equipes, 161 vínculos, 472 payloads

**Nada marcado como NEEDS CLARIFICATION.** As duas decisões que estavam em aberto —
destruir ou desativar a credencial, e a forma da confirmação — foram decididas pela
pessoa mantenedora antes do plano.

## Constitution Check

Os oito princípios, um a um.

| # | Princípio | Situação | Como |
|---|---|---|---|
| I | Domínio organizado pelas ontologias | **PASS, sem mudança** | Nenhum conceito novo. Verificado: `connected_tools` não aparece em `priv/knowledge_base/` — é infraestrutura da plataforma, não conceito de EO. "Observação encerrada" não é conceito ontológico e não deve ser: é estado de uma ferramenta da plataforma, não fato sobre a organização observada |
| II | Fonte externa não é domínio | **PASS** | O encerramento não escreve nada vindo da origem. Ele muda o que a plataforma decide observar, e essa decisão é da plataforma — registrada com proveniência `project_decision`, como a equipe derivada |
| III | Proveniência e idempotência (NÃO NEGOCIÁVEL) | **PASS, e é o eixo da feature** | Nenhum registro observado é apagado; a marca de não mais observado é a mesma que a ausência entre coletas já usa. Encerrar duas vezes é idempotente. Retomar reusa a linha existente pela Application Reference da ferramenta, sem duplicar |
| IV | Semântica declarada em YAML versionado | **PASS, com acréscimo obrigatório** | A base declara **uma** causa para um vínculo terminar; esta feature cria a segunda e a declara no mapeamento de evidência. Sem isso, quem lê um registro marcado não sabe se a origem mudou ou se a plataforma parou de olhar |
| V | Monólito modular multitenant | **PASS** | Toda leitura e escrita recebe o tenant explicitamente. FR-025 exige que ferramenta de outro tenant devolva não encontrado, e o teste é a violação |
| VI | Spec Kit e sprint backlog antes do código | **PASS** | Spec aprovada, checklist 16 de 16, este plano antes de qualquer código. Os contratos em `contracts/` ficam escritos antes da primeira função pública |
| VII | Quality gates e revisão independente | **PASS com lacuna herdada** | Os nove gates valem. A revisão independente continua impossível de registrar como aprovação enquanto o PR sair com o token de quem opera a ferramenta — lacuna nomeada em L15 e L16, não desta feature |
| VIII | Desenho que o problema justifica | **PASS, com um padrão introduzido** | Um só: eventos append-only para as transições de observação. As três respostas abaixo |

### Princípio VIII — as três respostas, por padrão introduzido

**Padrão: eventos append-only para as transições de observação, com o estado derivado.**

| Pergunta | Resposta |
|---|---|
| Qual problema concreto resolve? | FR-014 exige que o histórico mostre as **transições**, não o estado final. O edge case "encerrar e reconectar no mesmo dia" produz três transições, e um par de colunas guarda uma: o segundo encerramento sobrescreveria o primeiro, e o registro passaria a afirmar uma transição onde houve três |
| O problema existe agora ou é previsão? | **Existe agora, por decisão registrada.** A ADR 0004 D7 já decidiu que evento é append-only e situação é derivada, e encerrar é evento. Não estou introduzindo um padrão: estou aplicando um que o projeto já adotou, ao caso que ele cobre |
| O que fica pior? | Toda leitura de "esta ferramenta está observada?" passa a depender de derivação em vez de ler uma coluna — mais uma junção, e um erro na derivação faz a plataforma inteira discordar sobre o que observa. O risco é real e a mitigação é uma só: a derivação existe **num lugar**, e o filtro de coleta usa o mesmo caminho que a tela |

**Padrão deliberadamente não introduzido: máquina de estados.** Encerrar e retomar são
duas transições sobre dois estados. Uma máquina de estados formal resolveria um problema
que não existe, e o custo — declarar estados, transições e guardas para dois casos —
seria maior que o `case` que resolve.

**Padrão deliberadamente não introduzido: soft delete genérico.** A tentação é uma
coluna `deleted_at` em tudo. A plataforma já tem a semântica certa e mais precisa —
`no_longer_observed_at` diz *por que* o registro saiu de vigência, e "deletado" não diz
nada. Generalizar apagaria a distinção que a feature 002 pagou para construir.

### Dívida declarada, não ampliada

`connected_tools.status` materializa uma situação — `active` / `needs_attention` —, o
que a D7 desaconselha. É dívida da feature 001. **Esta feature não a aumenta**: o estado
de observação não vira coluna. Unificar as duas coisas é trabalho próprio, e fazê-lo
aqui misturaria a correção de um defeito antigo com a entrega de uma feature.

## Project Structure

### Documentation (this feature)

```text
specs/003-editar-remover-ferramentas/
├── spec.md
├── research.md              R1 a R6
├── plan.md                  este arquivo
├── data-model.md
├── quickstart.md            V1 a V10
├── checklists/requirements.md
└── contracts/
    ├── observation-lifecycle.md    encerrar, retomar, e o que cada um marca
    ├── credential-management.md    renomear, remover, destruir
    └── screens.md                  impacto antes de confirmar, e a ausência explicada
```

### Source Code

```text
lib/the_band/
├── sources.ex                          + encerrar, retomar, renomear, remover
├── sources/
│   ├── connected_tool.ex               inalterado na identidade
│   ├── tool_credential.ex              inalterado
│   └── observation_event.ex            NOVO — append-only
├── ontology/seon/eo/
│   ├── commands.ex                     + marcar por organização encerrada
│   └── queries.ex                      + o que depende de uma ferramenta
├── jobs/sync_github_eo.ex              + perceber encerramento entre páginas
└── the_band_web/live/source_live/      + encerrar com impacto, editar credencial

priv/knowledge_base/
└── mappings/github/eo/team_membership_evidence.yaml   + a segunda causa

priv/repo/migrations/
├── ..._create_tool_observation_events.exs
└── (nenhuma migração remove coluna nesta feature)
```

## A ordem dos movimentos

```text
F1 Base de conhecimento  declarar a segunda causa
      └→ F2 Eventos       tabela append-only + estado derivado
            └→ F3 Encerrar   marcar por vínculo, destruir credencial, interromper coleta
                  ├→ F4 Retomar
                  ├→ F5 Editar credenciais
                  └→ F6 Telas
```

**F1 vem primeiro pela mesma razão da feature 002**: a semântica é declarada antes de o
código a implementar. Ali foi coluna antes de relação; aqui seria marca sem causa
declarada, e quem lesse o registro não saberia o que ele afirma.

**F2 bloqueia F3** porque o encerramento é um evento, e sem a tabela ele não tem onde
ser registrado.

## MVP

**F1, F2 e F3.** Encerrar a observação é o pedido, e as três entregam.

F4 fica de fora do MVP com um custo declarado: sem retomar, o encerramento é
irreversível na prática, e encerramento irreversível faz as pessoas não encerrarem —
deixam a ferramenta quebrada no lugar. Se o MVP for entregue sem F4, a tela precisa
dizer que a retomada ainda não existe, em vez de deixar descobrir.

## Riscos

| Risco | Mitigação |
|---|---|
| **Marcar quem continua sendo observado** | é o defeito que a primeira versão da spec tinha. O teste é a violação: encerrar `ifesserra-lab` e conferir que `Paulo` continua vigente, porque está em duas outras organizações |
| **Sobrar texto cifrado após destruir a credencial** | a verificação é uma consulta direta à tabela, não uma afirmação: nenhuma linha com aquele identificador, e nenhum valor cifrado remanescente |
| **A coleta em andamento escrever depois do encerramento** | a percepção acontece onde o checkpoint é gravado, que é o único ponto em que o estado é consistente por construção |
| **A derivação do estado discordar entre a tela e o filtro de coleta** | um caminho só, usado pelos dois. O teste confere que a coleta não inclui o que a tela mostra como encerrado |
| **Retomar ressuscitar vínculo que a origem já não tem** | é a razão de R6 existir. Só o que foi marcado por decisão da plataforma volta pela retomada; o marcado por ausência na origem espera a origem |

## Constitution Check — reavaliação depois do desenho

Refeita com os artefatos escritos, e ela achou uma lacuna.

| # | Princípio | Depois do desenho |
|---|---|---|
| I | Ontologias | mantido: nenhum conceito entra. O `data-model.md` diz explicitamente que este modelo **não** é derivado do derivador, porque `connected_tools` não é conceito de ontologia — dizê-lo evita a confusão que a feature 002 pagou para desfazer |
| II | Fonte externa não é domínio | mantido |
| III | Proveniência e idempotência | **reforçado pelo desenho**: encerrar duas vezes grava dois eventos e não é erro; a tabela de eventos não tem `updated_at`, de propósito, porque evento não se reescreve |
| IV | Semântica em YAML | mantido: a segunda causa é declarada em F1, antes do código |
| V | Multitenant | mantido: `tool_observation_events` tem `tenant_id`, e `clear_needs_attention` passa a recebê-lo — hoje ela não recebe, e função de escrita sem tenant é função cujo escopo depende de quem chama lembrar |
| VI | Spec Kit e contrato antes do código | mantido: três contratos escritos |
| VII | Quality gates | mantido, com a lacuna herdada |
| VIII | Desenho justificado | mantido: um padrão, três respostas, e dois padrões recusados com razão |

**A lacuna que a reavaliação achou**: SC-011 — nenhuma tela de edição exibe segredo em
forma utilizável — não tinha verificação no quickstart. É invariante de segurança, e
invariante de segurança se verifica pela **violação**. Virou V10, que procura o segredo
no HTML e exige não encontrar.

Ter passado é o argumento a favor de reavaliar: os dez SC pareciam cobertos porque nove
estavam, e o que faltava era justamente o de segurança.

## Complexity Tracking

| Item | Por que é aceito |
|---|---|
| Tabela de eventos para duas transições | ADR 0004 D7, e FR-014 exige as transições visíveis. Uma coluna guardaria um ciclo |
| Estado derivado em vez de coluna | mesma decisão. O custo — uma junção e um lugar só para derivar — está declarado no princípio VIII |
| A pessoa marcada só quando todos os vínculos caem | é o que a medição exige. A alternativa seria uma coluna que mente escolhendo uma ferramenta entre três |
