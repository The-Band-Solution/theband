# Contrato — a origem e o limite por origem (spec 077)

Escrito **antes** do código (constituição, princípio VI). Quando a implementação mostrar que algo
aqui estava errado, este arquivo muda no mesmo commit, com a razão.

## §1 `TheBand.Origem` — quem tenta, normalizado

Depende de: nenhuma ontologia. Domínio puro: não conhece `Plug.Conn`.

```elixir
@type estado :: :socket | :proxy | :nao_declarada
@type t :: %TheBand.Origem{chave: String.t(), estado: estado(), prefixo: String.t()}

@spec de_endereco(term(), estado()) :: t()
@spec normalizar(term()) :: :inet.ip_address() | :sem_endereco
@spec analisar_estrito(String.t()) :: {:ok, :inet.ip_address()} | :error
@spec pertence?(term(), cidr()) :: boolean()
@spec analisar_cidr(String.t()) :: {:ok, cidr()} | :error
```

*Emendado na implementação (T003)*: `analisar_cidr/1` entrou no contrato porque a configuração
(§2) precisa ler os blocos com a mesma análise estrita dos endereços, e uma segunda análise de
endereço em outro módulo seria a cópia que diverge. `pertence?/2` aceita `term()` porque normaliza
os dois lados antes de comparar.

- `de_endereco/2` recebe o que o socket (ou o cabeçalho) deu e o estado da configuração.
  **Normaliza antes de tudo** (L2): IPv4 mapeado em IPv6 (`::ffff:0:0/96`) vira o IPv4; o que não é
  tupla de endereço (`{:local, _}`, `:unspec`, `nil`) vira a origem fixa `"sem-endereco"`.
- `chave`: IPv4 inteiro (`"203.0.113.7"`); IPv6 pelo `/64` (`"2001:db8:1:2::/64"`). É o que conta.
- `prefixo`: IPv4 `/24`, IPv6 `/48` — a **única** forma do endereço que pode ir para o log (L10).
  `"sem-endereco"` para a origem fixa.
- `analisar_estrito/1`: apara espaço, usa `:inet.parse_strict_address/1`; zona (`%`), porta,
  colchetes e formas curtas (`127.1`) são `:error` (L12).
- `pertence?/2` compara já normalizado: o endereço mapeado casa a lista IPv4.

**O que não expõe**: o endereço inteiro como campo. Quem tem a struct não tem como logar o IPv6
inteiro nem o IPv4 de outro jeito que não pela `chave`, e a `chave` não vai para log nem
telemetria (a guarda de Q22 confere).

## §2 `TheBand.Origem.Configuracao` — os três estados

```elixir
@type t ::
        %{estado: :socket}
        | %{estado: :nao_declarada}
        | %{estado: :proxy, cabecalho: String.t(), proxies: [cidr()]}

@spec ler!(%{optional(String.t()) => String.t()}) :: t()
@spec frase(t()) :: String.t()
```

- `ler!/1` recebe `System.get_env()` em `config/runtime.exs` (produção):
  - `THE_BAND_ORIGEM` ausente → `%{estado: :nao_declarada}` (L1: conta e registra, **não recusa**);
  - `"socket"` → `%{estado: :socket}`;
  - `"proxy"` → exige `THE_BAND_ORIGEM_CABECALHO` (nome de cabeçalho, minúsculo, `[a-z0-9-]+`) e
    `THE_BAND_ORIGEM_PROXIES` (CIDRs separados por vírgula, todos de rede local: `10/8`,
    `172.16/12`, `192.168/16`, `100.64/10`, `127/8`, `::1/128`, `fc00::/7`);
  - qualquer outro valor, lista vazia, CIDR malformado, `/0` ou faixa não local → **levanta**
    `ArgumentError` com a mensagem que nomeia a **variável** e o motivo, nunca o valor (L3). A
    aplicação não sobe.
- Desenvolvimento e teste declaram `%{estado: :socket}` em `config/dev.exs` e `config/test.exs`.
- `frase/1` é a linha do log de subida (FR-009): o estado, e em `proxy` o cabeçalho e a lista.

**O que não expõe**: nenhum caminho que ligue a confiança no cabeçalho sem as duas variáveis.

## §3 `TheBandWeb.Origem.de/1` — a origem da requisição

```elixir
@spec de(Plug.Conn.t()) :: TheBand.Origem.t()
```

- Lê `Application.get_env(:the_band, :origem)`; ausente vale `:nao_declarada`.
- `:socket` e `:nao_declarada`: `conn.remote_ip`.
- `:proxy`: só se o socket normalizado pertence à lista; então junta **todas** as linhas do
  cabeçalho configurado, na ordem, separa por vírgula, e percorre da direita para a esquerda: a
  origem é o primeiro valor que **não** pertence à lista (L4). Valor que não passa em
  `analisar_estrito/1`, ou cabeçalho vazio, faz valer o socket (FR-006). Fora da lista, o socket.
- Nenhum outro cabeçalho é lido (`Forwarded`, `X-Real-IP`, `CF-Connecting-IP`).

## §4 `TheBand.LimitePorOrigem` — o contador

