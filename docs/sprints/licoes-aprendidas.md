# Lições aprendidas

Registro acumulativo, atravessa os sprints. Lida **antes** de abrir qualquer
sprint novo: uma lição em aberto que se aplique entra como restrição, não como
sugestão.

Um sprint que termina sem registrar o que aprendeu condena o próximo a repetir os
mesmos erros — e é o erro repetido que custa mais caro, porque já era conhecido.

---

## Sprint 001 — Fundação e coleta EO (2026-08-09)

### L01 — Ferramenta de scaffolding sobrescreve documento normativo

**O que aconteceu.** `mix phx.new .` no diretório existente sobrescreveu
`AGENTS.md` — o documento normativo do projeto — pela versão genérica que o
Phoenix 1.8 gera. Também substituiu o `.gitignore` e o `README.md`.

**Por que importa.** O `AGENTS.md` tem 654 linhas de decisões acumuladas. A perda
só não foi permanente porque o arquivo estava commitado; se a geração tivesse
acontecido antes do commit, teria sumido sem aviso. Nada no output do gerador
menciona que ele sobrescreveu um arquivo normativo.

**Como aplicar.** Antes de rodar qualquer gerador sobre diretório já povoado,
conferir `git status` limpo e listar o que o gerador cria. Depois de rodar,
`git diff --stat` e restaurar o que não deveria ter mudado — **antes** de
qualquer commit.

### L02 — Servidor no ar duplica o efeito de qualquer job disparado por script

**O que aconteceu.** A demonstração chamava `Worker.perform/1` diretamente com o
`mix phx.server` rodando. O Oban do servidor pegou o mesmo job da fila, e a
coleta rodou duas vezes: 32 registros coletados em vez de 16, duas páginas por
entidade em vez de uma.

**Por que importa.** Os números pareciam plausíveis. Sem conferir contra a origem
— 6 pessoas, 2 times — a duplicação passaria como resultado correto, e o
relatório de FR-028 estaria mentindo.

**Como aplicar.** Script de demonstração ou de carga usa **o mesmo caminho que a
interface usa**: enfileira e aguarda. Chamar `perform/1` à mão só com o servidor
parado, e dizendo no próprio script por que está fazendo isso.

### L03 — Um teste com dado inválido encontra o que o caminho feliz esconde

**O que aconteceu.** O teste "registro sem Application Reference é rejeitado"
derrubou a query com `ArgumentError` do Ecto — comparar coluna com `nil` é
proibido — em vez de devolver changeset inválido. A coleta real nunca teria
exposto isso: o GitHub sempre devolve `id`.

**Por que importa.** O código estava correto para toda entrada que a fonte
produz, e quebrava para a primeira entrada que uma fonte nova produzisse. O
defeito ficaria latente até a segunda integração.

**Como aplicar.** Para cada invariante que a spec declara, escrever o teste da
**violação**, não só o da conformidade. Validar antes de consultar, sempre que a
consulta usar campos que a validação exige.

### L04 — Campo opcional na query pode custar um escopo inteiro

**O que aconteceu.** Pedir `email` nas consultas GraphQL fez a coleta falhar com
`INSUFFICIENT_SCOPES`: o campo exige `read:user`, muito mais amplo que o
`read:org` que a coleta precisa. O próprio mapeamento já declarava que esse campo
"costuma ser nulo por configuração de privacidade".

**Por que importa.** O pedido teria empurrado todo tenant a conceder um escopo
maior por um campo quase sempre vazio — e escopo excedente é superfície de ataque
que ninguém revisa depois de concedido.

**Como aplicar.** Ao montar consulta, conferir campo a campo qual escopo ele
exige, e cruzar com as limitações declaradas no mapeamento. Campo declarado como
"normalmente nulo" não justifica escopo adicional.

### L05 — `varchar(255)` em coluna de diagnóstico troca o erro real por um erro de banco

**O que aconteceu.** `syncs.error_reason` era `varchar(255)`. Um erro de GraphQL
mais longo estourou o `UPDATE`, e a exceção que apareceu foi
`string_data_right_truncation` — não a causa da falha da coleta. O diagnóstico
levou uma rodada a mais só por isso.

**Como aplicar.** Coluna que guarda motivo, mensagem ou diagnóstico nasce `text`.
Limite arbitrário em campo de erro não protege nada e apaga a informação
justamente quando ela é mais necessária.

### L06 — `cd` no shell persiste entre comandos e escreve no lugar errado

**O que aconteceu.** Um `cd /tmp` feito para testar a interface com `curl`
persistiu, e os comandos seguintes criaram `test/test_helper.exs` dentro de
`/tmp`. O `test/` real do projeto, gerado pelo Phoenix, ficou intocado — e a
conclusão errada foi "o gerador não criou os testes".

**Como aplicar.** Comando que escreve arquivo usa caminho absoluto, ou começa com
`cd` explícito para a raiz. Antes de concluir que um diretório não existe,
conferir de onde a checagem foi feita.

### L07 — `autogenerate: false` em chave `binary_id` devolve struct sem `id`

**O que aconteceu.** Os schemas declaravam `@primary_key {:id, :binary_id,
autogenerate: false}` confiando no `DEFAULT gen_random_uuid()` do Postgres. O
`INSERT` funcionava, mas o struct devolvido vinha com `id: nil`, e a primeira
associação a usá-lo comparava `tenant_id` com `nil`.

**Como aplicar.** Com `binary_id`, `autogenerate: true` no schema; o `DEFAULT` do
banco permanece como rede de segurança para inserções fora do Ecto.

### L08 — Contrato escrito junto com o código descreve, não decide

**O que aconteceu.** O `/speckit-analyze` encontrou duas divergências entre
`contracts/ontology-eo.md` e o código: a assinatura de
`mark_evidence_no_longer_observed/2` e as `opts` das funções de leitura. Nos dois
casos o **código estava certo e o documento, desatualizado**. Os dois contratos
tinham sido redigidos junto com a implementação.

**Por que importa.** Contrato escrito depois vira comentário: descreve o que já
existe, deixa de decidir o que deveria existir, e a divergência entre os dois
passa a ser invisível até alguém comparar linha a linha. Um dos itens
divergentes, `:order_by`, prometia parametrizar a ordenação — o que teria
reintroduzido pela porta dos fundos a divergência entre `list_*` e `count_*` que
o próprio contrato existia para impedir.

**Como aplicar.** Escrever o contrato **antes** da primeira função pública:
assinatura, retorno de sucesso, retorno de erro, e o que a API deliberadamente
não expõe. Quando a implementação mostrar que o contrato errou — e vai —,
corrigir o contrato no mesmo commit, com a razão.

A seção "o que esta API não expõe" é a que mais rende. Foi ela que impediu
`create_person/2` de existir sem proveniência, e `delete_*` de apagar o que
deveria virar `no_longer_observed_at`. Escrevê-la obriga a decidir as ausências,
que é onde a maioria dos erros de fronteira nasce.

Virou norma em `AGENTS.md` §12 e na constituição, princípio VI, emenda 1.1.0.

### L09 — Um contrato pode contradizer a si mesmo, e só a implementação revela

**O que aconteceu.** O contrato de reprocessamento, escrito antes do código,
prometia `{:error, {:unknown_mapping, id}}` como retorno de lote **e**, no
parágrafo seguinte, que um mapeamento quebrado não impede a correção dos outros.
As duas coisas não podem ser verdade ao mesmo tempo. A contradição só ficou
visível ao escrever a cláusula que nunca casava.

**Como aplicar.** Contrato antes do código não dispensa revisão do contrato. Ao
implementar, tratar cláusula inalcançável e retorno que nunca ocorre como
**sintoma de contrato errado**, não como código a apagar em silêncio: a pergunta
certa é qual das duas afirmações do documento prevalece, e por quê.

### L10 — Rótulo de cipher precisa identificar a chave, não a versão do algoritmo

**O que aconteceu.** A rotação da chave mestra foi implementada com dois ciphers
de rótulo fixo — `AES.GCM.V1` para a chave nova e `AES.GCM.V0` para a antiga. O
Cloak escolhe com qual cipher decifrar pelo **rótulo gravado no início do valor
cifrado**. Como o rótulo não dizia nada sobre a chave, ele escolhia pela ordem da
configuração e usava a errada. A rotação não funcionava.

**Por que importa.** O sintoma seria "não consigo decifrar esta credencial", sem
causa aparente, e só no momento de usá-la — no meio de uma coleta, com a
ferramenta sendo marcada como precisando de atenção por um motivo que não era o
verdadeiro. Nenhum teste unitário do cifrador teria pego: cada um funciona
sozinho, e o defeito só existe na convivência das duas chaves.

**Como aplicar.** Rótulo de cipher deriva da chave — oito caracteres do SHA-256
bastam para identificar sem revelar. Assim cada valor cifrado carrega qual chave
o cifrou, e a escolha deixa de depender de ordem de configuração.

O ponto mais geral: **rotação de segredo só é verificável executando a rotação.**
Implementar os dois lados e conferir que compilam não prova nada — a prova é
recifrar e depois ler com a chave nova, e só com ela.

### L11 — Configurar iterations do ProjectV2 recria as existentes

**O que aconteceu.** Ao acrescentar a iteration do sprint 002,
`updateProjectV2Field` **substituiu o conjunto inteiro** de iterations. A do
sprint 001 foi recriada com identificador novo, e os 77 itens atribuídos a ela
ficaram órfãos. A mutação não aceita `id` nas iterations existentes, então não há
como preservá-las passando a lista.

Ao reatribuir, um segundo erro: o script atribuiu por número de issue, e o projeto
continha 10 itens de **outros repositórios** — que foram para o sprint 001 e
precisaram ser limpos.

**Por que importa.** Nada avisa. A iteration continua existindo com o mesmo
título e as mesmas datas; só o identificador mudou, e os itens simplesmente
deixam de aparecer no sprint. Quem olhasse o quadro veria um sprint vazio sem
explicação.

**Como aplicar.** Antes de mexer na configuração de iterations, listar os itens e
seus identificadores de iteration — é o que permite reatribuir. E filtrar por
**repositório**, não por número de issue: número de issue não é único num projeto
que agrega vários repositórios.

Melhor ainda: criar todas as iterations previstas de uma vez, no início, e não
tocar mais na configuração enquanto houver sprint aberto.

**Aplicada em**: Sprint 002 — ao mudar a cadência de 14 para 7 dias, em 2026-08-10.

### O procedimento que funcionou, e a descoberta que ele revelou

A mudança de cadência exigia mexer na mesma configuração. Com a lição aplicada como
procedimento, o estrago foi integralmente revertido:

| Passo | Resultado |
|---|---|
| snapshot **antes** — item, repositório, número e iteration de cada item | 97 itens: 76 no sprint 001, 11 no 002, 10 sem iteration |
| `updateProjectV2Field` com `duration: 7` | as duas iterations recriadas, **97 itens órfãos** — como previsto |
| reatribuição pelo **`item id`** do snapshot | 87 reatribuídos, 0 falhas |
| conferência contra o snapshot | 76 · 11 · 10, e os 10 sem iteration de **outros repositórios**, como estavam |

Duas escolhas fizeram a diferença, e as duas vêm desta lição:

- **reatribuir pelo `item id`**, que não muda quando a iteration é recriada. Foi o que
  evitou repetir o erro de casar por número de issue — número não é único num projeto
  que agrega vários repositórios;
- **tirar o snapshot antes.** Sem ele, a informação de qual item pertencia a qual
  sprint não existiria em lugar nenhum depois da mutação. Não é backup por precaução:
  é a única cópia.

**Descoberta nova: iteration com data no passado sai de `iterations` e entra em
`completedIterations`.** Ao receber 2026-08-03 com 7 dias, a do sprint 001 terminou
antes de hoje e mudou de lista, com identificador próprio (`2849580c`). A resposta da
própria mutação devolveu **só** o sprint 002, o que parece perda de dado e não é.

Consequência para qualquer script: **ler as duas listas.** Quem consulta apenas
`iterations` conclui que a iteration passada deixou de existir, e um script de
reatribuição que só a procure ali falha em silêncio — deixando órfãos os itens do
sprint encerrado, que é justamente o histórico de que as medidas de fluxo dependem.

### L12 — Pull request não aberto na hora passa a carregar outra feature

**O que aconteceu.** A tarefa T073 da feature 001 previa abrir o pull request ao
fim daquela feature. Não foi aberto. O sprint 001 encerrou, o sprint 002 foi
planejado, e três commits de documentação da 002 entraram na mesma branch
`feature/001-github-eo-ingestion`.

Quando o PR finalmente foi aberto, ele já não continha a feature 001: continha a
001 **mais** o planejamento da 002. Quinze commits, dois escopos.

**Por que aconteceu.** Abrir o PR era a última tarefa da feature, e a última
tarefa é a que se empurra. Não havia nada que impedisse o trabalho seguinte de
começar antes dela — e trabalho seguinte, na mesma branch, é trabalho que entra
no PR.

**Por que importa.** Quem revisa perde a unidade de revisão. Um PR de dois
escopos obriga o revisor a separar mentalmente o que pertence a qual feature, e é
exatamente aí que passa o que não deveria passar. Pior: a revisão da 001 passa a
ser condição para o merge de documentos da 002 que não têm nada a ver com ela.

**Como aplicar.** Duas coisas, e a segunda é a que resolve:

1. abrir o PR **quando a tarefa pedir**, não quando a feature "estiver redonda" —
   PR aberto cedo é revisável em partes; PR aberto tarde é irrevisável;
2. **não puxar trabalho novo com item anterior sem destino.** Esta lição é a
   origem da regra que a skill `product-owner` passou a exigir no planejamento, e
   da Fase 0 do sprint 002: o que sobrou do sprint anterior recebe destino antes
   de qualquer escopo novo ser selecionado.

O destino não precisa ser "concluído". Pode ser devolvido ao backlog, descartado
com motivo, ou bloqueado com bloqueador nomeado — a revisão independente é desse
último tipo, porque exige uma pessoa que o time não pode produzir. O que não pode
é ficar aberto sem nenhum dos quatro.

**Aplicada em**: Sprint 002 — Fase 0, antes de F1.

### L13 — Secret referenciado e não cadastrado chega como string vazia

**O que aconteceu.** O PR da feature 001 foi aberto e o CI reprovou em `mix test`,
com a aplicação recusando o boot por chave mestra ausente. Os oito gates passavam
na máquina local, e nada no código estava errado.

O workflow declarava `THE_BAND_MASTER_KEY: ${{ secrets.THE_BAND_MASTER_KEY }}`, e
o secret **não estava cadastrado** no repositório. O GitHub não omite a variável
nesse caso: define como **string vazia**.

**Por que aconteceu.** O `config/runtime.exs` tem um fallback deliberado — em
`config_env() == :test` fornece uma chave fixa e assumidamente pública, porque em
CI ela cifra apenas fixture em banco descartável. O padrão era `{nil, :test}`, e
`""` não é `nil`. O fallback existia e não era alcançado.

O resultado é o pior dos dois mundos: **referenciar um secret que não existe ficou
pior que nunca tê-lo referenciado.** Sem a linha, o fallback funcionaria.

**Por que importa além deste caso.** Ausente e vazio são a mesma coisa para
qualquer segredo, credencial ou chave — nenhum sistema aceita `""` como valor
válido. Onde o código distingue os dois, ele criou um terceiro estado que ninguém
modelou, e esse estado aparece exatamente quando alguém esquece de cadastrar algo.
O `TheBand.Vault` já acertava (`decode_key(value) when value in [nil, ""]`); a
configuração, não. Um trecho tratava vazio como ausente, o outro como valor.

**Como aplicar.**

1. **Onde a ausência tem tratamento, tratar vazio igual.** `when blank in [nil, ""]`,
   nunca só `nil`;
2. **Não referenciar secret que o ambiente não precisa.** O CI não precisava de
   chave própria: o `:test` já fornece uma. A referência não adicionava proteção e
   quebrava o fallback;
