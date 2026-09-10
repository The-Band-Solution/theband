# A conta desativada — o desligamento que hoje é implícito

**Prioridade**: **alta — à frente da [061](../../specs/061-api-publica/spec.md)**, decidida
pelo papel de Product Owner em 2026-09-09, a confirmar pela pessoa alocada.
**Risco**: em produção **hoje**, com dado real de uma organização.
**Origem**: levantado pela spec 061 como *"item de backlog anterior a esta feature"*, e
**medido com teste** pelo papel de Security em 2026-09-09 —
[`H3`](../seguranca/2026-09-09-o-que-consertar-agora.md), severidade **Alta**, subida de Média
justamente por ter sido medida.

> **Correção do meu próprio levantamento, registrada em vez de silenciada.** A primeira versão
> deste documento argumentava que o desligamento de hoje **funciona** — que reiniciar a senha
> gira o token de sessão e corta o acesso — e que o risco era a **indistinguibilidade** dos
> estados na tela. A primeira metade está certa e a segunda continua de pé, mas as duas juntas
> **subestimam o problema**: eu inferi do código o caminho que quem administra *deveria* seguir,
> e não medi o que acontece no caminho que a tela *oferece*. O H3 mediu, e o resultado é pior.
> É a lição *"limitação declarada sem olhar o dado"* aplicada a mim: ler o código da tela não
> diz o que a tela deixa fazer.

---

## Estado em 2026-09-09T23:19Z — construída, em produção, e **NÃO ACEITA**

