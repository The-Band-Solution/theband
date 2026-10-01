# Contrato — os eventos de acesso da plataforma

FR-010, O14. Acréscimos a `TheBand.Tenants.AccessEvents` (`lib/the_band/tenants/access_events.ex`),
que é **registro, e não decisão**: removidas, a plataforma se comportaria igual (`:28-41`).

Todas em `:warning`, para serem observáveis com o nível de `config/test.exs` (`:157-171`). O ator
vem do `Logger.metadata(operator_id: …)` do plug, e `config/config.exs:80` ganha `:operator_id` na
lista do formatador.

| função | campos |
|---|---|
| `ato_de_plataforma(:organizacao_suspensa, tenant_id, extra)` | `tenant_id` **da organização afetada**, `episodio_id`, `razao`, `sessoes_encerradas`, `tokens_revogados` |
| `ato_de_plataforma(:organizacao_reativada, tenant_id, extra)` | `tenant_id`, `episodio_id`, `razao`, `sessoes_encerradas` |
| `operador_concedido(operator_id, declarado_por)` | `via: :release_command` |
| `operador_revogado(operator_id, declarado_por, sessoes_encerradas)` | `via: :release_command` |
| `operador_credencial_reiniciada(operator_id, declarado_por)` | `via: :release_command` |
| `operador_entrada_aceita(operator_id, falhas_apagadas)` | |
| `operador_entrada_recusada(operator_id ou nil, motivo)` | o motivo interno de `Credentials` |
| `operador_espera_acionada(operator_id, segundos)` | |
| `operador_sessao_derrubada(operator_id ou nil, motivo)` | o motivo de `Platform.Sessions.conferir/2` |
| `operador_ato_recusado(operator_id, tenant_id, motivo)` | `:nao_autorizado`, `:ja_suspensa`, `:nao_suspensa`, changeset resumido em códigos |

## O que NÃO vai para o log, e por quê

| ausência | por quê |
|---|---|
| a nota livre do episódio | é texto de pessoa, sem limite de conteúdo; fica na linha, que tem dono |
| o código de definição, a senha, o hash, o token | `access_events.ex:43-48`; as assinaturas não aceitam |
| `user_id` com o id do operador | `user_id` significa `users.id` em toda linha (research R12) |
