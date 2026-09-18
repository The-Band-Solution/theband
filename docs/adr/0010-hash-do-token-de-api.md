# ADR 0010 — O token de API é guardado como hash, e não cifrado como as outras credenciais

## Status

**Proposta** — 2026-09-18.

Exigida por: [`AGENTS.md` §16](../../AGENTS.md) — divergir de um padrão estabelecido da casa exige ADR. O padrão é `TheBand.Encrypted.Binary`, e **toda** credencial desta plataforma o usa.

Depende de: [ADR 0009](0009-api-publica-com-token.md) — é ela que decide abrir a API por token.

Realiza: [spec 061](../../specs/061-api-publica/spec.md), FR-003 a FR-005.

Fundamenta-se em: [avaliação de segurança de 2026-09-09](../seguranca/2026-09-09-api-com-token.md), decisão Q1.

## Contexto

A casa tem um padrão para guardar segredo em repouso, e ele é bom: `TheBand.Encrypted.Binary`, que é Cloak com AES-GCM de 256 bits, chave mestra vinda do ambiente, cifragem no `Ecto.Type` e nunca no código de aplicação. É o que protege o token do GitHub, a chave do provedor de modelo, e toda credencial de terceiro.

Aplicá-lo ao token de API seria o caminho sem atrito — e seria errado.

### As duas coisas que parecem a mesma e não são

| | credencial de **terceiro** | token de **API** |
|---|---|---|
| quem gera | o GitHub, o provedor de modelo | esta plataforma |
| o que a plataforma faz com ela | **replica** — manda de volta ao terceiro a cada chamada | **confere** — compara com o que chega |
| precisa do valor em claro depois? | **sim, sempre** | **não, nunca** |
| proteção certa | cifragem reversível | função de digestão |

**A pergunta que separa as duas é uma só: a plataforma precisa recuperar o valor?** Para o token do GitHub, sim — sem ele não há chamada. Para o token de API, não: o cliente apresenta o valor, e a plataforma só precisa saber se bate.

Guardar cifrado o que só precisa ser conferido é guardar uma porta a mais. Com a chave mestra, `TheBand.Encrypted.Binary` devolve **todos** os tokens em claro.

## Decisão

**SHA-256 do segredo, comparado com `Plug.Crypto.secure_compare/2`, e a busca feita pelo id público.**

O token tem **três partes** — `tb_api_<id_publico>_<segredo>` —, e o formato é consequência da decisão, não preferência.

## Alternativas, e por que cada uma foi recusada

### `TheBand.Encrypted.Binary` — o padrão da casa

**Recusada por ser reversível.** É a proteção certa para o que a plataforma precisa replicar, e a errada para o que ela só precisa conferir. Manter o padrão aqui aumentaria a superfície sem aumentar a garantia: um vazamento da chave mestra passaria a incluir as credenciais de entrada na própria plataforma, e não só as de saída.

**O padrão continua certo onde ele está.** Esta ADR não o enfraquece; delimita.

### `Bcrypt.hash_pwd_salt/1` — o hash "mais forte"

**Recusada por custo e por busca.** São **~100 ms por verificação**, medidos e declarados no próprio `mix.exs`. Esse custo *é* a proteção contra senha humana de baixa entropia, onde o atacante percorre dicionário; numa API que atende requisição atrás de requisição, é auto-negação de serviço.

E há um segundo motivo, menos óbvio: bcrypt tem sal por linha, então **não dá para buscar por índice**. Conferir exigiria carregar candidatos e testar um a um.

**O que decide é a entropia da entrada, não a preferência pelo hash mais forte.** São 32 bytes de gerador criptográfico — 256 bits. Não há dicionário a percorrer, e o alongamento de chave não protege contra nada que exista aqui.

## As duas consequências que a decisão arrasta, e a segunda é fácil de errar

### A comparação tem de ser em tempo constante

Hoje a sessão compara token com `==`, e **está correta**: o valor vem de cookie assinado pelo próprio servidor, e sem a assinatura não se itera valor para medir tempo.

Na API o valor vem **cru de um cabeçalho controlado por quem chama**. O canal de tempo é alcançável, e `Plug.Crypto.secure_compare/2` é obrigatório.

### A busca tem de ser pelo id público, e nunca pelo hash

`where: t.token_hash == ^hash` entrega a comparação ao **Postgres**, fora do nosso controle de tempo — e desfaz a garantia anterior no mesmo gesto que parecia cumpri-la.

**É por isso que o token tem duas partes além do prefixo.** O id público é indexado e único, e é por ele que a linha é achada; o segredo é conferido em memória, em tempo constante.

## Consequências

**O que melhora.** Um vazamento do banco não devolve token nenhum. A verificação custa um SHA-256 — microssegundos —, e a API aguenta requisição em série.

**O que piora.** O token fica mais comprido, e o parser precisa de formato fixo com teste para cada entrada malformada. O id público é um dado a mais que vaza em qualquer log de cabeçalho — então **log de cabeçalho `Authorization` não pode existir**, e isso passa a ser invariante, não recomendação.

**O que o esquema perde de graça.** Não há como recuperar um token perdido: o caminho é revogar e gerar outro. É o comportamento certo, e a tela precisa dizê-lo no momento em que mostra o valor.

**O que a casa ganha além deste token.** A pergunta que separa os dois casos — *a plataforma precisa recuperar o valor?* — passa a ser a pergunta padrão para todo segredo novo. Ela é mais útil que "qual hash é mais forte", que é a pergunta que leva a bcrypt numa API.
