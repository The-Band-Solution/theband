# Plano de implementação: clicar leva à página

**Feature**: `specs/014-clicar-leva-a-pagina/` · **Branch**: `020-clicar-leva-a-pagina`
**Spec**: [spec.md](spec.md) · **Constituição**: v1.4.0 · **Origem**: [#281](https://github.com/The-Band-Solution/theband/issues/281)

## Summary

O nome de uma pessoa vira ligação para a página dela nas **duas** telas onde hoje é texto: o detalhe
da issue — autor e designados, **8 470** nomes — e o detalhe da equipe.

## O que este plano decide antes de tudo

| Decisão | Escolha | O que a alternativa quebraria |
|---|---|---|
| o que vira ligação | o **nome**, e só quando há `person_id` | ligar sempre produz clique que promete e não entrega |
| onde | detalhe da issue e detalhe da equipe | as outras telas já ligam — medido |
| a área clicável | o nome, nunca a linha | linha inteira sequestra a seleção de texto |
| organização | **não** vira ligação | não existe página de organização |
| consultas | **nenhuma nova** | o `person_id` já viaja nos dados carregados |

**A tela não ganha dado novo.** `@issue.author_person_id`, `a.person_id` e `member.person.id` já
estão carregados — a feature usa o que já está lá.

## Constitution Check

**I, II, IV, IX** — não se aplicam: nenhuma semântica, nenhum conceito, nenhuma fronteira nova.

**III. Proveniência** — conforme: nada é gravado.

**V. Multitenant** — conforme: a rota de destino já resolve por tenant e devolve `não encontrado`
para pessoa de outro.

**VI. Spec Kit antes do código** — conforme.

**VII. Gates e revisão** — conforme, lacuna declarada.

**VIII. Desenho que o problema justifica** — a feature é `<.link navigate={...}>` onde havia texto.
Nenhum padrão introduzido.

**X. Responsabilidade única** — conforme: cada tela continua respondendo à mesma pergunta.

## Registro das decisões de desenho (princípio VIII)

**Nenhum padrão novo.** O componente `<.link navigate>` já é usado em nove lugares.

O único registro que a feature exige é o **negativo**: a ligação é **condicional**, e a condição é a
existência da pessoa. Um `<.link>` incondicional seria mais simples de escrever e produziria 288
cliques mortos.

| Pergunta | Resposta |
|---|---|
| **Que problema resolve a condicional** | 288 aparições cuja pessoa não foi coletada |
| **Existe agora ou é previsão** | existe agora, medido em 15 logins |
| **O que fica pior** | dois caminhos no template — com e sem ligação. É o custo de não mentir |

## Fases

| Fase | O que |
|---|---|
| **F1** | o detalhe da issue: autor e designados |
| **F2** | o detalhe da equipe: os membros |
| **F3** | a prova do que **não** mudou — texto idêntico, consultas idênticas, nome sem pessoa sem ligação |

## Riscos

| Risco | Mitigação |
|---|---|
| **ligar login sem pessoa** | a condicional é sobre `person_id`; o teste monta o caso e faz `refute` |
| acrescentar consulta por linha | o teste conta consultas antes e depois |
| mudar o texto da tela | a comparação de conteúdo, como na feature 013 |
| ligação para rota inexistente | o teste segue a ligação e exige resposta |

## Complexity Tracking

Nenhuma violação. Sem migração, sem consulta nova, sem componente novo.
