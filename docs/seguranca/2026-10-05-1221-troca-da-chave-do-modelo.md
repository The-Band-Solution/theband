# Parecer de segurança — o registro da troca da chave do modelo (#1221, R1 do C.1)

**Feito em 2026-10-05, antes do código**, pelo agente `security`, que não escreveu o desenho
(AGENTS.md §14.0). O objeto é o desenho de quatro pontos proposto para fechar o achado **R1**
de `specs/064-segredo-em-repouso/seguranca-c1-mesma-chave.md`: `TheBand.AI.put/3` troca a chave
do provedor de modelos do tenant sem deixar evento, e `declared_by_user_id` é sobrescrito a cada
gravação, inclusive quando a chave é a mesma.

O desenho, em resumo:

1. `AccessEvents.chave_do_modelo_gravada(ato, tenant_id, actor_user_id)`, com
   `ato in [:primeira, :troca, :mesma_chave]`, em `:warning`, só com átomo e ids;
2. `put/3` classifica o ato com o que já existe (linha inexistente, `mesma_chave?/2` depois do
   `verify/2`, senão troca) e emite **só depois** de `Repo.insert_or_update` devolver `{:ok, _}`;
3. na `:mesma_chave`, `declared_by_user_id` fica o anterior, posto por `Ecto.Changeset.change/2`;
4. a comparação continua uma só, em tempo constante, em memória.

A leitura foi feita contra `lib/the_band/ai.ex` (`put/3` em `:134-165`, `declared_by_user_id`
em `:149`, `data_da_troca/3` em `:171-183`, `mesma_chave?/2` em `:187-190`, `delete/2` em
`:194-203`), `lib/the_band/ai/provider_credential.ex`, `lib/the_band/tenants/access_events.ex`
(`conta_da_organizacao/5` em `:253`, `registrar/2` em `:411`),
`lib/the_band_web/live/ai_live/index.ex` (`save` em `:53`, `delete` em `:119-137`),
`lib/the_band_web/router.ex:361-375`, `lib/the_band/integrations/llm/http/req.ex:38-78`,
`lib/the_band/repo/log_da_consulta.ex`, `config/config.exs:85-95`, `config/test.exs:31`,
`config/prod.exs:34`, a migração de `ai_provider_credentials` e
`deps/phoenix_live_view/lib/phoenix_live_view/logger.ex` (versão 1.2.9 em `mix.lock`). É leitura
de código. Nenhum teste, nenhuma ferramenta e nenhum gate rodou.

## Veredito

**Concorda com condições.** O desenho fecha o R1 na forma certa: o evento é registro e não
decisão, a assinatura só admite átomo e ids, o evento sai depois do commit, e a comparação não
se multiplica. Faltam três coisas para que ele cumpra o que o R1 promete, que é *reconstruir quem
trocou a chave e quando*:

- **`delete/2` precisa entrar no escopo (achado S1, médio).** Sem isso, apagar e gravar de novo
  é uma troca que o log registra como `:primeira`, sem ator para a remoção. O desenho, como está,
  é contornável pela outra porta da mesma tela;
- **o nível e a forma do evento precisam ser os de `conta_da_organizacao/5`** (S2, médio). Um
  evento em `:info` não sai em teste (`config/test.exs:31`) e não é verificável (L69);
- **a classificação precisa ser uma só e alimentar as datas e o evento** (S3, baixo). Duas
  decisões sobre "é a mesma chave" podem divergir, e então o log contradiz a idade.

Nenhum achado é alto nem crítico. Não há caminho em que o desenho exponha segredo, atravesse
tenant ou contorne autenticação. A severidade do R1 continua média.

## A análise, cenário por cenário

