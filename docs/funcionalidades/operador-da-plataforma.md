<div class="tb-assinatura">Funcionalidades · a área do operador da plataforma</div>

# Suspender e reativar uma organização

<dl class="tb-recibo">
<dt>a tela</dt><dd><code>Organisations</code>, na área do operador da plataforma, e a página de cada organização</dd>
<dt>a spec</dt><dd><span class="tb-marca tb-declarado"><span class="tb-q"></span>070 · Draft · 2026-10-01</span> <a href="https://github.com/The-Band-Solution/theband/tree/development/specs/070-operador-da-plataforma">specs/070-operador-da-plataforma, no GitHub</a></dd>
<dt>em produção</dt><dd><span class="tb-marca tb-ausente"><span class="tb-q"></span>ainda não</span> em development; entra na próxima release</dd>
<dt>a régua</dt><dd>só o que a tela faz em development; o que a spec pede e a tela não faz fica nomeado no fim</dd>
</dl>

O operador da plataforma é um papel acima das organizações: ele não pertence a nenhuma, e é quem
suspende uma organização e a reativa depois. Suspender corta o acesso de todos de uma vez — cada
pessoa é desconectada, em todo dispositivo, e todo token de API da organização é revogado — e
reativar **não devolve** nada disso: cada pessoa entra de novo, e cada token é emitido de novo.
Cada suspensão fica registrada, com quem, quando e por quê.

## O que você passa a conseguir fazer

Esta página é para quem opera a plataforma. Quem usa uma organização não vê esta área.

- **Ver as organizações e o estado de cada uma**: a tela `Organisations` lista `organisation`,
  `slug`, `state` e `last suspended`. Organização que nunca foi suspensa diz `never suspended`,
  em vez de uma célula vazia. A tela diz também o que você **não** vê: as pessoas, as equipes, o
  trabalho e os números de cada organização. Operar a plataforma não abre organização nenhuma.
- **Ver o histórico de uma organização**: na página dela, `Suspension history` mostra cada
  suspensão em duas metades, `suspended` e `reactivated`, com quem, quando, a razão e a nota. A
  suspensão ainda aberta diz `not reactivated — still suspended`.
- **Suspender**: o formulário `Suspend` + nome da organização pede uma razão da lista (`Reason —
  required`), aceita uma nota (`Note`), lista o que vai acontecer (`What suspending does, at once
  and in one step`) e pede que você digite o slug da organização para confirmar. O botão diz o
  que faz: `Suspend, sign everyone out, revoke all tokens`. Os dados da organização ficam como
  estão; nada é apagado.
- **Reativar**: numa organização suspensa, a página mostra só o formulário `Reactivate` + nome
  — o ato que cabe ao estado, e nunca os dois. Ele também pede razão, nota opcional e o slug, e
  diz o que reativar faz e o que não faz (`What reactivating does, and what it does not`): as
  pessoas podem entrar de novo, cada uma do começo; nenhuma sessão e nenhum token voltam; a
  coleta retoma no intervalo normal, sem começar uma na hora.

As razões de suspensão são `Suspected compromise`, `The contract ended`, `Requested by the
organisation` e `Other`; as de reativação são `Investigation closed — no compromise found`, `The
contract resumed`, `Suspended by mistake` e `Other`. Algumas razões oferecidas na reativação só
aparecem quando respondem à razão da suspensão aberta, e a tela diz isso ao lado delas.

Depois do ato, a página confirma: `Suspended. Every session was ended and every API token
revoked.` ou `Reactivated. No session or token came back.`

## O que a tela recusa, e diz por quê

| situação | o que a tela diz |
|---|---|
| o slug digitado não confere | `Not suspended. The confirmation did not match.` (ou `Not reactivated.`) — `Type` + slug + `exactly. Nothing changed.` |
| nenhuma razão escolhida | `Choose a reason from the list.` — `Nothing changed.` |
| razão que exige nota, sem nota (`Suspected compromise` e `Other`, na suspensão) | `A note is required for this reason` — e diz o que escrever: `Write what was seen and why it calls for suspension.` |
| suspender uma organização que já está suspensa | `Not suspended.` + nome + `is already suspended`, com desde quando e por quem; `The page now shows the reactivate form.` |
| reativar uma organização que não está suspensa | `Not reactivated.` + nome + `is not suspended.` — `The page now shows the suspend form.` |
| quem não é operador tenta esta área | "not found", e nunca "sem permissão" |

## O que ela não faz

- Não mostra nem abre dado de domínio de nenhuma organização: nem pessoas, nem equipes, nem
  issues, nem medidas — nem "só para suporte".
- Não suspende todas as organizações de uma vez: é um ato por organização, cada um com a sua
  razão.
- Não concede nem revoga o papel de operador: nenhuma tela faz isso, e quem entra por uma
  organização não consegue se tornar operador.
- Não cria, não apaga e não renomeia organização.
- Não promove nem rebaixa administrador dentro de uma organização: isso é a
  [tela de contas](administradores.md), de quem administra a própria organização.
- Uma suspensão feita antes de este registro existir aparece no histórico sem autor nem razão, e a
  tela diz isso (`The reason was not recorded`), em vez de inventar quem foi.
