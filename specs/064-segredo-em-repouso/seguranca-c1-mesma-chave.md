# Parecer de segurança — o aviso da mesma chave (064/T018, item C.1, #883)

**Feito em 2026-10-03, antes do código**, pelo agente `security`. Ele não escreveu o desenho
(AGENTS.md §14.0). O objeto é o flash da tela 2f do protótipo
(`prototipo/credential-age.html`), a linha 2.8 e o item C.1 de `prototipo/PROMPT.md`, e a decisão
Q4 (a) de `prototipo/README.md`. Quem grava de novo a **mesma** chave em `/ai` lê:

> Key checked against the provider and saved (••••<4>). It is the key already registered, so it
> still counts from <data>.

A leitura foi feita contra `lib/the_band/ai.ex` (`put/3`, `data_da_troca/3`, `mesma_chave?/2`),
`lib/the_band/ai/provider_credential.ex`, `lib/the_band/credenciais/idade.ex`,
`lib/the_band_web/live/ai_live/index.ex`, `lib/the_band_web/router.ex:329-354`,
`lib/the_band_web/live/hooks.ex:74-100`, `config/config.exs:90` e o achado 5 de
`seguranca-idade-da-credencial.md`. É leitura de código. Nenhuma ferramenta nem teste rodou.

## Veredito

**Concorda com condições.** O flash pode entrar se as seis condições abaixo forem cumpridas e
cada uma estiver guardada por um teste. Sem elas, vale o flash de sempre, e o QA reprova a frase
(C.1).

**Severidade do risco do oráculo: informativo.** Nenhum caminho de exploração dá a alguém algo
que ele ainda não tinha. As condições existem para que isso **continue** verdadeiro depois da
implementação. A condição 3 é a exceção: ela corrige um defeito real, já aberto, que faria a
frase mentir.

## A análise, pergunta por pergunta

| Pergunta | Resposta, e como foi verificada |
|---|---|
| **Quem chega à tela?** | **Não é só quem administra.** `/ai` está na `live_session :operacao` (`router.ex:352`), com `require_operacao` no pipeline e no `on_mount` (`hooks.ex:74`). Entra quem administra e também quem tem **concessão `organization` vigente**. A pessoa mantenedora decidiu isso em 2026-08-28 (comentário em `router.ex:345-351`). A chave é uma só por tenant, então quem responde por uma única organização também opera a chave do tenant inteiro. O `@moduledoc` de `ai_live/index.ex:5` ainda diz "Só perfil `admin`" e está desatualizado (R2 abaixo). |
| **Essa pessoa pode SUBSTITUIR a chave?** | Pode. `AI.put/3` sobrescreve a linha, e a LiveView é o único chamador (`ai_live/index.ex:34`). |
| **Pode LER a chave?** | Não. A tela mostra só `masked/1` (`••••` + `last_four`, `provider_credential.ex:53`). O campo é `redact: true` (`:27`) e `"secret"` está em `filter_parameters` (`config/config.exs:90`). O oráculo **não** se torna leitura, porque não há como enumerar a chave (próxima linha). |
| **O oráculo dá algo novo?** | Não, por três razões. **(1)** A comparação só acontece **depois** de `HTTP.impl().verify/2` aceitar o valor (`ai.ex:102` antes de `:121-123`). Logo, quem pergunta já tem uma chave **válida** no provedor. Uma chave inválida recebe "refused", com ou sem a frase nova, e isso inclui a chave guardada se o provedor a tiver revogado. **(2)** A pergunta **destrói a própria resposta**: quando o candidato válido é diferente, ele substitui a chave guardada. Testar uma lista de candidatos troca a chave do tenant já no primeiro erro, de forma visível (o `last_four` e a data mudam no cartão). Não existe varredura silenciosa. **(3)** A informação já está na tela sem o flash: depois de gravar, o cartão mostra o mesmo `last_four` e a mesma data "key registered" (D9). Os dois juntos, inalterados, **são** a resposta. O flash só diz em palavras o que o cartão já mostra. |
| **A comparação é em tempo constante?** | É. `Plug.Crypto.secure_compare/2` (`ai.ex:144-145`) recebe dois binários, e o caso `nil` tem cláusula própria (`:147`, achado 1 da avaliação anterior). O tempo vaza só se os tamanhos são iguais, e isso não serve para nada aqui. O `verify` remoto domina qualquer medida de tempo. A frase **não** introduz comparação nova se for decidida pelas datas, como manda a condição 2. |
| **Limite de tentativas?** | Não há, e o C.1 não precisa de um. Cada tentativa custa uma chamada ao provedor e exige uma chave válida. Uma chave de API do provedor não é adivinhável por força bruta, e o oráculo nem responde para chave inválida. A ausência de limite **no formulário** é um ponto anterior e separado (R3). |
| **O ato é registrado?** | Não. `ai.ex` e `ai_live/index.ex` não têm `Logger` nem telemetria. A única marca é `declared_by_user_id`, e `put/3` **a sobrescreve mesmo quando a chave é a mesma** (`ai.ex:113`). Esse defeito é anterior ao C.1 e não fica pior com ele (R1). A frase em si não pede log. Se alguém registrar o ato, registra a classificação (primeira / troca / mesma chave) e nunca o valor. |
| **A frase vaza algo para outro tenant?** | No desenho atual, não. `fetch/2` filtra por `tenant_id` (`ai.ex:32-35`). O flash vai só para o socket de quem gravou (`put_flash`, sem `PubSub` no arquivo). A data citada é a da linha do próprio tenant. O caso a guardar é o de dois tenants que usam **a mesma** chave do provedor (uma conta compartilhada): a frase não pode responder "é a mesma" comparando com a linha do vizinho (condição 5). |

