# Contrato: `TheBand.Profiles.Automation`

**Feature**: 027 · **Data**: 2026-08-16

O estado da geração automática de uma organização, e os dois atos que o mudam. Nenhuma função pública deste módulo é escrita antes deste contrato — princípio VI.

---

## `enabled?/1`

```elixir
@spec enabled?(Tenant.t()) :: boolean()
```

Se a geração automática está ligada **agora**. Derivado do evento mais recente; sem evento, `false`.

Booleano é o retorno certo aqui e só aqui: a pergunta é binária e não tem motivo. Quem precisa do motivo chama `state/1`.

---

## `state/1`

```elixir
@spec state(Tenant.t()) ::
        {:enabled, %{by: User.t(), at: DateTime.t()}}
        | {:disabled, %{by: User.t(), at: DateTime.t()}}
        | :never_enabled
```

O estado **com autor e data** — `FR-019`. Três respostas, e a terceira não é redundante: *"nunca foi ligada"* e *"foi desligada em março por alguém"* pedem frases diferentes na tela, e achatá-las em `false` apagaria quem desligou.

---

## `enable/2`

```elixir
@spec enable(Tenant.t(), User.t()) ::
        {:ok, %{event: AutomationEvent.t(), run: Run.t()}}
        | {:error, :already_enabled}
        | {:error, :no_credential}
```

Liga, grava o evento com autor, e **dispara a primeira rodada imediatamente** — `FR-004a`.

- `:already_enabled` — ligar o que já está ligado não grava evento. Dois eventos `enabled` seguidos fariam a tela mostrar um ato que não mudou nada;
- `:no_credential` — sem credencial da organização não há o que ligar. `FR-011`: a rodada não pode cair na chave do processo, então ligar seria prometer uma execução que não vai acontecer.

---

## `disable/2`

```elixir
@spec disable(Tenant.t(), User.t()) ::
        {:ok, AutomationEvent.t()} | {:error, :not_enabled}
```

Desliga a partir da **próxima** rodada — `FR-018b`. Rodada em execução não é interrompida: metade das pessoas geradas é um estado que a tela não sabe nomear.

---

## `history/1`

```elixir
@spec history(Tenant.t()) :: [AutomationEvent.t()]
```

Os atos, do mais recente para o mais antigo. Existe porque `FR-019` grava os dois lados, e "quem desligou" é a pergunta que aparece quando os perfis param de aparecer.

---

## O que este módulo **não** expõe, e por quê

- **`set/3` ou `toggle/2`.** Ligar e desligar têm pré-condições diferentes — `:no_credential` só existe num dos lados. Uma função com um booleano de argumento esconderia isso, e é o antipadrão "booleano no lugar do relator" que `AGENTS.md` §7.7 nomeia;
- **estado por pessoa.** `FR-018` decidiu que não há entrada nem saída individual nesta versão. Expor a porta convidaria a implementá-la sem a decisão;
- **remoção de evento.** A tabela é somente-acréscimo. Desligar é evento novo.
