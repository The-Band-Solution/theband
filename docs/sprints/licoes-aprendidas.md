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
