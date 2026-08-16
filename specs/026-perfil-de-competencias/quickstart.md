# Quickstart — perfil de competências

## Pré-requisitos

```bash
set -a && . ./.env && set +a     # API_KEY vem daqui; nunca do chat, nunca do repositório
mix ecto.migrate
```

## O caminho feliz

1. Abrir `/people` e escolher alguém com material — `AndreCoelhoS` tem 97 concluídas.
2. Entrar na aba **Profile & growth** e pedir a geração.
3. A tela deve dizer, imediatamente, que a geração foi pedida — e **não** ficar em branco.
4. Quando o job terminar, o perfil aparece **hachurado**, com o modelo, a data e o recorte
   acima do texto.

**O que conferir na tela:**

- a linha de habilidades tem de três a cinco itens, nenhum deles "backend" ou "DevOps";
- o resumo não contém `#` algum;
- nenhum pronome de gênero em lugar nenhum;
- os números — 97 concluídas, 5 abertas — aparecem **sólidos**, visualmente distintos do texto.

## A recusa

Abrir a aba de `costabeber`: 100 concluídas, 41 com corpo, mediana zero caracteres.

Não deve haver perfil, nem botão de gerar habilitado. A mensagem deve trazer os números e
atribuir a falta ao **registro** — quem lê não pode sair achando que a pessoa produziu pouco.

## A falha

Com `API_KEY` inválida no ambiente, pedir geração. Conferir que:

- a tela nomeia a falha, e não mostra tela vazia;
- se havia perfil anterior, ele continua visível, com aviso de que a regeração falhou;
- **a chave não aparece no log** — `grep` na saída pelo prefixo da chave não pode achar nada.

## Sem sair da máquina

```bash
mix test test/the_band/profiles/          # material, baseline, veredito, sanitizador
mix test test/the_band_web/live/perfil_test.exs
mix gates                                 # nunca com | tail — o veredito é o código de saída
```

O teste do sanitizador usa **o texto real** que o modelo devolveu na validação de 2026-08-15,
com as 17 citações num parágrafo e o `( no resumo do período 3)` que sobrou da primeira versão
da limpeza.