3. **Gate verde localmente não é gate verde.** Este defeito só existia no CI, e só
   apareceu porque o PR foi aberto e o pipeline **rodou**. É a mesma forma da
   [L10](#l10--rótulo-de-cipher-precisa-identificar-a-chave-não-a-versão-do-algoritmo):
   a prova é executar, não implementar.

**Aplicada em**: Sprint 002 — Fase 0, ao abrir o PR da 001.

### L14 — `gh` engole em silêncio o pedido de revisão recusado

**O que aconteceu.** Passou a valer a regra de todo PR nascer com revisor pedido, e
o PR #90 foi aberto com `gh pr create ... --reviewer paulossjunior`. O comando
imprimiu a URL e **nada mais** — nenhum aviso, código de saída zero.

O revisor não foi atribuído. `gh pr edit 90 --add-reviewer paulossjunior` fez o
mesmo: imprimiu a URL, saiu com zero, não atribuiu ninguém.

Só a chamada direta à API mostrou o motivo:

```text
POST repos/.../pulls/90/requested_reviewers
422  Review cannot be requested from pull request author.
```

**Por que aconteceu.** O PR foi aberto com o token de `paulossjunior`, então ele é
o autor — e o GitHub recusa pedir revisão ao autor do próprio PR. A recusa é
legítima e é exatamente a regra que o princípio VII quer: ninguém revisa o que
escreveu.

O defeito não é a recusa. É o `gh` **não reportá-la**: a flag `--reviewer` falha
sem sinal, e quem roda o comando fica convencido de que pediu revisão.

**Por que importa.** É a pior classe de falha para uma regra de processo. Uma regra
que falha alto é corrigida na hora; uma que falha em silêncio produz um registro
que afirma conformidade — "o PR foi aberto com revisor" — enquanto a fila do
revisor continua vazia. A verificação e o resultado divergem, e nada avisa.

Mesma forma da [L13](#l13--secret-referenciado-e-não-cadastrado-chega-como-string-vazia):
a configuração parecia certa e o efeito não existia.

**Como aplicar.**

1. **Nunca confiar no código de saída de `gh pr create --reviewer`.** Depois de
   abrir o PR, conferir o resultado:
   `gh pr view <n> --json reviewRequests`. Lista vazia significa que ninguém foi
   pedido, independentemente do que o comando disse;
2. **Para ver o erro, usar a API**, não a flag:
   `gh api -X POST repos/<owner>/<repo>/pulls/<n>/requested_reviewers -f 'reviewers[]=<login>'`;
3. **Registrar a lacuna quando o pedido é impossível.** Uma conta só não satisfaz
   o princípio VII: quem abre o PR e quem revisa têm de ser identidades diferentes.
   Enquanto for a mesma, a exigência é inalcançável, e isso pertence ao registro de
   cada sprint em vez de reaparecer como surpresa a cada merge.

**Aplicada em**: Sprint 002 — ao abrir o PR #90, que é o próprio caso.

### L15 — Não há revisor possível num repositório de um colaborador só

**O que aconteceu.** A regra de todo PR nascer com revisor pedido foi escrita e
falhou nas três tentativas seguintes, cada uma por um motivo diferente:

```text
reviewers[]=paulossjunior
  422  Review cannot be requested from pull request author.

team_reviewers[]=the-band
  422  Reviews may only be requested from collaborators.
       One or more of the users or teams you specified is not a collaborator.
```

O levantamento explicou por quê:

| Fato | Evidência |
|---|---|
| o repositório tem **um** colaborador: `paulossjunior`, admin | `GET /repos/.../collaborators` |
| **nenhuma equipe** tem acesso | `GET /repos/.../teams` devolve vazio |
| revisão só pode ser pedida a colaborador | o segundo 422 |
| o autor não pode ser o revisor | o primeiro 422 |

**Por que importa.** As quatro juntas dão **zero revisores possíveis**: o único
colaborador é o autor de todo PR. O princípio VII da constituição — revisão por quem
não implementou — é **inalcançável** neste repositório, não atrasado. Foi tratado
como pendência de agenda durante todo o sprint 001; era pendência de permissão.

A organização tem duas equipes com pessoas que não implementaram — `the-band`, com
`Adylla027` e `EduardoNFraiz`, e `zeppelin`, com mais três. Nenhuma das duas é
colaboradora do repositório. **A capacidade de revisar existe na organização e não
alcança o repositório**, e nada no processo revela isso: a exigência aparece como
item pendente numa lista, indistinguível de um item que só precisa de tempo.

**Como aplicar.**

1. **Antes de escrever regra que dependa de permissão, verifique a permissão.**
   `collaborators` e `teams` do repositório respondem em duas chamadas se a regra é
   cumprível. Regra incumprível gasta o mesmo esforço de escrita e não produz efeito;
2. **Distinga pendência de agenda de pendência de permissão.** A primeira fecha com
   trabalho, a segunda só com decisão de quem administra. Misturá-las faz a segunda
   ser replanejada sprint após sprint sem nunca avançar;
3. **Declare a impossibilidade com as quatro evidências**, e não como "revisão
   pendente". A frase genérica sugere que basta esperar.

**Aplicada em**: Sprint 002 — a herança do sprint 001 passou a classificar a revisão
independente como bloqueada **estruturalmente**, e não como atrasada.

**Resolvida em 2026-08-10, com duas chamadas de API:**

```text
PUT /orgs/The-Band-Solution/teams/the-band/repos/The-Band-Solution/theband
    permission=pull

POST /repos/.../pulls/91/requested_reviewers
    team_reviewers[]=the-band          → {"equipes":["the-band"]}
```

`pull` é o mínimo que revisão exige — quem revisa precisa ler, não escrever.

**Correção do registro.** Este parágrafo dizia que a concessão deu **leitura** à equipe,
e o efetivo é outro: `Adylla027` e `EduardoNFraiz` são admins da organização, então o
nível resolvido no repositório é `admin`. A concessão de `pull` à equipe não elevou
ninguém — apenas os tornou **visíveis como colaboradores**, que era exatamente o que
faltava para o pedido de revisão passar.

O mecanismo da lição continua certo; a descrição do acesso estava errada. E a
distinção importa: "dei leitura a duas pessoas" e "duas pessoas que já eram admins
passaram a ser alcançáveis pelo pedido de revisão" são fatos diferentes, e só o segundo
é verdade.

**Pedir à equipe é melhor que pedir a uma pessoa**, e não por conveniência: o pedido
fica aberto para qualquer membro, e o autor, sendo membro, simplesmente não pode
atendê-lo. A restrição do GitHub passa a **produzir** a independência que o princípio
exige, em vez de bloqueá-la.

**O que isso ensina, e é o ponto da lição.** A exigência atravessou um sprint inteiro
como "revisão pendente", indistinguível de qualquer item que só precisa de tempo. O
que faltava eram **duas chamadas de API**. A pendência não era de esforço nem de
agenda; era de permissão, e a única razão de ter durado tanto é que ninguém perguntou
*se* era possível antes de planejar *quando* seria feito.

**Fica um resíduo que não se recupera**: o PR #89 já foi mergeado sem revisão, e não
existe como pedir revisão de PR mergeado. O código da feature 001 está na `main` sem
nunca ter sido revisado, e isso permanece no registro de aceitação — a correção vale
de #91 em diante.

## Sprint 002 — Escopo por organização (2026-08-10 a 2026-08-16)

### L17 — A derivação do esquema não era função da ontologia

**O que aconteceu.** A tarefa T004 exigia uma regressão obrigatória: acrescentar a
regra de associação ao derivador e conferir que **a derivação de todas as outras
ontologias sai idêntica**. A comparação acusou dez das onze ontologias como
alteradas.

Nenhuma tinha mudado. Três execuções do **mesmo código**, sobre a **mesma base**,
davam três saídas diferentes:

```text
run1 != run2
run1 != run3
```

**Por que acontecia.** `owned = {cid for cid, (o, _) in concepts.items() ...}` é um
conjunto de strings, e iterar um conjunto de strings em Python varia entre execuções
por randomização de hash. Essa ordem decidia a ordem de inserção em `absorbed`, que
decidia a ordem dos valores de discriminador, das notas e das colunas. `glob` somava
a sua parte: devolve na ordem do sistema de arquivos, e a ordem de leitura decidia a
ordem das relações, logo das chaves estrangeiras.

**Por que importa muito mais que a estética da saída.** A ADR 0004 decide que o
modelo de informação é **derivado e nunca escrito à mão**. Uma derivação que muda
entre execuções não é derivação: é sorteio estável o suficiente para parecer
determinístico e instável o suficiente para não ser verificável. Três consequências
concretas:

- **nenhum diff de derivação é revisável.** Todo diff vem cheio de reordenação, e a
  mudança real fica escondida no ruído;
- **a regressão que T004 exige era impossível**, e ninguém tinha notado porque
  ninguém a havia executado;
- **a promessa da ADR 0004 D4 ficava sem verificação.** "O esquema corresponde ao
  modelo derivado" não é conferível quando o modelo derivado depende de quando foi
  gerado.

Vale notar o que **não** era o problema: o defeito não produzia esquema errado. A
mesma tabela, com as mesmas colunas, saía descrita em outra ordem. É por isso que
sobreviveu — ninguém compara duas execuções quando a de hoje parece certa.

**Como aplicar.**

1. **Ordene toda iteração cuja ordem chegue à saída.** Conjunto e `glob` não têm
   ordem; `sorted` custa nada e é a diferença entre derivação e sorteio;
2. **Gate de reprodutibilidade no CI**, e não confiança: o pipeline deriva quatro
   ontologias duas vezes e compara. É o único jeito de isto não voltar;
3. **Regressão sobre saída de gerador exige gerador determinístico primeiro.**
   Quando uma comparação acusar mudança em tudo, desconfie da comparação antes de
   desconfiar da mudança — e execute o baseline duas vezes contra si mesmo.

**Aplicada em**: Sprint 002 — T004. O baseline foi refeito com o código do `HEAD`
mais o conserto de determinismo e nada mais, e só então a regra nova foi comparada:
**apenas EO mudou**, e apenas pela coluna nova.

### L18 — Um critério atendido não é um critério suficiente

**O que aconteceu.** A verificação V9 do sprint 002 exigia zero pessoas sem
organização, e é o critério SC-003a do MVP. A primeira execução devolveu exatamente
isso:

```text
pessoas sem organização alcançável: 0
```

Critério atendido. E a plataforma estava mentindo: a equipe derivada de
`ifesserra-lab`, organização de **5 membros**, havia recebido **72** pessoas — o
tenant inteiro. As três organizações passaram a mostrar todas as 72.

O defeito só apareceu ao percorrer o critério **seguinte**, SC-009, que exige
"exatamente uma equipe derivada, e nela exatamente os membros que faltavam". 72 não é
5.

**Por que aconteceu.** `list_people_without_team/2` devolvia toda pessoa do tenant
fora das equipes daquela organização, e isso é coisa diferente de "membro da
organização fora das equipes dela". A definição de "de uma organização" nunca havia
sido escrita, e sem ela a função respondia à pergunta errada com a forma certa.

O que tornou o erro invisível é que **ele satisfazia o critério com folga**: quanto
mais pessoas na derivada, mais garantido o zero de V9.

**Por que importa.** Um critério de aceitação verifica uma afirmação, não o sistema.
V9 afirma "ninguém sem organização", e a derivada acolhendo o mundo torna isso
verdadeiro pelo pior caminho possível. Só a leitura conjunta dos critérios — o que
percorrer um a um obriga — expôs a contradição.

Um registro de aceitação que se contentasse com V9 teria aceito o entregável, com
evidência, de boa-fé, e errado.

**Como aplicar.**

1. **Nunca aceite por um critério.** Percorrer todos não é formalidade de processo: é
   o mecanismo que faz um critério corrigir a leitura de outro;
2. **Desconfie do critério que passa com folga.** Zero absoluto, 100%, "nenhum caso
   restante" — quando um limite é atingido com margem, pergunte qual excesso o
   produziu;
3. **Critério de contagem exige o critério de composição ao lado.** "Ninguém de fora"
   e "exatamente estes dentro" respondem coisas diferentes, e só juntos descrevem o
   resultado;
4. **Definição ausente é defeito, não estilo.** "De uma organização" parecia óbvio, e
   a função implementava outra coisa. Onde um termo do domínio aparece na assinatura,
   ele precisa estar definido na documentação da função.

**Aplicada em**: Sprint 002 — a avaliação de D01 encontrou o defeito antes da
aceitação, e a correção está registrada no `aceitacao.md`.

### L19 — Marcar ausência por tenant marca o que é de outra organização

**O que aconteceu.** A demonstração da feature 003 mostrou `Paulo` com uma única
organização vigente — `leds-conectafapes` — quando `The-Band-Solution` também continua
sendo observada. E `EduardoNFraiz` apareceu com **nenhuma** vigente, estando em duas
organizações ativas.

Nenhum dos dois foi marcado pelo encerramento. O que estava marcado eram os **vínculos**,
e a marca tinha vindo de antes:

```text
organização        vínculos  marcados  primeira marca
The-Band-Solution         7         7  2026-08-10 00:44:30
leds-conectafapes        70        55  2026-08-10 00:44:30
ifesserra-lab             5         5  2026-08-10 23:21:59   ← o encerramento
```

Os dois primeiros no **mesmo instante**, muito antes de a feature 003 existir.

**Por que aconteceu.** `mark_evidence_no_longer_observed/2` é chamada ao fim de cada
coleta para marcar o que não apareceu nela, e filtra por **tenant**:

```elixir
where: e.tenant_id == ^tenant_id and e.last_observed_at < ^collection_started_at
```

Sem escopo de organização. Então coletar `The-Band-Solution` marca os vínculos de
`leds-conectafapes`, porque eles não apareceram *naquela* coleta — e não apareceriam,
porque são de outra organização.

**Por que importa.** É defeito da feature 001, e a semântica que ele quebra é a mais
central do projeto: a marca significa "a origem deixou de mostrar", e passou a significar
"a última coleta não era desta organização". Toda consulta que pede só o vigente devolve
menos do que a plataforma observa — foi exatamente o que a demonstração mostrou.

**Não foi corrigido na feature 003, de propósito.** Emendar aqui misturaria a correção de
um defeito antigo com a entrega de uma feature, e é a mesma razão pela qual a dívida de
`connected_tools.status` também não foi tocada.

**O que torna a lição maior que o defeito.** A feature 002 deu à plataforma exatamente o
vocabulário que falta aqui — `organization_id` na equipe, e o caminho pessoa → equipe →
organização. Ela corrigiu o modelo e **não revisitou quem já usava a semântica antiga**.
Acrescentar a capacidade de escopar não escopa nada por si.

**Como aplicar.**

1. **Feature que acrescenta uma dimensão deve procurar quem decide sem ela.** Ao
   introduzir escopo por organização, a pergunta seguinte é "que consultas e escritas hoje
   decidem por tenant e deveriam decidir por organização?";
2. **Marca de ausência precisa do escopo da observação que a produziu.** "Não apareceu"
   só significa algo em relação ao que foi olhado;
3. **Demonstrar no dado real acha o que o teste não acha.** Os 151 testes passam: cada um
   cria o seu cenário, e num cenário de uma organização a falta de escopo é invisível. O
   defeito exige duas organizações e duas coletas em sequência — que é o que o banco de
   desenvolvimento tem e o teste não tinha.

**Corrigida no sprint 003.** `mark_evidence_no_longer_observed/3` passou a exigir a
organização, e a coleta devolve **qual organização observou** em vez de só dizer que
terminou. Quatro testes reprovam quando o escopo é removido, incluindo um cuja mensagem
diz o motivo: *"coletar alfa marcou o vínculo de beta — é a L19 de volta"*.

**O dado histórico continua errado, e a correção não o conserta.** A mudança vale para
coletas futuras; os vínculos marcados antes seguem marcados. Não foram desmarcados por
decisão: não se sabe o que a origem mostrava naquele instante, e desmarcar por conta
própria afirmaria observação que não ocorreu — exatamente o erro que a L19 é.

O reparo acontece sozinho na próxima coleta real de cada organização: reobservar um
vínculo limpa a marca. Até lá, consultas por vigência devolvem menos do que a plataforma
observa, e o registro diz isso.

**A demonstração no banco ficou fraca, e é honesto dizer.** Ao simular uma coleta de
`leds-conectafapes`, os vínculos de `The-Band-Solution` ficaram intactos — mas ela já
estava com **zero** vínculos vigentes, pelo próprio defeito. "0 antes, 0 depois" é
intacto no zero, e prova pouco. A prova forte está nos testes, com duas organizações
construídas do zero.

### L20 — Estado derivado do "último" precisa de desempate determinístico

**O que aconteceu.** Ao implementar o retomar, o teste "reusa a ferramenta existente"
falhou dizendo que a observação continuava encerrada depois de retomada. Os dois eventos
— `ended` e `resumed` — tinham sido gravados no **mesmo segundo**, e a derivação do
estado pede o último evento por `occurred_at desc, inserted_at desc`. Com as duas colunas
em `timestamp(0)`, o empate era total, e o banco devolvia qualquer um dos dois.

**Já tinha acontecido, com outro nome.** No sprint 001, `active_credential/1` escolhia a
credencial mais recentemente validada, e duas cadastradas no mesmo segundo empatavam em
`validated_at` — o mesmo estado do banco escolhia credenciais diferentes entre execuções.
A correção lá foi acrescentar desempate; a correção aqui é a mesma ideia com outro
mecanismo.

**Por que reincidiu.** Porque a lição anterior foi registrada como sendo sobre
**credenciais**, e não sobre **derivar estado de um conjunto ordenado**. O padrão é o
mesmo toda vez que o código pergunta "qual o último": se a chave de ordenação tem
granularidade maior que a frequência de escrita, o "último" é indefinido.

E a granularidade que engana é justamente o segundo, porque parece fino o bastante. Duas
ações de interface distam segundos; duas de um teste, microssegundos.

**A correção.** `occurred_at` continua em segundos — é quando a coisa **ocorreu**, e
segundo basta. `inserted_at` passou a microssegundo: é a ordem de gravação, e é ela que
desempata. Separar os dois papéis é o que torna a ordem definida sem fingir precisão que
o evento não tem.

**Como aplicar.**

1. **Toda derivação de "o último" declara o desempate.** Se a resposta muda conforme o
   plano de execução, não é derivação;
2. **Segundo não é desempate.** Onde a escrita pode ocorrer mais de uma vez por segundo —
   e quase sempre pode —, a ordem precisa de coluna com resolução maior, ou de sequência;
3. **Ao registrar lição sobre um caso, pergunte de que classe ele é.** "Credencial
   empatada" travou o caso; "estado derivado sem desempate" teria travado a classe, e
   esta lição não existiria.

**Aplicada em**: Sprint 003 — a tabela de eventos de observação.

---

## L21 — Função pública testada e sem consumidor não é funcionalidade entregue

**Onde**: Sprint 003, feature 003 — `resume_observation/3`.

**O que aconteceu.** Retomar a observação estava especificado (US2, quatro cenários de
aceitação), implementado e coberto por seis testes verdes. A pessoa mantenedora pediu
"especifique a opção de reativar a observação", e a conferência mostrou que a
especificação já existia. O que não existia era o **botão**: a LiveView tinha zero
ocorrências de `resume_observation`.

Encerrar era possível pela interface. Retomar, só pelo console — e um encerramento que na
prática é irreversível faz as pessoas não encerrarem, que é exatamente o que a própria
US2 diz na justificativa da prioridade.

**Por que passou.** Porque cada gate media o que sabe medir, e nenhum mede alcance:

| Gate | O que disse | O que não disse |
|---|---|---|
| `mix test` | 161 verdes | ninguém consegue chamar a função |
| cobertura das tarefas | T023 a T025 concluídas | as tarefas eram de domínio |
| `sprint-review.md` | F4 entregue | entregue **para quem** |

O `sprint-backlog` declarava F4 como "US2 — retomar", e a fase terminou quando o domínio
terminou. A fatia vertical existe precisamente para impedir isso, e a regra estava
escrita: *nunca infraestrutura sem consumidor visível*. Ela foi seguida em F3 — a tela de
encerramento veio junto — e não em F4.

**O que exercitar pela tela achou, e os testes não.** Dois defeitos, ambos por os testes
de domínio sempre passarem atributos completos:

- rótulo `""` não pegava o padrão, porque o padrão só valia para campo **ausente**;
- changeset inválido virava `MatchError` dentro da transação, matando a LiveView em vez
  de responder.

Nenhum dos dois é sutil. Os dois exigiam um formulário para aparecer.

**Como aplicar.**

1. **Fase de user story só fecha com consumidor.** Se a US descreve alguém fazendo algo,
   a fase não termina enquanto esse alguém não conseguir fazer;
2. **Antes de declarar uma fase pronta, procure a função na camada de interface.** Um
   `grep` do nome da função pública custa segundos e responde "entregue para quem";
3. **Ao ler um pedido que já parece atendido, confira o caminho inteiro.** "Já está
   especificado e implementado" era verdade e escondia a lacuna. A pergunta útil não é
   "existe?", é "quem consegue usar?".

**Aplicada em**: Sprint 003 — botão de retomar, formulário e histórico de observação.


---

## L22 — Gate que só compara duas execuções não sabe dizer se alguma funcionou

**Onde**: Sprint 003 — o gate "modelo de informação — derivação reproduzível".

**O que aconteceu.** O gate nasceu na correção da [L17](#l17), para provar que a
derivação é determinística. Ele roda o script duas vezes e compara as saídas:

```bash
for o in eo sro cmpo spo; do
  python scripts/derive_information_model.py --ontology "$o" > /tmp/d1-$o.txt
  python scripts/derive_information_model.py --ontology "$o" > /tmp/d2-$o.txt
  diff "/tmp/d1-$o.txt" "/tmp/d2-$o.txt" || { echo "não é reproduzível"; exit 1; }
done
```

A derivação da SRO **falha**, porque 43 conceitos não declaram
`ontouml_stereotype` — e falha do mesmo jeito nas duas execuções. O `diff` passa.
O que reprovou o passo foi o `bash -e` interrompendo no código de saída do script,
e a mensagem que o gate imprime nunca apareceu: quem lesse o log veria um erro sem
explicação, no meio de um passo que se chama "reproduzível".

**E eu reportei o gate como verde duas vezes**, nas reviews dos sprints 002 e 003.
Conferi que as duas saídas eram iguais e não conferi se alguma delas era uma
derivação. A `main` estava vermelha desde o PR #93.

**O que o gate escondia.** Anotar a SRO e voltar a derivar mostrou um defeito que
existia antes dela: a guarda da ADR 0004 D5 — `role` materializa por relator,
nunca por discriminador — só era aplicada quando o alvo do lifting estava na mesma
ontologia. **CMPO e SPO já produziam a violação**, visível na saída, verde no CI:

```
spo.artifact.type += {configuration_item}
ufo.agent.type    += {change_implementer}
eo.person.type    += {project_person_stakeholder}
```

Uma tabela de pessoas afirmando que alguém **é** um Product Owner. O gate lia essa
saída duas vezes, achava as duas iguais, e dizia que estava tudo bem.

**Como aplicar.**

1. **Todo gate diferencial precisa de um gate de sucesso antes.** Comparar duas
   execuções só significa algo depois de saber que uma execução vale. `set -o
   pipefail`, checar código de saída, e falhar com a mensagem do gate — não com o
   `-e` do shell;
2. **Ler o log do passo verde uma vez.** O que a derivação imprime é o modelo de
   informação; ninguém o leu, e ele dizia a violação em voz alta;
3. **Reportar gate como verde exige ter visto o verde.** Eu carreguei adiante uma
   afirmação de uma review anterior. Uma afirmação repetida não vira verificação.

**Aplicada em**: Sprint 003 — os 43 estereótipos da SRO e a guarda de `role` para
kind de outra ontologia.


---

## L23 — Aviso de verificação pulada é reprovação, não observação

**Onde**: feature 004, ao escrever os mapeamentos.

**O que aconteceu.** O validador Python imprime, quando falta a biblioteca de
schema:

```text
[schema] jsonschema não instalado — validação de forma NÃO executada
         (pip install -r scripts/requirements.txt)
```

Eu li isso em **todas** as execuções desta sessão — foram mais de dez — e tratei
como nota de ambiente. Não é: a linha é registrada como `fail`, o validador conta
"1 problema(s)" e **sai diferente de zero**. Eu rodava com `| tail -2`, que engole o
código de saída, e concluía "passou" a cada vez.

O CI, que instala a dependência, reprovou seis mapeamentos por erro de forma —
`source_path: null` onde o schema exige string. Erros que estavam ali desde o
primeiro arquivo que escrevi.

**A relação com a L22.** É o mesmo defeito, e reincidiu **dois dias depois** de eu
registrá-lo. Lá, o gate de derivação comparava duas execuções que falhavam igual e
eu não conferi o código de saída. Aqui, o validador dizia que não tinha validado e
eu não conferi o código de saída.

A L22 foi registrada como sendo sobre **gate diferencial**. O padrão é maior:
**qualquer verificação cujo resultado eu leio por texto, e não por código de
saída**.

**O que a correção do erro ensinou de quebra.** `source_path: null` não era só
inválido no schema — era errado no conteúdo. Declarar um atributo apontando para
nada afirma "existe mapeamento, e ele mapeia para nada". A ausência de mapeamento
se representa **omitindo o atributo**, e a limitação nomeia o porquê. Mesma regra
que a constituição já dá para dado: ausência é nula, nunca zero.

**Como aplicar.**

1. **Nunca `| tail` num gate.** Rode, olhe o código de saída, e só então resuma.
   `cmd && echo OK || echo FALHOU` custa nada;
2. **Verificação que se auto-declara pulada é falha.** "Não executada" e "executada
   e passou" não podem produzir a mesma reação em quem lê;
3. **Paridade de ambiente é parte do gate.** Se o CI valida mais que a máquina
   local, o local dá falso verde. O `README` passou a mandar criar o venv antes,
   com a razão escrita.

**Aplicada em**: feature 004 — seis mapeamentos corrigidos, e o venv documentado.


---

## L24 — Caminho que só roda no ambiente limpo não é testado por quem já tem o ambiente

**Onde**: feature 004, ao criar `mix gates`.

**O que aconteceu.** A task provisiona `.venv` na primeira execução. Rodei `mix
gates` nove vezes localmente, os nove gates verdes todas as vezes, e o CI reprovou:

```text
── 8/9 validador Python
   criando .venv (uma vez)
** (ErlangError) Erlang error: :enoent
    System.cmd(".venv/bin/pip", ["install", ...])
```

`System.cmd` não resolve caminho relativo. Eu já sabia disso — tinha corrigido
exatamente isso para o `python` na mesma função, minutos antes — e não corrigi para o
`pip` ao lado.

**Por que passou nove vezes.** Porque `.venv` **já existia** na minha máquina, desde
agosto. `ensure_venv` encontrava o interpretador e devolvia o caminho sem nunca
entrar no ramo de criação. O código que falhava era o único que eu não executava, e
era o único que o CI sempre executa.

**O que fechou.** Movi `.venv` para fora e rodei de novo. O ramo de criação rodou,
falhou onde o CI falhava, e a correção pôde ser verificada:

```bash
mv .venv /tmp/venv-guardado
mix gates --from "validador Python"
```

E a correção em si é melhor que consertar o caminho: `python -m pip` em vez do
executável `pip` deixa **um** caminho a expandir em vez de dois, e é o próprio
interpretador do venv que resolve o módulo.

**Como aplicar.**

1. **Todo ramo de provisionamento tem de ser exercitado sem o recurso.** `mv` do
   diretório, `docker rm` do volume, `unset` da variável — o custo é uma linha, e é
   o único jeito de rodar o caminho que o CI roda;
2. **Ambiente sujo esconde o ramo do ambiente limpo.** Nove execuções verdes não
   dizem nada sobre a décima numa máquina nova, e é a máquina nova que o CI é;
3. **Corrigir uma ocorrência de um defeito não corrige as vizinhas.** Duas chamadas
   com o mesmo problema estavam a cinco linhas de distância. Ao corrigir, procure o
   padrão no arquivo inteiro antes de seguir.

**Relação com a L23**: a L23 foi sobre paridade de **verificação** — o CI validava
mais que o local. Esta é sobre paridade de **ambiente** — o CI parte de máquina
limpa e o local não. As duas produzem verde falso, e por caminhos diferentes.

**Aplicada em**: `mix gates` — `python -m pip`, e o ramo de criação exercitado com o
venv removido.

---

## L25 — Número da issue não identifica: ele é único dentro do repositório

**Onde**: Sprint 004 — ligação de sub-issues ao pai, na coleta.

**O que aconteceu.** A tabela `collected_issues` já carregava a regra no índice único: a
identidade é a Application Reference, e `number` fica fora dela, com o motivo escrito na
migração.

E eu liguei as partes ao pai por **número**:

```elixir
por_externo = Map.new(WorkItems.list_issues(ctx.tenant), &{&1.number, &1.id})
pai_id = por_externo[node["number"]]
```

A organização tem 135 repositórios. Vários têm issue `#1`. O `Map.new` manteve a última de
cada número, e partes de um repositório foram ligadas ao pai de outro.

**O efeito foi silencioso.** Nenhum erro, nenhuma exceção, nenhum teste vermelho: a
classificação saiu errada. A tela mostrava **2 épicos** onde havia 3, e a issue `#1` — com
39 partes — aparecia como user story atômica.

**Por que passou.** Porque o teste de roteamento chama `decide/2` com a lista de tipos das
partes **já montada**, e a montagem é justamente o que estava errado. O defeito vivia entre
duas peças que cada teste exercitava separadamente.

O que o achou foi olhar a tela com dado real e reparar num número que não fechava com o que
a API dizia.

**A correção.** Chavear por `external_id`, que é global:

```elixir
por_externo = Map.new(WorkItems.list_by_external_id(ctx.tenant), &{&1.external_id, &1.id})
```

**Como aplicar.**

1. **Onde a identidade estiver declarada, use-a.** O índice único de `collected_issues` já
   dizia qual era a chave; eu escrevi outra ao lado dele;
2. **Chave que "funciona no meu teste" costuma ser chave de um só escopo.** Um fixture com
   um repositório não distingue número de identificador — o dado real com 135 distingue;
3. **`Map.new` sobre chave não única perde silenciosamente.** Ele não avisa colisão: mantém
   um e descarta o resto. Onde a unicidade não é garantida, `Enum.group_by` mostra o
   problema em vez de escondê-lo.

**Aplicada em**: Sprint 004 — `vincular/2`, e a contagem de épicos passou de 2 para 3.

---

## L26 — Casar o envelope errado devolve lista vazia em vez de erro

**Onde**: Sprint 004 — primeira execução da coleta de repositórios contra a origem real.

**O que aconteceu.** `Client.graphql/4` devolve `{:ok, %{data: ..., rate_limit: ...}}` — um
envelope. Eu casei `{:ok, data}` e passei o envelope para a função que extrai os nós:

```elixir
{:ok, data} -> {nodes, page_info} = extrair(data, query_name)
```

`extrair` faz `get_in(data, ["organization", "repositories"])`. Num envelope com chaves
`:data` e `:rate_limit`, isso devolve `nil`, que o código trata como `[]`.

**Resultado: o job completou com sucesso e coletou zero.** `status: completed`, nenhum erro
registrado, nenhum payload gravado. A tela mostrou "0 issues coletadas" e a explicação
plausível era "a organização não tem repositórios".

**Por que compilou e passou.** `{:ok, data}` casa qualquer `{:ok, _}`. O Dialyzer não
reclama porque `get_in/2` aceita mapa e devolve `nil` legitimamente. E os testes usavam o
Mox da borda HTTP com payload já no formato interno — nunca exercitaram o envelope real.

**A relação com a L22 e a L23.** É a mesma família: **o sucesso silencioso**. Lá um gate
comparava duas execuções que falhavam igual; aqui um job completa sem fazer nada. Em todos
os três, a ausência de erro foi lida como presença de resultado.

**Como aplicar.**

1. **Casamento de padrão largo esconde mudança de forma.** `{:ok, %{data: data}}` falha alto
   quando a forma muda; `{:ok, data}` segue adiante com o que vier;
2. **Coleta que devolve zero precisa ser distinguível de coleta que não olhou.** O relatório
   do `sync` agora conta por `sync_id`, e zero com 14 repositórios observados é diferente de
   zero sem nenhum;
3. **Teste com Mox no formato interno não valida a fronteira.** O payload capturado da
   origem tem de passar pelo cliente inteiro, envelope incluído, ao menos uma vez.

**Aplicada em**: Sprint 004 — a coleta passou de 0 para 14 repositórios e 189 issues na
primeira organização.

---

## L27 — Implementar antes do plano faz o teste descobrir o que o plano descobriria

**Onde**: Sprint 005 — feature 006, detalhe da issue.

**O que aconteceu.** A spec e o contrato de API existiam; o pedido foi direto — *"ao clicar no
titulo do repositorio e da issue quero ver os detalhes"* —, e eu implementei a partir do
contrato, sem `plan.md`, `research.md` nem `tasks.md`.

O código ficou bom: nove gates verdes, 29 testes novos, o axioma com caminho único. Mas **duas
decisões de desenho só foram examinadas quando um teste as reprovou**:

1. eu exibia `partes declaradas: 39` no painel do épico, ao lado de 9 na composição e 30 no
   atendimento. O `refute html =~ ">39<"` do SC-004 reprovou, e estava certo: 39 é exatamente a
   soma, e um leitor concluiria que as duas seções contam a mesma coisa duas vezes;
2. o teste que compara os dois caminhos do axioma usava `for issue <- ..., pai = fetch_parent(...)`
   — e em comprehension uma expressão que não é gerador vale como **filtro pelo seu valor**.
   `pai = nil` descartava justamente a tarefa sem pai, que é um dos dois casos comparados. O
   teste concordava por não olhar.

**Por que aconteceu.** As duas são perguntas de desenho, não de código: *o que a tela mostra ao
lado das duas relações?* e *como se prova que os dois caminhos concordam?* São exatamente as
perguntas que `research.md` obriga a responder com o que foi recusado, e que a fase de tarefas
obriga a escrever como *Teste* antes de existir implementação.

Sem o plano, elas viraram descoberta tardia — e a primeira só foi pega porque o SC-004 estava
escrito na spec com o número proibido. Se a spec tivesse dito apenas "mostre a decomposição", a
soma teria passado.

**O que fazer diferente.** Quando o pedido chega direto e a tentação é implementar, escrever
**só o `research.md`** já paga: são as perguntas de desenho, com o recusado ao lado. `plan.md`,
`data-model.md` e `tasks.md` podem vir junto com o código sem custo comparável — mas as decisões
de desenho examinadas depois do código já foram tomadas, e o que sobra é justificá-las.

E o corolário que vale para toda spec: **escreva o número proibido**. "Mostre 9 e 30, nunca 39"
é verificável; "mostre a decomposição separada" não é.

**Estado**: aberta. **Tipo**: processo. **Aplicar em**: sprint 005, feature 005 — cujo ciclo
completo foi escrito antes de qualquer linha de código, e é a primeira verificação desta lição.

---

## L28 — Calcular e não gravar é pior que não calcular

**Onde**: Sprint 005 — primeira execução do recálculo no dado real.

**O que aconteceu.** A decisão calculava a divergência entre o rótulo e a estrutura, com
frase e tipo, para 488 issues. O banco tinha **zero**.

`mudou_registro?/2` — a função que decide se vale gravar linha nova — comparava conceito,
motivo da lacuna, regra e fonte da evidência. **Não comparava a divergência.** Uma issue cujo
conceito não mudava nunca recebia a divergência descoberta depois.

**Por que aconteceu.** A função nasceu antes da divergência estrutural existir, e ninguém
voltou nela quando o campo novo entrou. O teste que eu escrevi verificava que a decisão
*calcula* a divergência — e passava, porque ela calcula mesmo.

**Por que é pior que não calcular.** Uma feature ausente é visivelmente ausente. Esta
mostrava **zero divergências** numa tela desenhada para exibi-las, e quem lesse concluiria
que nenhuma issue diverge. O produto afirmava o contrário do que sabia.

**O que fazer diferente.** Quando um campo novo entra numa estrutura que já é comparada em
algum lugar, **procurar a comparação**. `grep` pelo nome dos campos vizinhos acha em segundos:
se `evidence_source` é comparado e o campo novo não, é defeito.

E o teste tem de ir até o banco. "A decisão calcula X" e "X está gravado" são afirmações
diferentes, e só a segunda é o que a tela lê.

**Estado**: aberta. **Tipo**: técnica.

---

## L29 — Falha transitória que marca estado permanente tira dado de circulação em silêncio

**Onde**: Sprint 005 — conferência da contagem de issues contra a origem.

**O que aconteceu.** A API do GitHub diz que `leds-conectafapes` tem 4282 issues. A coleta
via 3383. A diferença — **899 issues** — estava em **38 repositórios marcados como
inacessíveis** por um `:nxdomain`, uma falha de DNS de um instante.

A marca era permanente na prática: `list_collectable/2` exclui inacessíveis, e nada a
limpava. Os 38 saíram de **toda** coleta seguinte, e a tela dizia "concluída · 100%".

**Por que aconteceu.** `mark_inaccessible/3` era chamada para qualquer erro. A distinção entre
falha que se repete — credencial revogada, repositório apagado — e falha do momento existia no
código (`Client.transient?/1`, usada para decidir retry) e **não era consultada aqui**.

**Por que passou despercebido.** A coleta terminou com sucesso, o percentual fechou em 100%, e
o denominador também vinha só dos repositórios acessíveis. **O número era coerente consigo
mesmo e errado.**

**O que fazer diferente.** Antes de marcar estado que retira algo de circulação, perguntar:
*isto se cura sozinho?* Se sim, não marque — e se marcar, marque **quem limpa**. A cura aqui é
a própria coleta: alcançou, limpa.

E: um percentual calculado sobre o que a plataforma decidiu olhar nunca detecta o que ela
deixou de olhar.

**Estado**: aberta. **Tipo**: técnica.

---

## L30 — Conferir o número contra a origem acha o que a suíte não acha

**Onde**: Sprint 005 — as duas lições acima, e o corpo vazio da feature 006.

**O que aconteceu.** Três defeitos em dois dias, todos com a suíte verde:

| defeito | como apareceu |
|---|---|
| 480 issues com corpo `NULL` | a origem devolve `""`; `cast/4` descarta string vazia |
| 899 issues fora de coleta | soma dos `totalCount` da origem contra o que a coleta viu |
| 488 divergências não gravadas | a decisão calculava e o banco não tinha |

Nenhum tinha teste que falhasse, porque **os três eram sobre dado que o cenário de teste não
produz**: corpo vazio, repositório inacessível, issue cujo conceito não muda.

**Por que aconteceu.** O cenário de teste é construído a partir do que se espera. O dado real
tem o que ninguém esperou — e é exatamente aí que o defeito mora.

**O que fazer diferente.** Ao entregar qualquer coisa que conte, **medir contra a origem uma
vez**. Não é auditoria: é uma consulta. `search(query: "org:x is:issue")` e a soma de
`issues.totalCount` levaram dois minutos e acharam 899 issues perdidas.

Quando os dois números divergirem, **explicar a diferença até o fim**. "Provavelmente issues
criadas depois" é uma hipótese, não uma explicação — e neste sprint essa hipótese estava
errada.

**Estado**: aberta. **Tipo**: processo.

---

## L31 — Regra nova muda o significado de teste que passava

**Onde**: Sprint 005 — a classificação por estrutura.

**O que aconteceu.** A regra estrutural passou a classificar toda issue. Dois testes da prévia
quebraram, e **nenhum deles estava errado**: eles mediam "quantas issues mudariam de conceito",
comparando com o que estava gravado. Com a estrutura decidindo de todo modo, essa comparação
passou a atribuir à regra o que a estrutura faria sozinha.

A correção não foi no teste nem na regra: foi no **significado**. `would_change` passou a
medir o efeito *da regra* — com ela contra sem ela — e um número novo, `rows_to_write`, passou
a medir o que a gravação produz.

**Por que importa.** Um teste que quebra depois de uma regra nova é convite a "ajustar o
esperado". Fazer isso aqui teria mantido o teste verde e a prévia mentindo: ela diria que uma
regra inócua muda 3451 issues.

**O que fazer diferente.** Quando um teste correto quebra por causa de uma regra nova,
perguntar **o que a asserção significava** antes de mudar o número. Se a pergunta que ela fazia
deixou de fazer sentido, a resposta é uma pergunta nova — não um valor novo.

**Estado**: aberta. **Tipo**: processo.

---

## L32 — Texto que afirma o que a plataforma não observou é o mesmo defeito, na direção oposta

**Onde**: Sprint 006 — a marca de trabalho no repositório.

**O que aconteceu.** A feature existe para impedir que ausência apareça como zero. O terceiro
estado da marca — "não se sabe" — recebeu o texto `not collected yet`, e ele **afirma** que a
coleta não ocorreu.

Medido no banco depois da migração: **94 repositórios com `issues_collected_at` nulo, e a coleta
visitou 61 deles** e não achou nada. `nil` significa ausência de **registro**, não ausência de
coleta. A tela estaria afirmando sobre 61 repositórios algo que a plataforma não observou.

**Por que aconteceu.** Toda a atenção do desenho foi para uma direção — não deixar ausência
parecer quantidade — e a frase escolhida para nomear a ausência afirmava um fato na direção
contrária. `no collection recorded` nomeia o que existe: a ausência do registro.

**Por que passou perto de escapar.** Nenhum teste reprovaria: o texto é diferente do texto do
estado vazio, que é o que os testes exigiam. A distinção que faltava não era entre dois textos,
era entre **o que o texto afirma** e o que a plataforma tem como observado.

**O que fazer diferente.** Para cada frase que a interface exibe sobre ausência, perguntar: *isto
afirma um fato, e a plataforma observou esse fato?* "Não coletado" afirma; "sem registro de
coleta" descreve o que existe. A diferença é a mesma que separa `declared_type` de `structure` na
evidência.

**Estado**: aberta. **Tipo**: técnica.

---

## L33 — A pergunta que pega o defeito de migração é "o que a tela diz no dia seguinte"

**Onde**: Sprint 006 — achado A1 da análise, antes de existir código.

**O que aconteceu.** A marca decidia pela data de coleta antes da contagem. Cada peça funcionava:
a consulta contava certo, a coluna gravava certo, a tela lia as duas. E o resultado, no instante
seguinte à migração, seria a plataforma dizendo `no collection recorded` sobre **41 repositórios**
de que ela tem issues coletadas — um deles com 2514.

Nenhum teste de unidade tem esse instante como cenário: o cenário de teste cria a data porque o
teste precisa dela.

**Por que aconteceu.** Migração que acrescenta coluna anulável deixa **todas** as linhas
existentes nulas, e o código novo é escrito olhando o estado que ele vai produzir — não o estado
que vai encontrar.

**O que fazer diferente.** Ao acrescentar coluna que a interface lê, perguntar antes de escrever a
leitura: *quantas linhas existentes terão `nil`, e o que a tela dirá sobre elas?* Se a resposta
for uma afirmação falsa sobre parte dos dados, a ordem de decisão está errada — e o teste que
prova isso é o que dá dado sem a coluna preenchida.

Foi `/speckit-analyze` que fez a pergunta, e é o argumento concreto para a fase existir: ela
examina o desenho contra o estado do mundo, e não contra o cenário do teste.

**Estado**: aberta. **Tipo**: processo.

---

## L34 — A mesma palavra para duas coisas diferentes esconde o caso que a feature existe para resolver

**Onde**: Sprint 007 — a feature de destravar a sincronização presa.

**O que aconteceu.** O desenho tinha **uma** noção de "trabalho vivo": qualquer job em estado não
terminal. A implementação passou nos testes, e estava errada.

O job órfão medido no banco está `executing` desde 2026-08-09, num nó que não existe mais. Com uma
noção só, `executing` bloqueava o encerramento automático **e** o humano — e a feature deixava preso
exatamente o caso que a motivou. As duas execuções que exigiram SQL eram esse caso.

**Por que aconteceu.** "Vivo" parecia uma pergunta; eram duas. *A plataforma pode encerrar sozinha?*
e *a pessoa pode encerrar?* têm respostas diferentes para `executing`, porque a plataforma não
consegue distinguir coleta rodando de processo morto — e a pessoa que reiniciou a aplicação
consegue.

**Por que os testes não pegaram.** Eles mediam o que o desenho dizia. O teste de "não encerrar
coleta viva" passava com `executing`, e nenhum teste perguntava *"e o órfão, quem encerra?"* —
porque o desenho tinha respondido "ninguém" sem dizer.

**O que fazer diferente.** Quando uma condição aparece em **dois** pontos de decisão — aqui, o
gatilho automático e a ação humana —, perguntar se ela significa a mesma coisa nos dois. Se a
resposta para algum estado divergir, são duas condições, e usar uma só apaga um caso.

O sinal de alerta é o nome genérico: "ativo", "válido", "pronto". Nome genérico costuma cobrir duas
perguntas que ninguém separou.

**Estado**: aberta. **Tipo**: técnica.

---

## L35 — Conferir contra a origem acha defeito fora da feature que se está entregando

**Onde**: Sprint 007 — a pessoa mantenedora achou o número de issues baixo e pediu conferência.

**O que aconteceu.** A conferência confirmou que a coleta está quase completa — **4283 na origem,
4280 no banco**, e as 3 que faltam nasceram depois da última coleta. Nada é filtrado por estado nem
por arquivamento.

E achou **dois defeitos que ninguém procurava**:

| defeito | custo |
|---|---|
| a marca de inacessível não se cura: o repositório marcado é filtrado **antes** da coleta, e a função que limparia a marca nunca o alcança | 39 repositórios e **899 issues** fora de toda coleta futura |
| erro **interno** do GitHub — HTTP 200 com `errors` — é classificado como falha permanente | criou uma marca nova no mesmo dia |

O primeiro é a **L29 revisitada**, e é o que mais importa: a correção da L29 impediu marcas novas
por falha transitória e não alcançou as que já existiam — porque a cura declarada, *"a cura é a
própria coleta"*, pressupõe que a coleta **tente**. Ela não tenta: o inacessível é filtrado antes.

**Por que passou despercebido por dois sprints.** O total no banco está a 3 issues do total da
origem. **O número agregado está certo, e o mecanismo está quebrado** — a perda é de tudo que for
criado a partir de agora nesses 39 repositórios, e hoje ela é quase zero.

**O que fazer diferente.** Conferir contra a origem **não é só somar o total**. A soma casou aqui e
esconderia o defeito para sempre. O que achou foi comparar **repositório por repositório**, e depois
perguntar *por que este está marcado, e o que limparia a marca?*

E o corolário: quando uma lição declara uma cura — "a cura é a própria coleta" —, conferir se o
caminho da cura é **alcançável**. Cura que pressupõe um passo que o filtro impede não é cura.

**Estado**: aberta. **Tipo**: processo.

---

## L36 — Gate que descarta o retorno da task não é gate

**Onde**: Sprint 008 — e a primeira versão desta lição estava **errada** no mecanismo. A correção
está registrada abaixo, porque o erro é instrutivo.

**O que aconteceu.** Um `@doc` órfão entrou em `main` com **os dez gates verdes** e o CI verde.

**O mecanismo, isolado por experimento:**

```
$ mix gates            # com o defeito presente
   código de saída: 0
   warning: redefining @doc attribute previously set at line 419   ← impresso três vezes
── 1/10 format
── 2/10 compile
```

O aviso **é emitido**. O gate **imprime** o aviso e sai **zero**.

A causa está na própria definição dos gates:

```elixir
defp execute({:mix, [task | args]}) do
  Mix.Task.reenable(task)
  Mix.Task.run(task, args)      # ← o retorno é DESCARTADO
  :ok
rescue
  e in Mix.Error -> {:error, Exception.message(e)}
end
```

`mix compile --warnings-as-errors` **não levanta**: ele devolve `{:error, diagnostics}`. Como o
retorno era descartado e nada era levantado, o gate reportava `:ok`. **O gate de compilação nunca
reprovou por aviso** — nem local, nem no CI, porque o CI roda a mesma task.

**O que eu tinha escrito, e por que estava errado.** A primeira versão desta lição dizia que a
compilação incremental não emitia aviso de arquivo não recompilado, e que o cache de `_build` no CI
reproduzia a cegueira. **Duas afirmações, nenhuma verificada.** O experimento que as testaria — e que
eu fiz depois — mostra o contrário: o Elixir **reemite** diagnóstico em cache, e `mix compile
--warnings-as-errors` num processo próprio reprova mesmo sem recompilar nada.

Eu tinha duas medidas verdadeiras — `main` reprovando numa árvore limpa, e os gates passando — e
**inventei o elo entre elas** em vez de isolá-lo. A conclusão certa exigia um experimento a mais.

**O que fazer diferente, e são duas coisas.**

Primeiro, no código: **o veredito de um gate é o código de saída**, e por isso cada gate passou a
rodar em subprocesso. É a L22 aplicada à própria definição dos gates — ela dizia que conferir gate
por texto (`| tail`) não vale, e o mesmo vale para conferir por valor de retorno descartado.

Segundo, no método: **quando duas medidas verdadeiras parecem se contradizer, o elo entre elas é
hipótese, não conclusão.** Publicar a hipótese como causa foi o erro, e ele custou uma lição errada
no registro que o próximo sprint vai ler.

**Custo medido da correção**: `mix gates` completo em **78,6 s**, com cada gate subindo um VM próprio.

**Estado**: aberta. **Tipo**: processo.

---

## L37 — A coluna estreita só cai quando a escrita fica frequente

**Onde**: Sprint 008 — achado da análise, antes do código.

**O que aconteceu.** `inaccessible_reason` é `varchar(255)`. O maior motivo gravado tinha **181**
caracteres, e o motivo da falha interna da origem — com o prefixo que a plataforma acrescenta — dá
**~228**. Vinte e sete caracteres de folga, num texto que a origem controla e que carrega um
identificador de incidente de tamanho variável.

Sem `validate_length` no changeset, o valor longo vai ao banco e **levanta**. E o tratamento de erro
da coleta cobre changeset inválido, não exceção do driver: a fase cairia, e o erro no log seria do
banco em vez da origem.

**Por que ninguém tinha visto.** A coluna era escrita **uma vez por repositório**, e só quando ele
falhava de forma permanente. Trinta e nove escritas em dois dias, todas abaixo do limite. A feature
009 mudou isso: com a coleta tentando de novo a cada execução, o campo passa a ser escrito **a cada
coleta que falhar**.

**O padrão, e é o que interessa:** um limite estreito não cai por ser estreito — cai quando a
**frequência de escrita** aumenta. A feature não introduziu o defeito; ela mudou a exposição a ele.

**O que fazer diferente.** Ao mudar a frequência com que um campo é escrito, conferir o limite dele.
E, para campo de **diagnóstico**, não haver limite: a truncagem pertence à borda, onde a mensagem é
montada, não à largura da coluna. É o que a L05 já havia concluído, e o que esta lição acrescenta é
**quando** a dívida cobra.

**Estado**: aberta. **Tipo**: técnica.

---

## L38 — O custo de uma tela se mede pela diferença e pela constância, nunca pelo total

**Origem**: Sprint 009 · **Tipo**: técnica

**O que aconteceu.** O plano da feature 010 declarava oito consultas para a página da pessoa, e o
teste asseriu oito. Reprovou: a página faz **24**. Nenhuma das duas medidas estava errada — 16 são
framework e autenticação, em **dois** renders de `live/2`.

**Por que aconteceu.** "Quantas consultas a página faz" e "quantas consultas a página **acrescenta**"
são perguntas diferentes, e o plano respondia a segunda enquanto o teste media a primeira.

**O que fazer diferente.** Duas asserções, e as duas precisam existir:

1. a **diferença** contra uma tela de baseline, dividida pelo número de renders;
2. a **constância**: uma página com pouco dado e uma com muito medem **igual**.

A segunda é a que pega o defeito real — consulta por linha —, e a primeira é a que impede o número de
crescer sem decisão. **"Um número que não cresce" não é asserção**: passa com 8 e passa com 80.

**Aplicada em**: Sprint 010 — e ali ela cobrou duas vezes. O teste de custo comparava a mesma página
com ela mesma (**L41**), e uma mensagem de telemetria atrasada entrou na contagem seguinte (**L42**).

**Aplicada em**: Sprint 023 — e desta vez ela DEFENDEU: o guardião reprovou o veredito novo de
acesso (+5 consultas por render na página da pessoa) antes de qualquer tela lenta existir. A
correção voltou ao teto sem subir a régua: a própria pessoa decide em memória, o lado do alvo
só é lido quando há escopo com alvo, e nomes de concessão custam zero sem concessão.

**Estado**: aberta.

---

## L39 — Um `join` num escopo compartilhado desloca os bindings de quem compõe sobre ele

**Origem**: Sprint 009 · **Tipo**: técnica

**O que aconteceu.** `escopo/2` em `WorkItems.Queries` ganhou filtro por pessoa, escrito como `join`
em `issue_assignees`. `list_issues/2` compõe sobre esse escopo com um `join` próprio e um `select` por
**posição** — `[i, p]`. O binding `p`, que era a promoção, passou a ser a designação.

```
field derived_concept in select does not exist in schema IssueAssignee
```

**Por que aconteceu.** `select` por posição amarra o código à **ordem** dos joins, e um `join`
acrescentado a montante muda essa ordem sem tocar em quem consome.

**O que fazer diferente.** Filtro em função compartilhada usa **subconsulta**, não `join`:

```elixir
where(query, [i], i.id in subquery(designadas))
```

Subconsulta não cria binding, e por isso não desloca nada. E quando o `join` for inevitável, o
`select` passa a nomear os bindings em vez de contá-los.

**Aplicada em**: Sprint 010 — `list_parents/2` nasceu com `select` nomeando os campos, e o filtro por
repositório continua sendo `where`.

**Estado**: aberta.

---

## L40 — Duas grandezas com nomes parecidos, e o complemento derivado da errada

**Origem**: Sprint 010 · **Tipo**: processo

**O que aconteceu.** A spec da feature 011 abriu com a medida: *"4 529 issues vigentes, **1 666 com
pai**, 2 863 sem"*. As três estavam erradas em conjunto: **1 666 é a contagem de vínculos**, as issues
com pai são **1 630**, e as sem pai são **2 899**.

O erro sobreviveu porque a soma **fechava**: 1 666 + 2 863 = 4 529. Fechava porque o segundo número
foi **derivado** do primeiro por subtração, e não medido.

**Por que aconteceu.** A consulta contava linhas de `decomposition_links`, e a frase falava de issues.
A diferença — **36** — era exatamente o caso de borda que a feature existe para tratar: as issues com
mais de um pai.

**O que fazer diferente.** Duas regras, e a segunda é a que pega este caso:

1. **medir os dois lados**, nunca derivar o complemento por subtração — o total conferir não prova
   que as partes estejam certas;
2. quando duas grandezas se relacionam por multiplicidade — issue e vínculo, pessoa e designação —,
   **medir as duas e conferir a diferença**. Se a diferença for zero e não devia ser, ou o inverso, o
   nome de uma delas está errado.

**Aplicada em**: Sprint 010 — corrigido antes do plano, e a diferença de 36 virou verificação.

**Estado**: aberta.

---

## L41 — Teste que compara uma coisa com ela mesma passa sempre

**Origem**: Sprint 010 · **Tipo**: técnica

**O que aconteceu.** O teste de custo da coluna asseria a **constância** assim:

```elixir
poucas = contar_consultas(fn -> abrir(ctx) end)
grande = repositorio_grande(ctx)          # devolvia o MESMO repositório
muitas = contar_consultas(fn -> live(ctx.conn, ~p"/work/repositories/#{grande}") end)
assert poucas == muitas
```

`repositorio_grande/1` devolvia `ctx.cenario.observed_repository_id` — a mesma página que `abrir/1`
já abria. A igualdade era garantida, e o teste passou **medindo nada**.

**Por que aconteceu.** O ajudante foi escrito como atalho — "a página grande já existe, é o cenário" —
e o nome dele, `repositorio_grande`, descrevia a intenção em vez do que ele fazia. Ler o teste depois
dá a impressão de que duas páginas diferentes foram comparadas.

**O que fazer diferente.** Em teste de **invariância** — constância, idempotência, determinismo —,
conferir que os dois lados são de fato **diferentes** antes de asserir que o resultado é igual. Uma
forma barata: se trocar a asserção por `refute` o teste deve **reprovar**. Se ele passa nos dois, não
mede.

E o cheiro: ajudante cujo nome promete variação e cujo corpo devolve uma constante.

**Estado**: aberta.

---

## L42 — Mensagem atrasada de telemetria entra na contagem seguinte

**Origem**: Sprint 010 · **Tipo**: técnica

**O que aconteceu.** Medindo o custo da página três vezes em sequência — vazia, pequena, grande —, a
terceira medição devolveu **22** consultas numa página que faz **20**. O rastro completo, feito
depois, mostrou 10 por render nas duas páginas.

O contador anexa um handler de `[:the_band, :repo, :query]` que faz `send` ao processo do teste, e
depois drena a caixa com `after 0`. As duas mensagens excedentes eram da **medição anterior**,
chegadas depois de o `detach` acontecer.

**Por que é pior do que parece.** Eu quase escrevi uma explicação para o 22 — uma consulta condicional
que só apareceria com mais dado. **Explicar um número instável é a L36 outra vez**: o elo entre duas
medidas é hipótese, não conclusão. A diferença é que aqui uma das medidas simplesmente não era medida.

**O que fazer diferente.** Contador por telemetria **esvazia a caixa antes de anexar**, e o número
tem de repetir entre execuções antes de qualquer explicação. Se ele varia, o instrumento está errado —
e um instrumento errado não se interpreta.

**Estado**: aberta.

---

## L43 — Quando o axioma responde a pergunta errada, a correção é a precondição, não um filtro na resposta

**Origem**: Sprint 010 · **Tipo**: técnica

**O que aconteceu.** A coluna `part of` precisa dizer qual relação o vínculo é, e a decisão da
violação é de `Axioms.rule07/2` — reusá-lo é requisito, para a coluna não discordar do painel da mesma
tela.

Mas `rule07(tarefa, nil)` devolve `{:violation, :task_without_parent}`: em `rule07/2`, `nil` no
conceito do pai significa **não tem pai**. Chamá-lo para toda linha encheria **2 091 das 2 899**
células de aviso, afogando as **293** que são o caso interessante — e a suíte passaria, porque cada
peça funciona.

**Por que aconteceu.** O mesmo `nil` significa duas coisas: "não tem pai" no axioma, e "o pai existe e
não foi promovido" na coluna. É a **L34** — a mesma palavra para duas coisas — aparecendo num valor em
vez de num nome.

**O que fazer diferente.** Duas coisas, e a segunda é a lição:

1. tratar o `nil` ambíguo **antes** de chamar o axioma, numa cláusula própria;
2. quando a resposta do axioma não serve, **restringir a chamada**, não filtrar o resultado. A função
   nova declara a precondição — *há pai* — e o caso de fora dela nem chega ao axioma. Filtrar a
   resposta seria uma segunda decisão sobre o mesmo fato, que é exatamente o que reusar o axioma
   existia para evitar.

**Estado**: aberta.

---

## L44 — Sprint que fecha sem review deixa a lição rascunhada, e a próxima feature a cita como se existisse

**Origem**: Sprint 009, achada no Sprint 010 · **Tipo**: processo

**O que aconteceu.** O sprint 009 foi entregue e mergeado — PR #247, treze issues fechadas — **sem
`sprint-review.md`, sem `aceitacao.md` e sem lições consolidadas**. As lições **L38** e **L39** ficaram
rascunhadas na mensagem de commit da feature e nunca chegaram ao registro acumulado.

A ausência só apareceu quando o **sprint 010** as citou na tabela de "lições aplicadas", como
restrição. Elas foram aplicadas de fato — o `select` nomeado e a medida por diferença estão no
código —, mas **não existiam no documento que existe para ser lido ao abrir o sprint**.

**Por que aconteceu.** O merge encerra a sensação de conclusão. As três peças do fechamento — review,
aceitação, lições — vêm **depois** dele, e nada falha quando são omitidas: os gates passam, as issues
fecham, o PR mergeia.

**É o padrão do sucesso silencioso**, aplicado ao processo em vez ao código: ausência de erro lida
como trabalho concluído.

**O que fazer diferente.** O sprint só está fechado quando os **três** documentos existem, e a
conferência é mecânica:

```bash
ls docs/sprints/<n>-*/          # sprint-backlog.md e sprint-review.md
ls specs/<feature>/aceitacao.md # a aceitação, do sprint 006 em diante
```

**E a aceitação mora em dois lugares**, o que atrasou notar a falta: até o sprint 005 ela ficava em
`docs/sprints/<n>/aceitacao.md`, e do 006 em diante em `specs/<feature>/aceitacao.md`, junto da spec
que ela avalia. Procurar num só lugar dá falso negativo nos dois sentidos.

**Abrir um sprint novo confere o anterior** — e citar uma lição obriga a achá-la no arquivo, não na
memória.

**Estado**: aberta.

---

## L45 — Sprint novo tirado da `main` não enxerga o fecho do sprint anterior enquanto o PR está aberto

**Origem**: Sprint 011 · **Tipo**: processo

**O que aconteceu.** A branch do sprint 011 saiu da `main`, como sempre. E na `main` não existiam o
`sprint-review.md` do sprint 010, a aceitação da feature 011, o `RETOMAR.md` atualizado, nem as
lições **L38 a L44** — os quatro estão no PR [#264](https://github.com/The-Band-Solution/theband/pull/264),
aberto e aguardando revisão.

O sprint 011 abriria citando lições que, **daquela branch**, não existiam. É o defeito da L44 por
outro caminho: lá a lição não tinha sido escrita; aqui ela foi escrita e não está onde quem abre o
sprint procura.

**Por que aconteceu.** A L44 conferiu a **existência** dos três documentos e não a **visibilidade**
deles. `ls docs/sprints/<n>-*/` responde diferente conforme a branch, e a conferência foi escrita
como se `main` fosse o único lugar onde documento vive.

E há a causa de fundo: o fecho de um sprint viaja no **mesmo PR** da feature. Enquanto ele não
incorpora, o sprint está fechado no repositório e aberto na `main`.

**O que fazer diferente.** Ao abrir sprint, conferir **onde** o fecho do anterior está antes de
escolher a base da branch:

```bash
gh pr list --state open           # o fecho do sprint anterior está num PR aberto?
git log --oneline main -1         # a main tem o commit que fecha o sprint anterior?
```

Se estiver em PR aberto, **empilhar** a branch sobre a dele — foi o que este sprint fez, e teve o
efeito colateral de desbloquear a tarefa de tela, que dependia do mesmo código.

**Estado**: aberta.

---

## L46 — Teste com corte temporal e dado montado no mesmo instante passa ou falha por sorte

**Origem**: Sprint 011 · **Tipo**: técnica

**O que aconteceu.** Dois defeitos de teste, ambos de relógio, ambos no mesmo dia:

| Sintoma | Causa |
|---|---|
| a segunda coleta não marcava nada | as duas coletas caem no **mesmo segundo**, e o corte é `<` estrito |
| a marca alcançou **33** vínculos onde se esperava 9 | o corte era `DateTime.utc_now/1`, e montar a fixture leva centenas de milissegundos: parte dos vínculos ficou do lado errado da virada do segundo |

O segundo é o pior dos dois: ele **passa** quando a máquina está rápida.

**Por que aconteceu.** O corte de uma marca de ausência é uma afirmação sobre **tempo decorrido**, e
o teste montava tudo num instante só. No dado real, entre uma coleta e a seguinte passam horas.

**O que fazer diferente.** Em teste de corte temporal, duas regras:

- **envelhecer o dado explicitamente** — recuar o carimbo do que a coleta anterior gravou, em vez de
  esperar que o relógio ande sozinho;
- **o corte é sempre passado e fixo** — `agora() - 15 min`, nunca `agora()`. Um corte no instante da
  chamada compete com o tempo de montagem do cenário.

**Estado**: aberta.

---

## L47 — Vínculo entre repositórios só existe a partir da segunda coleta

**Origem**: Sprint 011 · **Tipo**: conhecimento

**O que aconteceu.** O teste do vínculo cujo pai está em `A` e a filha em `B` falhou por não achar
vínculo nenhum. A causa não é o teste: é como a coleta funciona.

`vincular/2` roda **por repositório**, e resolve a filha por `external_id` entre as issues **já
gravadas**. Quando `A` é processado, a issue de `B` ainda não existe — a relação vira recusa
`out_of_scope`. Na coleta **seguinte**, a filha já está no banco, e aí o vínculo é registrado.

**Por que importa.** Explica dois números do dado real que pareciam desconexos: as **4** recusas
`out_of_scope`, e os **57** vínculos que cruzam repositório. São o mesmo fenômeno em momentos
diferentes — a recusa é o vínculo cruzado **antes** da coleta que o completa.

E tem consequência direta: **a primeira coleta de uma organização subconta a decomposição**, e
ninguém percebe, porque a recusa é registrada em silêncio.

**O que fazer diferente.** Ao medir decomposição em organização recém-observada, conferir
`refused_links` antes de concluir que a origem não declara. E ao montar cenário de teste com vínculo
entre repositórios, **coletar duas vezes** — uma coleta só não produz o estado.

**Estado**: aberta.

---

## L48 — Palavra de fechamento em português não fecha a issue, e nada avisa

**Origem**: Sprint 011 · **Tipo**: processo

**O que aconteceu.** O PR [#278](https://github.com/The-Band-Solution/theband/pull/278) abriu com
**"Fecha #263"** na primeira linha do corpo. O PR foi incorporado, e a **#263 continuou aberta**.

**E não foi a primeira vez.** A conferência da lista de issues abertas — feita pela pessoa
mantenedora, perguntando *"por que estas ainda estão abertas?"* — achou a **#246** aberta desde o
merge do PR [#264](https://github.com/The-Band-Solution/theband/pull/264), que dizia **"Fecha
#246"**. Dois PRs, o mesmo mecanismo, e nenhum dos dois avisou.

O GitHub só reconhece as palavras em inglês — `close`, `closes`, `closed`, `fix`, `fixes`, `fixed`,
`resolve`, `resolves`, `resolved`. "Fecha" vira texto comum: cria a referência cruzada, que **parece**
o vínculo funcionando, e não fecha nada.

**Por que aconteceu.** Os documentos deste repositório são em português, e a frase saiu no idioma do
resto. E o sinal de que deu certo é indistinguível do sinal de que deu errado: a issue aparece
mencionada no PR nos dois casos.

**É o padrão do sucesso silencioso outra vez** — nenhum erro, e a issue fica aberta parecendo
trabalho não feito.

**O que fazer diferente.** A palavra de fechamento é **em inglês**, mesmo no corpo em português:

```text
Closes #263.
```

E a conferência é uma linha, depois do merge:

```bash
gh issue view <n> --json state --jq .state   # CLOSED, ou fecha na mão
```

**Vale também para a segunda armadilha do mesmo mecanismo**: a palavra só fecha quando o PR entra na
branch **padrão**. PR empilhado, cuja base é outra branch, não fecha issue nenhuma ao ser incorporado
— e o #278 era empilhado. O #264 **não** era, e mesmo assim não fechou: ali a causa foi só o idioma.

**E a conferência que achou a reincidência não foi minha**: foi a pessoa mantenedora olhando a lista
de issues abertas. Duas issues entregues ficaram abertas por dias sem que nada indicasse. **A lista
de issues abertas é a conferência**, e ela vale ao fechar o sprint:

```bash
gh issue list --state open --limit 100   # alguma delas já foi entregue?
```

**Estado**: aberta.

---

## L49 — Uma medida não descreve uma tela cujo custo depende do plano de execução

**Origem**: Sprint 012 · **Tipo**: técnica

**O que aconteceu.** Medi o detalhe da pessoa numa pessoa só — **85 ms** — e escrevi a spec inteira
com esse número. A pessoa mantenedora apontou uma página que levava **2 s**. As oito pessoas com mais
trabalho mediram entre **3,5 e 6,12 s**, e a que eu havia medido era a **mais rápida de todas** —
com mais issues designadas que qualquer outra.

**Por que aconteceu.** A consulta tinha uma subconsulta sobre todas as promoções do tenant, e o
Postgres a executava por estratégias diferentes conforme o que estimava: uma ordenação única em um
caso, **163 451 ordenações em grupo** em outro. O tempo não dependia do tamanho da pessoa; dependia
do caminho escolhido.

**É a L30 num terreno novo.** Lá era conferir o número contra a origem; aqui é que **uma amostra não
descreve uma distribuição** quando a variável escondida é o plano de execução.

**O que fazer diferente.** Ao medir tela, medir **a cauda**: os casos com mais dado, e pelo menos
cinco deles. E quando dois casos parecidos derem tempos muito diferentes, isso **é** o achado —
não ruído a ser descartado.

**Estado**: aberta.

---

## L50 — Teste que compara duas medidas precisa provar que mediu alguma coisa

**Origem**: Sprint 012 · **Tipo**: técnica

**O que aconteceu.** O teste que garante que o custo não cresce com o histórico comparava linhas
lidas antes e depois de dobrar as promoções. **Passou na primeira execução — medindo zero.** A
expressão que extraía o número do plano procurava `"Relation Name"` antes de `"Actual Rows"`, e o
JSON do Postgres traz as chaves em **ordem alfabética**: nunca casava.

`0 <= 0 × 1,5` é verdadeiro. O teste teria vigiado a regressão para sempre sem nunca olhar.

**Por que aconteceu.** A asserção era sobre a **relação** entre duas medidas, e relação entre dois
zeros é sempre satisfeita. O caso de teste tinha a forma certa e o conteúdo vazio.

**O que fazer diferente.** Todo teste que compara medidas carrega uma **guarda de que a medida
existe**:

```elixir
assert simples > 0, "a medida deu zero — o que passou não foi a garantia"
```

É a mesma família da L22 e da L41: comparação que não sabe dizer se algum dos lados aconteceu.

**Estado**: aberta.

---

## L51 — Afirmar sobre o schema sem conferir contradiz a documentação que já está no código

**Origem**: Sprint 012 · **Tipo**: processo

**O que aconteceu.** Escrevi em **quatro documentos** que `inserted_at` tinha precisão de segundo, e
construí sobre isso um "defeito de correção": promoções empatadas devolveriam conceito arbitrário.

O schema declara `timestamps(type: :utc_datetime_usec)`, a coluna tem precisão **6** no banco, e a
docstring de `list_issues/2` já dizia, por extenso, *"`inserted_at` em microssegundo desempata"*.

**Por que aconteceu.** Reconheci um padrão — `utc_datetime` de segundo é o default do projeto em
outras tabelas — e apliquei sem conferir **nesta**. O padrão era verdadeiro em três tabelas vizinhas
e falso na que importava.

**E o custo foi baixo só por acaso**: o desempate continuou entrando como seguro, e nada no plano
mudou. Se a conclusão tivesse sido "precisamos migrar a coluna", teria custado um sprint.

**O que fazer diferente.** Antes de escrever uma característica do schema numa spec, **ler o schema**
— e, quando houver docstring sobre o assunto, ler antes de contradizê-la. O código é a origem; a
memória do padrão não é.

**Estado**: aberta.

---

## L52 — Continuidade de conversa não é continuidade de branch

**Origem**: Sprint 013 · **Tipo**: processo

**O que aconteceu.** As features 014 e 015 nasceram da mesma conversa: medir a 014 revelou os 288
logins sem pessoa, e a decisão de criá-los virou a 015. **Implementei as duas na mesma branch**, e o
PR nasceu com os dois diffs — contra o `AGENTS.md` §17, e contra o que o **meu próprio sprint
backlog** dizia duas seções acima: *"dois PRs, um sprint"*.

**Por que aconteceu.** A segunda feature era consequência direta da primeira, e a sensação de
continuidade — mesma conversa, mesma medida, mesmo assunto — se estendeu ao branch sem decisão
consciente. **Escrever a regra no backlog não impediu de quebrá-la**: ela foi lida na abertura e não
na hora de commitar.

**O custo real**: navegação e ingestão têm critérios de revisão diferentes. Quem revisasse o #284
teria de trocar de critério no meio do diff — e é exatamente isso que a regra existe para evitar.

**O que fazer diferente.** A pergunta é no **primeiro commit de código**, não na abertura do sprint:

```bash
git log --oneline main..HEAD    # os commits de código são todos da mesma feature?
```

Se a resposta for não, a branch nova nasce **antes** do commit, não depois. Corrigir depois custou
duas branches por cherry-pick e um PR fechado.

**Estado**: aberta.

---

## L53 — O teto de um teste de custo vem da medida dos dois lados

**Origem**: Sprint 013 · **Tipo**: técnica

**O que aconteceu.** Escrevi um teste garantindo que ligar nomes não acrescenta consulta, com o teto
`assert consultas <= 30`. **Reprovou com o código certo**: a tela fazia 38. O reflexo seria subir o
número até passar — e um `<= 300` passaria com o defeito que o teste existe para pegar.

Medi os dois lados: **39 antes** da feature, **38 depois**. O teto virou 39.

**Por que aconteceu.** O número saiu de estimativa — "uma tela dessas deve fazer umas 30" — e não de
medida. Um teto estimado erra nos dois sentidos, e os dois são ruins: reprova o certo, ou aprova o
errado.

**O que fazer diferente.** Teste de custo com teto numérico exige **medir o antes**, e o comentário
guarda os dois números:

```elixir
# 39 antes da feature, 38 depois. Um teto de 30 reprova o código certo;
# um de 300 passa com o defeito.
assert consultas <= 39
```

Vale para consulta, tempo, linhas lidas e memória — e é irmã da **L50**, que exige provar que a
medida não é zero.

**Estado**: aberta.

## L54 — Átomo criado sob demanda faz o resultado depender da ordem de carga

**Origem**: Sprint 014 · **Tipo**: técnica

**O que aconteceu.** O carregador da base classificava o tipo de cada artefato com
`String.to_existing_atom(chave_de_topo)`, com `rescue ArgumentError -> :unknown`. A intenção era
certa: texto vindo de arquivo não pode criar átomo.

O efeito era outro. A existência do átomo dependia de **qual módulo já tinha sido carregado**.
Antes de `Mix.Task.run("app.config")`, `:ontology` ainda não existia — as 12 ontologias viravam
`:unknown`, o mapa de dependências saía vazio, e a validação reprovava a base com **124 problemas
inventados**, todos em ontologias que declaram a dependência ali no arquivo. Depois de
`app.config`, a mesma base passava.

Perdi horas perseguindo o defeito na base, porque a chamada direta ao validador aprovava e a Mix
task reprovava — com o mesmo código, sobre os mesmos arquivos.

**Por que aconteceu.** `to_existing_atom` transforma uma pergunta sobre o **dado** ("este tipo é
conhecido?") numa pergunta sobre o **estado da máquina virtual** ("este átomo já foi criado?"). As
duas coincidem quase sempre, e divergem exatamente quando o código roda cedo.

**O que fazer diferente.** Conjunto fechado e conhecido em compilação vira **tabela literal**:

```elixir
@tops [{"ontology", :ontology}, {"module", :module}, ...]

defp kind_from(top) do
  case List.keyfind(@tops, top, 0) do
    {_, kind} -> kind
    nil -> :unknown
  end
end
```

O átomo existe assim que o módulo carrega, e o resultado deixa de depender da ordem. Vale para todo
mapeamento texto → átomo sobre conjunto fechado: tipo de artefato, coluna ordenável, papel.

**Estado**: aberta.

## L55 — Task que não compila valida o build anterior

**Origem**: Sprint 014 · **Tipo**: processo

**O que aconteceu.** `mix knowledge.validate` chamava `Mix.Task.run("app.config")` e nada mais.
`app.config` **não compila**. A task rodava contra os beams da compilação anterior, então uma
correção no validador não aparecia — e eu depurava um defeito já corrigido em disco, com a chamada
direta ao módulo aprovando e a task reprovando.

**Por que aconteceu.** `mix run`, `mix test` e `mix compile` compilam sozinhos, e a gente
generaliza que "task Mix compila". Não é verdade: quem compila é a dependência declarada, e
`app.config` não a tem.

**O que fazer diferente.** Toda Mix task que **mede** o código — gate, validador, relatório —
começa por `Mix.Task.run("compile")`. Gate que mede código velho mente nas duas direções: aprova o
que já quebrou, e reprova o que já foi corrigido.

**Estado**: aberta.

## L56 — Filtrar telemetria pela `source` não alcança quem consulta por SQL cru

**Origem**: Sprint 014 · **Tipo**: técnica

**O que aconteceu.** Os contadores de consulta excluíam as tabelas do Oban por `meta[:source]` —
correção da L42. O job de cobertura reprovou mesmo assim: 30 consultas com poucas issues e 31 com
muitas, numa tela que a branch não tocava.

O Oban consulta por **SQL cru**. Aí `meta[:source]` vem nula, enquanto o texto da consulta diz
`oban_jobs`. Sob cobertura a execução alarga, o tick do `Oban.Stager` cai dentro da janela, e a
consulta entra na conta da tela.

**Por que aconteceu.** A primeira correção fechou o caminho que eu tinha visto — consulta via
schema — e assumiu que era o único. `source` é preenchida pelo Ecto quando há schema; sem schema,
não há o que preencher.

**O que fazer diferente.** Filtro de telemetria de consulta olha **os dois**: a `source` e o texto.

```elixir
String.starts_with?(query, "SELECT") and
  to_string(meta[:source]) not in ignoradas and
  not String.contains?(query, "oban_")
```

E a lição atrás da lição: **teste que reprova sob cobertura e passa fora dela não é intermitente
por acaso** — a cobertura muda o tempo, e o que muda com o tempo é a janela de quem mede.

**Estado**: aberta.

## L57 — Verificação que filtra um tipo que ninguém produz nunca roda

**Origem**: Sprint 014 · **Tipo**: técnica

**O que aconteceu.** `perguntas_de_competencia/2` filtrava `kind == :competency_questions`, e
**nenhum** artefato da base tinha esse tipo — o carregador os classificava como `:unknown`. A
verificação existia, era chamada, percorria uma lista vazia e devolvia zero problemas. Verde.

Só apareceu porque a correção do carregador passou a produzir o tipo, e aí a verificação começou a
rodar de fato.

**Por que aconteceu.** É o sucesso silencioso na forma mais difícil de ver: não há erro, não há
aviso, e a função **está** no caminho de execução. O que falta é o dado, e a ausência de dado é
indistinguível de ausência de problema.

**O que fazer diferente.** Verificação que filtra por tipo carrega um teste que **prova que o
filtro acha alguém**:

```elixir
assert perguntas != [], "nenhum arquivo de perguntas de competência foi reconhecido"
```

Vale para toda a família: `Enum.filter` por tipo, `where` por categoria, consulta por
discriminador. Se o conjunto filtrado puder ser vazio por engano, o teste afirma que não é.

**Estado**: aberta.

## L58 — PR empilhado incorporado depois da base não chega a lugar nenhum

**Origem**: Sprint 015 · **Tipo**: processo

**O que aconteceu.** Três PRs empilhados, e a ordem de incorporação foi esta:

```
03:25:48  #302 → 034-editar-credenciais ... ✓ verde
03:26:03  #301 → main                    ... ✓ verde   (leva a 033, que leva a 034)
04:50:35  #303 → 034-editar-credenciais  ... ✓ verde
```

Os três merges ficaram verdes. **O conteúdo do #303 não chegou à `main`**, porque às 04:50 a
`034` já não era caminho para lugar nenhum: ela tinha sido incorporada à `033` às 03:25, e a
`033` à `main` quinze segundos depois.

Quatro commits ficaram órfãos — `data_table.ex` e `tabela_live.ex` sequer existiam na `main`.
E não eram só os do #303: os dois últimos commits do #302, empurrados **depois** que ele foi
incorporado, seguiram o mesmo caminho para lugar nenhum.

**Por que aconteceu.** Merge de PR empilhado não confere se a base ainda desagua. O GitHub
tem o que precisa para avisar — ele sabe que a `034` já foi incorporada — e não avisa: para
ele, incorporar numa branch existente é operação válida, e é mesmo.

O sinal também é enganoso na direção errada: **o PR fica verde**. Verde ali significa "este
diff se aplica sobre esta base", e não "este código vai para a `main`".

**O que fazer diferente.** Duas coisas, e a segunda é a que pega:

1. **incorporar o empilhado antes da base**, ou reapontá-lo para a `main` depois de a base
   ter ido;
2. **conferir o commit na `main`, e não o PR verde**:

```bash
git fetch origin
git branch -r --contains <sha> | grep origin/main   # vazio = não chegou
```

É a L48 aplicada a **conteúdo** em vez de a palavra de fechamento. A L48 nasceu de `Fecha #281`
não fechar a issue; esta nasce de um merge não incorporar o código. As duas têm a mesma forma:
a operação foi feita, o efeito não aconteceu, e nada disse.

**E é a L45 pela outra ponta.** A L45 diz que sprint novo tirado da `main` não enxerga o fecho
do anterior enquanto o PR está aberto — o trabalho existe e a `main` não o vê. Aqui o PR foi
incorporado e a `main` continua sem ver: mesmo sintoma, causa oposta.

**Estado**: aberta.

## L59 — O verde do CI dependia de quem disparou a execução

**Origem**: Sprint 015 · **Tipo**: técnica

**O que aconteceu.** O commit `090c9ea1` foi medido duas vezes pelo mesmo workflow, no mesmo
minuto:

```
por push            cobertura 80,2%   ✓ passou   (122,7 s de teste)
por pull_request    cobertura 23,4%   ✗ falhou   ( 14,0 s de teste)
```

A execução que falhou tinha **toda** a árvore `lib/the_band_web` em 0,0% — inclusive arquivos
com teste de sobra. Não era queda de cobertura: era a suíte caindo, e a cobertura medindo o que
sobrou.

**A cadeia.** `config/test.exs` não sobrescrevia o Oban, então em teste subiam fila, `Cron`,
`Pruner` e `Peer` de verdade. Eles consultam o banco por conta própria, fora do processo dono da
conexão do sandbox, e cada consulta morre com `DBConnection.OwnershipError`. O supervisor
reinicia, e o ciclo recomeça.

Quando a intensidade de reinício estoura, quem reinicia é o supervisor da **aplicação** — e ele
leva junto o `KnowledgeBase`, que é dono da tabela ETS da base de conhecimento:

```
** (ArgumentError) the table identifier does not refer to an existing ETS table
   :ets.lookup(:the_band_knowledge_base, {:derivation_rule, ...})
```

**197 testes** falharam assim, todos pelo mesmo motivo, e nenhum deles tinha defeito.

**Por que aconteceu.** Três coisas se somaram, e sozinha nenhuma teria derrubado:

1. processo do Oban consultando o banco fora do dono da conexão — barulho tolerado havia meses,
   com centenas de `OwnershipError` por execução local que ninguém lia;
2. um GenServer **dono de tabela ETS** na árvore da aplicação — a tabela morre com o processo;
3. a cobertura mudando o tempo, que é a **L56** de novo.

A terceira é a que fez o defeito escolher execuções. As duas primeiras estavam lá o tempo todo.

**O que fazer diferente.**

**Barulho tolerado é defeito não medido.** Centenas de `OwnershipError` por execução eram lidas
como ruído de teste. Eram um supervisor reiniciando em ciclo. Erro que aparece sempre e não
derruba nada ainda não derrubou — não é o mesmo que não derrubar.

**Estado guardado em processo tem o tempo de vida do processo.** Tabela ETS pertence a quem a
criou. Se o dono está na árvore da aplicação, todo reinício de supervisor apaga a base de
conhecimento — e o sintoma aparece longe, em qualquer teste que a leia.

**Veredito que muda com o gatilho é veredito que não vale.** Se o PR tivesse sido incorporado
pelo verde do push, o defeito seguiria escolhendo PRs ao acaso — e quem visse vermelho
aprenderia a reexecutar sem ler, que é a mesma erosão descrita na issue #232.

**E a nota do conserto**: `testing: :manual`, que é o modo documentado do Oban, **não serviu** —
ele confere a versão da migração na subida, e o repositório está em `version: 12` com a
biblioteca exigindo 14. Consertar o CI subindo migração de produção de carona teria trocado um
defeito por um risco. A dívida ficou registrada, separada, no PR #308.

**Estado**: aberta.

---

## L60 — O pipe no `mix gates` devolve o código de saída do `tail`

**Origem**: Sprint 016 · **Tipo**: processo

**O que aconteceu.** A primeira execução dos gates desta sessão foi:

```bash
mix gates 2>&1 | tail -40; echo "EXIT=$?"
```

O relatório disse **código de saída 0**. Os gates tinham **reprovado**:

```
** (Mix) The database for TheBand.Repo couldn't be created: killed
** (Mix) gate reprovou: testes — código de saída 1
EXIT=0
```

O `$?` de um pipeline é o do **último** comando, e o último era o `tail` — que sempre sai
com zero, porque ler quarenta linhas nunca falha. A causa real era o Docker fora do ar, e
o Postgres recusando conexão em `localhost:5432`.

**Por que isto é uma reincidência, e não um caso novo.** A regra já está escrita em três
lugares: no `AGENTS.md` (seção 4, *"não desabilite check"*), na memória do projeto
(*"`mix gates` é a definição única — nunca rodar gate com `| tail`"*), e nas próprias
lições. Foi violada mesmo assim, na primeira execução, por um motivo banal: o pipe estava
lá para **encurtar a saída**, e não para burlar o veredito.

**É a mesma família da lição que mais reincide neste repositório** — ausência de erro lida
como resultado. Aqui a ausência foi fabricada pelo próprio comando de leitura.

**O que fazer diferente.**

**Para encurtar a saída, redirecione para arquivo — nunca canalize.**

```bash
mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?"   # o $? é do mix
tail -40 /tmp/gates.log                            # a leitura vem depois, e é outra coisa
```

O redirecionamento preserva o código de saída porque não há segundo comando. A leitura da
saída e a obtenção do veredito passam a ser dois atos separados, que é o que eles sempre
foram.

**A regra escrita não impediu.** O que impede é a forma do comando ser diferente: enquanto
`| tail` for o jeito natural de encurtar, alguém vai usá-lo de novo. A alternativa acima
precisa ser tão curta quanto, senão a regra continua dependendo de memória.

**Estado**: aberta — a forma com redirecionamento **entrou no `AGENTS.md`** (seção 4,
ao lado da proibição), o que resolve a pendência original.

**Aplicada em**: Sprint 022 — e cobrou uma variação nova. O comando foi
`mix gates > log 2>&1; echo "EXIT=$?"` rodado em background: o `EXIT=` foi para a
saída da *task*, e o log terminou só em "13 gates verdes" — a aceitação apontou que o
log não continha o código de saída. A forma completa grava o veredito **no próprio
log**: `mix gates > log 2>&1; echo "EXIT=$?" >> log`. Duas execuções sem reincidência
do pipe; mais uma e encerra.

---

## L61 — Uma limitação declarada no mapeamento não vira restrição no código sozinha

**Origem**: Sprint 021 (feature 037) · **Tipo**: conhecimento

**O que aconteceu.** O mapeamento `github.workflow_run.to.ciro.continuous_integration_process`
dizia, desde a versão 1, na sua própria seção `limitations`:

> Nem todo workflow é integração contínua; workflows de release mapeiam para CDRO.

Implementei a coleta mapeando **toda** execução do Actions para
`ciro.continuous_integration_process`. Só ao medir contra o dado real o problema apareceu: das
1.051 execuções coletadas, as cinco mais frequentes são `Sync to GitLab` (264),
`Deploy Docs to GitHub Pages` (247), `Deploy Backoffice and Front-office` (235),
`Sprint Rollover` (109) e `Release ConectaFapes` (90). **Nenhuma integra código.**

**Por que aconteceu.** Li o mapeamento pelas seções `target`, `attributes` e `relations` — as
que dizem o que construir. `limitations` foi lida como documentação do que a plataforma não
conseguiria fazer, e não como **especificação de um caminho que o código precisa ter**. A
distinção não existe no formato: as duas coisas moram na mesma lista.

O custo teria sido uma medida de verificação contínua envenenada por execuções que nada
verificam — e ninguém a questionaria, porque o número teria a mesma aparência do número certo.

**O que fazer diferente.** Ao implementar um mapeamento, ler `limitations` **antes** de
`attributes`, e classificar cada item em dois montes: o que a plataforma não pode saber (vira
frase de ausência na tela) e o que a plataforma **precisa distinguir** (vira ramo no código).
O segundo monte é requisito, não nota de rodapé.

E quando um item do segundo monte for atendido, marcá-lo `RESOLVIDA na versão N` no próprio
arquivo — foi o que a versão 2 deste mapeamento passou a fazer.

**Estado**: aberta.

---

## L62 — Somar contadores por lista escrita à mão apaga a chave nova em silêncio

**Origem**: Sprint 021 (feature 037) · **Tipo**: técnica

**O que aconteceu.** A fase de coleta do CI acumula um resumo somando mapas com
`%{jobs: a.jobs + b.jobs, monoliticos: ..., sem_nome: ...}`. Ao acrescentar a chave
`sem_jobs` — que é o que decide se o checkpoint do repositório avança —, `somar/2` **não foi
atualizada**. O resultado: `marcar_se_completo/3` sem cláusula correspondente, e a fase
derrubaria qualquer sincronização de repositório com pelo menos uma execução.

Passou por `mix gates` inteiro, com 1.038 testes verdes, e foi para o PR.

**Por que aconteceu.** Duas causas somadas. A soma repetia a lista de chaves num segundo lugar,
e nada ligava os dois. E **a fase nunca era exercitada**: sem repositório observado, a lista de
repositórios é vazia e nenhuma requisição acontece — o teste da sincronização completa passava
por ela sem tocá-la. É a mesma sombra em que a coleta de arquivos ficou **desligada** com o
moduledoc afirmando que estava ligada.

**O que fazer diferente.** Duas coisas, e a segunda é a que pega a família inteira:

```elixir
# a soma deriva as chaves do zero, e não as repete
defp somar(a, b) do
  Map.new(zero(), fn {chave, _} -> {chave, Map.fetch!(a, chave) + Map.fetch!(b, chave)} end)
end
```

E: **toda fase que só roda com uma pré-condição de dado precisa de um teste que crie essa
pré-condição.** A pergunta ao terminar uma fase nova é "que linha do banco faz esta fase
existir?", e o teste começa criando essa linha. Sem isso, a suíte verde só prova que a fase
não foi visitada.

**Estado**: aberta.

---

## L63 — Vínculo que só grava o que casou apaga o que a origem disse

**Origem**: Sprint 021 (feature 038) · **Tipo**: técnica

**O que aconteceu.** Um painel novo em `/work/changes` mostrou **"no issue recognised:
4.177"** — 83% das 5.035 solicitações sem vínculo com escopo. A pessoa mantenedora
desconfiou do volume e mandou conferir. Três solicitações amostradas contra a origem:

| PR | a origem diz | o banco diz |
|---|---|---|
| `The-Band-Solution/theband#427` | fecha #426 | nenhum vínculo |
| `leds-conectafapes/…-otto#127` | fecha #675 | nenhum vínculo |
| `…prestacao-de-contas#133` | fecha nada | nenhum vínculo |

**Dois de três eram falha da coleta**, não fato sobre o processo.

**Por que aconteceu.** `GithubChangeRequests.vincular_issues/3` traduz os
`closingIssuesReferences` da origem para ids internos, e só grava o que **já existe** em
`collected_issues`:

```elixir
externos = Enum.map(get_in(node, ["closingIssuesReferences", "nodes"]) || [], & &1["id"])
ids = issue_ids_por_external(ctx.tenant.id, externos)   # casa só com o já coletado
:ok = Commands.replace_attended_issues(ctx.tenant, solicitacao_id, Map.values(ids))
map_size(ids)                                            # conta só o que casou
```

Quando a issue não está no banco, o vínculo é descartado **sem registro**. A função devolve
`map_size(ids)` — o que casou —, e nunca `length(externos)` — o que a origem disse. A
diferença entre os dois é exatamente o buraco, e ela não é gravada em lugar nenhum.

O padrão é o do `commits_total`, que a mesma feature acertou: o total da origem fica na
coluna, e a tela compara com o coletado para revelar truncamento. Aqui não ficou.

**O que fazer diferente.** Toda tradução de referência externa para id interno **grava os
dois números**: quantos a origem citou, e quantos a plataforma resolveu. A regra em uma
frase: *se a função descarta alguma coisa, o quanto ela descartou é dado, não detalhe de
implementação.*

E a asserção que pega isto num teste: montar um PR cuja `closingIssuesReferences` cite uma
issue **não coletada**, e exigir que o total da origem apareça no registro.

**O custo evitado.** O painel teria publicado "83% do trabalho sem rastro até o escopo"
como medida do processo da organização. Ninguém questionaria — o número tem a mesma
aparência do número certo. É a mesma família de
[[padrao-largo-inventa-mais]]: o erro caro é o que se parece com medida.

**Estado**: aberta — o conserto ainda não foi feito.

---

## L64 — Denominador que inclui o caso impossível esconde o sinal

**Origem**: Sprint 021 (issue #440) · **Tipo**: técnica

**O que aconteceu, duas vezes no mesmo dia.**

Primeiro: um painel dizia "no issue recognised: 4.177" — 83% das solicitações. Amostrei
três, duas eram falha da coleta, e anunciei que o número estava errado. Medido depois do
conserto: 4.168 eram fato real e 9 eram lacuna nossa. A amostra de três não media 5.035.

Depois, no levantamento do #440, ao avaliar dois campos do payload da execução de CI:

| campo | como eu apresentei | o denominador certo |
|---|---|---|
| `pull_requests` | 3 de 1.052 execuções — 0,3%, "não vale" | 3 de **33** execuções disparadas por PR — **9%** |
| `triggering_actor` | difere em 1 de 1.052 — "não vale" | difere em 1 de **3** reexecuções — **33%** |

**Por que aconteceu.** Nos dois casos o denominador incluiu registros onde o campo **não
pode existir**. Execução disparada por `push` não tem pull request associado; primeira
tentativa não tem ator de reexecução diferente do ator original — é a mesma pessoa, por
definição. Somar esses casos ao denominador dilui o sinal até ele desaparecer.

E a pessoa mantenedora pegou as duas vezes, pelo volume. Na segunda, citando de volta o meu
próprio texto.

**O que fazer diferente.** Antes de calcular uma proporção, responder: **em quantos
registros esse campo poderia estar preenchido?** Esse é o denominador. Se a resposta exige
um filtro, o filtro é parte da medida e vai declarado junto com ela.

E o corolário, que vale para toda medida desta plataforma: quando o denominador correto é
pequeno — 33, ou 3 —, a conclusão honesta é **"amostra pequena, não sei"**, e não uma
porcentagem. Três reexecuções não decidem se vale guardar `triggering_actor`.

**A raiz comum com [[padrao-largo-inventa-mais]]**: o erro caro é o que se parece com
medida. Uma porcentagem com denominador errado tem exatamente a mesma aparência de uma
correta.

**Estado**: aberta.

---

## L65 — Coleta que a rede já especificou custa a fração de uma que não

**Origem**: Sprint 021 (issue #440) · **Tipo**: processo

**O que aconteceu.** O levantamento do #440 encontrou três mapeamentos declarados sem
nenhuma linha no banco: review, branch e deployment. Implementar os dois primeiros levou
uma sessão, e o motivo é que **quase nada precisou ser decidido**:

| peça | review | branch |
|---|---|---|
| conceito alvo | declarado | declarado |
| atributos e caminhos na origem | declarados | declarado (um) |
| relações | declaradas no mapeamento | declaradas |
| necessidade de informação | declarada | — |
| medida | declarada, com insumos | — |
| limitações | quatro, todas acionáveis | duas |

O trabalho foi **traduzir o que já estava escrito** para migração, esquema, consulta e
tela. Nenhuma reunião, nenhuma escolha de recorte, nenhuma dúvida sobre o que o número
significa.

**A comparação que fecha o argumento.** No mesmo dia, a terceira — deployment — não avançou
nem um passo, porque a fonte estava errada: a API do GitHub tem 2 registros onde os jobs de
CI já produzem 1.361. Ela virou a issue #442, com quatro decisões pendentes, e a decisão da
pessoa mantenedora de usar o ArgoCD. **Uma coleta cuja fonte ainda não foi decidida custa
ordens de magnitude mais que uma cuja ontologia já foi.**

**Por que aconteceu, e o que isso ensina sobre a ordem do trabalho.** O mapeamento
escrito na frente do código não é documentação: é a parte cara do trabalho já feita. As
quatro limitações da review viraram quatro decisões de esquema em minutos —
`author_type` para separar bot, `state` cru para não afirmar conformidade, `reviews` em vez
de `reviewThreads`, e `submitted_at` nulo para rascunho. Nenhuma delas eu teria pensado
sozinho na hora de escrever a migração.

**O que fazer diferente.** Antes de propor coleta nova, varrer os mapeamentos declarados e
perguntar **quais já estão especificados e sem dado**. Essa lista é o backlog mais barato
que existe, e ela não aparece em nenhuma tela — só lendo os YAML.

O comando que a produz:

```bash
# para cada mapeamento, existe tabela com dado?
for f in $(find priv/knowledge_base/mappings -name "*.yaml"); do
  grep -m1 "  id: " "$f"
done
```

E o corolário: **limitação declarada no mapeamento vale mais que requisito escrito depois**,
porque foi escrita por quem estava olhando a ontologia, não a tela. É [[L61]] pelo lado
positivo.

**Estado**: aberta.

---

## L66 — Script que monta o contexto à mão esconde o contrato que o job real quebra

**Origem**: Sprint 021 · **Tipo**: técnica

**O que aconteceu.** A sincronização agendada morria em **todos os três tenants**, nas cinco
tentativas do Oban, com `KeyError key :started_at not found`. Ficava `interrupted`, e já
acontecia desde **2026-08-17** — dias antes de alguém notar. A pessoa mantenedora perguntou
por que dois tenants tinham dado erro; eram três.

A causa é uma linha em `SyncGitHubEO.run/4`:

```elixir
started_at = sync.started_at        # variável local

ctx = %{tenant: tenant, sync: sync, tool: tool, token: token, org: tool.organization_login}
#      ^ sem `started_at`, e nove pontos de ingestão leem `ctx.started_at`
```

**Por que ninguém viu.** Duas causas somadas, e a segunda é a lição:

1. O caminho que lê a chave só roda **quando há dado para marcar** — a marca de ausência de
   issue e de iteração. Com fixture vazia, nada precisa de marca e a linha nunca é
   alcançada. É a [[L62]] outra vez.

2. **Toda coleta manual desta sessão montou o `ctx` à mão**, e sempre com `started_at`:

   ```elixir
   ctx = %{tenant: tenant, tool: tool, token: token, started_at: DateTime.utc_now(:second)}
   ```

   Rodei a coleta de mudanças, de CI, de branches e de reviews contra o dado real, todas com
   sucesso — e nenhuma passou pelo `ctx` que o job constrói. O script satisfazia o contrato
   que o job violava, e por isso a evidência de "funciona contra o dado real" era falsa
   justamente onde importava.

**O que fazer diferente.** Script de coleta avulsa **não monta o contexto**: chama a mesma
função que o job chama, ou pede o contexto a ela. Quando isso não é possível, o script
declara no topo que o contexto é sintético — e o resultado dele não conta como evidência de
que o job funciona.

A pergunta que fecha: *este script prova que o caminho de produção funciona, ou só que a
função funciona com o contexto que eu escolhi?*

**E a tentativa de teste que não provou nada.** Escrevi um teste que devolve uma issue pela
borda simulada para forçar a marca de ausência. Ele passou. **Removi a correção de propósito
e ele continuou passando** — a issue não chegava a ser gravada, e o caminho nunca rodava.
Sem essa verificação eu teria anunciado uma garantia inexistente.

*Todo teste escrito para pegar um defeito específico precisa ser rodado contra o código
defeituoso.* Se ele passa nos dois, não é teste do defeito — é teste de outra coisa.

**Estado**: aberta.

---

## L67 — Duas medidas do mesmo nome: comparar os totais esconde que são fenômenos diferentes

**Tipo**: técnica · **Origem**: feature 041 (issue #439) · **Estado**: aberta

**O que aconteceu.** Troquei a medida de "solicitação integrada com verificação
vermelha" do casamento por `head_sha` para o `statusCheckRollup` da ponta, e
justifiquei a troca comparando os **totais**: "o casamento achava 284, o rollup
acha 349 — 23% mais". Escrevi isso em quatro lugares: dois `@moduledoc`, um
comentário de consulta e um comentário de coluna.

Medido no banco depois: o casamento acha **296**, o rollup acha **221**. O rollup
acha **menos**. A afirmação estava invertida, e ela era o argumento inteiro da
troca.

*(Números finais, com a recoleta concluída em 2026-08-20: casamento **323**, rollup
**261**, nos dois **115**, união **469**. O sinal não mudou; ver a L70 sobre por que
os números do meio do caminho não deviam ter sido escritos como definitivos.)*

**Por que aconteceu.** Comparei dois números de uma linha. A pergunta que não fiz
foi *quais* solicitações cada um acha — e a resposta muda tudo:

    nos dois         82
    só o casamento  214
    só o rollup     139
    união           435

Sobreposição de 82 em 435. **Não são duas precisões do mesmo fenômeno; são
fenômenos diferentes.** Das 214 que só o casamento acha, 186 estão verdes na
ponta: a vermelha estava num commit intermediário e foi consertada antes do
merge. O casamento supercontava — e supercontava exatamente o caso que o
`@moduledoc` da tela declara recusar contar ("vermelho num ramo de proposta é o
processo funcionando").

Ou seja: a troca estava certa, e por um motivo **melhor** do que o que eu
escrevi. Mas eu tinha escrito o motivo errado, com um número invertido, e ele já
estava em código revisado.

**O que fazer diferente.** Ao substituir uma medida por outra, nunca justificar
pela diferença dos totais. Medir a **sobreposição** — nos dois, só em A, só em B,
união — e olhar uma amostra do que só o antigo acha. Se a sobreposição for
pequena, os dois não medem a mesma coisa, e o total de cada um não é comparável.

E o corolário sobre convivência: medida antiga substituída se **remove**, não se
deixa ao lado. `integrated_with_red/2` ficou com `@spec`, `@doc` de 25 linhas e
nenhum chamador — código morto cujo `@doc` convenceria quem fosse ligá-lo de que
estava certo.

**Relação com L64.** A L64 é sobre denominador que inclui o caso impossível; esta
é sobre numerador que inclui o caso oposto ao que se quer medir. As duas nascem
de aceitar a contagem sem olhar o que ela contou.

---

## L68 — Corte incremental exclui para sempre o registro antigo quando a consulta ganha campo

**Tipo**: técnica · **Origem**: feature 041 (issue #439) · **Estado**: aberta

**O que aconteceu.** A feature 041 acrescentou `statusCheckRollup` à consulta de
solicitações de mudança. Duas semanas depois, **763 solicitações integradas em 10
repositórios** continuavam sem o campo — e não por falha: `GithubChangeRequests.collect/1`
para de paginar quando alcança `observed_repositories.changes_collected_at`, e esses
repositórios já constavam como coletados.

A assinatura é inconfundível: nos dez repositórios a fração sem o campo era **100%**.
Repositório inteiro sem o campo é repositório não tocado desde que o campo existe.

**Por que aconteceu.** O corte incremental é certo para dado que não muda, e é o que evita
repaginar o histórico a cada coleta. Mas ele responde "já coletei este registro", e a
pergunta que a mudança de consulta faz é outra: "já coletei este registro **com esta
consulta**?". As duas coincidem até alguém acrescentar campo.

**O que fazer diferente.** Toda vez que a consulta de uma fase ganha campo, a mesma
mudança precisa responder o que acontece com o já coletado. Três saídas, e a escolha é
explícita:

  * o campo só interessa daqui para frente — declarar isso, e a tela distinguir
    "não medido" de "medido e vazio", que é o que estas colunas já fazem;
  * reabrir o corte dos repositórios afetados — `mix the_band.recollect_changes`;
  * um backfill dirigido, se a recoleta inteira for caro demais.

O que **não** serve é deixar implícito: o número fica errado, a tela chama de "não dá para
saber", e ninguém liga a lacuna à mudança que a criou.

**A correção estrutural fica em aberto.** Nada no código impede que isso volte na próxima
feature que acrescentar campo. Um marcador de versão da consulta por repositório
invalidaria o corte automaticamente — é decisão de desenho, e está registrada como issue.

---

## L69 — Defeito dentro de `Logger.info` é invisível a teste, por configuração

**Tipo**: técnica · **Origem**: feature 041 · **Estado**: aberta

**O que aconteceu.** `Jobs.RecomputePromotions` interpolava o retorno de
`Mapping.recompute/2` numa string de log. O retorno é `%{written:, concept_changed:}`, e a
interpolação estourava `Protocol.UndefinedError` **depois** de o recálculo já ter
acontecido: o trabalho era feito três vezes e o job terminava `discarded`.

Escrevi o teste, ele reprovou — e reprovou **pelo motivo errado**, no `assert_received` do
broadcast. Ao restaurar só a metade do log, o teste passou.

**Por que aconteceu.** `config :logger, level: :warning` em `config/test.exs`. `Logger.info/1`
é macro: com o nível desligado ela sai **antes de avaliar o argumento**. A interpolação
nunca roda, então o defeito não existe no ambiente de teste.

E `capture_log([level: :info], fn -> ... end)` **não resolve** — a opção filtra o que é
capturado, não o que o Logger emite. O log volta vazio e a asserção falha por outro motivo,
que é fácil confundir com "a frase mudou".

**O que fazer diferente.** Teste que precisa exercitar o conteúdo de um `Logger.info` ou
`Logger.debug` eleva o nível de verdade:

```elixir
nivel = Logger.level()
Logger.configure(level: :info)
on_exit(fn -> Logger.configure(level: nivel) end)

log = capture_log(fn -> assert :ok = Worker.perform(job) end)
assert log =~ "o que a frase promete"
```

E a regra mais larga: **não colocar em interpolação de log nada que possa levantar.** O log
é o lugar do código onde a falha é mais silenciosa — no teste ele não avalia, e em produção
ele derruba o trabalho já feito.

**Relação com o padrão do sucesso silencioso.** É o mesmo defeito de sempre, num lugar
novo: ausência de sinal lida como ausência de problema. Aqui a ausência era da própria
avaliação.

---

## L70 — Número medido no meio de um backfill parece final e não é

**Tipo**: processo · **Origem**: feature 041, recoleta das 763 · **Estado**: aberta

**O que aconteceu.** A L67 conta que eu tinha escrito "2.038 solicitações entraram sem
check, de 4.734 medidas", medi o banco, achei **1.705** de 4.056, e **corrigi** o número em
quatro lugares — inclusive na landing page publicada.

Com a recoleta concluída, o número verdadeiro é **2.024** de 4.878.

Ou seja: o valor original estava a 14 de distância do certo, e a minha "correção" o afastou
para 319 de distância. Corrigi na direção errada, com confiança, e publiquei.

**Por que aconteceu.** Havia 763 solicitações sem o campo medido, e eu sabia disso — a
própria frase que escrevi dizia "só 763 foram coletadas antes de a plataforma pedir o
campo". Mas usei como **denominador** o total já medido, e reportei a contagem parcial como
se fosse o fenômeno.

Um número medido enquanto um backfill roda tem duas propriedades ruins ao mesmo tempo: ele
é preciso (a consulta está certa) e é provisório (a população não está completa). A precisão
faz ele parecer confiável.

**O que fazer diferente.** Antes de escrever qualquer contagem em `@moduledoc`, tela, PR ou
página publicada, checar se existe backfill pendente **daquela coluna**:

```elixir
Repo.aggregate(from(c in tabela, where: is_nil(c.coluna)), :count, :id)
```

Se for maior que zero, uma de duas: esperar, ou rotular o número como parcial e dizer quanto
falta. O que não serve é reportar a contagem sobre o que já foi medido — que é exatamente o
"denominador que exclui o caso pendente", primo da L64.

E o corolário sobre correção: **corrigir um número exige a mesma prova que publicá-lo.** Eu
tratei "medi agora" como suficiente para derrubar um valor anterior, e "agora" era o meio de
uma recoleta.

**Relação com a L68.** A L68 é a causa da população incompleta — o corte incremental
excluindo o registro antigo. Esta é o que fazer enquanto a lacuna existe.

---

## L71 — Quando o requisito muda de lugar, os testes que documentam o lugar antigo caem em lote

**Origem**: Sprint 022 (feature 046) · **Tipo**: processo · **Estado**: aberta

**O que aconteceu.** A feature 046 moveu a navegação — barra de 12 itens virou 4 entidades +
Settings, e o rastro (Changes/Files/Checks) virou sub-aba de Work. A primeira rodada completa da
suíte derrubou **6 testes de uma vez**, e nenhum era defeito do código novo: eram testes
guardando o requisito antigo. Quatro em `menus_do_rastro_test` ("os três destinos aparecem NA
BARRA"), um em `clicar_leva_a_pagina_test` (refutava `href="/organizations"` na página inteira
porque "não existe página de organização" — passou a existir), e um em `migalha_test`
(`aria-current="page"` em âncora — a barra nova usava o mesmo valor da migalha).

**Por que aconteceu.** Testes bons carregam a *razão* do requisito no próprio arquivo — e é
exatamente isso que os torna sensíveis quando a razão muda de endereço. O plano da feature listou
telas e componentes a tocar, mas não perguntou **"quais testes documentam o comportamento que
esta feature aposenta?"**. A suíte respondeu, ao custo de uma rodada inteira (≈10 min) e do
diagnóstico um a um.

**O que fazer diferente.** No plan de qualquer feature que MOVE um requisito (menu, rota, regra
de visibilidade, formato), acrescentar um passo de busca dirigida antes de implementar:
`grep` nos testes pelos invariantes que a spec revoga (os hrefs, as frases, os valores de
atributo). Cada acerto vira decisão registrada: o teste muda de morada junto com o requisito
(preservando a asserção), estreita o escopo, ou morre com a premissa — decidido no plan, não no
vermelho da suíte. E a resolução dos três casos deste sprint é o catálogo de referência:
mudança de morada (rastro), estreitamento de escopo (organização fora da barra), separação de
vocabulário (`"true"` na barra, `"page"` só na migalha).

---

## L72 — A API de iterations substitui a lista inteira: reenviar sempre as vigentes

**Origem**: Sprint 023 · **Tipo**: técnica · **Estado**: aberta

**O que aconteceu.** Ao criar a iteration do Sprint 023 com
`updateProjectV2Field.iterationConfiguration`, a do Sprint 022 sumiu e os 15 itens dele
ficaram sem sprint. A entrada `iterations` não ACRESCENTA — substitui a lista ativa por
inteiro, e não aceita `id` (recriar gera id novo, órfanando as atribuições).

**O que fazer diferente.** Toda mutação nessa configuração reenvia TODAS as iterations
vigentes junto da nova. Quando o dano acontecer: recriar as duas e reatribuir os itens na
hora, conferindo por consulta — foi o reparo, com datas até mais fiéis (022 = 1 dia).

**Aplicada em**: Sprint 024 (abertura) — a dança preventiva preservou 34 atribuições,
conferidas por consulta. **E o Sprint 025 (abertura) refinou o mapa do perigo**: iteration
COMPLETADA mantém o id e sobrevive à mutação, mas os VALORES dos itens que apontavam para
uma iteration que saiu da lista ativa são apagados — e a API recusa reatribuir a uma
completada ("The iteration Id does not belong to the field"). Os 15 itens do Sprint 022
perderam o campo de forma irrecuperável; o registro de pertença é o sprint-backlog no
repositório, e o campo do Projects é retrato do presente, não arquivo.

---

## L73 — `isVisible` não vê o corte por overflow: a prova de tela é a imagem

**Origem**: Sprint 023 · **Tipo**: processo · **Estado**: aberta

**O que aconteceu.** O dropdown do Settings abria CORTADO pelo `overflow-x-auto` da barra
(overflow-x força overflow-y). O diagnóstico inicial acertou a causa — e foi descartado
porque o `isVisible()` do Playwright devolveu `true`: o predicado não considera corte por
overflow de ancestral. O screenshot capturado NA MESMA SESSÃO mostrava o menu ausente, e
não foi olhado. A pessoa mantenedora reportou o defeito duas vezes até a imagem ser lida.

**O que fazer diferente.** Predicado de visibilidade nunca encerra diagnóstico de tela: a
prova é a IMAGEM, olhada. Se um screenshot já foi capturado para provar algo, ele é lido
antes de qualquer conclusão — capturar e não olhar é pior que não capturar, porque veste
o diagnóstico de verificado.

---

## L74 — A árvore de trabalho decide o que o dev server serve

**Origem**: Sprint 023 · **Tipo**: processo · **Estado**: aberta

**O que aconteceu.** Duas vezes no mesmo dia: (1) `mix.lock` mudou (bcrypt) e o code
reloader passou a responder 500 em tudo exigindo restart — o erro estava claro no log do
servidor, não na tela; (2) o conserto do schema vivia na branch do fix, e voltar a árvore
para a branch da feature ressuscitou o 400 NO MEIO de um teste da pessoa mantenedora — o
schema é lido do disco a cada geração, e o disco é a branch atual.

**O que fazer diferente.** Com dev server de reloader ligado, trocar de branch é mexer no
servidor VIVO: antes de trocar, dizer o que o usuário verá mudar; depois de mexer em
mix.lock/config, reiniciar o servidor sem esperar o sintoma. Fix quente que o usuário está
exercitando fica também na árvore ativa (aplicado sem commit) até o merge oficial.

---

## L75 — Squash-merge abre janela para commits órfãos na branch do PR

**Origem**: Sprint 023 · **Tipo**: processo · **Estado**: aberta

**O que aconteceu.** O PR #562 foi squash-mergeado enquanto a sessão continuava
empurrando commits na mesma branch (dropdown, alcance do organization, página da pessoa).
Os pushes entraram na branch remota — e em lugar nenhum: o PR já estava fechado, e nada
avisa. Só a pergunta "fez o PR?" revelou; a comparação por SHA engana (squash não preserva
commits), e foi o diff de CONTEÚDO contra a main que disse o que faltava.

**O que fazer diferente.** Antes de cada push numa branch com PR aberto, conferir o estado
do PR (`gh pr view --json state`). Depois de merge detectado: parar de empurrar ali,
cherry-pick do que sobrou numa branch nova a partir da main, PR complementar. Diferença
real entre branch e main se mede por conteúdo (`git diff main branch`), nunca por lista de
commits.

---

## L76 — A ferramenta de medir precisa da gramática do alvo

**Origem**: Sprint 024 · **Tipo**: técnica · **Estado**: aberta

**O que aconteceu.** O plano da 047 mediu "55 literais de mensagem" com grep. O
verificador por AST, na execução, achou **137** — multilinha, concatenação e a forma
pipe eram invisíveis à regex. O plano dimensionou a migração pela metade.

**Por que aconteceu.** Grep lê linhas; código é árvore. Medir estrutura sintática com
ferramenta de texto erra sempre para baixo — e o número menor parece mais crível.

**O que fazer diferente.** Contagem que vira escopo de tarefa usa a ferramenta com a
gramática do alvo: código Elixir se conta por AST (`Code.string_to_quoted`), nunca
por regex. Grep serve para ACHAR candidatos, não para CONTAR compromissos. Parente
próxima da "verificar número contra a origem" — aqui a origem é a árvore sintática.

---

## L77 — Verificador novo nasce com teste de ponta que NÃO passa por ele

**Origem**: Sprint 024 · **Tipo**: técnica · **Estado**: aberta

**O que aconteceu.** O verificador da 047 cobria `put_flash` simples — e a forma
qualificada `Phoenix.Controller.put_flash` (outra cabeça de AST) passou reta. Quem
pegou foi o TESTE DE IDIOMA: a recusa do plug não trocava de língua, porque o literal
nunca tinha migrado. O verificador dizia "zero achados" com um achado vivo.

**Por que aconteceu.** Testar o verificador só com fixtures desenhadas por quem o
escreveu prova que ele vê o que o autor lembrou — não o que o repositório contém.

**O que fazer diferente.** Todo verificador/gate novo ganha ao menos um teste de
ponta a ponta que exercita o EFEITO prometido (aqui: trocar o idioma troca a frase)
sem passar pelo verificador. É o par de fora que pega a cabeça de AST esquecida.

---

## L78 — "Troca em runtime" só entra no contrato com teste em runtime

**Origem**: Sprint 024 · **Tipo**: técnica · **Estado**: aberta

**O que aconteceu.** O contrato da 047 prometia trocar o idioma padrão via config do
backend gettext. Na implementação, o teste reprovou: a config do backend é
COMPILE-TIME; só a do app `:gettext` é lida em runtime. O contrato foi corrigido no
mesmo commit, com a razão — mas a promessa tinha sido escrita sem prova.

**O que fazer diferente.** Cláusula de contrato do tipo "mudar X reconfigura em
runtime" nasce com o teste que muda X em runtime e observa o efeito — antes de o
contrato ser dado como escrito. Documentação de biblioteca não substitui a medição
(a do gettext descreve as duas configs sem gritar qual é compile-time).

---

## L79 — Agente com árvore compartilhada não troca de branch

**Origem**: Sprint 024 · **Tipo**: processo · **Estado**: aberta

**O que aconteceu.** O agente de aceitação do PO rodou `git checkout main` para
avaliar a 047 — na MESMA árvore da sessão principal. A máquina dormiu, o agente
morreu, e a sessão voltou com os arquivos da 048 "revertidos" no disco até alguém
notar que a branch era outra. Nada se perdeu porque tudo estava commitado e empurrado
— por sorte de disciplina, não por desenho.

**O que fazer diferente.** Prompt de agente que toca repositório compartilhado carrega
a regra explícita: NÃO trocar de branch/stash — avaliar o que a árvore tem, ou pedir
worktree próprio (`git worktree add`). E a sessão principal confere
`git branch --show-current` ao retomar de qualquer agente que rodou git.

---

## L80 — A pendência medida com o grep do instrumento herda a cegueira dele

**Origem**: Sprint 024 (aceitação) · **Tipo**: técnica · **Estado**: aberta

**O que aconteceu.** O `pendencias.md` da 047 prometia enumerar todo texto de tela
fora do verificador — e foi medido com um grep de `<.notice>/<.absent>`. A classe
"assign de mensagem renderizado" (`assign(erro: "...")` exibido num div) não é
notice nem `put_flash`: ficou fora do catálogo, fora do verificador E fora da
enumeração. O PO achou com leitura dirigida, e duas user stories voltaram por isso.

**Por que aconteceu.** O documento de pendências foi validado contra o próprio
método (o grep reproduzia as contagens byte a byte — E7 da aceitação), não contra a
pergunta que ele responde ("o que a tela diz que não vem do catálogo?"). Instrumento
conferido consigo mesmo confirma a si, não o mundo.

**O que fazer diferente.** Enumeração de lacuna se valida por AMOSTRAGEM INDEPENDENTE:
abrir N telas e listar à mão o que elas dizem, e conferir a lista contra a
enumeração — o mesmo princípio da dupla medição (duas medidas, comparar
sobreposição). E toda classe nova de ralo descoberta vira caso de teste do
verificador no mesmo commit.

**Aplicada em**: Sprint 025 — o retrabalho amplia o verificador para a classe assign
por AST e refaz as pendências com amostragem.

---

## L81 — Fechar o contraexemplo não fecha a classe

**Origem**: Sprint 025 (aceitação) · **Tipo**: técnica · **Estado**: aberta

**O que aconteceu.** O retrabalho da 047 migrou os 13 pontos que a aceitação do 024
apontou e ampliou o verificador para a classe assign — e a US1 caiu DE NOVO: as
mesmas frases-de-tela-em-literal existiam um nível atrás, nascendo em função de
origem (`PatternValidator.explicar/1`, `primeira_mensagem/1`) e chegando ao mesmo
ralo assign por trás de uma chamada que o verificador aprova de propósito.

**Por que aconteceu.** O retrabalho mirou a LISTA de achados, não a FORMA deles. A
fronteira "chamada de função aprovada" é legítima — desde que o que escapa por ela
esteja enumerado, e ninguém caçou o que escapava.

**O que fazer diferente.** Todo retrabalho de classe fecha com a caça aos IRMÃOS:
derivar o padrão sintático da classe (aqui, `(erro|ok|error|aviso): funcao(...)`) e
varrer o repositório por ele ANTES de entregar. O que a varredura achar ou migra no
mesmo PR ou entra nomeado nas pendências — nunca fica para a próxima aceitação
descobrir.

---

## L82 — O comentário que contradiz o contrato é a violação documentando a si mesma

**Origem**: Sprint 025 (aceitação) · **Tipo**: processo · **Estado**: aberta

**O que aconteceu.** Spec, contrato e tasks da 051 pediam a ORGANIZAÇÃO no resultado
da busca de pessoas (o edge case dos homônimos). A implementação mostrou só nome e
login — e deixou um comentário dizendo "organização não", com um racional novo, sem
corrigir contrato nenhum. A US caiu na aceitação por isso.

**Por que aconteceu.** No calor da implementação, a divergência pareceu melhoria e o
comentário pareceu registro. Mas a regra da casa é outra: erro de contrato se
corrige NO CONTRATO, no mesmo commit, com a razão — comentário em código não emenda
documento normativo, só confessa que ele foi ignorado.

**O que fazer diferente.** Ao divergir de spec/contrato/tasks durante a implementação:
parar, corrigir o documento com data e razão (ou perguntar, se a divergência é
decisão de produto), e SÓ ENTÃO codificar. Grep de conferência antes do PR:
comentários com "não"/"em vez de" perto de referências a FR/contrato merecem
leitura dupla.

---

## L83 — Squash-merge no release diverge os históricos

**Origem**: Sprint 026 (release v0.1.0) · **Tipo**: processo · **Estado**: aberta

**O que aconteceu.** O PR #636 entrou na `main` por squash, criando ali um commit
que a `development` não conhecia. O merge de volta abriu **6 conflitos, todos de
conteúdo idêntico** — a árvore resultante era igual à da `development`.

**Por que aconteceu.** Squash produz um commit novo, sem parentesco com os que ele
resume. Os conteúdos continuam iguais e os históricos divergem; o git não tem como
saber que os dois lados são a mesma coisa, e o GitHub passa a avisar
"main had recent pushes" nos PRs seguintes.

**O que fazer diferente.** Duas coisas, e a primeira evita metade do problema.

**O bump da versão é commit na `development`**, antes de abrir o PR de release —
nunca numa branch `release/*`. A v0.1.0 saiu de `development → main` e o bump
voltou junto; a v0.2.0 saiu de `release/v0.2.0 → main`, e **a `development`
continuou dizendo `0.1.0` no `mix.exs` enquanto a produção servia `0.2.0`**. A
fonte única da versão afirmando o que o ambiente contradiz, e qualquer imagem
construída a partir da `development` sairia com a tag errada. Descoberto no
back-merge, que separou o conflito falso (oito arquivos idênticos) da diferença
real (uma linha).

**E o back-merge da `main` na `development` depois de cada release**, resolvendo
os conflitos pela versão da `development`. Sem ele, cada release aumenta a
divergência e os conflitos falsos crescem. Com o bump no lugar certo, o
back-merge passa a ser só convergência de histórico — nenhuma decisão de
conteúdo. A alternativa estrutural — trocar o squash por merge commit **apenas**
no PR de release — é emenda ao fluxo da constituição 1.7.0, e ainda não foi
decidida.

---

## L84 — O painel dizer `Done` não significa aplicação no ar

**Origem**: Sprint 026 (produção) · **Tipo**: técnica · **Estado**: aberta

**O que aconteceu.** O Dokploy marcou dois deploys como concluídos enquanto o
contêiner morria em laço.

**Por que aconteceu.** `Done` no painel de quem hospeda significa "criei o
serviço", não "o processo sobreviveu". São duas afirmações diferentes, e a
interface mostra só a primeira com a palavra que sugere a segunda.

**O que fazer diferente.** A prova de que a aplicação está no ar é **sempre a
medição de fora** — requisição ao endereço público, com código de resposta e
tempo. Painel de terceiro é indício; medição é evidência. Vale para qualquer
ferramenta de implantação, não só para o Dokploy.

---

## L85 — Um 200 de HTTP pode afirmar o que o socket contradiz

**Origem**: Sprint 026 (produção) · **Tipo**: técnica · **Estado**: aberta

**O que aconteceu.** Com `PHX_HOST` apontando para o host do painel e as pessoas
acessando por outro endereço, o `check_origin` padrão do Phoenix recusava o
WebSocket do LiveView com **403** enquanto a página respondia **200**. O log
registrou `_mount_attempts => "79"`. Para quem olhava, era uma barra de
carregamento que não terminava.

**Por que aconteceu.** `PHX_HOST` serve para **gerar** URLs; a origem aceita no
socket é **por onde as pessoas chegam**. Com um endereço só, as duas coincidem e
ninguém nota que são coisas diferentes.

**O que fazer diferente.** Medir o **socket**, não só o HTTP: uma aplicação
LiveView só está no ar quando a conexão do socket é aceita. É a classe do sucesso
silencioso na direção do falso positivo — o verde de uma camada afirmando o que
a de baixo contradiz.

---

## L86 — Denominador móvel mente igual a denominador inventado

**Origem**: Sprint 026 (produção) · **Tipo**: técnica · **Estado**: aberta

**O que aconteceu.** A barra de progresso de `/syncs` marcou **100% durante a
coleta inteira**, porque o total crescia junto com o coletado. Enganou inclusive
a investigação que procurava por que a coleta parecia travada.

**Por que aconteceu.** Percentual pressupõe denominador fechado. Enquanto a
descoberta e a coleta correm juntas, `coletado/total` é sempre ≈1 — e o número
mais convincente da tela é o mais vazio.

**O que fazer diferente.** **Sem total fechado, contagem — nunca percentual.**
Mostrar `1.204 itens` diz a verdade que `100%` esconde. Corrigido no PR #642.
Vale para toda medida derivada de um denominador ainda em formação — é a mesma
família da L70 (número medido no meio de um backfill).

---

## L87 — Fase invisível faz trabalho parecer travado

**Origem**: Sprint 026 (produção) · **Tipo**: técnica · **Estado**: aberta

**O que aconteceu.** A coleta de quadros roda depois da promoção e **não tinha
linha na tela nem checkpoint**. Com as sete fases visíveis cheias e o sync ainda
`running`, a conclusão natural era que travara — quando faltavam 15 quadros e
3981 itens para trazer.

**Por que aconteceu.** A tela enumerava as fases que existiam quando foi escrita.
A fase nova entrou no processo e não na enumeração, e ausência de linha foi lida
como ausência de trabalho.

**O que fazer diferente.** Toda fase de processo longo nasce com **linha na tela e
checkpoint**, no mesmo commit que a cria. Enumeração de fases é a mesma classe da
L80: o instrumento que não vê a fase nova afirma que ela não existe.

---

## L88 — Um segredo de 8 segundos, e o contrato que salvou o diagnóstico

**Origem**: Sprint 026 (release v0.1.0) · **Tipo**: dependência · **Estado**: aberta

**O que aconteceu.** O CD da v0.1.0 falhou porque leu `DOKPLOY_WEBHOOK_URL` **oito
segundos antes** de o segredo ser criado. A mensagem do contrato foi a que devia
ser — *"a imagem e a tag existem, mas NÃO houve delivery"* — e por causa dela
ninguém procurou a imagem no lugar errado. O re-run resolveu em 11s.

**Por que aconteceu.** Marco humano e disparo automático correndo em paralelo:
o merge disparou o workflow enquanto a pessoa ainda cadastrava o segredo.

**O que fazer diferente.** Nenhuma ação corretiva — o contrato já fazia o certo, e
a lição é a **confirmação**: mensagem de falha que separa o que aconteceu do que
não aconteceu vale o custo de escrevê-la, e se paga na primeira falha real.
Registrar como evidência a favor da prática, não como defeito a corrigir.

---

## L89 — PR sem revisor pedido não é PR revisado, e o merge não sabe disso

**Origem**: Sprint 026 (aceitação) · **Tipo**: processo · **Estado**: aberta

**O que aconteceu.** Dos nove PRs do sprint, **seis foram mergeados sem revisor
pedido** (#635, #637, #638, #639, #640, #642). Os três primeiros (#630, #631,
#632) pediram revisão a duas pessoas, e **nenhuma revisou**: `reviews` está vazio
nos nove. Ninguém percebeu durante o sprint — o merge não pergunta.

**Por que aconteceu.** A sessão da produção correu em ritmo de incidente, e o
pedido de revisão é o passo que some primeiro quando o PR é meio para outra
coisa. O princípio VII da constituição exige revisor diferente de quem
implementou; a ferramenta não o exige, e o que só o processo exige é o que só o
processo perde.

**O que fazer diferente.** Conferir o pedido **depois de pedir** —
`gh pr view <n> --json reviewRequests` —, porque o comando de pedir sai com
código zero mesmo quando não pede ninguém (L14). E, quando não houver revisor
possível, **escrever o atestado**: quem revisou, quando, e sob que condição. As
três situações são diferentes e só uma é lacuna de revisão: *revisão registrada*,
*revisão atestada sem registro* e *revisão não ocorreu*. O que este sprint
produziu foi a terceira em seis PRs, e ela não se conserta depois do merge.

---

## L90 — Contar só o vencedor da corrida não prova o perdedor

**Origem**: Sprint 026 (aceitação) · **Tipo**: técnica · **Estado**: aberta

**O que aconteceu.** O teste da corrida da 052 (FR-005) asseverava duas coisas:
que existe **um** administrador ao fim, e que **exatamente uma** das duas chamadas
devolveu `{:ok, :criada, _}`. Desligando a leitura da corrida perdida — o
perdedor passando a devolver `{:error, changeset}` em vez de `{:ok, :ja_existe}` —
**os 16 testes continuaram verdes**. O defeito só apareceu porque a aceitação
injetou.

**Por que aconteceu.** As asserções descreviam o **estado final** e o **vencedor**.
O perdedor não tem efeito no banco, então nenhuma contagem o alcança — e é
justamente ele que a FR-005 promete atender: numa segunda subida real, o caminho
comum é o do perdedor, e um `{:error, ...}` ali faria o boot gritar sobre uma
instalação que está correta.

**O que fazer diferente.** Em toda corrida, **asserir os dois lados**: o que o
vencedor produziu e o que o perdedor devolveu. A regra vale além de corrida — é a
forma geral do relator: quando uma função devolve fases diferentes para o mesmo
estado final, o teste que só olha o estado não distingue as fases. Vale também
como recado sobre injeção: a injeção que **passa** é a informativa, porque não
diz "o código está certo", diz "o teste não vê aqui".

---

## L91 — O passo do ciclo que não tem gate é o que some

**Origem**: Sprint 026 (fechamento) · **Tipo**: processo · **Estado**: aberta

**O que aconteceu.** Duas features seguidas — a 052 e a 054 — correram
`/speckit-specify` → `/speckit-plan` → `/speckit-tasks` → **implementação**,
pulando o `/speckit-taskstoissues`. Nenhuma das duas teve issue no GitHub
enquanto o trabalho acontecia. Descoberto só no fechamento do sprint, quando a
aceitação foi procurar as issues das tarefas e não achou.

**Por que aconteceu.** Todo passo anterior do ciclo **produz um arquivo que o
passo seguinte lê**: sem `spec.md` não há plano, sem `tasks.md` não há o que
implementar. O `taskstoissues` é o único que produz algo **fora do repositório**
— e nada dentro dele repara na ausência. Os gates rodam sobre o código; o
`tasks.md` fica completo e correto; a implementação segue. **Não existe passo
seguinte que tropece.**

O custo não é burocrático: `flow.wip.count` subcontou o sprint 026 enquanto ele
corria, e essa medida não se recupera depois. Issues criadas retroativamente
restauram a rastreabilidade, nunca a série temporal.

**O que fazer diferente.** Tratar `taskstoissues` como **parte da tarefa T001 do
sprint**, e não como passo solto: nenhuma tarefa começa antes de a issue dela
existir. E a conferência é uma linha —
`gh issue list --search "<feature>/T in:title"` devolvendo o número esperado —,
que cabe na mesma checagem em que se lê o código de saída dos gates.

A forma geral, que vale além deste ciclo: **passo de processo cujo produto vive
fora do repositório precisa de conferência explícita**, porque nenhum gate o
alcança. É a mesma família da L57 — verificação que nunca roda é verificação que
não existe.

---

## L92 — Squash num back-merge apaga o back-merge

**Origem**: Sprint 026 (release v0.3.0) · **Tipo**: processo · **Estado**: **encerrada no Sprint 028** — virou regra no `AGENTS.md` §12 e campo obrigatório no template de PR

**O que aconteceu.** O PR #646 fez o back-merge da `main` na `development` — a
ação que a L83 prescreve — e **foi mergeado por squash**. O conteúdo chegou; a
ancestralidade não. Duas releases depois, o PR de release da v0.3.0 nasceu
`DIRTY`, conflitando nos **mesmos arquivos falsos** que o #646 já tinha
resolvido: gettext, o `tasks.md` da 052, o `bootstrap_test.exs`.

A prova está no próprio histórico: o back-merge do v0.1.0 (`d9c6a57`)
**sobreviveu**, porque aquele foi mergeado com merge commit. E
`git merge-base main development` continuava apontando para `cc4b5f9` — a
v0.1.0 —, como se a v0.2.0 nunca tivesse voltado.

**Por que aconteceu.** Squash existe para transformar N commits em um, e o preço
é **descartar os pais**. Num PR comum isso é o efeito desejado. Num back-merge,
o segundo pai **é o produto inteiro** — o conteúdo já era idêntico dos dois
lados. Squashar um back-merge é pedir o que ele entrega e jogar fora o que ele
faz.

O que escondeu o erro por um ciclo: **o resultado parecia certo**. Os arquivos
ficaram corretos, os gates passaram, e nada apareceu até o release seguinte.

**O que fazer diferente.** **Back-merge é mergeado com merge commit, nunca com
squash** — o repositório permite os três métodos, e a escolha é de quem aperta o
botão. Para tornar isso conferível em vez de lembrado, o PR de back-merge nasce
dizendo no título e no corpo que squash o anula, e traz as duas medidas que o
provam:

```bash
git diff origin/development          # vazio: nenhuma decisão de conteúdo
git cat-file -p HEAD | grep -c ^parent   # 2: é isso que o squash apagaria
```

E a conferência depois: `git merge-base main development` tem que apontar para o
**último** release, não para o anterior.

---

## L93 — Durante o deploy, duas versões atendem, e a medida de fora não diz qual respondeu

**Origem**: Sprint 026 (produção, feature 054) · **Tipo**: técnica · **Estado**: aberta

**O que aconteceu.** Logo depois de um redeploy, três sondas ao socket devolveram
`400 / 400 / 403` — o resultado que provava a feature 054 em produção. Foi
declarado como prova. Minutos depois, o log do contêiner mostrou a **mesma
origem sendo recusada** no mesmo minuto:

```
20:04:54  Access TheBandWeb.Endpoint at https://theband.5.189.161.85.sslip.io
20:05:35  [error] Could not check origin — Origin: https://app.theband.dev
20:10:20  SIGTERM received - shutting down
```

O contêiner **antigo** ainda estava atendendo, com a configuração antiga, e só
morreu às 20:10. Durante cinco minutos os dois estiveram atrás do mesmo
roteador: cada requisição caía num ou noutro, e a medida virou cara ou coroa. A
repetição depois do `SIGTERM` deu `400/400/403` três vezes seguidas — aí sim.

**Por que aconteceu.** Deploy sem interrupção **existe justamente porque as duas
versões coexistem**. Quem mede de fora vê um endereço só e conclui que há um
serviço só. O engano é invisível: o número que sai é plausível, e é o número que
se esperava.

**O que fazer diferente.** Medida de aceitação **não se faz durante o deploy**.
Três formas de evitar, em ordem de força:

1. esperar o `SIGTERM` do contêiner antigo aparecer no log — é o único sinal que
   diz que a coexistência acabou;
2. conferir a identidade de quem respondeu: a linha `Access TheBandWeb.Endpoint
   at …` do boot diz qual configuração está em vigor;
3. **repetir a medida até estabilizar** — uma leitura só, numa janela de troca,
   não é evidência. Duas versões produzem duas respostas para a mesma pergunta.

É a mesma família da L70 (número medido no meio de um backfill) e da L84 (`Done`
no painel não é aplicação no ar): **o instrumento está certo, o momento é que
está errado** — e o resultado parece bom, que é o que faz ninguém conferir.

---

## L94 — Mensagem que afirma a causa sem conferir manda procurar no lugar errado

**Origem**: Sprint 027 (produção) · **Tipo**: técnica · **Estado**: aberta

**O que aconteceu.** A tela de escopos de acesso mostrava
*"Já existe concessão vigente para esse alvo"* para **qualquer** erro de
changeset — falta de campo obrigatório, nível inválido e violação de unicidade
caíam todos na mesma frase:

```elixir
{:error, %Ecto.Changeset{}} ->
  assign(socket, erro: dgettext("errors", "Já existe concessão vigente para esse alvo."))
```

A pessoa mantenedora tentou conceder escopo de organização a uma conta, recebeu
essa frase, e concluiu o que a frase diz: **que só uma pessoa pode ter escopo por
organização**. Não pode ser mais errado — o índice é
`(tenant_id, user_id, level, target_id)`, e duas contas na mesma organização
foram provadas por teste, no domínio e pela tela.

O diagnóstico consumiu quatro medições — a contagem no banco de desenvolvimento,
o índice na migração, `granted_scopes/2` para ver se a lista escondia algo, e a
busca por um segundo índice — e **nenhuma delas encontrou a causa**, porque a
causa nunca chegou à tela. A captura da produção derrubou as duas hipóteses que
eu tinha formado a partir da própria mensagem.

**Por que aconteceu.** O `case` casava a **forma** do erro (`%Ecto.Changeset{}`) e
escrevia a **causa** mais provável. Enquanto a causa provável é a única, ninguém
nota; no dia em que for outra, a mensagem mente com convicção — e quem lê para de
procurar, porque já recebeu uma resposta.

É o sucesso silencioso ao contrário: em vez de um erro que não aparece, **um erro
que aparece dizendo outra coisa**.

**O que fazer diferente.** Erro exibido a alguém descreve **a situação
observada**, nunca a restrição presumida. Em Ecto, isso é conferir o
`constraint` no `opts` do erro antes de nomeá-lo:

```elixir
if Enum.any?(errors, fn {_c, {_m, opts}} -> opts[:constraint] == :unique end) do
  # aí sim, a frase da duplicata
else
  # e aqui, o que o changeset realmente disse
end
```

A pergunta que separa as duas: *"se a causa fosse outra, esta frase mudaria?"* Se
não muda, ela não está descrevendo o que aconteceu — está descrevendo o que quem
escreveu imaginou.

---

## L95 — Pedir revisor não é obter revisão, e o merge não espera

**Tipo**: processo · **Origem**: Sprint 027 · **Estado**: aberta

**O que aconteceu.** Os quatro PRs da feature 055 — #706, #710, #712 e #713 —
foram incorporados em `development` com **2 revisores pedidos e 0 revisões** cada
um. Medido em 2026-09-02 com `gh pr view --json reviews,reviewRequests`.

**Por que aconteceu.** A L89 fez pedir revisor virar hábito, e o hábito foi
confundido com a garantia. Pedir revisor é uma ação de quem abre o PR; revisar é
ação de outra pessoa, em outro momento — e nada entre as duas impede o merge. O
botão não sabe a diferença entre "ninguém revisou ainda" e "ninguém vai revisar".

**O que fazer diferente.** Antes de incorporar, medir: `gh pr view <n> --json
reviews --jq '.reviews|length'`. Zero é impedimento, não observação. Quando a
revisão não puder ser obtida, **declarar a lacuna na review do sprint** — que foi
o que se fez aqui, tarde.

**Aplicada em**: Sprint 028 — condição de entrada dos PRs da feature 057.

---

## L96 — Issue que ninguém fecha faz o sprint parecer não entregue

**Tipo**: processo · **Origem**: Sprint 027 · **Estado**: aberta

**O que aconteceu.** Treze tarefas concluídas e incorporadas, e **zero issues
fechadas**. Em 2026-09-02, quem olhasse a origem veria 18 issues abertas e
concluiria que o sprint não entregou nada.

**Por que aconteceu.** O fechamento dependia da palavra-chave no PR, que já falha
por três motivos conhecidos, e ninguém conferiu depois. Não há gate entre "o
código está em `development`" e "a issue está fechada" — e o passo sem gate é o
que some, que é a L91 aparecendo em outro lugar.

**Por que custa caro aqui em particular.** A plataforma existe para calcular
medidas de fluxo a partir de issues. Um repositório em que a issue não fecha
quando o trabalho acaba produz lead time infinito e throughput zero — sobre o
próprio projeto que a mede.

**O que fazer diferente.** Ao fechar o sprint, `gh issue list --state open` com o
prefixo da feature **antes** de escrever a review. Issue aberta com tarefa
marcada `[x]` no `tasks.md` é divergência a resolver, não detalhe.

**Aplicada em**: Sprint 028 — entra na Definition of Done do sprint.

---

## L97 — Feature que corrige o vínculo não corrige quem lê o vínculo

**Tipo**: técnica · **Origem**: Sprint 027 · **Estado**: aberta

**O que aconteceu.** A feature 055 entregou `started_at`, `ended_at` e a
invalidação do vínculo, com o SC-003 exigindo que registrar uma saída não mude o
passado. **Nenhuma consulta de medida passou a usar isso.**
`Profiles.TeamSkills` continuou lendo a evidência que a origem lista hoje — de
modo que quem saiu segue contando, e o conjunto de membros de hoje é aplicado aos
meses passados.

O defeito que o SC-003 proíbe no vínculo estava acontecendo na medida, **no mesmo
sprint que criou o dado para evitá-lo**.

**Por que aconteceu.** O escopo foi escrito em termos de *quem escreve* o vínculo
— declarar, encerrar, invalidar. Ninguém listou *quem lê*. Um dado novo não
alcança sozinho os consumidores do dado antigo, e a busca por eles não acontece
por acaso.

**Um segundo defeito, da mesma família**, achado ao planejar a 057: a condição de
vigência usa `started_at <= data`, e `started_at` é anulável de propósito. Contra
nulo a comparação avalia para desconhecido e a linha é descartada — quem tem data
de início desconhecida **não é membro em data alguma**, sem erro e sem aviso.

**O que fazer diferente.** Feature que acrescenta atributo temporal a um conceito
**lista os consumidores atuais** desse conceito no `plan.md`, e diz para cada um
se muda ou não muda. `grep` pelo nome do conceito é o mínimo. E toda condição
sobre coluna anulável precisa dizer explicitamente o que faz com o nulo.

**Aplicada em**: Sprint 028 — US1 e T034 da feature 057 são a correção.

---

## As três do squash, encerradas juntas — Sprint 028

**L75**, **L83** e **L92** são o mesmo defeito visto em três lugares: o squash cria
um commit **novo, sem os pais originais**, e o Git perde a informação de que
aquele trabalho já foi integrado.

A L92 aconteceu **depois** de a L75 e a L83 já estarem escritas. Isso é o achado:
**lembrar da lição no momento de clicar o botão não funcionou**, e três registros
não impediram a quarta ocorrência.

O que mudou no sprint 028, e por que isto encerra as três:

1. **`AGENTS.md` §12** ganhou a tabela de quando usar cada tipo — vira obrigação
   verificável em revisão, e não lembrete;
2. **`.github/pull_request_template.md`** exige o tipo de merge **declarado no
   corpo do PR**, com o motivo. Quem clica não precisa lembrar de qual caso este
   PR é: quem abriu já disse.

A diferença entre lembrete e regra é essa: o lembrete depende de alguém recordar
no pior momento — quando já está com o dedo no botão e o trabalho parece
terminado.

**Se reincidir mesmo assim**, a próxima medida não é uma quarta lição: é
desabilitar o squash na configuração do repositório para os casos em que ele
destrói, e deixar o botão oferecer só o que é correto.
