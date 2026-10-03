# Contrato — a tela da rede de revisão

FR-013 a FR-018b. **Provisório**: o protótipo em [`prototipo/`](../prototipo/) decide a forma, e
**nenhuma linha da LiveView é escrita antes de a pessoa mantenedora aprová-lo** (FR-017). Este
contrato fixa só o que não depende do desenho: a rota, quem entra, o que a tela chama e o que ela
não pode fazer. Quando o protótipo for aprovado, este arquivo é corrigido no mesmo commit que
registrar a aprovação.

## Rota e entrada

```elixir
# lib/the_band_web/router.ex, live_session :autenticado (on_mount :current_scope)
live "/organizations/:id/review-network", ReviewNetworkLive.Show, :show
```

- qualquer conta autenticada do tenant; o recorte é `ReviewNetwork.read/4`, e **não** um
  `require_*` ([research.md R15](../research.md#r15--a-tela-e-o-protótipo-antes-dela));
- área do menu `:organization`, pelo prefixo já declarado (`layouts.ex:187`);
- `?window=` em `handle_params/3`, passado **cru** a `read/4`. `{:error, :janela_invalida}` faz
  `push_patch` para a janela padrão de `ReviewNetwork.windows/0`;
- `{:error, :not_found}`: flash *"Organization not found."* e volta a `/organizations`, o mesmo
  texto para organização inexistente e de outro tenant.

## O que a tela chama, e só isto

| quando | chamada |
|---|---|
| `mount/3` conectado | `ReviewNetwork.subscribe(tenant)` |
| `handle_params/3` | `ReviewNetwork.read(tenant, current_user, id, window)` |
| `handle_info({:review_network_ready, id, _}, …)` da organização aberta | `read/4` de novo; **nunca** `assign` do que chegou |
| desenhar a escolha de janela | `ReviewNetwork.windows/0` |

O alcance **não** vira `assign` (R10, A13).

## O que a tela tem de fazer

- dizer a janela ao lado de cada número (US1, cenário 2) e o instante do cálculo;
- marcar todo número como **derivado**, com texto, por `<.evidence>` (FR-014);
- nomear toda ausência por `<.absent reason=…>`, dizendo de quem é (FR-009, FR-014);
- dizer, com alcance parcial, que há recorte e **qual é a regra**, sem número. A frase descreve
  `pessoas_alcancadas/2` como ela é: **não** repete *"whoever you lead by declared role"* de
  `verification_live/people.ex:159-160`, que a função não aplica
  ([research.md R6](../research.md#r6--o-alcance-pessoas_alcancadas2-e-não-pode_ver3));
- dizer, ao lado da lista por pessoa, que a medida não avalia pessoa (FR-018a);
- empilhar por padrão; tabela com mais de três colunas com `stacked` e `data-label` (FR-016);
- interface em inglês, com comentário dizendo que a frase nasceu no domínio (§11.1).

## O que a tela não pode fazer

- ordenar a lista por medida, ou oferecer isso (FR-018a);
- exportar, copiar como tabela, ou ter impressão dedicada (FR-018b);
- nomear quem mais revisou (R1);
- filtrar a leitura ela mesma (R3);
- usar biblioteca JS de grafo, ou `raw/1` em rótulo (R13);
- enfileirar cálculo (R6).
