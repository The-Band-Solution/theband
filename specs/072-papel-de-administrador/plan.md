# Implementation Plan: A marca de administrador

**Branch**: `feature/568-papel-de-administrador` | **Date**: 2026-10-03 | **Spec**: [spec.md](spec.md)

## Summary

Promover e rebaixar administrador, com:
- um guarda só, que trava o conjunto de admins e relê o ator e o alvo (R1);
- a conferência do ator relido em todos os atos de administração (R2);
- o registro somente-acréscimo garantido no banco (R3);
- o aviso que derruba a tela aberta (R4);
- o fim do `cast` de `:role` e o `CHECK` (R5);
- a tela do protótipo aprovado (R7).

## Technical Context

**Language/Version**: Elixir 1.20.2, OTP 29. **Dependencies**: as de hoje, nenhuma nova.
**Storage**: PostgreSQL; uma tabela, um `CHECK` e dois triggers novos.
**Testing**: ExUnit; o trigger adiado com `SET CONSTRAINTS ALL IMMEDIATE`.
**Project Type**: monólito Phoenix; a tela é `/accounts`.

## Constitution Check

| princípio | como cumpre |
|---|---|
| I, II, IX | não toca ontologia; é acesso, em `Tenants` |
| III | o registro é a proveniência do papel, somente-acréscimo |
| IV | as frases e os rótulos na base (`access.account_role`, R6) |
| V | toda leitura e escrita pelo `tenant_id`; conta de outra organização dá "não encontrada" |
| VI | spec, avaliação de segurança, protótipo aprovado, plano, tarefas e backlog, antes do código |
| VII | guardas provadas com o defeito injetado; `mix gates` |
| VIII | uma estrutura nova, justificada abaixo |
| X | `PapelDeAdministrador` faz uma coisa: quem pode mexer na marca e se a organização fica com admin |
| XI | o guarda lê o estado travado antes de decidir |

### Decisões de desenho (VIII)

| estrutura | problema concreto | agora? | o que piora |
|---|---|---|---|
| `Tenants.PapelDeAdministrador` (o guarda e `exigir_ator/2`) | três atos precisam da mesma trava e dez atos precisam da mesma conferência; espalhados, divergiriam (S3 nasceu disso) | sim | um módulo a mais em `Tenants` |
| o trigger adiado em `users.role` | a SC-002 ("só o ato muda o papel") só é mensurável no banco | sim | é invisível a quem lê Elixir, e o nome do erro diz onde olhar |

## Riscos

| risco | mitigação |
|---|---|
| a FR-002a muda o comportamento de dez atos | cada um ganha teste com o ator rebaixado, e o defeito injetado |
| os triggers desligáveis pelo dono das tabelas | a 071 (#1131) |
| a janela entre o `commit` e o aviso | o domínio confere o ator relido; o aviso só antecipa |
| os tokens emitidos pelo rebaixado para outros donos | risco residual declarado (S5) |
