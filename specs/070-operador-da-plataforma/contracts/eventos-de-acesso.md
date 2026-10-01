# Contrato — os eventos de acesso da plataforma

FR-010, O14. Acréscimos a `TheBand.Tenants.AccessEvents` (`lib/the_band/tenants/access_events.ex`),
que é **registro, e não decisão**: removidas, a plataforma se comportaria igual (`:28-41`).

Todas em `:warning`, para serem observáveis com o nível de `config/test.exs` (`:157-171`). O ator
vem do `Logger.metadata(operator_id: …)` do plug, e `config/config.exs:80` ganha `:operator_id` na
lista do formatador.

> **Emendado em 2026-10-01**: A7 (a definição da senha deixa rastro) e o segundo fator (FR-016).

| função | campos |
|---|---|
| `ato_de_plataforma(:organizacao_suspensa, tenant_id, extra)` | `tenant_id` **da organização afetada**, `episodio_id`, `razao`, `sessoes_encerradas`, `tokens_revogados` |
| `ato_de_plataforma(:organizacao_reativada, tenant_id, extra)` | `tenant_id`, `episodio_id`, `razao`, `sessoes_encerradas` |
| `operador_concedido(operator_id, declarado_por)` | `via: :release_command` |
| `operador_revogado(operator_id, declarado_por, sessoes_encerradas)` | `via: :release_command` |
| `operador_credencial_reiniciada(operator_id, declarado_por)` | `via: :release_command` |
| `operador_entrada_aceita(operator_id, falhas_apagadas)` | |
| `operador_entrada_recusada(operator_id ou nil, motivo)` | o motivo interno de `Credentials`, inclusive `:sem_segundo_fator`, `:segundo_fator_errado`, `:segundo_fator_reusado`, `:recuperacao_usada` e `:segundo_fator_travado` |
| `operador_senha_definida(operator_id)` | o primeiro passo da definição aceito (A7) |
| `operador_definicao_recusada(operator_id ou nil, motivo)` | `:codigo_errado`, `:codigo_vencido`, `:sem_codigo`, `:identificador_nao_resolveu`, `:sem_concessao` (A7, A14) |
| `operador_segundo_fator_cadastrado(operator_id)` | o **terceiro** passo aceito (`concluir_cadastro/2`, emenda T012): é aqui que o segundo fator passa a valer, e não na confirmação do TOTP |
| `operador_cadastro_recusado(operator_id ou nil, motivo)` | `:identificador_nao_resolveu`, `:codigo_de_cadastro_errado`, `:codigo_de_cadastro_vencido`, `:totp_errado`, `:sem_concessao`; e, no passo 3, `:codigo_de_guarda_errado`, `:codigo_de_guarda_vencido`. `:totp_errado` repetido no passo 2 é o rastro da tentativa que T12 (seguranca-totp.md) aceitou limitar só pela espera e pela validade de 10 min |
| `operador_recuperacao_usada(operator_id, restantes)` | um código de recuperação consumido; `restantes` é a contagem que sobrou |
| `operador_segundo_fator_travado(operator_id)` | `second_factor_failures` chegou ao limite (seguranca-totp.md, T1); sai uma vez, na transição. Com senha certa, é o sinal de que a senha está com outra pessoa |
| `operador_espera_acionada(operator_id, segundos)` | |
| `operador_sessao_derrubada(operator_id ou nil, motivo)` | o motivo de `Platform.Sessions.conferir/2` |
| `operador_ato_recusado(operator_id, tenant_id, motivo)` | `:nao_autorizado`, `:ja_suspensa`, `:nao_suspensa`, changeset resumido em códigos |

## O que NÃO vai para o log, e por quê

| ausência | por quê |
|---|---|
| a nota livre do episódio | é texto de pessoa, sem limite de conteúdo; fica na linha, que tem dono |
| o código de definição, o de cadastro, a senha, o hash, o token, o segredo TOTP, o código TOTP e o de recuperação | `access_events.ex:43-48`; as assinaturas não aceitam, e o teste de A7 faz `refute =~` do valor em toda linha capturada |
| `user_id` com o id do operador | `user_id` significa `users.id` em toda linha (research R12) |
