# Plano — Busca, ordenação e página no endereço (#292)

**Spec**: [spec.md](./spec.md) · **Branch**: `030-estado-na-url`

## Onde mexe

| Arquivo | O quê |
|---|---|
| `lib/the_band_web/estado_da_tabela.ex` | novo — lê os parâmetros e devolve o que não deu para ler |
| `live/work_item_live/index.ex` | `handle_params`, e os eventos passam a `push_patch` |
| `live/repository_live/show.ex` | idem |

## Decisões de projeto

### D1 — Um módulo para as duas telas

**Problema**: `/work` e a página do repositório ordenam pelas mesmas colunas e paginam igual.
Duas implementações divergiriam, e a divergência apareceria como link que abre diferente.
**Existe agora**: sim — as duas telas já tinham o mesmo trio de eventos, copiado.
**Piora**: uma tela com coluna própria precisa passar a lista dela. É por isso que `ler/2`
recebe `campos` em vez de guardar uma lista fixa.

### D2 — `{estado, avisos}` em vez de `{:ok, _} | {:error, _}`

**Problema**: parâmetro ruim não pode derrubar a tela nem sumir em silêncio. Um retorno de erro
obrigaria cada chamador a decidir de novo o que fazer, e a decisão certa é sempre a mesma:
mostrar o padrão e dizer.
**Existe agora**: sim — `?ordem=inexistente` chega de link velho depois de renomear coluna.
**Piora**: quem chama pode ignorar `avisos`. Contido pelo teste que abre a URL inválida e exige
a frase na tela.

### D3 — O átomo vem da lista declarada

`String.to_existing_atom` no parâmetro pareceria seguro e não é: qualquer átomo já existente
passa, e a coluna aceita passa a depender do que o resto do sistema criou. `Enum.find` sobre
`@colunas` responde exatamente "esta tela ordena por isto".

## Constitution Check

| Princípio | Como atende |
|---|---|
| VIII — o que se constrói se justifica | D1 a D3 |
| X — telas e módulos fazem uma coisa | `EstadoDaTabela` lê endereço; não consulta, não renderiza |
