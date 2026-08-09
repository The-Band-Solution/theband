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
