# Research — spec 064, segredo em repouso

**Data**: 2026-09-13 · **Branch**: `064-plan-segredo-em-repouso`

Cada decisão aqui foi tomada depois de ler o código que ela muda. Duas delas **contrariam o
que a própria spec afirmava**, e a correção está escrita em R1.

---

## R1 — O que o `session_token` é, de fato

**Decisão**: corrigir a afirmação da spec. `users.session_token` **não é credencial ao
portador sozinho**.

**Como se mediu**: lendo o caminho inteiro, de ponta a ponta.

1. `endpoint.ex:7-12` — a sessão é **cookie assinado**: `signing_salt`, sem
   `encryption_salt`. O conteúdo é legível por quem tem o cookie; forjá-lo exige o
   `SECRET_KEY_BASE`.
2. `SECRET_KEY_BASE` **não está no banco** — conferido: zero colunas `%secret_key%`,
   `%signing%`, `%encryption%`.
3. `current_scope.ex:54` e `hooks.ex:139` comparam o valor do banco com o valor **da sessão
   do Phoenix**, não com nada que o cliente envie diretamente.
4. `auth.ex:190-192` diz o que ele é, por escrito: *"Garante o token (conta que nunca logou);
   **NÃO o gira** — girar é ato de troca de senha, e girar aqui derrubaria as outras sessões
   a cada login."*

**Conclusão**: é uma **época por usuário**, estável entre logins e dispositivos, cujo giro
invalida todas as sessões na troca de senha.

**A afirmação errada, e a certa**:

> ~~"quem lê um dump se passa por qualquer sessão viva"~~ — **falso**. O dump sozinho não
> basta.
>
> **Certo**: o valor no banco é **metade** de uma credencial de duas partes. A outra metade é
> o `SECRET_KEY_BASE`, que vive no ambiente. Quem tem **as duas** forja sessão de qualquer
> pessoa; quem tem só uma, não forja nada.

Isso **rebaixa a severidade** e **não elimina o problema**: as duas metades estão hoje em
lugares com exposições muito diferentes, e uma delas viaja inteira em todo backup. Um
vazamento do `SECRET_KEY_BASE` — que é um segredo de ambiente, e ambientes vazam — tornaria
cada cópia do banco suficiente para assumir todas as contas.

---

## R2 — O mecanismo da FR-004

**Decisão**: **token por sessão, guardado como resumo**, separado de uma **época de senha não
secreta**. O que hoje é um campo com dois trabalhos vira dois campos com um trabalho cada.

### Por que não simplesmente resumir a coluna de hoje

Foi a primeira ideia, e o código a derruba. O token é **estável entre logins**: um dispositivo
novo que entra precisa receber **o valor bruto** no cookie, e o banco teria só o resumo. As
saídas seriam duas, ambas ruins:

- **gerar um valor novo a cada login** — derruba as outras sessões a cada entrada, que é
  exatamente o que o comentário em `auth.ex:191` proíbe;
- **guardar o bruto em algum lugar para poder reemitir** — é não ter resumido.

### Por que não trocar por um valor não secreto

Tentador: se a época só serve para invalidar, um contador ou `password_changed_at` bastaria, e
não haveria segredo nenhum na coluna. **Mas isso enfraquece o sistema.** Hoje, quem obtém o
`SECRET_KEY_BASE` sem acesso ao banco ainda não forja sessão: falta o valor aleatório de 32
bytes. Com um contador, forjaria — porque contador se adivinha.

Trocar segredo por não-segredo aqui **transformaria duas metades em uma**. Não é o que a
FR-004 pede.

### O desenho escolhido

| o que | onde | segredo? | trabalho |
|---|---|---|---|
| token **por sessão**, aleatório | cookie (bruto) + banco (**resumo**) | sim, e o banco não o tem | prova *esta* sessão |
| **época de senha**, não secreta | banco | não | invalida *todas* na troca de senha |

**Propriedade obtida (FR-004)**: quem lê o banco — dump incluído — não consegue se passar por
ninguém, **nem tendo o `SECRET_KEY_BASE`**. O resumo não permite reconstruir o bruto, e é o
bruto que o cookie precisa carregar.

**Resumo, e não cifra**: a plataforma nunca precisa **recuperar** o token, só **comparar** —
é a mesma razão da FR-001. Cifra criaria uma chave capaz de abrir todas as sessões.

**SHA-256, e não bcrypt.** O token tem 32 bytes de aleatoriedade real. O custo do bcrypt
existe para proteger segredo de **baixa entropia**, que se ataca por dicionário; aqui não há
dicionário possível, e o custo viraria latência em **toda requisição**. Comparação por
`Plug.Crypto.secure_compare/2`.

---

## R3 — A migração, e a FR-002 (sessão não cai em silêncio)

**Decisão**: **as sessões vivas continuam valendo.** Nenhuma queda, anunciada ou não.

**Como**: o cookie de cada pessoa já carrega o valor bruto de hoje. A migração cria uma linha
de sessão por usuário com token, guardando o **resumo daquele mesmo valor**. Na requisição
seguinte, o valor do cookie é resumido e encontra a linha. Continua valendo, sem que ninguém
perceba.