O [#844](https://github.com/The-Band-Solution/theband/pull/844) construiu isto e foi mergeado na
`development` às 20:24Z. O veredito de aceitação está em
[`docs/releases/v0.7.0.md`](../releases/v0.7.0.md), entregável **D06**:
**`sro.not_accepted_deliverable`** — quatro critérios não conformes, um sem evidência.

**O que este item passa a ser**: não é mais *"o que construir"*. É **o que falta** para que o
que já está em produção possa ser aceito e anunciado.

| O que falta | Critério desta página que fica aberto |
|---|---|
| **a razão ao desativar** | *"o registro diz **quem** desativou, **quando** e **por quê**"* — a migração dá `disabled_at` e `disabled_by_user_id`; **o porquê não existe** |
| **o ator e a razão ao reativar** | *"reativar é ato registrado, com autor e razão"* — `enable_user/2` recebe tenant e `user_id`, e mais nada. Desativar deixa autor; **reativar não deixa** |
| **o teste de que nada muda na pessoa** | *"o roster, as medidas e o histórico da pessoa **não mudam** ao desativar a conta"* — **sem evidência**: nenhum teste compara medida antes e depois |
| **o texto do *revoke*** | Parte C — hoje diz *"a pessoa deixa de entrar pelo username do GitHub; a história do elo fica"*, e **não** diz que não remove acesso |
| **o teste que reprova** se revogar o elo voltar a ser o único ato oferecido a quem desliga | Parte C — não existe |
| **o protótipo aprovado** da superfície de `/accounts` | a seção *Tem tela, logo tem protótipo*, abaixo, que **eu escrevi antes do código e o código não seguiu** |

### As quatro decisões foram tomadas pelo código, e uma contraria a recomendação

Esta página diz, textualmente: *"Não decomponho antes destas respostas — decidir depois de
construir é o que produz retrabalho."* As quatro foram decididas na implementação, sem registro
de escolha da pessoa mantenedora. A que importa é a **decisão 1**:

| | |
|---|---|
| **recomendação** | **(b) relator próprio**, *"porque um `disabled_at` solto repete o `connected_tools.status` da ADR 0004 D7, que já é dívida declarada"* |
| **implementado** | **(a) `disabled_at` + autor na própria `users`** |
| **consequência** | a dívida da [#178](https://github.com/The-Band-Solution/theband/issues/178) ganha uma segunda ocorrência, e o campo de **razão** — que um relator carregaria naturalmente — é justamente o que ficou de fora |

**Isto não é motivo para desfazer**, e não é o que proponho: a migração é só-acréscimo, foi
ensaiada contra dado real, e desfazê-la custaria mais do que a dívida. É motivo para a decisão
ser **tomada** — confirmar (a) com a razão escrita, ou decidir migrar para (b) — em vez de ficar
como está, que é a forma vencendo por omissão.

### O que **não** está em causa

A migração `20260909180000` está em ordem, e a recusa não a alcança: colunas nulas, sem
backfill, sem CHECK, **ensaiada contra cópia do banco real** com **0 contas desativadas por
acidente** —
[`docs/producao/ensaio-2026-09-09-migracao-conta-desativada.md`](../producao/ensaio-2026-09-09-migracao-conta-desativada.md).
E as regras de recusa que existem — não se desativa a si, nem conta de outro tenant, nem duas
vezes; reativar não devolve a senha — têm asserção nomeada.

---

## O fato, verificado no esquema e não na prosa

**Não existe estado de conta desativada nesta plataforma.**

| Onde | O que tem | O que falta |
|---|---|---|
| `users` (`lib/the_band/tenants/user.ex:38`) | `email`, `name`, `role`, `tenant_id`, credencial, sessão, elo com a pessoa | **nenhum** `status`, `disabled_at` ou equivalente |
| `tenants` (`lib/the_band/tenants/tenant.ex:19`) | `status`, com `"active"` por omissão | — |
| migrações que tocam `users` | só acrescentam credencial (`20260828160855`) e o elo com a pessoa (`20260827050000`) | nenhuma coluna de desativação |
| `/accounts` (`accounts_live/index.ex`) | `criar`, `reset`, `associar`, `revogar_elo`, `buscar_pessoa` | **não há `desativar`** |

O `person_revoked_at` que existe revoga o **elo com a pessoa observada**, não a conta: quem
perde o elo continua entrando.

## A lacuna tem três partes, e só uma é a coluna que falta

Medidas com teste pelo papel de Security, não inferidas:

| # | Parte | O que se mediu |
|---|---|---|
| **A** | **`users` não tem estado de conta desativada** | a tabela nasce com `email`, `name`, `role`, `tenant_id` (`20260809120000_create_tenants_and_users.exs:26-31`); nenhuma migração posterior acrescenta situação |
| **B** | **`tenants.status` existe e não é lido em lugar nenhum** | marcar um tenant como `"suspended"` e autenticar em seguida: **as duas coisas funcionam**, com `assert suspenso.status == "suspended"` antes, para o teste não passar por não ter suspendido nada. É uma coluna que **parece** um controle e não é um |
| **C** | **revogar o elo — o ato que a tela oferece a quem desliga alguém — não remove acesso** | com o elo revogado, `pode_ver/3` recusa o painel da própria pessoa **e** `Tenants.authenticate/2` continua devolvendo `{:ok, user}`; `/people`, `/teams` e `/work/verifications/people` continuam abrindo |

**A parte C é a que muda a natureza do item**, e é a que eu não tinha visto. O único ato que a
tela oferece com cara de desligamento — *revoke link* — **não desliga**. Quem administra faz o
que a interface sugere, acredita ter cortado o acesso, e a pessoa continua entrando com a
senha que sabe.

E é pior em combinação: pelo [H2](../seguranca/2026-09-09-o-que-consertar-agora.md) o veredito
de acesso vale em **2 de 24 rotas autenticadas**, então o que a pessoa continua lendo não é o
painel dela — é a lista de pessoas, as equipes, os perfis derivados e o ranking nominal de quem
integrou com a verificação vermelha.

## O único ato que de facto corta o acesso, e por que isso não salva

Reiniciar a senha e não entregar a temporária **funciona**:

```elixir
# lib/the_band/tenants/user.ex:137 — dentro de hash_password/2
|> put_change(:session_token, novo_token())
# "Token de sessão novo — girá-lo derruba as outras sessões (FR-015)."
```

Mas isto é conhecimento tribal, não caminho oferecido: nada na tela diz que *reset* é o
desligamento e *revoke link* não é. O ato certo é o que **não** parece ser, e o ato que parece
ser é o que não funciona.

## E há um segundo risco, na mesma tela: o desligado é indistinguível do recém-criado

`reset_password/3` grava `must_change_password: true` (é o `temporary: true` de
`gravar_temporaria/1`). E a lista de contas mostra exactamente três estados:

```elixir
# lib/the_band_web/live/accounts_live/index.ex:327-333
<span :if={user.password_hash && !user.must_change_password}>definida</span>
<span :if={user.password_hash && user.must_change_password} class="text-warning">
  temporária pendente
</span>
<span :if={!user.password_hash} class="opacity-60">sem senha — a entrada recusa</span>
```

**Uma pessoa desligada aparece como `temporária pendente`. Uma pessoa acabada de criar, que
ainda não entrou, aparece como `temporária pendente`.** O mesmo rótulo, a mesma cor, a mesma
linha — e as duas pedem ações **opostas**:

| Estado real | O que a tela diz | O que quem administra faz, corretamente |
|---|---|---|
| acabou de ser criada, nunca entrou | `temporária pendente` | **reset, e entregar a senha** — é o caminho normal de entrada |
| foi desligada | `temporária pendente` | **nada**, para sempre |

O ato correto para o primeiro caso **reativa** o segundo, em silêncio, sem nada na tela
avisando. Não é hipótese remota: é o procedimento de rotina de quem administra, aplicado à
linha errada, e a tela não oferece nenhuma forma de distinguir — não há data do desligamento,
não há autor, não há razão, não há sequer um rótulo diferente.

E a plataforma **não consegue responder** *"quem tem acesso hoje, quem foi desligado, por quem
e quando"*, que é a pergunta que se faz num pedido de auditoria. Num produto cuja tese é
proveniência, o ato mais sensível da administração é o único sem proveniência alguma.

## É a mesma família de defeito que a casa já nomeou

*Zero não é a mesma coisa que não conferido* — a asserção que carrega a seção *Problems now*
(060 FR-067). Aqui: **desligada não é a mesma coisa que ainda não entrou**, e as duas se
apresentam como um rótulo só. Duas afirmações opostas renderizadas idênticas é o defeito que
esta plataforma existe para não cometer.

## O que a 061 acrescenta, e o que ela não causa

A spec 061 registra a limitação com precisão: *"esse mecanismo para de funcionar no dia em que
existir token"*. Com token, a pessoa que saiu **continua lendo os dados por API** — o giro do
`session_token` não alcança um token de API, e quem administra não tem ato que resolva. É
acesso órfão, e passa por todas as travas porque o token é válido e a conta existe.

**Mas a 061 agrava, não origina.** O defeito é de hoje, sem token nenhum, e são as partes A, B
e C acima. O critério de separação do papel de Security é o certo: *existe caminho de
exploração contra o código que está rodando hoje?* Para a parte C, **sim, medido**.

## A decisão de prioridade, e a razão

**Entra à frente da 061.** Quatro razões, em ordem de força:

1. **É risco de hoje, em produção, com dado real — e medido, não inferido.** Não depende da API
   existir. O ato que a tela oferece para desligar alguém não desliga, e o que a pessoa
   continua lendo é ampliado pelo H2.

2. **Colocá-la à frente não custa nada no caminho crítico, porque a 061 está bloqueada.** A
   spec 061 tem tela (a de tokens, US1 e US3) e **não tem protótipo** — não existe
   `specs/061-api-publica/prototipo/`. Pela regra deste papel, US1 e US3 não são decompostas
   em tarefas antes de o Design desenhar e a pessoa mantenedora aprovar. Então "à frente da
   061" é **grátis**: não há troca a fazer, e sequenciar na ordem inversa não aceleraria a
   061 em um dia.

3. **Feita antes, a 061 não precisa publicar um buraco.** Hoje a 061 depende da FR-074 como
   *substituto*, e obriga a limitação a *"aparecer na documentação da API"*. Entregar a API
   primeiro significa **publicar, no primeiro contrato público do produto**, a declaração de
   que acesso órfão não tem remédio. Com `disabled_at` pronto, a regra passa a ser a simples e
   verdadeira: **conta desativada não autentica, nem por senha nem por token** — e não há
   limitação a documentar.

4. **Não está bloqueada em recurso nenhum.** Ao contrário do [ensaio de
   restauração](backup-restaurado-de-verdade.md), que espera uma conta S3 que não existe, esta
   pede uma coluna, um ato na tela e uma regra nas duas portas de autenticação. Fecha com
   trabalho, e trabalho é o que se pode agendar.

**O que a decisão não é**: não é "a 061 pode esperar indefinidamente". A 061 é o que destrava
a [062 (servidor MCP)](servidor-mcp.md) e é proposta de 2026-09-08. A ordem proposta é
*primeiro esta, que é pequena e desbloqueada; a 061 em seguida, sem a limitação*.

## O que precisa ser decidido antes de haver tarefa

Não decomponho antes destas respostas — decidir depois de construir é o que produz retrabalho.

| # | Pergunta | Opções | Recomendação |
|---|---|---|---|
| 1 | **desativar é marca ou é campo?** | (a) `disabled_at` + autor + razão na própria `users`; (b) relator próprio, como as concessões e os escopos | **(b)**, por coerência: esta casa registra ato com autor, data e razão, e revogação sem apagar. Um `disabled_at` solto repete o `connected_tools.status` da ADR 0004 D7, que já é dívida declarada |
| 2 | **o que aparece na lista de contas** | (a) um quarto estado no mesmo lugar da senha; (b) coluna própria de situação da conta, separada da situação da senha | **(b)** — misturar situação da **conta** com situação da **credencial** é o que produziu a colisão de hoje. São dois fatos, e o rótulo único é a causa do defeito |
| 3 | **reativar existe?** | (a) sim, com autor e razão; (b) não — cria-se conta nova | **(a)**, porque (b) perderia o histórico da pessoa e o elo com `eo_people` |
| 4 | **a conta desativada aparece no roster e nas medidas?** | — | **sim, e sem mudança**: é o mesmo princípio da saída declarada da US3 — quem saiu continua contando no período em que esteve. Desativar a **conta** não altera o que a **pessoa** fez |

## Tem tela, logo tem protótipo

O ato vive em `/accounts`, e a situação da conta aparece na lista. Pela regra da casa, o
Design desenha antes: o quarto estado (ou a coluna nova), o diálogo que pede a razão, e como o
desligado se distingue do recém-criado **sem depender de cor**. É uma superfície pequena sobre
uma tela que já existe, e não um protótipo de tela nova.

## Critérios que a spec vai precisar carregar

Escritos aqui para não nascerem no fim, quando já não se pode avaliá-los:

**Parte A — a conta desativada**

- conta desativada **não autentica por senha** e a recusa é a mensagem única, sem dizer que a
  conta está desativada (não vaza estado de conta para quem não entrou);
- conta desativada **não autentica por token** — a regra tem de valer nas duas portas, e a
  segunda ainda não existe;
- desativar **gira o token de sessão**, e a sessão viva morre no ato;
- o registro diz **quem** desativou, **quando** e **por quê**; nada é apagado;
- a lista de contas distingue **desativada** de **temporária pendente** de **sem senha**, e a
  distinção sobrevive sem cor;
- reativar é ato registrado, com autor e razão;
- o roster, as medidas e o histórico da pessoa **não mudam** ao desativar a conta.

**Parte B — `tenants.status` passa a ser lido, ou deixa de existir**

- tenant com `status` diferente de `"active"` **não autentica**, e a recusa é a mensagem única;
- se a decisão for que suspender tenant não é caso de uso, **a coluna sai** — coluna que parece
  controle e não é é pior que coluna ausente, porque quem administra confia nela.

**Parte C — o ato da tela diz a verdade sobre o que faz**

- *revoke link* **não** é apresentado como desligamento: o texto diz que desfaz a ligação entre
  a conta e a pessoa observada, e que **não** remove acesso;
- desligar acesso tem ato próprio, nomeado, e é o que aparece a quem procura desligar alguém;
- teste que **reprova** se revogar o elo passar a ser o único ato oferecido a quem desliga.
