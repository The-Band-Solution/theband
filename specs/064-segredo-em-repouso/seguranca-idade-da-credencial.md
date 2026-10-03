# Avaliação de segurança — a idade da credencial (064/T017 e T019)

**Feita em 2026-10-03, antes do código**, pelo agente `security`, que não escreveu o desenho
(AGENTS.md §14.0). Objeto: `contracts/idade-da-credencial.md` (FR-016, FR-018 e FR-019), lido
contra `lib/the_band/ai.ex` (`put/3`, `fetch/2`, `origem_da_chave/1`),
`lib/the_band/ai/provider_credential.ex`, `lib/the_band/sources.ex` (`add_credential/3`,
`credenciais_sem_segredo/0`) e `lib/the_band/sources/tool_credential.ex`. Leitura de código e de
contrato; nenhuma ferramenta rodou, porque não há código novo ainda.

## Veredito

**Pode seguir.** Nenhum achado alto ou crítico. Os achados 1 e 2 (média) entram como obrigação
da própria T019, com o teste correspondente, e não como item posterior.

## Achados

### 1. Média — a comparação pode vazar o segredo pelo relatório de erro (A09, ASVS V7)

- **Onde**: `AI.put/3` (`lib/the_band/ai.ex:97`), na comparação nova. Na primeira gravação o
  `existente/2` devolve `%ProviderCredential{}`, cujo `secret` é `nil`.
- **O que é**: `Plug.Crypto.secure_compare/2` só tem cláusula para dois binários. Chamá-la com
  `nil` levanta `FunctionClauseError`, e o relatório de falha do processo (LiveView) **imprime os
  argumentos** — entre eles a chave nova, em claro. O `redact: true` do schema não protege um
  binário solto. O caminho: qualquer pessoa que grava a primeira chave de um tenant derruba o
  processo e põe a chave no log.
- **O que o código deve fazer**: a decisão "mesma chave?" numa função privada com cláusula
  própria para `secret: nil` (devolve "diferente", sem chamar `secure_compare`), e a chamada a
  `secure_compare/2` só com dois binários. Comparar com `==` não é a correção — o contrato acerta
  em exigir `secure_compare`. O resultado é booleano interno: não vai para log, telemetria nem
  retorno.
- **Teste**: a primeira gravação de um tenant devolve `{:ok, cred}` com `secret_set_at`
  preenchido e `previous_secret_set_at` `nil` — que reprova, com `FunctionClauseError`, se a
  cláusula do `nil` for removida.

### 2. Média — a data da troca não pode ser recebida do chamador (A04, ASVS V1/V5)

- **Onde**: `ProviderCredential.changeset/2` (`lib/the_band/ai/provider_credential.ex:58`), o
  `cast` genérico.
- **O que é**: se `secret_set_at` e `previous_secret_set_at` entrarem na lista do `cast`, a
  garantia de que são calculadas passa a morar só em `put/3` — o mesmo desenho frágil que o
  `base_url` já tem. Um segundo chamador, ou um `attrs` vindo de formulário, poderia gravar uma
  data recente e **esconder uma credencial vencida**. Isso anula a FR-016 em silêncio.
- **O que o código deve fazer**: `put/3` monta os atributos a partir de valores calculados, e
  nunca de `attrs`, como já faz com `base_url`. O melhor é gravar as duas datas com
  `put_change/3`, num changeset ou função própria, fora do `cast` que recebe entrada.
- **Teste**: `AI.put(tenant, %{"secret" => …, "secret_set_at" => ~U[2099-01-01 00:00:00Z],
  "previous_secret_set_at" => …})`. A asserção lê o banco (`AI.fetch/1`) e confirma que a data
  gravada é a calculada, e não a recebida.

### 3. Média — a chave do ambiente (`API_KEY`) não tem idade e não está no contrato (FR-016)

- **Onde**: `AI.origem_da_chave/1` (`lib/the_band/ai.ex:51`) e
  `lib/the_band/integrations/llm/http/req.ex:84`.
