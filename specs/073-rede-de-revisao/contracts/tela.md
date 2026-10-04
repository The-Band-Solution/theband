# Contrato — a tela da rede de revisão

FR-013 a FR-018b. **O protótipo em [`prototipo/`](../prototipo/) foi aprovado pela pessoa
mantenedora em 2026-10-03** (D1–D10; Q1 sem desenho da rede nesta fatia, Q3, Q4, Q5), e a forma é a
dele, seção a seção (`prototipo/PROMPT.md` §3 é a régua do QA). Este contrato fixa o que não é
desenho: a rota, quem entra, o que a tela chama e o que ela não pode fazer.

**O que a aprovação acrescentou aqui**: a linha de coleta mais nova que a leitura (Q3,
`newer_collection`); grupos e exclusões pelo recorte (Q4, Q5); concentração ausente abaixo da amostra
mínima e no k maior que os revisores; a frase acima da lista sobre o total da pessoa contra os pares
alcançados; nenhum desenho de grafo (Q1).

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
- `{:error, :not_found}`: flash *"Not found."* e volta a `/organizations`, o mesmo texto para
  organização inexistente e de outro tenant (régua 4.6; nunca *"permission denied"*);
- `{:ausente, :not_computed}`: o aviso tracejado de 4.4, sem número nenhum.

## O que a tela chama, e só isto

| quando | chamada |
|---|---|
| `mount/3` conectado | `ReviewNetwork.subscribe(tenant)` |
| `handle_params/3` | `ReviewNetwork.read(tenant, current_user, id, window)` |
| `handle_info({:review_network_ready, id, _}, …)` da organização aberta | `read/4` de novo; **nunca** `assign` do que chegou |
| desenhar a escolha de janela | `ReviewNetwork.windows/0` |
| nome da organização e os links das organizações observadas (1.1, 1.3) | `EO.fetch_organization/2`, `EO.list_organizations/1` |
| abrir os pares de uma pessoa (tela 2) | evento `toggle` só com o `person_id`; os pares já vêm na visão recortada |

O alcance **não** vira `assign` (R10, A13).

## O que a tela tem de fazer

- dizer a janela ao lado de cada número (US1, cenário 2) e o instante do cálculo;
- marcar todo número como **derivado**, com texto (FR-014). `<.evidence>` desenha a marca de
  **conceito** (`ConceptLabel`), e aqui a marca é de bloco: a tela usa um componente local com o
  mesmo preenchimento (sólido observado, hachurado derivado, tracejado ausente, contorno para o
  alcance) e a palavra ao lado, como a régua pede;
- nomear toda ausência por `<.absent reason=…>`, dizendo de quem é (FR-009, FR-014);
- dizer, com alcance parcial, que há recorte e **qual é a regra**, sem número. A frase descreve
  `pessoas_alcancadas/2` como ela é: **não** repete *"whoever you lead by declared role"* de
  `verification_live/people.ex:159-160`, que a função não aplica
  ([research.md R6](../research.md#r6--o-alcance-pessoas_alcancadas2-e-não-pode_ver3));
- dizer, ao lado da lista por pessoa, que a medida não avalia pessoa (FR-018a);
- empilhar por padrão; a tabela de pessoas usa `stacked` e `data-label` em cada célula, mesmo com
  três colunas, porque a régua 5.2 pede cartões no telefone (FR-016);
- seguir a régua `prototipo/PROMPT.md` §3, versão 2, item a item; telas 6 e 7 **não** existem;
- interface em inglês, com comentário dizendo que a frase nasceu no domínio (§11.1).

## O que a tela não pode fazer

- ordenar a lista por medida, ou oferecer isso (FR-018a);
- exportar, copiar como tabela, ou ter impressão dedicada (FR-018b);
- nomear quem mais revisou (R1);
- filtrar a leitura ela mesma (R3);
- usar biblioteca JS de grafo, ou `raw/1` em rótulo (R13);
- enfileirar cálculo (R6).
