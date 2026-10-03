# Tasks: A marca de administrador

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/papel.md](contracts/papel.md), [seguranca.md](seguranca.md), [prototipo/](prototipo/README.md)

## Fase 2: Fundação

- [ ] T001 Restringir o papel a dois valores
  - **Pronta quando**: R5; nada além do repositório
  - **Descrição**:
    - `User.changeset/2` deixa de fazer `cast` de `:role`.
    - O bootstrap grava `admin` por `put_change`, e `cadastrar_conta/3` grava sempre `member`.
    - Uma migração conta as linhas fora de `admin` e `member` e levanta se houver alguma. Depois,
      cria o `CHECK users_role_valido`.

    FR-006; S4, S7.
  - **Feita quando**:
    - `cadastrar_conta/3` com `"role" => "admin"` cria `member`;
    - `update_all` com `role = 'Admin'` é recusado pelo `CHECK`;
    - a migração levanta com a contagem quando há valor fora da lista.
  - **Teste**: `test/the_band/tenants/papel_restrito_test.exs`. **Defeito a injetar**: voltar o
    `cast` de `:role`; o caso do cadastro precisa reprovar.

- [ ] T002 Registrar as mudanças de papel no banco
  - **Pronta quando**: `data-model.md`; T001
  - **Descrição**: a migração de `account_role_changes`, com os `CHECK`s, os índices e os triggers
    `nao_apaga`, `nao_altera` e `nao_trunca` (`search_path` fixo com `pg_temp` por último). O
    schema fica em `lib/the_band/tenants/schemas/account_role_change.ex`. FR-005, S6.
  - **Feita quando**: `DELETE`, `UPDATE` e `TRUNCATE CASCADE` levantam; o round trip
    `migrate`/`rollback` volta ao estado anterior
  - **Teste**: `test/the_band/tenants/registro_do_papel_test.exs`. **Defeito a injetar**: tirar o
    `nao_altera`; o `UPDATE` precisa passar e o teste reprovar.

- [ ] T003 O banco recusa papel sem episódio
  - **Pronta quando**: T002
  - **Descrição**: o trigger de constraint adiado `users_papel_tem_episodio`, `AFTER UPDATE OF
    role`, conferindo `txid_current()` (R3). FR-005, SC-002.
  - **Feita quando**:
    - `update_all` em `users.role` sem episódio é recusado com o nome da constraint quando se
      força a conferência;
    - a sequência legítima, o papel e o episódio na mesma transação, passa.
  - **Teste**: `registro_do_papel_test.exs`, com `SET CONSTRAINTS ALL IMMEDIATE` e a asserção
    sobre `postgres.constraint`. **Defeito a injetar**: o trigger removido.

- [ ] T004 O guarda único do papel
  - **Pronta quando**: `contracts/papel.md`; T001
  - **Descrição**: `lib/the_band/tenants/papel_de_administrador.ex`.
    - `travar/3` trava as contas admin ativas por id, confere o ator no conjunto, e trava e relê o
      alvo (R1).
    - `exigir_ator/2` relê o ator (R2).

    FR-002, FR-004; S2, S3.
  - **Feita quando**:
    - o ator que não está no conjunto dá `:nao_autorizado`;
    - o alvo é a struct relida, e não a recebida;
    - a captura do SQL mostra o `FOR UPDATE`.
  - **Teste**: `test/the_band/tenants/papel_de_administrador_test.exs`, a parte do guarda.
    **Defeito a injetar**: decidir pelo alvo recebido; o caso da struct velha precisa reprovar.

- [ ] T005 As frases do papel na base
  - **Pronta quando**: R6
  - **Descrição**: `priv/knowledge_base/rules/access_account_role.yaml`, regra `access.account_role`,
    na forma de `access_account_lifecycle.yaml`.
  - **Feita quando**: `mix knowledge.validate` passa, e o leitor devolve os rótulos e as frases
  - **Teste**: `test/the_band/tenants/account_role_rule_test.exs`

## Fase 3: US1 e US2 — promover e rebaixar (P1)

- [ ] T006 [US1] Promover e rebaixar numa transação
  - **Pronta quando**: T002–T005; `contracts/papel.md`
  - **Descrição**: `Tenants.promote_user/4` e `demote_user/4`, como o contrato. O aviso e o evento
    saem depois do `commit`. FR-001 a FR-005, FR-007.
  - **Feita quando**:
    - cada motivo do contrato é produzido por um caso, e nada muda na recusa;
    - dez rebaixamentos cruzados concorrentes, com dois admins, terminam com pelo menos um
      admin ativo, em 10 de 10 (SC-001);
    - o rebaixado com a struct de antes não se promove de volta (S2).
  - **Teste**: `papel_de_administrador_test.exs`. **Defeitos a injetar**:
    - conferir o ator pela struct;
    - tirar o `FOR UPDATE`.

