# Modelo de dados — feature 062

**Nenhuma tabela nova. Nenhuma migração.** O que esta feature modela é a **forma da
resposta**, e ela vive em memória, montada a cada chamada.

Se houvesse tabela, haveria estado guardado — e a FR-003 proíbe: o alcance é recomputado a
cada chamada, e nada de escopo, papel ou organização sobrevive entre uma e outra.

> **Isto só é verdade com `protocol_mode: :modern_only`** (R5 da revisão independente,
> 2026-09-24). Na era legada do protocolo, a `ex_mcp` guarda **sessão**: versão negociada, ids
> de requisição e identidade, e não o token. Essa sessão ficaria sem identidade e com um teto
> global por nó. A fatia usa `:modern_only` (T007), e a frase acima vale. Se a era legada
> entrar, esta seção tem de dizer o que a sessão carrega.

---

## `TheBand.MCP.Envelope`

O objeto que **toda** resposta de medida carrega. Não é campo opcional e não é rodapé.

| Campo | Tipo | Obrigatório | De onde vem |
|---|---|---|---|
| `value` | qualquer | sim | a função do contexto |
| `composition` | mapa | sim | sobre **quem** foi calculado — na equipe composta, a equipe mais as partes |
| `window` | mapa ou `nil` | sim, e `nil` é dito | `%{days:, from:, to:}`; `nil` quando a medida é um estado agora, e não uma janela |
| `origin` | `observed` \| `derived` \| `declared` | sim | a marca da casa |
| `rule` | mapa ou `nil` | sim | `%{id:, version:}` — **só quando `origin` é `derived` e o valor vem de regra** |
| `measurement_id` | string ou `nil` | sim | o id na base de conhecimento, quando há |
| `limitations` | lista | sim | lida da base, campo obrigatório lá (`minItems: 1`) |
| `misinterpretations` | lista | sim | lida da base; `[]` quando a medida não declara nenhuma |
| `collected_at` | data-hora ou `nil` | sim | quando o dado foi observado na origem (FR-014) |

### Três regras que o envelope aplica, e a razão de cada uma

**`rule` é `nil` para medida, e preenchido para regra.** O schema de `measurement` **não tem**
`version`; o de `derivation_rule` tem. Inventar uma versão para medida seria afirmar
versionamento que a base não declara — lido em `priv/knowledge_base/schemas/`, 2026-09-21.

**`window: nil` é dito, e não omitido.** *"Quantos estão abertos agora"* não tem janela.
Omitir o campo faria o consumidor supor que há uma e ele não a recebeu.

**`misinterpretations: []` não é o mesmo que campo ausente.** `[]` diz *a base foi lida, e
esta medida não declara nenhuma*. Ausente diria *ninguém olhou*.

---

## `TheBand.MCP.Ausencia` — os três estados, e por que um zero não serve

FR-012. **O defeito que isto impede tem nome nesta casa**: nove ocorrências do mesmo padrão,
ausência de resultado lida como presença.

| Estado | O que significa | O que um `0` diria no lugar |
|---|---|---|
| `:conferido_e_nada` | a consulta rodou, e não achou | *achou zero* — o que é verdade aqui, e é o único caso em que o zero não mente |
| `:nao_conferido` | não foi possível conferir, **e diz o que falta** | *conferimos e deu zero* — falso, e indistinguível |
| `:recusado` | o veredito negou, **com a razão** | *você tem acesso, e não há nada* — falso, e pior: esconde que houve recusa |

**A forma no protocolo** distingue os três num campo próprio, e nunca pelo valor:

```json
{ "state": "not_checked", "value": null, "missing": "a coleta de comentários deste repositório ainda não rodou" }
{ "state": "refused",     "value": null, "reason": "fora_do_alcance" }
{ "state": "checked",     "value": 0 }
```

**Lista vazia por falta de permissão é o sucesso silencioso** que este repositório já
registrou nove vezes. A FR-013 é a regra; este é o formato que a cumpre.

---

## As quatro ferramentas, e o que cada uma devolve

Todas recebem **um** argumento: `team_id`. Nenhuma recebe `tenant_id` — ele vem do token
(FR-002), e aceitá-lo como parâmetro seria o achado A01-2 da avaliação de segurança da 061
com outro nome.

| Ferramenta | `value` | `window` | Origem |
|---|---|---|---|
| `team_roster` | pessoas, com `origin` por **vínculo** | `nil` — é estado agora | `observed` \| `declared` por linha |
| `team_open_work` | por pessoa, as tarefas abertas com idade | `nil` | `observed` |
| `team_review_wait` | **duas** leituras, nunca somadas | 56 dias | `derived` |
| `team_stale_work` | as paradas, com o corte em dias | `nil`, mas **carrega `stale_after_days`** | `derived` |

### `team_review_wait` devolve duas leituras, e é a razão de a feature existir

```json
{
  "reviewed": { "count": 23, "median_hours": 0.2 },
  "waiting":  { "count": 79, "median_days": 46 }
}
```

Medido na equipe `LEDS - ConectaFapes` em 2026-09-21, pela rota HTTP equivalente.

**Uma mediana só teria respondido `0.2`** — *"doze minutos"* — sobre 102 solicitações das
quais 79 esperam há mês e meio. Omitir as em curso faria a medida **melhorar quanto pior a
equipe estivesse**, porque as que ninguém revisou são justamente as que mais interessam.
Contá-las como zero afirmaria revisão instantânea.

As duas viajam com o denominador de cada uma. `median_hours: null` e `median_days: null` são
ausências ditas, nunca zero.

### `team_stale_work` carrega o corte

*Parada* não é adjetivo: é um corte em dias, e sem ele o número não diz nada. `stale_after_days`
viaja junto para que quem integra compare com o próprio critério em vez de adivinhar o nosso.

---

## O que NÃO entra em resposta alguma

| Fora | Por quê |
|---|---|
| `platform_access_level` | a tela deixou de exibi-lo por decisão registrada — era nível de acesso de administração lido como papel. Sair por MCP seria a afirmação falsa voltando por outra porta (FR-031) |
| e-mail de quem quer que seja | a API já o exclui, nas pessoas e em quem declarou vínculo. Duas portas com regras diferentes sobre o mesmo dado é a regra mais frouxa valendo |
| o token, ou parte dele além do prefixo público | FR-008. O consumidor repete o que recebe, e o que ele repete pode ser registrado e indexado do outro lado |
| qualquer credencial ou chave | FR-030 |

**A verificação é por varredura do objeto inteiro**, e não por conferência dos campos
esperados (SC-005): campo novo que vaze não estaria na lista de esperados.
