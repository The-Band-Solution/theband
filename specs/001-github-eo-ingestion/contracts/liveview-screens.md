# Contrato — telas

**Feature**: 001 · **Fase**: 1

LiveView conta como tela e backend na mesma entrega, que é o que o princípio VI
da constituição exige. As quatro telas fecham a fatia vertical: sem elas a
feature entrega infraestrutura sem consumidor visível.

Todas as rotas ficam sob o escopo autenticado, e **toda** consulta passa o tenant
da sessão. Não existe caminho de interface que alcance dado de outro tenant — é o
que SC-008 verifica, com dois tenants povoados ao mesmo tempo.

## `/ferramentas` — conectar e listar ferramentas

Cobre US1. Perfil `admin` apenas; `member` recebe 403.

| Elemento | Comportamento |
|---|---|
| Lista de ferramentas | tipo, instância, estado, credenciais com `last_four`, data da última sincronização |
| Formulário de conexão | tipo, instância, credencial. Ao submeter, valida contra o GitHub **antes** de gravar |
| Credencial inválida | mensagem dizendo o que faltou — acesso negado ou escopo insuficiente. **Nada é gravado** |
| Credencial válida | ferramenta aparece como conectada; a chave **nunca mais** é exibida, só `••••` + `last_four` |
| Segunda credencial | coexiste com a primeira; cada uma ativável e desativável de forma independente |
| Ferramenta com falha | selo "precisa de atenção", com data e motivo. As demais ferramentas do tenant seguem normais |

**Verificação de SC-005 na interface**: recarregar a página não torna a chave
legível por nenhum caminho — nem no HTML, nem no estado do socket, nem em
atributo de dado.

## `/sincronizacoes` — disparar e acompanhar

Cobre US2.

| Elemento | Comportamento |
|---|---|
| Botão de sincronizar | por ferramenta conectada. Desabilitado quando já há uma em curso |
| Disparo com uma em curso | mensagem informando que já existe uma em andamento; a segunda **não** inicia |
| Progresso | atualiza ao vivo — páginas processadas, registros coletados, entidade atual |
| Pausa por rate limit | estado visível "aguardando janela da API", com o horário de retomada. Não é erro, e não se parece com um |
| Conclusão | relatório de FR-028: coletados, criados, atualizados, ignorados com motivo |
| Vínculos pendentes de papel | número exibido explicitamente ao fim (SC-010), apresentado como lacuna de conhecimento — **não** como alerta de erro |

## `/pessoas` — pessoas conhecidas

Cobre US3.

| Coluna | Origem |
|---|---|
| Nome | `eo_people.name`; conta sem nome preenchido aparece pelo login |
| Tipo de conta | `person` \| `bot` \| `app`. Automação é exibida e **não** entra na contagem de pessoas |
| Origem | `source_system` + `source_instance` |
| Identificador na origem | `external_id` |
| Coletado em | `collected_at` |

A contagem do cabeçalho usa `count_people/2` com **as mesmas** `opts` da
listagem. Cabeçalho dizendo "41 pessoas" sobre uma lista de 10 é o defeito que
esse contrato existe para impedir.

## `/equipes` — equipes e seus integrantes

Cobre US3.

| Elemento | Comportamento |
|---|---|
| Lista de equipes | nome, tipo (`organizational_team` nesta entrega), origem, identificador externo, data da coleta |
| Integrantes | ao abrir a equipe: pessoa, nível de acesso na plataforma, quando foi observada |
| Nível de acesso | rotulado como **acesso na plataforma**, nunca como "papel" ou "cargo". O rótulo é parte do contrato: chamá-lo de papel na tela desfaz na interface a distinção que o modelo preserva |
| Pendentes de papel | contagem por equipe e total |
| Vínculo não mais observado | exibido com marcação histórica; nada some da tela sem explicação |
| Organização sem equipes | estado vazio explicando que a organização não tem equipes na origem — **não** é erro |

## Estados que toda tela trata

Vazio, carregando, erro de carregamento, e sem permissão. Estado vazio sempre diz
**por que** está vazio — "nenhuma sincronização foi executada ainda" é diferente
de "a organização não tem equipes", e confundir os dois faz a pessoa procurar
defeito onde não há.

## Idioma

Interface e mensagens em português do Brasil, como o restante da base de
conhecimento.