- [ ] T007 [US2] A desativação pelo mesmo guarda
  - **Pronta quando**: T004
  - **Descrição**: `disable_user/4` usa `travar/3` no lugar de `resta_um_admin_ativo/2`. S3.
  - **Feita quando**:
    - a sequência de S3 (desativar com a struct velha de um membro promovido no meio) não deixa a
      organização sem admin;
    - o `:ja_desativada` falso não acontece mais;
    - o `ultimo_admin_ativo_test.exs` continua verde, com a invariante de pé (sobra um admin). Os
      motivos mudaram: o membro que tenta desativar recebe `:nao_autorizado`, e a segunda desativação
      cruzada também, porque o ator relido sob a trava já não é admin ativo. Registrado na T007.
  - **Teste**: `papel_de_administrador_test.exs`, o caso de S3.

- [ ] T008 [US2] Os atos de administração conferem o ator relido
  - **Pronta quando**: T004
  - **Descrição**: `exigir_ator/2` no começo de cada ato de R2. FR-002a; S1.
  - **Feita quando**: cada um dos dez atos, chamado com um ator que perdeu a marca, devolve
    `:nao_autorizado` e não muda nada
  - **Teste**: `test/the_band/tenants/ator_relido_test.exs`, um caso por ato. **Defeito a
    injetar**: tirar a conferência de `ApiTokens.criar/4`; o caso do token precisa reprovar.

- [ ] T009 [US2] A tela aberta do rebaixado cai
  - **Pronta quando**: T006
  - **Descrição**: o `reconferir/2` de `hooks.ex` relê a conta, e numa área admin redireciona para
    `/people` com a frase de hoje (Q3). FR-008, R4.
  - **Feita quando**: uma aba de `/accounts` aberta pelo rebaixado vai para `/people` depois do
    rebaixamento, e um `render_click` depois disso não executa
  - **Teste**: `test/the_band_web/live/papel_aba_aberta_test.exs`. **Defeito a injetar**: tirar o
    aviso depois do `commit`; a aba precisa continuar.

## Fase 4: US3 — a tela (P2)

- [ ] T010 [US3] Ler o registro das mudanças
  - **Pronta quando**: T002
  - **Descrição**: `Tenants.role_changes/2`, com as 20 mais recentes e a contagem total (Q5)
  - **Feita quando**: devolve do mais novo ao mais antigo, só da organização, e a contagem
  - **Teste**: `papel_de_administrador_test.exs`, "role_changes", com dois tenants

- [ ] T011 [US3] A tela de contas do protótipo aprovado
  - **Pronta quando**: T006, T010; o protótipo aprovado em 2026-10-03
  - **Descrição**: `lib/the_band_web/live/accounts_live/index.ex`, exatamente como
    `prototipo/accounts-admin-role.html`:
    - a célula Management, com a marca, a linha de quem e quando, e o ato;
    - "N active administrators";
    - os painéis de promover, rebaixar e deixar o próprio papel (digitando o e-mail);
    - as recusas D4 e D5;
    - "Administrator changes";
    - `member` em palavra, e não `—`;
    - a tabela empilhada.

    Inglês na tela. FR-009.
  - **Feita quando**: cada item da régua de `prototipo/PROMPT.md` §3 aparece; nenhum ato numa conta
    de membro desativada; nenhum controle para membro
  - **Teste**: `test/the_band_web/live/accounts_papel_test.exs`

- [ ] T012 [US3] Conferir a tela contra o protótipo
  - **Pronta quando**: T011
  - **Descrição**: o QA, item a item da régua, em `prototipo/conferencia.md`
  - **Feita quando**: não há `diverge` aberto sem decisão
  - **Teste**: o próprio registro

## Fase 5: Acabamento

- [ ] T013 Escrever a nota de riscos e abrir o PR
  - **Pronta quando**: T001–T012
  - **Descrição**:
    - o risco residual de `seguranca.md`: os triggers do dono (#1131), a janela do aviso e os tokens
      de terceiros;
    - `mix gates`;
    - o PR pelo template.
  - **Feita quando**: `GATES_EXIT=0` lido no log; o revisor pedido
  - **Teste**: as leituras coladas no PR

## Dependências

- T001 → T002 → T003.
- T001 → T004 → T006, T007 e T008.
- T005 → T006 → T009.
- T002 → T010 → T011 → T012.
- Tudo → T013.