- **O que é**: a FR-016 diz "toda credencial de terceiro". O tenant sem chave própria usa a
  `API_KEY` do processo, que é compartilhada entre tenants e não tem linha nem data. O contrato
  cobre `ToolCredential` e `ProviderCredential` e não fala dela. O risco: a tela da T018
  mostrar "no prazo", ou não mostrar nada, para a chave de maior alcance.
- **O que fazer**: o contrato declara, em "O que não muda", que a chave do ambiente fica fora de
  `Idade`, com o motivo, e que a tela a apresenta como *idade desconhecida* (FR-019), nunca como
  no prazo. A rotação dela é operacional (do ambiente/Dokploy). Não bloqueia a T017/T019; vira
  obrigação da T018.

### 4. Baixa — `:idade_desconhecida` está bem fechado no contrato; falta só fechar no consumidor (FR-019)

- **Onde**: `TheBand.Credenciais.Idade.estado/2` e quem consumir o estado (T018).
- **O que é**: o contrato já fecha bem a ausência: sem booleano, sem "dias restantes", e `nil`
  cai em `:idade_desconhecida`. A credencial de ferramenta lida por `credenciais_sem_segredo/0`
  carrega `validated_at` no `select` (`lib/the_band/sources.ex:44`), então a idade não some na
  leitura sem segredo. Se alguém tirar o campo do `select`, o erro cai no lado seguro
  (desconhecida). O que resta aberto é o consumidor: um `case` com `_ ->` no fim reintroduz o
  fallback.
- **O que o código deve fazer**: `estado/2` com uma cláusula explícita por caso e **sem**
  cláusula-coringa. O teste 2 do contrato (`refute == :no_prazo` para `nil`) já é a guarda certa,
  e deve ser visto reprovando com o defeito injetado. Na T018, o `case` sobre o estado enumera os
  três átomos.

### 5. Informativo — o que foi avaliado e não precisa de mudança

- **Comparação como oráculo**: não funciona como oráculo. A comparação só acontece **depois** de
  `HTTP.impl().verify/2` aceitar a chave nova, então quem a usa já tem uma chave válida. E a
  gravação substitui a chave guardada nos dois casos. Saber se ela era igual à anterior não dá
  nada a quem já pode sobrescrevê-la, e o `last_four` já é exibido a quem administra. **Ordem
  obrigatória**: verificar antes de comparar. Inverter a ordem faria `put/3` responder, para uma
  chave inválida, se ela é a guardada.
- **Timing**: `secure_compare/2` é de tempo constante para tamanhos iguais, e revela só o
  tamanho, o que é irrelevante aqui. O custo do `verify` remoto domina a medida de tempo de
  qualquer forma.
- **Decifragem**: `existente/2` já decifra o segredo hoje, então a comparação não abre leitura
  nova. Com chave mestra perdida, o `fetch` levanta como já levanta, e isso não é fallback
  silencioso.
- **(b) As colunas novas**: `secret_set_at` e `previous_secret_set_at` são metadado não secreto.
  Revelam a cadência de troca, e nada do valor nem de derivado dele. Viajar em backup é aceitável
  e não exige cifragem. Basta `:utc_datetime` comum, como `validated_at`. Não precisam de
  `redact`.
- **Coleta não consulta `estado/2`**: está correto do ponto de vista de disponibilidade
  (FR-016: pedir, não impedir).

## O que NÃO foi verificado

- nenhum código novo existe: esta avaliação é do desenho. A implementação precisa de revisão
  própria contra os achados 1 e 2;
- não rodei `mix sobelow`, `mix hex.audit` nem `mix gates`;
- não li a migração, que ainda não existe. A reversibilidade e o fato de não preencher linhas
  existentes ficam para a revisão do PR;
- não avaliei a tela da T018 (FR-017): ela espera protótipo, e é lá que os achados 3 e 4 se
  cumprem;
- não conferi se `AI.put/3` tem guarda de acesso nos chamadores (`ai_live/index.ex`). Está fora
  do escopo desta mudança, que não altera quem pode chamar;
- concorrência: duas gravações simultâneas no mesmo tenant podem registrar a
  `previous_secret_set_at` de uma delas. Não há impacto de segurança no desenho atual, e não
  testei.