| Cenário | O que acontece com o desenho, e como foi verificado |
|---|---|
| **Ator nil** | `put/3` tem `user_id \\ nil` (`ai.ex:134`). O único chamador de produção passa `socket.assigns.current_user.id` (`ai_live/index.ex:53`), mas cerca de trinta chamadas de teste omitem o ator (`grep -rn "AI.put" test`). A guarda aceita `nil`, e é certo aceitar: o evento **tem** de sair com `actor_user_id=nil`, porque omitir a linha quando falta o ator seria apagar o rastro justamente no caso anômalo. Na `:primeira` e na `:troca`, `declared_by_user_id` vira `nil`, o que é a ausência nomeada (princípio VIII) e não um valor inventado. Tornar o ator obrigatório na assinatura é melhor desenho, mas obriga a mexer em todos aqueles testes (R-a, fora de escopo). |
| **Regravar a mesma chave para "limpar" o declarante** | Hoje funciona: quem tem a chave em uso regrava e passa a constar como declarante (`ai.ex:149`). Com o ponto 3, a `:mesma_chave` não toca `declared_by_user_id`, e o evento registra quem regravou. O ataque deixa de funcionar e passa a deixar rastro. Note que regravar a mesma chave exige **possuir** a chave em uso, porque o `verify/2` vem antes da comparação (`ai.ex:136-138`). |
| **Troca e destroca em sequência** | O operador O troca K0 por K1 e depois volta a K0. São duas linhas `:troca` com ator, e o `declared_by_user_id` final é o de quem destrocou. É a reconstrução correta. A destroca exige ter K0, que a tela nunca mostra (`masked/1`). O log é o único histórico, porque a coluna guarda só o último. Isso é aceitável **desde que** o log sobreviva (ver "O que NÃO foi verificado"). |
| **Apagar e gravar de novo** (S1) | `delete/2` (`ai.ex:194`) não recebe ator nem emite evento, e o chamador (`ai_live/index.ex:120`) também não. Apagar K0 e gravar K1 produz no log **uma `:primeira`** de quem gravou K1, sem nada sobre a remoção. Quem lê conclui que o tenant nunca teve chave antes, o que é falso, e não sabe quem removeu. Há um efeito a mais: entre o `delete` e o `put`, `opcoes/1` devolve `[]` e a geração cai no `API_KEY` do ambiente (`ai.ex:102-110`), que é **compartilhado entre tenants**. A conta da instalação passa a pagar pelo tenant, sem rastro de quem causou isso. |
| **Dois tenants com a mesma chave** | `existente/2` usa `fetch/2`, que filtra por `tenant_id` e `provider` (`ai.ex:32-35`). A comparação nunca vê a linha do vizinho. Se o tenant A, sem linha, grava a chave K que o tenant B já tem, o ato de A é `:primeira`. Se A tinha J, é `:troca`. Nenhuma linha de log sai com o `tenant_id` de B. A condição 5 do C.1 já guarda a comparação; aqui o que se acrescenta é a guarda **do evento**. |
| **Concorrência entre duas gravações** | Não há trava: `existente/2` lê, e `insert_or_update` escreve depois. **Duas primeiras simultâneas**: uma falha no `unique_constraint` (`provider_credential.ex`, índice `ai_provider_credentials_por_tenant_index`), devolve `{:error, changeset}` e, pelo ponto 2, não emite evento. Está certo. **Troca contra mesma chave**: A grava K1 e B regrava K0, os dois tendo lido K0. B classifica `:mesma_chave`. Se A grava primeiro, o `UPDATE` de B **não** reescreve `secret` nem `declared_by_user_id`, porque o `cast` e o `change/2` do Ecto descartam valor igual ao do `data` (que é o K0 obsoleto). O estado final é K1 declarado por A, e o log diz *troca por A, mesma chave por B*, coerente com o banco. **Essa coerência depende de usar `change/2` e não `force_change/3`** (S4). Resta um efeito de correção: o `secret_set_at` de B é a data de K0, gravada sobre K1, e a chave parece mais velha do que é. É a direção conservadora (pede troca antes da hora) e não esconde vencimento. |
| **`:mesma_chave` no log é oráculo?** | Não no sentido de revelar segredo. Quem lê o log aprende que o ator X regravou a chave em uso. Isso implica que X **possui** a chave válida do tenant, o que é informação de auditoria, e é a mesma coisa que o flash já disse a X e que o cartão mostra (`last_four` e data inalterados, análise do C.1). Não há comparação entre tenants e não há parte do valor. Quem tem acesso ao log de produção já está num nível de confiança acima de quem opera `/ai`. Informativo. |
| **Recusa do provedor: emitir evento?** (R3 do C.1) | É útil: o formulário funciona como verificador de chaves alheias sem limite de tentativas (R3), e uma série de recusas de um mesmo ator é o sinal disso. Mas é **outro** evento e outro achado. Se entrar, a regra é rígida: **só o átomo do motivo** (`:rejeitada`, `:indisponivel`, `:sem_modelos`, `:modelo_desconhecido`) e **nunca a string**. A string vem do provedor (`req.ex:64-65`): `HTTP.redigir/2` tira o valor exato da chave, mas a mensagem de erro da OpenAI cita a chave **mascarada pelo próprio provedor**, com prefixo e sufixo, e essa forma não casa com o valor exato. No flash, para quem digitou, isso é aceitável; num log, é parte de segredo de terceiro. Recomendação R-b, fora de escopo. |
| **`log: false` do Ecto** | Já não é a defesa. Desde #1222, o Repo tem o log embutido desligado na configuração, e `TheBand.Repo.LogDaConsulta` redige todos os parâmetros de consulta que tocam tabela com campo cifrado (`log_da_consulta.ex`). O `log: false` em `ai.ex:164` ficou redundante e inofensivo. O desenho não muda isso, e não deve trocar por `log: :debug` ou outro nível, que contornaria o handler (`segredo_fora_do_log_test.exs` já reprova). |
| **`Phoenix.LiveView.Logger` nos parâmetros do `handle_event`** | `lv_handle_event_start` imprime `inspect(filter_values(params))` (`logger.ex:151-164`). O filtro casa **por trecho** do nome da chave (`deps/phoenix/lib/phoenix/logger.ex`, `String.contains?(k, key_match)`), e `"secret"` está em `filter_parameters` (`config/config.exs:95`). O campo do formulário é `name="secret"` (`ai_live/index.ex:344`), de primeiro nível. Verificado por leitura. A condição 4 de `mesma_chave_test.exs` submete o formulário em `:debug` e assere `refute log =~ chave`, o que cobre esse caminho se o logger do LiveView estiver anexado no teste. Não conferi que está. |
| **`delete/2` está no escopo?** | **Sim, e é a condição 1.** Ver S1. A regra de §14.0 (item 2) também empurra nessa direção: é defeito conhecido na **mesma superfície**, na mesma tela, um botão ao lado. |