Processo supervisionado, **dono** da tabela ETS (L11). Sobe depois de `TheBand.Ontology.KnowledgeBase`
e antes de `TheBandWeb.Endpoint`.

```elixir
@type balde :: :contas | :operador
@opaque ficha
@type decisao ::
        {:segue, ficha()}
        | {:observado, :transicao | :dentro | :abaixo, ficha()}
        | {:recusa, :transicao | :dentro}

@spec conferir(balde(), TheBand.Origem.t()) :: decisao()
@spec conferir(balde(), TheBand.Origem.t(), integer()) :: decisao()
@spec devolver(ficha()) :: :ok
@doc false
@spec varrer(integer()) :: non_neg_integer()
```

- `conferir/2,3` **incrementa antes**, sempre, e lê a soma da janela **depois** do incremento (L8).
  A chave é `{balde, origem.chave, fatia}`. Soma acima do limite:
  - estado `:socket` ou `:proxy` → `{:recusa, :transicao}` na primeira vez que a soma passa do
    limite na janela, `{:recusa, :dentro}` nas seguintes;
  - estado `:nao_declarada` → `{:observado, :transicao | :dentro, ficha}`: quem chama **segue**.
    Abaixo do limite em `:nao_declarada`, `{:observado, :abaixo, ficha}`.
  Abaixo do limite nos outros estados → `{:segue, ficha}`.
- Na **transição**, e só nela, uma linha de log `warning`: o balde, o estado, o prefixo e a soma.
  Nunca a `chave`, nunca em `Logger.metadata` (L10). A decisão volta no retorno (L69).
- `devolver/1` subtrai **um** da fatia da ficha, com piso zero, e **não cria** a chave se a
  varredura já a apagou. Só quem teve sucesso chama.
- `varrer/1` apaga, de **todas** as chaves, as fatias fora da janela, e devolve quantas apagou. O
  processo a chama a cada largura de fatia; o teste a chama com o relógio que quiser (Q21). Acima
  do teto de tamanho da regra, registra.
- Tabela ausente (o processo dono reiniciando) levanta: **nunca** vira "permitido" em silêncio
  (L11). Ao renascer vazia, o processo registra.
- Os números vêm de `access.origin_limit` na base de conhecimento, a cada chamada.

**O que não expõe**: a soma, o limite e quanto falta. Nenhum chamador tem o que pôr num
`retry-after` (L9).

## §5 As cinco portas

### `TheBand.Tenants.authenticate/3` (balde `:contas`)

```elixir
@spec authenticate(String.t(), String.t(), keyword()) ::
        {:ok, User.t()} | {:error, :invalid_credentials} | {:error, {:throttled, pos_integer()}}
```

- `opts[:origem]` é **obrigatória** (`Keyword.fetch!/2`): uma chamada sem origem é bug, e quebra.
  Não há segunda porta sem limite.
- `conferir(:contas, origem)` é a **primeira** coisa, antes de `resolver/1` (L5, L7).
- `{:recusa, _}` → `{:error, :invalid_credentials}`, **sem** consulta, **sem** hash, **sem**
  `registrar_falha/1`, **sem** a linha de log por recusa; emite o passo `entrar_com_senha` /
  `falhou` / `limite_por_origem`, sem conta e sem organização (FR-010).
- `{:segue, f}` e `{:observado, _, f}` → a decisão de sempre; em `{:ok, _}`, `devolver(f)`.
- Cada custo de hash da entrada (`no_user_verify/0` e `verify_pass/2`) emite
  `[:the_band, :tenants, :custo_do_hash]` com o motivo, como a porta do operador já fazia: é o que
  permite ao teste contar **zero** hashes na recusa por limite (Q5), sem cronômetro.

### `TheBand.Platform.Credentials` (balde `:operador`)

```elixir
@spec autenticar(String.t(), Segredo.t(), Segredo.t(), TheBand.Origem.t()) :: ...
@spec definir_senha(String.t(), Segredo.t(), Segredo.t(), TheBand.Origem.t()) :: ...
@spec confirmar_segundo_fator(String.t(), Segredo.t(), Segredo.t(), TheBand.Origem.t()) :: ...
@spec concluir_cadastro(String.t(), Segredo.t(), TheBand.Origem.t()) :: ...
```

Os retornos são os de antes. A origem é o último argumento. `conferir(:operador, origem)` antes de
`operador_por_email/1`; a recusa é `{:error, :invalid_credentials}`, sem consulta, sem
`custo_do_hash`, sem evento de acesso por requisição; o sucesso devolve a ficha.

### Os controllers

`SessionController.create/2`, `Plataforma.EntradaController.create/2` e os três `POST` de
`Plataforma.CadastroController` passam `TheBandWeb.Origem.de(conn)`. As pré-conferências do
cadastro (confirmação diferente, caixa desmarcada) continuam **antes** do contexto e não contam
(L7). As respostas não mudam em nada: a recusa por limite sai pelo ramo `{:error, _}` que já
existia em cada um.

## §6 A taxonomia da 074

`priv/knowledge_base/rules/journey_entrar_e_sair.yaml`, passo `entrar_com_senha`, ganha o motivo
`limite_por_origem` (`origin: "077 FR-010"`, `action: "campanha de uma origem; ver o log da transição"`).