## As condições, cada uma verificável em teste

Todas valem para o teste de LiveView de `/ai` ou de `AI.put/3`. Cada uma deve ser **vista
reprovando** com o defeito injetado antes de ser aceita (AGENTS.md §14.0).

1. **Conferir antes de comparar.** Com o duplo de `verify/2` recusando o próprio valor guardado,
   o envio desse valor mostra a recusa e **não** contém `already registered`. O banco fica
   inalterado: `secret_set_at` e `validated_at` iguais aos de antes. Defeito a injetar: a
   comparação feita antes do `with`.
2. **A decisão vem do estado do servidor, nunca da requisição.** A frase sai da comparação entre
   a data em uso **antes** (lida do banco, no tenant corrente, no mesmo evento) e
   `Idade.em_uso_desde/1` do registro devolvido por `put/3`. Ela não sai de campo do formulário
   nem de uma segunda comparação do segredo. Teste: enviar uma chave **diferente** com parâmetros
   extras hostis (`"same_key" => "true"`, `"secret_set_at" => "2026-01-01T00:00:00Z"`). O flash é
   o de troca, `refute =~ "already registered"`, e a data gravada é a calculada.
3. **A linha legada não zera a idade, e a frase não mente sobre ela.** Este é o defeito registrado
   em `prototipo/README.md` ("O que o protótipo descobriu"). Uma linha com `secret_set_at` nulo e
   `validated_at` de quatro meses atrás, regravada com a mesma chave, precisa manter
   `Idade.em_uso_desde/1` igual ao `validated_at` antigo. `Idade.estado/2` continua `:vencida`, e o
   flash cita **aquela** data. Hoje `put/3` grava `validated_at: agora` e a idade zera. Com a
   frase, a tela afirmaria "still counts from <hoje>" para uma chave vencida, o que é o achado 2
   da avaliação anterior (a cobrança vencida escondida) por outra porta. **O conserto vem antes da
   frase.** Defeito a injetar: retirar o conserto.
4. **Nenhuma parte do segredo além dos quatro últimos.** Em todos os ramos (primeira, troca,
   mesma), `refute html =~ chave` e `refute html =~ String.slice(chave, 0, 8)`. A frase só pode
   interpolar `masked/1` e a data. Nada da comparação vai para `Logger` nem para telemetria.
   Teste com `capture_log` em nível `:debug`, `refute log =~ chave`.
5. **A comparação não atravessa tenants.** Dois tenants povoados: o B guarda a chave K e o A
   guarda J. O A grava K, e o duplo aceita K. O flash do A é o de **troca**
   (`refute =~ "already registered"`), a linha do A passa a ter `secret_set_at` novo e
   `previous_secret_set_at` igual à data de J, e a linha do B continua byte a byte igual. Antes de
   asserir, confirme que as duas linhas existem (`AI.fetch/1` devolve `{:ok, _}` para as duas).
6. **A frase só aparece quando a chave é a mesma.** Primeira gravação e troca por chave diferente:
   `refute =~ "already registered"`. Mesma chave: `assert =~ "already registered"` e a data é a
   de antes. É o par que impede a frase de virar o flash padrão por engano.

## Recomendações fora do C.1 (não condicionam o flash)

| # | Severidade | O que é | Onde | Proposta |
|---|---|---|---|---|
| **R1** | Média (A09, ASVS V7) | A troca da chave do tenant não deixa evento. `declared_by_user_id` é sobrescrito até quando a chave é a mesma, e "quem pôs esta chave" passa a significar "quem gravou por último". Depois de um incidente, não dá para reconstruir quem trocou a chave nem quando. | `ai.ex:107-124` | Registrar a classificação do ato (primeira / troca / mesma), com `tenant_id` e quem fez, nunca o valor. Manter `declared_by_user_id` quando a chave é a mesma, ou separar "quem registrou o segredo" de "quem mexeu por último". Issue própria. |
| **R2** | Baixa | O `@moduledoc` diz que `/ai` é só para admin, mas a rota é operacional. Um revisor que confia no comentário avalia a superfície errada. | `ai_live/index.ex:5` | Corrigir o texto citando a decisão de 2026-08-28. |
| **R3** | Informativo | O formulário confere qualquer chave do provedor e, no erro de modelo, lista até oito modelos que ela alcança. Para quem opera, ele funciona como verificador de chaves alheias, sem limite de tentativas. É anterior à 064, e o C.1 não muda isso. | `ai.ex:102`, `ai_live/index.ex:82-93` | Avaliar se cabe registrar o uso (R1) ou limitar. Não bloqueia nada. |

## O que NÃO foi verificado

- nenhum teste, `mix sobelow`, `mix hex.audit` nem `mix gates` rodou. O pedido era só o parecer,
  e o código da T018 ainda não existe;
- não li `TheBand.Tenants.Access.operacional?/2`, só onde ele é chamado. Não conferi se o recorte
  por organização tem algum efeito em `/ai`. Pelo comentário do router, não tem;
- não conferi a implementação de `Plug.Crypto.secure_compare/2` na versão travada em `mix.lock`
  (`deps/` não está neste worktree). A afirmação de tempo constante vem da documentação da
  biblioteca;
- não verifiquei se o `Phoenix.Logger` do LiveView aplica `filter_parameters` aos parâmetros de
  `handle_event` na versão em uso. `"secret"` está na lista, mas isso não foi visto num log real;
- não avaliei concorrência: duas gravações simultâneas no mesmo tenant podem fazer a frase
  descrever uma chave que já não é a guardada. O efeito é de correção, sem ganho de informação;
- não avaliei `/tools`: a credencial de ferramenta troca por linha nova e não tem o caso "mesma
  chave".