## Achados

| # | Severidade | O que é | Onde | Consequência para o negócio |
|---|---|---|---|---|
| **S1** | **Médio** (A09, ASVS V7.1/V7.2) | A remoção da chave não deixa evento nem ator, e anula a reconstrução que o R1 promete: apagar e gravar vira `:primeira`. | `ai.ex:194-203`, `ai_live/index.ex:119-137` | depois de um incidente, não se sabe quem removeu a chave do tenant, nem que o tenant passou a gastar a chave compartilhada do ambiente |
| **S2** | **Médio** (A09, L69) | O evento só é verificável se sair em `:warning`. `registrar/2` decide o nível pelo **nome** do evento (`access_events.ex:411-428`): um nome novo fora da lista cai em `:info`, invisível em teste. Uma assinatura aberta (como o `extra` de `ato_administrativo/4`) aceitaria qualquer termo. | `access_events.ex:230-237`, `:411` | o registro pode existir no código e nunca ter sido visto por teste, e sumir num refactor sem nada acusar |
| **S3** | **Baixo** (A04) | Se a classificação do evento e o cálculo das datas (`data_da_troca/3`) decidirem "mesma chave" cada um por conta própria, podem divergir. O log diria `:troca` e a idade diria "não houve troca", ou o contrário. | `ai.ex:171-190` | o relatório de incidente e a cobrança de troca discordam, e não há como saber qual está certo |
| **S4** | **Baixo** (A04) | A coerência entre log e banco sob concorrência depende de `change/2` descartar valor igual ao do registro lido. `force_change/3` faria uma `:mesma_chave` obsoleta regravar o declarante antigo por cima de uma troca recém-commitada. | ponto 3 do desenho | o banco atribuiria a chave nova a quem não a pôs, o mesmo defeito que o R1 quer fechar |
| **S5** | **Informativo** | O log é o **único** histórico da troca, e vai para stdout do contêiner. Não há handler que o exporte (`grep add_handler` em `config/` e `lib/` volta vazio). A retenção depende do Dokploy e do driver de log do Docker. | `config/prod.exs:34`, `access_events.ex` | se o log cai num redeploy, "reconstruir depois" vale só para o que aconteceu desde o último deploy. É o limite de todo o H4, e não deste desenho |

## As condições, cada uma verificável em teste

Todas valem para `test/the_band/ai_test.exs` ou um teste novo de `AI.put/3` e `AI.delete`, com
`capture_log` no nível padrão do teste (`:warning`). Cada uma deve ser **vista reprovando** com o
defeito injetado antes de ser aceita (AGENTS.md §14.0). Segredos de teste são strings óbvias de
teste, nunca chave real.

