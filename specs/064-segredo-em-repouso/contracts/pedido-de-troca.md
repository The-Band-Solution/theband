# Contrato — o pedido de troca na tela que administra (064/T018, FR-016, FR-017, FR-019)

**Escrito em 2026-10-03, antes do código.** A tela é a do protótipo aprovado, versão 2
([`../prototipo/credential-age.html`](../prototipo/credential-age.html)); a régua é a seção 3 de
[`../prototipo/PROMPT.md`](../prototipo/PROMPT.md). Este contrato declara só o que a tela
acrescenta de **função pública**, e o que ela não acrescenta.

## O problema que pede módulo novo

As duas telas que administram credencial (`/tools` e `/ai`) mostram a mesma coisa da mesma forma:
a data, o intervalo (F.2), a marca de três estados (F.3), a data inferida (D7) e o aviso com
ícone (D3). Escrita duas vezes, a regra de formato divergiria na primeira mudança — e uma das
duas passaria a dizer `within` para o que a outra chama de `age unknown`, que é o defeito que a
FR-019 proíbe. Por isso um módulo de componentes, e só um.

## `TheBandWeb.IdadeDaCredencial`

Componentes de exibição. **Não decide** nada: o estado vem de `TheBand.Credenciais.Idade.estado/2`,
e o prazo de `Idade.limite_em_meses/0` (F.4). Texto de tela em inglês, de propósito (§11.1).

| função | assinatura | o que devolve |
|---|---|---|
| `marca/1` | componente; `estado :: Idade.estado()`, `meses`, `ativa?` (padrão `true`) | a marca: `within N months` (contorno fino), `replace · N months in use` (borda dupla, `!`), `past N months · inactive` (borda dupla, inativa), `age unknown` (tracejada, itálica). Cada estado por cláusula própria, **sem coringa** (achado 4). `data-estado` com o átomo, para o teste não depender da frase |
| `idade/1` | componente; `credencial`, `agora`, `ativa?` (padrão `true`), `sem_data` (frase da ausência) | a célula: data `AAAA-MM-DD` (F.1), intervalo no prazo (F.2), a marca, `replacement asked from <data + prazo>` no prazo (F.5), e a marca hachurada `inferred from the last check` quando a chave do modelo não tem `secret_set_at` (D7) |
| `aviso/1` | componente; `forma :: :vencida \| :desconhecida`, `titulo`, slot interno, slot `quem` | o aviso com ícone (`!` borda dupla; `?` tracejado), `role="note"`. Nenhuma ação, nenhum "dismiss" (F.7) |
| `intervalo/2` | `(DateTime.t(), DateTime.t()) :: String.t()` | `today`, `N day(s) ago` abaixo de um mês, `N month(s) ago` a partir de um mês — meses de calendário inteiros, para baixo (F.2) |
| `duracao/2` | `(DateTime.t(), DateTime.t()) :: String.t()` | o mesmo, sem o "ago": `N days` ou `N months` — o "in use for N months" da chave anterior (2.7) |
| `meses/2` | `(DateTime.t(), DateTime.t()) :: non_neg_integer()` | os meses de calendário inteiros entre as duas datas. Data no futuro dá `0` |
| `data/1` | `(DateTime.t()) :: String.t()` | `AAAA-MM-DD` |
| `marca_da_aba/2` | `([credencial], DateTime.t()) :: String.t() \| nil` | `"replace"` quando alguma credencial **ativa** da lista está `:vencida`; `nil` caso contrário (A.1). A chave do ambiente nunca entra: não tem linha |

Os cálculos (`meses/2`, `intervalo/2`, `duracao/2`) contam pela **data** (`Date`), e não pelo instante:
é a data que a tela mostra ao lado, e "registrada em 4 de setembro, há 29 dias" tem de fechar
com o calendário de quem lê.

## `TheBand.AI.fetch_sem_segredo/2` — a única função nova no domínio

```elixir
@spec fetch_sem_segredo(Tenant.t(), String.t()) ::
        {:ok, ProviderCredential.t()} | {:error, :not_found}
```

