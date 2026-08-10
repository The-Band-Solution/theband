# Contrato — gerenciar credenciais

**Feature**: 003 · **Requisitos**: FR-015 a FR-018, FR-026 · **Research**: [R3](../research.md)

Complementa o [contrato da feature 001](../../001-github-eo-ingestion/contracts/connected-tools.md), que já define conectar, acrescentar e ativar/desativar — e que já declara qual credencial a coleta usa, com a ordem determinística.

## API pública

Módulo: `TheBand.Sources`.

```elixir
@spec rename_credential(Tenant.t(), ToolCredential.t(), label :: String.t()) ::
        {:ok, ToolCredential.t()} | {:error, Ecto.Changeset.t()}

@spec destroy_credential(Tenant.t(), ToolCredential.t()) ::
        {:ok, ToolCredential.t()} | {:error, :last_active_credential}

@spec clear_needs_attention(Tenant.t(), ConnectedTool.t()) ::
        {:ok, ConnectedTool.t()} | {:error, Ecto.Changeset.t()}
```

`clear_needs_attention/1` já existe da feature 001 e passa a receber o tenant
explicitamente — hoje ela aceita só a ferramenta, e uma função de escrita sem tenant é
uma função em que o escopo depende de quem chama lembrar.

## `rename_credential/3` — só o rótulo

Altera **exclusivamente** `label`. O segredo, os escopos, `validated_at` e `last_four`
permanecem.

**Por que a restrição é explícita.** Renomear não revalida. Se a mesma função aceitasse
o segredo, um rótulo trocado atualizaria `validated_at` e a ferramenta pareceria ter sido
validada agora — a data de validação é o que a ordem de escolha de credencial usa como
primeiro critério de desempate, e mexer nela mudaria qual credencial a coleta usa.

Quem quer trocar o segredo acrescenta outra credencial e desativa esta. É o caminho que
a feature 001 já definiu, e ele preserva qual credencial coletou o quê.

## `destroy_credential/2` — apaga, não desativa

Apaga a linha. Depois disso não existe o segredo cifrado, nem o rótulo, nem os escopos.

**Recusa a última credencial ativa** de uma ferramenta cuja observação está vigente, com
`{:error, :last_active_credential}`. FR-017, e a razão é evitar um estado que a
plataforma não sabe descrever: ferramenta observada e sem como coletar não é observada
nem encerrada — a coleta falharia com `:no_active_credential` a cada tentativa, e o
registro diria que a origem está com problema quando o problema é de configuração.

A mensagem diz o caminho: **encerrar a observação** é como se para de coletar.

**Erro nomeado, não changeset.** `:last_active_credential` é uma condição do domínio, não
de validação de campo, e a tela precisa dizer o que fazer em vez de "inválido".

### O que se perde ao apagar, declarado

`syncs.credential_id` é `ON DELETE SET NULL`. O histórico de coletas **sobrevive
inteiro**, perdendo apenas qual credencial cada uma usou.

Isso é perda real e aceita. A credencial não existe mais, então apontar para ela
responderia com um identificador morto. O que continua respondível é o que a proveniência
exige: qual ferramenta, qual instância, quando.

## Garantias

**O segredo nunca aparece.** Nenhuma função devolve o valor decifrado, e nenhuma tela de
edição o exibe — FR-026. O que a interface mostra é `last_four`, como já faz.

**Apagar é apagar.** A verificação não é uma afirmação no código: é uma consulta direta à
tabela, conferindo que nenhuma linha com aquele identificador existe e que nenhum valor
cifrado remanescente responde por ela.

**Desativar continua existindo, e é coisa diferente.** Credencial desativada permanece
cifrada e pode voltar; destruída não volta. As duas ações convivem porque respondem a
necessidades distintas — parar de usar por ora, e parar de guardar.

## O que este contrato NÃO expõe, e por quê

| Ausente | Razão |
|---|---|
| ler o segredo | não existe caminho na API pública, e é o que sustenta SC-011. O cofre decifra no `Ecto.Type` para o cliente HTTP usar, e nada mais |
| trocar o segredo de uma credencial existente | acrescente outra e desative esta. Trocar o segredo faria os registros já coletados apontarem para uma credencial que não os coletou |
| revalidar sem trocar o segredo | `validated_at` diz quando **aquele** segredo foi aceito pela origem. Revalidar sem trocar mudaria a data sem mudar o fato |
| apagar credencial de ferramenta encerrada | não há o que apagar: o encerramento já destruiu todas |
| recuperar credencial destruída | ela não existe. É o ponto |