1. **A remoção emite evento com ator (S1).** `AI.delete/3` passa a receber o ator, e o chamador
   em `ai_live/index.ex:120` passa `current_user.id`. O evento usa o mesmo nome e as mesmas guardas,
   com um quarto átomo (`:removida`) ou com função própria. Teste: grava K, apaga com o ator A,
   assere uma linha com `ato=:removida`, o `tenant_id` e `actor_user_id` de A. Depois grava K2
   com o ator B e assere a linha `:primeira`. A sequência das duas é o que reconstrói. Apagar
   sem linha (`{:error, :not_found}`) **não** emite. *Defeito a injetar:* tirar a chamada de
   `delete/2`.
2. **O evento sai em `:warning`, com assinatura fechada (S2).** A função nova segue a forma de
   `conta_da_organizacao/5` (`access_events.ex:253`): guardas `ato in [...]`,
   `is_binary(tenant_id)`, `is_binary(actor_user_id) or is_nil(actor_user_id)`, **sem** `extra`
   keyword, e passa por `registrar("ato administrativo", ...)`. Testes: (a) `capture_log` sem
   mudar o nível captura a linha; (b) `chave_do_modelo_gravada(:outro, t, u)`,
   `chave_do_modelo_gravada("troca", t, u)` e `chave_do_modelo_gravada(:troca, t, %{id: u})`
   levantam `FunctionClauseError`. *Defeitos a injetar:* trocar o nome do evento por um fora da
   lista de `:warning`, e afrouxar uma guarda para `is_atom/1`.
3. **As três classificações, e o declarante de cada uma.** O ator A grava K: `ato=:primeira` e
   `declared_by_user_id == A`. O ator B grava K: `ato=:mesma_chave`, `actor_user_id` de B, e
   `declared_by_user_id` **continua A**. O ator B grava K2: `ato=:troca` e `declared_by_user_id ==
   B`. Cada caso assere exatamente uma linha do evento. *Defeitos a injetar:* classificar só por
   `anterior.id == nil` (tudo vira `:troca`), e tirar o `change/2` do declarante.
4. **O evento só depois do commit.** Com o duplo de `verify/2` aceitando, grava um segredo que
   passa no provedor e reprova no changeset (abaixo de 20 caracteres, `provider_credential.ex`,
   `validate_length`): `{:error, %Ecto.Changeset{}}` e `refute log =~ "chave_do_modelo"`. Com o
   duplo recusando: `{:error, {:rejeitada, _}}` e nenhuma linha do evento. *Defeito a injetar:*
   emitir antes do `insert_or_update`.
5. **Nenhuma parte do segredo na linha.** Nos três ramos e na remoção, com `capture_log` e o
   nível em `:debug`: `refute log =~ chave`, `refute log =~ String.slice(chave, 0, 8)`, e
   `refute log =~ "last_four"`. Use uma chave de teste que termine em caracteres fora do
   hexadecimal (por exemplo `wxyz`) e asserte `refute linha_do_evento =~ "wxyz"`. Com sufixo
   hexadecimal, a asserção casaria por acaso com os UUIDs da linha e reprovaria sem defeito.
   *Defeito a injetar:* acrescentar `last_four: cred.last_four` aos campos do evento.
6. **O evento não atravessa tenants.** Dois tenants povoados, cada um com seu usuário. B guarda
   K. A, sem linha, grava K: o ato de A é `:primeira`. A grava J e depois K: `:troca`. Antes de
   asserir, confirme que as duas linhas existem (`AI.fetch/1` devolve `{:ok, _}` para A e B). Em
   todo o log capturado, `refute log =~ tenant_b.id`, e a linha de B no banco continua igual
   (`declared_by_user_id`, `secret_set_at`, `updated_at`). *Defeito a injetar:* `existente/2`
   buscando sem `tenant_id`, só por `provider`.
7. **Uma classificação só (S3).** A mesma variável decide as datas e o evento. Teste: em cada
   ramo, a linha do evento e as datas concordam. `:mesma_chave` implica `secret_set_at`
   inalterado. `:troca` implica `secret_set_at` novo e `previous_secret_set_at` igual à data
   anterior. *Defeito a injetar:* uma segunda chamada a `mesma_chave?/2` com um dos argumentos
   trocado (por exemplo, comparando com `attrs["secret"]` antes do `trim` ou do `||`).
8. **Ator nil não suprime o evento.** `AI.put(tenant, %{"secret" => k})` sem ator emite a linha
   com `actor_user_id=nil`. *Defeito a injetar:* `if user_id, do: emitir(...)`.
