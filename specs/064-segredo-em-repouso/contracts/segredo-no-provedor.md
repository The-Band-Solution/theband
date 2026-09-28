# Contrato — a chave do provedor de modelos viaja fechada (064/T006, FR-006)

**Escrito em 2026-09-28, antes do código.** Muda o tipo de dois `@callback` públicos de
`TheBand.Integrations.LLM.HTTP`.

## O problema, medido

`lib/the_band/integrations/llm/http/req.ex` recebe a chave do provedor como **binário nu**, e ela
atravessa quatro funções até a linha do cabeçalho (`"Bearer " <> chave`, linhas 41 e 93). Qualquer
exceção no caminho (um `FunctionClauseError`, um `MatchError`) formata os argumentos, e a chave
sai inteira no texto do erro, que vai para o log e para `oban_jobs.errors`.

É a mesma classe do defeito medido no caminho do GitHub em 2026-09-04, quando um token ficou em
texto claro em `oban_jobs.errors` por oito dias. Ali ele foi fechado pelo `TheBand.Segredo`
(#864), e aqui não.

## O que muda

| Antes | Depois |
|---|---|
| `@callback verify(secret :: String.t(), opts)` | `@callback verify(secret :: Segredo.t(), opts)` |
| `opts[:key] :: String.t() \| nil` em `complete/3` | `opts[:key] :: Segredo.t() \| nil` |
| `API_KEY` do ambiente lida como binário | embrulhada em `Segredo.novo/1` **no momento da leitura** |
| `HTTP.redigir(texto, chave :: String.t() \| nil)` | `HTTP.redigir(texto, chave :: Segredo.t() \| nil)` |
| `AI.opcoes/1` devolve `key: cred.secret` (binário) | devolve `key: Segredo.novo(cred.secret)` |
| `AI.put/3` chama `verify(secret)` com o texto do formulário | chama `verify(Segredo.novo(secret))` |

**A regra**: a chave é embrulhada **na borda em que é lida** (a credencial decifrada, o ambiente,
o formulário) e aberta com `Segredo.expor/1` **só na montagem do cabeçalho** e dentro de
`redigir/2`. Entre as duas pontas, nenhuma função tem a chave em claro na lista de argumentos.

## O que não muda

- **O valor na rede e no banco.** O cabeçalho continua `Bearer <chave>`, e a credencial continua
  cifrada em repouso, como hoje.
- **As respostas.** Os erros continuam `{:rejeitada, texto}`, `{:indisponivel, texto}`,
  `{:http, status, texto}`, e o texto continua passando por `redigir/2`.
- **Quem não olha a chave.** Os testes que fazem `expect(..., fn _secret, _opts -> …)` não mudam.

## O que a API não expõe, e por quê

`Segredo.t()` é opaco: fora de `TheBand.Segredo`, ninguém casa a struct nem lê o campo. Quem
precisa do valor chama `expor/1`, e cada chamada é um ponto de revisão. Hoje são duas nesta
borda: o cabeçalho e a redação.

## Como se prova

`test/the_band/segredo_llm_test.exs`:

1. força uma exceção no caminho que recebe a chave (`FunctionClauseError`), formata com
   `Exception.format/3` e **o texto não contém a chave**;
2. **a reinjeção**: o mesmo caminho com a chave em binário nu **vaza**. Sem ela, o primeiro teste
   passaria numa implementação que não protege nada.
