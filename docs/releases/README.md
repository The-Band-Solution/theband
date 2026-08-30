# Registros de release

Um arquivo por release publicada: `vX.Y.Z.md`. É o documento que a constituição
1.7.0 e o FR-016 da 050 pedem — a decisão do Product Owner sobre o que foi ao ar,
quando, e o que se observou depois.

**Quem escreve**: o papel de Product Owner, ao abrir o PR de release
`development → main`. **Quando fecha**: depois do merge (que é o deploy), com as
medidas do primeiro acesso e a evidência do que o CD fez.

A versão vive no `mix.exs` — fonte única (contrato do pipeline). O PR de release
carrega o bump; o CD lê, publica `ghcr.io/the-band-solution/theband:vX.Y.Z`, cria
a tag git e chama o webhook do Dokploy. Tag e imagem NASCEM do merge: não se
tagueia à mão.

## Modelo — `vX.Y.Z.md`

```markdown
# vX.Y.Z — <o que esta release entrega, numa frase>

**Decidida por**: <papel de Product Owner> em <data>
**PR de release**: #NNN (`development → main`) · **Merge/deploy**: <data e hora>
**Aceitação que a sustenta**: docs/sprints/NNN/aceitacao.md

## O que embarca

Só entregáveis ACEITOS (recusado não embarca — o mesmo invariante do entregável de
sprint):

| User story | Issue | Sprint | PR |
|---|---|---|---|
| <título> | #NNN | NNN | #NNN |

## O que ficou de fora, e por quê

<US recusadas ou não terminadas, com o destino. Silenciar isto faria a release
parecer o sprint inteiro.>

## O que o CD fez

| Passo | Evidência |
|---|---|
| imagem | `ghcr.io/the-band-solution/theband:vX.Y.Z` — digest <sha256> |
| tag git | `vX.Y.Z` em <commit> |
| delivery | webhook aceito às <hora>; Dokploy reimplantou em <duração> |

## As medidas do release (runbook §7)

| Critério | Alvo | Observado |
|---|---|---|
| SC-001 | entrar e ver painel em <2min | |
| SC-002 | <15min de procedimento, <2min de indisponibilidade | |
| SC-004 | zero segredos em imagem e logs | |
| SC-005 | 100% das rotas de dados recusam sem sessão (27 rotas da 045) | |

## Ensaio de restauração (FR-008)

<Data do ensaio mais recente e os três números que bateram; ou a data agendada, se
esta release não carrega dado real ainda.>

## O que se observou depois

<Primeiras horas em produção: o que funcionou, o que surpreendeu, o que virou
issue. Release sem esta seção é release que ninguém olhou.>
```

## Regras que não se negociam

- **Nada de segredo aqui** — nem trecho, nem endereço com credencial embutida.
- **Rollback registrado**: se a release voltou atrás, o arquivo diz para qual
  versão e por quê. Release revertida em silêncio apaga a única prova de que o
  problema existiu.
- **Uma release, um arquivo**: reescrever o registro de uma versão publicada é
  reescrever história — correções entram como nota datada no fim.
