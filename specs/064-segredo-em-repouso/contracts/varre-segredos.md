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
