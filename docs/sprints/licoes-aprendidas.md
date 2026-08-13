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
