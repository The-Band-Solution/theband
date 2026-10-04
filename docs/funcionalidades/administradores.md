<div class="tb-assinatura">Funcionalidades · a tela de contas</div>

# Promover e rebaixar administradores

<dl class="tb-recibo">
<dt>a tela</dt><dd><code>/accounts</code>, coluna <code>Management</code></dd>
<dt>a spec</dt><dd><span class="tb-marca tb-declarado"><span class="tb-q"></span>072 · Draft · 2026-10-02</span> <a href="https://github.com/The-Band-Solution/theband/tree/development/specs/072-papel-de-administrador">specs/072-papel-de-administrador, no GitHub</a></dd>
<dt>em produção</dt><dd><span class="tb-marca tb-ausente"><span class="tb-q"></span>ainda não</span> em development; entra na próxima release</dd>
<dt>a régua</dt><dd>só o que a tela faz em development; o que a spec pede e a tela não faz fica nomeado no fim</dd>
</dl>

Quem administra uma organização dá a marca de administrador a outra conta ativa, e a tira de
quem não deve mais tê-la. Assim a organização não depende de uma pessoa só para conectar
ferramentas, gerenciar credenciais e administrar contas. O bloco `Who administers this
organisation`, no alto da tela, diz o que um administrador faz e a regra que vale sempre: a
organização mantém pelo menos um administrador ativo.

## O que você passa a conseguir fazer

- **Promover** uma conta ativa: `Make administrator…` na coluna `Management`. A confirmação
  nomeia a pessoa e aceita uma nota opcional, no campo `Note`.
- **Rebaixar** um administrador: `Remove admin role…`. A pessoa continua entrando, como membro.
- **Deixar o seu próprio papel**: na sua linha o botão é `Step down…`, e a confirmação pede que
  você digite o seu e-mail em `Type your e-mail to confirm`. Só é possível se houver outro
  administrador ativo.
- **Ver o papel de cada conta na própria linha**: desde quando é administradora e por quem foi
  promovida, ou o período em que foi, e se saiu por conta própria (`stepped down`) ou foi
  rebaixada (`removed by` …). Quem nunca teve o papel aparece como `never an administrator`; o
  único administrador ativo leva `the only active administrator`.
- **Ver quem mudou o quê**: a seção `Administrator changes`, abaixo da tabela, lista cada
  mudança com quem, quando e a nota. Um administrador cuja marca é mais antiga que o registro
  aparece como `since the organisation was created`, seguido de `no role change recorded` —
  a tela diz que não há registro, em vez de inventar uma data.

Depois de cada mudança, a tela confirma no lugar do painel, e diz quantos administradores ativos
a organização passou a ter.

## O que a tela recusa, e diz por quê

| situação | o que a tela diz |
|---|---|
| rebaixar o último administrador ativo, inclusive você | `The organisation would have no active administrator. Make someone else administrator first.` — o botão fica desabilitado; se outra pessoa agiu antes de você, a recusa diz `Not changed:` e nomeia quem agiu |
| promover uma conta desativada | `Role changes wait for reactivation.` |
| administrador com a conta desativada | `not counted while the account is disabled` — ele não conta como administrador ativo |
| deixar o próprio papel digitando outro e-mail | `Not changed. That is not the e-mail of your account. You are still an administrator.` |
| conta de outra organização | `Account not found.` — e nunca "sem permissão" |

## O que ela não faz

- Quem não é administrador não vê controle nenhum.
- Não pede razão de uma lista fechada; a nota é livre e opcional, e sem ela o registro diz
  `no note`.
- Não muda senha nem sessão de quem é rebaixado: a pessoa segue entrando, como membro.
- Não cria papéis além de administrador e membro.
