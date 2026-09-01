# Contrato — A primeira conta nasce do ambiente

Feature 052. Este contrato decide o comportamento; se a implementação mostrar que
ele errou, a correção é aqui, **no mesmo commit**, com a razão escrita.

## Os quatro valores

| variável | obrigatória | o que é |
|---|---|---|
| `THE_BAND_TENANT_NOME` | sim | nome legível da organização |
| `THE_BAND_TENANT_SLUG` | sim | identificador estável da organização |
| `THE_BAND_ADMIN_EMAIL` | sim | e-mail de entrada da primeira pessoa |
| `THE_BAND_ADMIN_SENHA` | sim | senha da primeira pessoa |

`THE_BAND_ADMIN_NOME` é **opcional**: sem ela a conta nasce sem nome, e a pessoa
o preenche depois em `/profile`. Nome ausente não impede entrar; e-mail ausente
impede.

A lista é **fechada**. Valor novo aqui é mudança de contrato, não detalhe de
implementação.

## A função de domínio

```
TheBand.Tenants.Bootstrap.criar_primeira_conta(ambiente \\ &System.get_env/1)
```

O parâmetro existe para o teste injetar os valores sem tocar no ambiente do
processo — `System.put_env/2` num teste assíncrono vaza para os outros.

### O que ela devolve

| retorno | quando |
|---|---|
| `{:ok, :criada, %{email: e, slug: s}}` | não havia administrador, os quatro valores presentes e válidos |
| `{:ok, :ja_existe}` | havia ao menos uma pessoa com marca de administração |
| `{:error, {:faltando, [atom]}}` | um ou mais valores obrigatórios ausentes ou vazios — a lista traz **todos** os que faltaram, não o primeiro |
| `{:error, %Ecto.Changeset{}}` | valor presente recusado pelas regras que já valem |

**A senha NUNCA aparece no retorno.** Nem em `:criada`, nem no changeset de erro
— o changeset devolvido tem o campo virtual limpo. Isso é invariante do contrato,
e tem teste próprio: manter a proteção no formato do dado, e não na disciplina de
quem escreve o `IO.puts`.

### O que ela garante

1. **Uma consulta no caminho comum.** Instalação já feita: pergunta se existe
   administrador, recebe que sim, e para. Não lê o ambiente, não abre transação.
2. **A pergunta é "existe algum administrador"**, nunca "existe este e-mail".
3. **Ato único.** Organização e conta nascem na mesma transação. Falha em
   qualquer ponto não deixa nada.
4. **Organização existente é reaproveitada.** Slug já presente: a conta nasce
   dentro dela, sem tentar criar uma segunda.
5. **A recusa vem dos changesets que já existem** — `Tenant.changeset/2`,
   `User.changeset/2`, `User.senha_changeset/3`. Nenhuma validação nova, para não
   haver duas fontes que divirjam.
6. **Violação de unicidade é lida como `:ja_existe`.** Duas subidas simultâneas
   tentam o mesmo slug e o mesmo e-mail; o banco deixa uma passar, e a outra trata
   a recusa como instalação já feita — não como erro.

## O chamador, no release

```
TheBand.Release.semear_primeira_conta()
```

Chamada pelo `rel/entrypoint.sh`, na linha seguinte a `Release.migrate()`.

Traduz o relator em uma frase e imprime. **Nunca derruba o contêiner** — os
quatro casos terminam com a plataforma subindo.

| retorno | frase | saída |
|---|---|---|
| `:criada` | `primeira conta criada: <email>, admin de <slug>.` | 0 |
| `:ja_existe` | `já existe administrador — nada a criar.` | 0 |
| `{:faltando, vars}` | `sem <VAR1>, <VAR2> — nenhuma conta criada. A plataforma sobe vazia.` | 0 |
| changeset | `primeira conta recusada: <campo> <motivo>. A plataforma sobe vazia.` | 0 |

O `set -e` do entrypoint derruba o contêiner em qualquer passo que falhe. Por
isso esta chamada **não pode** sair diferente de zero: a ausência dos valores é
caso previsto, e derrubar por ela transformaria uma variável esquecida em
produção fora do ar — pior que o problema original.

Contraste deliberado com `DATABASE_URL`, cuja ausência **derruba**: sem banco,
subir significaria servir telas com zero em tudo, indistinguível de "ainda não
coletamos nada". Sem primeira conta, a plataforma está correta e apenas vazia.

## Os testes que provam o contrato

| invariante | prova |
|---|---|
| cria quando não há admin | criar com banco vazio devolve `:criada`, e há 1 organização e 1 admin |
| não cria quando há admin | com admin existente, devolve `:ja_existe` e a contagem não muda |
| e-mail diferente não cria segundo | admin existente + e-mail novo nas variáveis → `:ja_existe` |
| senha trocada sobrevive | trocar a senha, rodar cinco vezes, e a senha trocada continua valendo |
| ausência nomeia todas | faltando duas variáveis, a lista traz as duas |
| recusa vem do changeset existente | senha de 11 caracteres → erro do `senha_changeset`, nada criado |
| ato único | falha na conta não deixa organização |
| organização existente é reaproveitada | slug já presente + sem admin → conta nasce nela, 1 organização ao fim |
| a senha não vaza | nem `:criada` nem o changeset de erro carregam a senha |
| corrida | duas chamadas concorrentes → um admin ao fim, a segunda com `:ja_existe` |
