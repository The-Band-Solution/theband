# CLAUDE.md — The Band

Este arquivo existe para que o Claude Code carregue as regras da casa **em toda sessão**. Ele
lê o `CLAUDE.md` automaticamente, e não o `AGENTS.md`. Até 2026-09-25 este arquivo não existia,
e o `AGENTS.md` §18 mandava lê-lo.

As regras completas estão no `AGENTS.md`, importado abaixo. A constituição, em
`.specify/memory/constitution.md`, prevalece sobre os dois numa disputa.

## Segurança vem primeiro — sempre

Decisão da pessoa mantenedora em 2026-09-25. **Quando segurança disputa com qualquer outra
coisa, segurança ganha**. A ordem de prioridade do trabalho é:

1. **exposição ativa** (credencial vazada, dado de outro tenant alcançável, defeito de acesso em
   produção): interrompe o que estiver em curso;
2. **defeito de segurança conhecido**: vem antes de funcionalidade nova na mesma superfície;
3. só então, funcionalidade.

Na prática, em toda sessão:

- **antes de escolher o trabalho**, veja o que está aberto: `gh issue list --label security
  --state open` e o inventário mais recente em `docs/seguranca/`;
- **feature que toca autenticação, sessão, token, tenant, acesso, dado de pessoa, entrada
  externa, dependência nova ou exposição a modelo** tem avaliação do agente `security` antes do
  código, feita por quem não escreveu o desenho;
- **guarda de segurança nasce provada**: com o defeito injetado, o teste é visto reprovando;
- **exceção em gate de segurança** só entra com medição, decisão da pessoa mantenedora e guarda
  em teste;
- **nunca** peça, aceite ou escreva segredo no chat, em commit ou em log;
- **na dúvida sobre se algo é de segurança, trate como se fosse.**

O detalhe, com o lugar onde cada obrigação se verifica, está no `AGENTS.md` §14.0.

## As regras da casa

@AGENTS.md