Isso satisfaz o **primeiro** ramo da FR-002 — *"continua valendo"* —, que é o preferível: o
segundo ramo custa uma entrada a todo mundo.

### A pergunta que isso deixa aberta, e por que ela NÃO é resolvida aqui

Os valores de hoje **foram medidos em claro dentro de um dump**. Carregá-los adiante preserva
valores que já estiveram expostos.

Mas *expostos* aqui significa *expostos em combinação com o `SECRET_KEY_BASE`* (R1), e a
medição foi num dump de **desenvolvimento**, na mesma máquina. Derrubar toda sessão de
produção por causa disso seria decidir por medida que ninguém tomou lá.

**Separação deliberada**: a migração não derruba ninguém. E o runbook ganha um procedimento
**girar todas as sessões**, ato operacional explícito, para ser executado quando houver
suspeita de exposição — inclusive depois da varredura de produção da FR-010. Mecanismo é do
plano; o ato é de quem opera.

---

## R4 — A varredura (FR-008, 009, 010)

**Decisão**: uma tarefa Mix, `mix the_band.varre_segredos`, que aceita **um arquivo de dump**
ou **o banco**, e que **se recusa a dizer "limpo" sem antes provar que enxerga**.

**Por que tarefa Mix, e não script solto**: o script solto de 2026-09-12 funcionou e não
sobreviveria — não tem teste, não tem nome, e ninguém o acha daqui a três meses. A FR-010 pede
um ato **repetível antes de cada cópia nova**; ato repetível precisa de nome.

**O caso positivo é parte da execução, não um teste à parte.** A tarefa planta um valor
conhecido no material que vai varrer, confirma que o encontra, e só então relata o resultado
real. Se o controle falhar, ela **falha** — não relata zero.

É a lição L104 virada em código: uma varredura degradada que diz zero é pior que nenhuma,
porque produz atestado.

**O que ela procura**: os padrões declarados por tipo de segredo — token do GitHub, chave de
provedor de modelos, e o que mais a FR-014 vier a declarar. A lista fica **em um lugar só**, e
a tarefa a lê; padrão espalhado por scripts diverge.

**Alternativa descartada**: varrer com `grep` no CI. O dump não está no CI, e nem deve estar.
A varredura roda onde o dump está, que é onde quem opera trabalha.

---

## R5 — O efeito de uma restauração sobre as sessões (FR-013)

**Decisão**: escrever no runbook, e a resposta **decorre do desenho da R2**.

Restaurar um backup devolve as linhas de sessão **daquele instante**. Consequências, que
precisam estar escritas antes de alguém descobri-las num desastre:

- sessão aberta **depois** do backup: a linha não existe no restaurado → **cai**, e a pessoa
  entra de novo;
- sessão aberta **antes** do backup e ainda válida: continua valendo;
- sessão **encerrada** entre o backup e o desastre: **volta a valer** — é o caso que mais
  surpreende, e o motivo de o procedimento de restauração terminar com *girar todas as
  sessões* como passo recomendado.

O último item é a razão de a R3 deixar esse procedimento pronto.

---

## R6 — O registro que escapa da poda (FR-015)

**Decisão**: **preencher as datas que faltam e impedir que voltem a faltar** — não mexer na
dependência.

**O que se mediu** (2026-09-12): quatro registros de `oban_jobs` em estado `cancelled` com
`cancelled_at` **vazio**, de 2026-09-04. A regra de poda é
`state == "cancelled" and cancelled_at < ^time`; campo vazio nunca satisfaz a comparação, e os
quatro são **permanentes**. Um deles carregava o segredo.

**De onde vieram**: nenhuma chamada a `Oban.cancel_*` existe em `lib/`. Foram cancelados por
fora — comando manual ou versão anterior da dependência. **Isto é uma incógnita declarada**, e
a mitigação não depende de resolvê-la.

**A mitigação, em duas partes**:

1. **Preencher** as datas ausentes, uma vez, usando a data disponível mais próxima do fim do
   registro.
2. **Um verificador** que conte registros terminados sem a data do encerramento e **falhe**
   se houver algum. Sem ele, a correção de hoje é um `UPDATE` que ninguém repete.

**Alternativa descartada**: mudar a regra de poda para usar `scheduled_at` em qualquer estado.
É a tabela de uma dependência — reescrever a regra dela diverge na próxima atualização, e o
problema não é a regra: é o dado incompleto.

---

## R7 — O caminho do provedor de modelos

**Decisão**: aplicar o `TheBand.Segredo`, já mergeado, aos dois pontos que faltaram —
`llm/http/req.ex:41` e `:93`.

**Por que agora**: é o **mesmo** mecanismo já medido no caminho do GitHub. Nenhuma ocorrência
foi medida neste, e ausência de medida não é ausência de risco — a diferença entre os dois
caminhos é só que um já falhou.

**Sem desenho novo**: o tipo existe, o padrão está estabelecido, e usá-lo aqui é o problema que
o motivou. A seção 7.7 do `AGENTS.md` dispensa rejustificar padrão já justificado dentro do
problema que o originou.