9. **`change/2`, nunca `force_change/3`, para o declarante (S4).** Não há teste barato de
   concorrência real. Exija na revisão, e registre no comentário do código **por que** é
   `change/2`. A forma testável é o caso degenerado: a mesma chave regravada pelo próprio
   declarante não produz mudança em `declared_by_user_id` no changeset. Revisor confere.

Toda condição muda ou estende contrato. Pela regra de "contrato antes da implementação", o
contrato de `put/3` em `specs/064-segredo-em-repouso/contracts/idade-da-credencial.md` (seção
"O que muda em `AI.put/3`") ganha a classificação e o declarante, e a assinatura nova de
`delete` entra no mesmo lugar, **antes** do código.

## Recomendações fora de escopo (issue própria, não condicionam esta correção)

| # | Severidade | O que é | Proposta |
|---|---|---|---|
| **R-a** | Baixo | `put/3` aceita gravar sem ator (`user_id \\ nil`). | Tornar o ator obrigatório, ajustando os testes que o omitem. Hoje o único chamador de produção o passa. |
| **R-b** | Baixo (R3 do C.1) | A recusa do provedor não deixa rastro. O formulário funciona como verificador de chaves sem limite. | Evento `:chave_do_modelo_recusada` com **só o átomo** do motivo e o ator. Nunca a string do provedor (ver a análise acima). Avaliar limite por ator depois de medir o uso. |
| **R-c** | Informativo | A troca do `default_model` sem troca de chave sai como `:mesma_chave`, sem dizer que o modelo mudou. O modelo decide o custo. | Se for útil, incluir no evento um booleano `modelo_alterado`. Não é dado sensível. |
| **R-d** | Informativo (S5) | Retenção do log de acesso em produção. | Medir quanto tempo o log de `docker logs` sobrevive a redeploy no Dokploy. Se for curto, todo o H4 tem o mesmo limite, e a resposta é exportar (o épico de observabilidade com SigNoz é o lugar), e não tabela de evento só para esta feature. |
| **R-e** | Baixo | O `log: false` de `ai.ex:164` virou redundante desde #1222, e o comentário ao lado ainda o descreve como a defesa. | Corrigir o comentário para apontar `TheBand.Repo.LogDaConsulta`. Manter o `log: false` não faz mal. |

## O que NÃO foi verificado

- **nenhum teste, `mix sobelow`, `mix hex.audit`, `mix deps.audit` nem `mix gates` rodou.** O
  pedido era o parecer antes do código, e o código não existe;
- **a retenção do log em produção** (Dokploy, driver de log do Docker, redeploy). A promessa
  "reconstruir depois de um incidente" depende dela, e ela não foi medida (S5, R-d);
- **se `Phoenix.LiveView.Logger` está anexado no ambiente de teste.** A filtragem de `"secret"`
  foi verificada **lendo** `logger.ex` e `Phoenix.Logger.filter_values/1` da versão travada, e não
  vista num log real. Se o logger não estiver anexado, o `refute` de `mesma_chave_test.exs` passa
  sem ter medido esse caminho;
- **o comportamento de `Ecto.Changeset.change/2` e do `cast` com o tipo `TheBand.Encrypted.Binary`
  ao comparar valor igual.** A análise da concorrência supõe que o valor igual ao do `data` é
  descartado, que é o comportamento documentado do Ecto com `equal?/2` padrão. Não conferi se o
  tipo cifrado define `equal?/2` próprio;
- **a mensagem de erro real da OpenAI** para chave recusada. A afirmação de que ela cita a chave
  mascarada pelo provedor vem de conhecimento da API, e não de resposta medida nesta base;
- **`TheBand.Tenants.Access.operacional?/2`.** Li só a rota (`router.ex:361-375`). Quem chega a
  `/ai` foi tomado do parecer do C.1 e do comentário do router, não reverificado;
- **o comportamento com a chave mestra perdida.** `existente/2` usa `fetch/2`, que decifra, e
  levantaria antes de qualquer classificação. Não há evento nesse caso, e a falha é ruidosa, o
  que está certo. Não verifiquei se o erro chega ao log com algo além do nome da exceção;
- **`/tools` e as credenciais de ferramenta.** Têm o mesmo tipo de pergunta (quem trocou a
  credencial de uma fonte) e não fazem parte deste desenho. Não foram lidos para isso.
