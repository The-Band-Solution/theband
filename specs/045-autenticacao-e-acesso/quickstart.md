# Quickstart — validar autenticação e escopos (045)

## Pré-requisitos

```bash
docker compose up -d postgres
set -a && source .env && set +a
mix ecto.migrate                # 2 migrações novas; seed de grants p/ admins
mix phx.server                  # http://localhost:4000
```

## Cenários de validação

### US1 — entrar e sair

1. `/sign-in` não lista conta nenhuma: identificador + senha (protótipo aprovado).
2. Conta sem senha (pré-feature) → "Credenciais inválidas."; quem administra roda o
   reset e entrega a temporária; primeira entrada obriga troca.
3. Entrar por e-mail; sair; entrar pelo usuário do GitHub (conta com elo vigente);
   revogar o elo → username recusa, e-mail entra.
4. 4+ senhas erradas seguidas → mesma mensagem, espera crescente (medir o intervalo).
5. Trocar a senha num navegador → sessão do outro cai na próxima ação (FR-015).
6. Rota protegida sem sessão → redireciona a /sign-in preservando destino (FR-005).

### US2 — escopos acumulativos

1. Conta só com elo (piso): vê o próprio painel e nenhum outro; recusa nomeia motivo.
2. Pessoa com vínculo em equipe → painéis da equipe (derivado, hachura na tela de
   gestão); encerrar o vínculo → escopo fecha sozinho.
3. Equipe ligada a projeto declarado (`spo_project_teams`) → derivado project.
4. Concessão team/project/organization por admin em /access-scopes (alvo obrigatório;
   sem alvo recusa com motivo); revogar marca, não apaga.
5. Admin sem concessão e sem elo → gerencia (/accounts, /access-scopes) mas não vê
   painel nenhum (FR-022).
6. Organization: vê todos os painéis da organização-alvo; Syncs/Tools/AI filtrados
   pelas organizações concedidas; member puro nem vê as entradas (FR-023).
7. Dois tenants povoados: 0 vazamento (SC-003).

### US3 — perfil

1. /profile: nome editável, e-mail somente leitura, senha com confirmação da atual,
   escopos vigentes com origem (piso/derivado hachura/concedido), estado do elo.
2. Trocar senha com atual errada → recusa; com certa → próxima entrada exige a nova.

## Testes e gates

```bash
mix test test/the_band/tenants/auth_test.exs test/the_band/tenants/access_test.exs
mix test test/the_band_web/live/login_test.exs test/the_band_web/live/profile_test.exs \
         test/the_band_web/live/access_scopes_test.exs test/the_band_web/live/gating_operacional_test.exs
mix ecto.rollback --step 2 && mix ecto.migrate     # ida e volta das migrações
mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?" >> /tmp/gates.log; tail -3 /tmp/gates.log
```

Contratos: [auth.md](contracts/auth.md) · [access-scopes.md](contracts/access-scopes.md).
Modelo: [data-model.md](data-model.md). Protótipo: canvas "Autenticação e Acesso".
