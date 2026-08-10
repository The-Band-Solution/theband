# Quickstart — editar e remover ferramentas conectadas

**Feature**: 003 · **Spec**: [spec.md](spec.md)

Dez verificações. Cada uma diz o que executar e **o número que precisa aparecer** — não
"funciona", mas o valor conferível.

Os números partem do estado atual do banco de desenvolvimento:

```text
3 organizações · 72 pessoas · 12 equipes (10 observadas, 2 derivadas)
161 vínculos · 472 payloads preservados

ifesserra-lab      5 membros, 4 exclusivas, 1 equipe (derivada), 24 payloads
The-Band-Solution  6 membros, 4 exclusivas, 2 equipes,          64 payloads
leds-conectafapes 64 membros, 62 exclusivas, 9 equipes,        384 payloads
```

## Pré-requisitos

```bash
mix ecto.migrate
mix test
```

`ifesserra-lab` é a organização de teste, por ser a menor e por ter equipe derivada — os
dois casos difíceis num só.

---

## V1 — Encerrar não apaga nada (SC-001)

Contar antes, encerrar, contar depois. **Os quatro números têm de ser idênticos.**

```text
antes:  72 pessoas · 12 equipes · 161 vínculos · 472 payloads
depois: 72 pessoas · 12 equipes · 161 vínculos · 472 payloads
```

É a garantia central da feature. Qualquer diferença aqui reprova a entrega inteira.

## V2 — Marca só o que não tem vigência em outra ferramenta (SC-002, SC-003)

Encerrar `ifesserra-lab` e conferir, um a um:

```text
equipes marcadas          1    a derivada
vínculos marcados         5
pessoas marcadas          4    as exclusivas
Paulo marcado?            NÃO  ← está em The-Band-Solution e leds-conectafapes
```

**A linha do Paulo é o teste que importa.** Se ele aparecer marcado, o defeito é o que a
primeira versão da spec tinha, e nenhum outro número compensa.

## V3 — A credencial deixou de existir (SC-004)

Consulta direta à tabela, não afirmação no código:

```text
credenciais daquela ferramenta antes:  1 ou mais
depois:                                0
valor cifrado remanescente:            nenhum
```

## V4 — A coleta seguinte não toca a origem encerrada (SC-005)

Rodar a coleta de todas as ferramentas com a observação de `ifesserra-lab` encerrada.

**O teste roda sem expectativa no Mox da borda HTTP** para aquela instância: qualquer
chamada à origem encerrada o derruba sozinho. É a mesma forma de garantia que o
reprocessamento da feature 001 usa.

```text
sincronizações criadas para ifesserra-lab: 0
```

## V5 — Retomar não duplica (SC-006)

Reconectar `ifesserra-lab` com credencial nova.

```text
ferramentas para (github, https://github.com, ifesserra-lab):  1   ← não 2
pessoas:                                                       72  ← inalterado
equipes:                                                       12  ← inalterado
```

## V6 — A coleta é que devolve vigência (SC-007)

Depois de retomar, rodar a coleta.

```text
registros que a origem voltou a mostrar:  vigentes
registros que a origem não mostra mais:   continuam marcados
```

A segunda linha é a que prova R6: retomar **não** ressuscita o que a origem já não tem.

## V7 — Quem perdeu uma organização mantém as outras (SC-008)

```text
Paulo, antes:  The-Band-Solution, ifesserra-lab, leds-conectafapes
Paulo, depois: The-Band-Solution, leds-conectafapes    ← 2, vigentes
               ifesserra-lab                            ← consultável como histórico
```

## V8 — O impacto mostrado é o impacto que acontece (SC-009)

Abrir a confirmação, anotar os números, confirmar, e conferir contra o que foi marcado.

```text
tela dizia:      1 equipe · 5 vínculos · 4 pessoas · 1 permanece
foi marcado:     1 equipe · 5 vínculos · 4 pessoas · 1 permaneceu
```

Divergir aqui significa duas contagens no código, e é o que o contrato proíbe ao exigir
que a tela use a mesma função do encerramento.

## V9 — Isolamento entre organizações clientes (SC-010)

Com dois tenants povoados, tentar encerrar, renomear e remover pela sessão do outro.

```text
encerrar ferramenta alheia:  não encontrado
renomear credencial alheia:  não encontrado
remover credencial alheia:   não encontrado
```

**Não encontrado, nunca "sem permissão"**: dizer que existe mas não é sua já vaza que
existe.

## V10 — O segredo não aparece em nenhuma tela de edição (SC-011)

Percorrer as telas que a feature acrescenta ou muda, com uma credencial cujo segredo é
conhecido, e procurar o texto do segredo no HTML servido:

```text
/ferramentas                       segredo ausente
formulário de renomear credencial  segredo ausente
confirmação de encerramento        segredo ausente
confirmação de remover credencial  segredo ausente
```

**O teste é a violação**, não o caminho feliz: procura o segredo e exige não encontrar.
"A tela renderiza" não prova nada aqui, e é a mesma forma de verificação que a feature
001 usa para as quatro telas dela.

Confere também que o que aparece é `last_four`, e que ele **não** basta para usar a
credencial.

---

## O que não é verificável nesta entrega, e por quê

Registrado para que ninguém confunda coberto por teste com observado em uso.

| Item | Por quê |
|---|---|
| **Encerrar durante coleta em andamento** | exige uma coleta longa o suficiente para encerrar no meio. Coberto por teste com coleta simulada; a ocorrência real depende de uma organização grande |
| **A última credencial de ferramenta observada** | verificável por teste, e a ocorrência real exigiria alguém tentar quebrar a própria coleta |
| **Retomar organização renomeada na origem** | exigiria renomear uma organização real do GitHub. Não deve ser feito para validar software |