A credencial do provedor do tenant, com `secret: nil` — o `select` não traz a coluna cifrada.
Usada também por `/ai` para ler as datas de antes da gravação: a frase do flash não precisa
do segredo, e não o abre.

**O problema que resolve**: `/tools` passa a mostrar a marca da aba "AI provider" (A.1), e só
precisa das datas da chave. `AI.fetch/2` **decifra** o segredo, e com a chave mestra perdida o
`Ecto.Type` levanta ao carregar: `/tools` cairia por causa de uma chave que nem mostra — o
defeito de 2026-08-13 que `Sources.credenciais_sem_segredo/0` existe para impedir, entrando por
outra porta. Filtra por `tenant_id`, como `fetch/2`.

**O que não expõe**: o segredo, nem decifrado nem cifrado.

## O que muda em `TheBandWeb.CoreComponents.abas/1`

Cada aba aceita uma chave opcional `marca` (texto). Presente, a aba mostra a marca ao lado do
rótulo, inclusive a aba atual (Q3 b). Ausente, a aba é a de hoje.

## O que as telas decidem, e onde

| decisão | onde | de onde vem |
|---|---|---|
| a frase do flash em `/ai` — primeira, troca, ou mesma chave (2.7, 2.8) | `AILive.Index`, privada | as datas **antes** — `Idade.em_uso_desde/1` e `previous_secret_set_at` —, lidas por `AI.fetch_sem_segredo/1` no tenant corrente no mesmo evento, comparadas com as do registro que `AI.put/3` devolve. Mesma chave ⇔ as duas iguais: uma troca no mesmo segundo da gravação anterior deixa a data de início igual, e só a anterior a denuncia (achado ao testar, 2026-10-03). Sem data anterior, o flash de sempre — a tela não afirma nem troca nem mesma chave. **Nunca** de parâmetro do formulário nem de nova comparação do segredo (C.1, condição 2) |
| o pedido de `/tools` depois da troca (1.7, D5) | `SourceLive.Index`, privada | pelo estado, e não pelo clique: existindo, na mesma ferramenta, credencial ativa vencida **e** credencial ativa no prazo mais nova, o pedido é o da 1.7, nomeando a mais nova |
| a marca da aba "Connected tools" em `/ai` | `AILive.Index` | as ferramentas **do recorte** (`Operacao.filtrar_tools/3`) — quem responde por uma organização não fica sabendo, nem por marca, de credencial vencida de outra (4.2) |

## O que a tela não expõe, e por quê

- **Nenhuma parte do segredo** no pedido, no flash ou na marca (4.4). O pedido nomeia a
  credencial pelo rótulo, e a chave como "this key". Os quatro últimos ficam onde já estão.
- **Nenhum botão novo, desabilitado ou escondido pelo estado** (F.6, D4). A coleta e a geração
  não consultam nada disto.
- **Nenhum "dismiss", "snooze" ou "remind me later"** (F.7). O pedido some quando a credencial
  é trocada ou desativada.
- **Uma função nova no domínio, e só uma** (abaixo). O estado já é de `Idade`; a lista de
  credenciais já vem de `Sources.list_connected_tools/1`, sem segredo; a chave do ambiente já vem
  de `AI.origem_da_chave/1`. Uma consulta "credenciais vencidas do tenant" continua sem
  consumidor: a tela classifica o que já carregou.
- **Nenhum `vencida?/1` booleano exposto.** `marca_da_aba/2` devolve o texto da marca, ou `nil`;
  a ausência da marca é "nenhuma ativa vencida", e não "tudo no prazo" — uma credencial de idade
  desconhecida não acende a marca, e também não é contada como no prazo em lugar nenhum.

## Como se prova

`test/the_band_web/live/idade_da_credencial_test.exs` (a régua, item a item, quando o item é
verificável no HTML) e `test/the_band_web/live/mesma_chave_test.exs` (as seis condições do
parecer [`../seguranca-c1-mesma-chave.md`](../seguranca-c1-mesma-chave.md)). Cada guarda é vista
reprovando com o defeito injetado.
