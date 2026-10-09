# Data model: a jornada de entrar e sair (074)

**Nenhuma tabela nova, nenhuma migração.** O passo de jornada não é persistido pela aplicação:
nasce como evento, vira span, e mora no backend de telemetria com a retenção da ADR 0005 (E4).
O que esta feature acrescenta ao repositório é **vocabulário declarado** e **um valor na sessão
do Phoenix**.

## 1. A taxonomia — `priv/knowledge_base/rules/journey_entrar_e_sair.yaml`

`derivation_rule`, id `journey.entrar_e_sair`, versão 1 (research R7).

```yaml
derivation_rule:
  id: journey.entrar_e_sair
  version: 1
  provider: platform
  status: proposed
  confidence: high
  name: { pt-BR: "A jornada de entrar e sair — passos, desfechos e motivos de falha" }
  description: { pt-BR: > ... }
  provenance: { source_type: project_decision, year: 2026, reference: "spec 074; ADR 0005" }

  outcomes: [concluiu, falhou, abandonou]

  steps:
    - id: abrir_a_entrada
      outcomes: [concluiu, abandonou]       # abandonou é derivado na consulta (R6)
      origin: "045/US1 #7"
    - id: entrar_com_senha
      outcomes: [concluiu, falhou]
      failure_reasons:
        - { id: senha_errada,               origin: "045/US1 #3", action: "a pessoa" }
        - { id: identificador_nao_resolveu, origin: "045/US1 #4, #5", action: "investigar enumeração quando em pico" }
        - { id: conta_sem_senha,            origin: "045/US1 #8", action: "quem administra reinicia a senha" }
        - { id: conta_desativada,           origin: "achado H3, parte B", action: "conferir se o desligamento é o esperado" }
        - { id: organizacao_suspensa,       origin: "achado H3, parte A", action: "operador da plataforma" }
        - { id: em_espera,                  origin: "045 FR-016", action: "campanha, se repetido" }
    - id: sair
      outcomes: [concluiu, falhou]
      failure_reasons:
        - { id: sessao_ja_nao_existia, origin: "045/US1 #6; 064 S5", action: "nenhuma, salvo pico" }
    - id: sessao_derrubada
      outcomes: [falhou]
      # Sessions.motivo() (sessions.ex:46-47) e as duas cláusulas de CurrentScope (current_scope.ex:55-60).
      # :sem_sessao NÃO entra: é o visitante sem cookie, e CurrentScope não o registra (current_scope.ex:33).
      failure_reasons: [malformado, inexistente, resumo_errado, encerrada, vencida, epoca_velha,
                        organizacao_suspensa, conta_desativada]
    - id: definir_a_senha
      outcomes: [concluiu, falhou]
      failure_reasons: [confirmacao_diferente, recusada_pela_regra, fora_do_fluxo]
    - id: trocar_a_senha
      outcomes: [concluiu, falhou]
      failure_reasons: [senha_atual_nao_confere, recusada_pela_regra,
                        em_espera, tentativas_esgotadas]   # os dois últimos: issue #1409

  absent_on_purpose:          # o backlog listava; o código não pode produzir (spec, "O que já existe")
    - { id: entrar_pelo_github, why: "não há OAuth; spec 049 em Draft" }
    - { id: tenant_errado,      why: "identificador global; o tenant sai da conta" }
    - { id: vinculo_expirado,   why: "o fluxo é por senha temporária, sem link" }
```

`mix knowledge.validate` exige de uma `derivation_rule` só a proveniência com `source_type`
(`lib/the_band/ontology/yaml_validator.ex:476-480`); o corpo é livre. Os campos novos (`outcomes`,
`steps`, `failure_reasons`, `absent_on_purpose`) passam no validador **sem** schema novo, e é por
isso que **a forma deles é garantida pelo `taxonomia_test.exs`**, e não pelo validador — que não
os conhece.

**Invariantes** (testadas em `taxonomia_test.exs`, research R8):

- todo `failure_reason` emitido por código está declarado no passo certo;
- todo `failure_reason` declarado é produzido por pelo menos um caso de teste;
- `abandonou` nunca é emitido pela aplicação;
- os motivos de `sessao_derrubada` são **exatamente** `CurrentScope` ∪ `Sessions.motivo()`.

## 2. O correlator — `:jornada_id` na sessão do Phoenix

| campo | tipo | vida | quem escreve | quem lê |
|---|---|---|---|---|
| `:jornada_id` | string, 22 caracteres base64url (16 bytes aleatórios) | do `GET /sign-in` até o `POST /session` seguinte; **substituído** a cada `GET /sign-in` | plug da rota `GET /sign-in` | `SessionLive.New.mount/3` conectado (para `abrir_a_entrada`) e `SessionController.create/2`, que o **apaga com qualquer desfecho** |

Não é segredo (não autentica nada), mas é **identificador de visita**: por isso morre na
tentativa e nunca é reaproveitado entre jornadas.

## 3. O passo, como entidade lógica (não persistida)

| atributo do span | de onde vem | formato aceito pelo filtro | cardinalidade |
|---|---|---|---|
| `journey.name` | constante | `entrar_e_sair` | 1 |
| `journey.step` | o passo | um dos 6 declarados | 6 |
| `journey.id` | `:jornada_id` | `^[A-Za-z0-9_-]{22}$` | uma por visita — **atributo de span, nunca rótulo de métrica** |
| `outcome` | o desfecho | `concluiu` ou `falhou` | 2 |
| `failure.reason` | o motivo | um dos declarados **para aquele passo** | 17 valores distintos |
| `tenant.id` | a conta | UUID | uma por organização — atributo, nunca rótulo |
| `user.ref` | a conta | UUID (D1; HMAC só quando outra pessoa ganhar acesso ao SigNoz) | uma por conta — atributo, nunca rótulo |

As métricas derivadas (US5) usam como rótulo **só** as linhas de cardinalidade fechada
(`journey.step`, `outcome`, `failure.reason`) — backlog, decisão 3.

## 4. Estados

O passo não tem ciclo de vida: nasce terminado. O único "estado" é o da jornada **na consulta**:

```
abrir_a_entrada ──(entrar_com_senha com o mesmo journey.id em ≤ 30 min)──▶ tentou
       │
       └──(nenhum em 30 min)──▶ abandonou
```
