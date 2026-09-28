# Contrato — `mix the_band.varre_segredos`

**FR**: 008 (a varredura), 009 (provada por caso positivo), 010 (antes da primeira cópia).

---

## Forma

```
mix the_band.varre_segredos --dump CAMINHO
mix the_band.varre_segredos --banco
```

Exatamente **um** dos dois. Sem argumento, recusa e explica — varrer "o que estiver por aí" é
o tipo de padrão que acha o lugar errado.

| opção | efeito |
|---|---|
| `--dump CAMINHO` | varre um arquivo de `pg_dump` |
| `--banco` | varre as colunas de texto do banco configurado |
| `--saida CAMINHO` | grava o relatório também em arquivo, para a FR-010 |

## Saída

Relatório que diz **o que procurou**, e não só o que achou:

```
varredura de segredos — dump: /tmp/theband-2026-09-13.sql (259 824 062 bytes)

controle positivo ......... ACHOU o valor plantado  ✓
padrões procurados ........ 3
  token do GitHub ......................... 0
  chave de provedor de modelos ............ 0
  token de sessão (formato de 43 chars) ... 0

RESULTADO: limpo — 0 ocorrências em 3 padrões
```

Uma varredura que relata "limpo" **sem** a linha do controle positivo não é um relatório
válido. É o que a L104 custou para ser aprendido.

## Códigos de saída

| código | significa |
|---|---|
| `0` | limpo, **e o controle positivo achou o plantio** |
| `1` | achou pelo menos um segredo |
| `2` | **o controle positivo falhou** — a varredura não enxerga, e o resultado não vale |
| `3` | erro de uso (arquivo ausente, as duas opções, nenhuma) |

**O código 2 é o que distingue esta tarefa de um `grep`.** Sem ele, "zero ocorrências"
significaria tanto *limpo* quanto *não olhei*, e as duas sairiam com zero.

## O controle positivo

Antes de relatar, a tarefa planta um valor conhecido com a forma de cada padrão que vai
procurar e confirma que o encontra.

| modo | como planta | como desfaz |
|---|---|---|
| `--dump` | concatena o valor a uma **cópia** do arquivo | apaga a cópia |
| `--banco` | escreve numa transação | `ROLLBACK`, sempre — inclusive se a varredura falhar |

**Nada é plantado no material original.** No modo `--banco`, o `ROLLBACK` acontece em
`after`, não no caminho feliz.

## O que a tarefa NUNCA faz

- **não imprime o valor encontrado.** Relata tabela, coluna, deslocamento e **tamanho**. Quem
  investiga vai ao lugar; a saída não vira mais uma cópia do segredo;
- **não apaga nem redige nada.** Encontrar e corrigir são atos diferentes, e o segundo exige
  decisão de quem opera — inclusive a rotação, que nenhum código faz;
- **não conclui que o sistema está seguro.** Ela diz o que procurou, onde, e o que achou.

## Os padrões

Vivem **em um lugar só**, declarados com o tipo a que pertencem (FR-014). Padrão espalhado por
scripts diverge, e a divergência aparece como "zero" no script que ficou para trás.

Acrescentar um tipo de segredo ao sistema **exige** acrescentar seu padrão aqui — é o que a
FR-014 quer dizer com *declarar o tipo antes de existir coluna para ele*.

### Onde cada padrão é procurado — emenda de 2026-09-28, medida

Cada padrão declara **onde** ele vale:

| padrão | onde | por quê |
|---|---|---|
| token do GitHub (`gh[pousr]_…`, `github_pat_…`) | **em qualquer lugar** | o prefixo é o que o distingue: fora dele não há falso positivo |
| chave de provedor de modelos (`sk-…`, `sk-proj-…`) | **em qualquer lugar** | idem |
| token de sessão (43 caracteres base64url) | **só em `users.session_token`** | não tem prefixo |

**A medição que obrigou a emenda.** Em 2026-09-28, no dump de desenvolvimento (327 MB), a regex
genérica de 43 caracteres base64url casou **5 928** vezes, e só **2** eram token de sessão. As
outras 5 926 eram `verification_components.phase`, `collected_verifications.phase`, caminhos
de arquivo, payloads do GitHub e títulos. Uma varredura que sai sempre "achou" é uma varredura
que ninguém lê: é o padrão largo que inventa. Os dois padrões com prefixo casaram **0** vezes no
mesmo dump.

**O custo, declarado.** Um token de sessão copiado para **outro** lugar (um log, um payload) não
é achado pela forma. Quem fecha esse caminho é a US3 (o segredo não chega a registro), e não a
varredura.

**No modo `--dump`**, "a coluna" vem do cabeçalho de cada bloco `COPY tabela (colunas) FROM
stdin;`, e o valor é casado só no campo daquela coluna.

**Enquanto a US2 não estiver pronta, a varredura sai com `1`**, porque `users.session_token` está
em texto claro por desenho. É o resultado certo, e o relatório diz qual coluna é.
