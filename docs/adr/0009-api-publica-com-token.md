# ADR 0009 — A API pública: o token identifica quem, e o veredito continua sendo um só

## Status

**Proposta** — 2026-09-09.

Exigida por: [`AGENTS.md` §16](../../AGENTS.md) — *"alterar contratos públicos"* está na lista de decisões que exigem ADR, e abrir a API é **estabelecer** um contrato público, o caso mais forte da regra.

Depende de: [ADR 0003](0003-organizacao-por-ontologias.md) — as rotas chamam a API pública de cada módulo ontológico, nunca o `Repo`.

Realiza: [spec 061](../../specs/061-api-publica/spec.md). Desbloqueia: [spec 062](../../specs/062-servidor-mcp/spec.md) — o servidor MCP é consumidor desta API.

Fundamenta-se em: [avaliação de segurança de 2026-09-09](../seguranca/2026-09-09-api-com-token.md) — 18 achados, dez de severidade alta.

## Contexto

### O ponto de partida, medido

`lib/the_band_web/router.ex:44-46` declara a pipeline `:api` e **nenhum `scope` a usa**. Não há módulo de token, não há `Authorization`, não há controlador JSON além do `ErrorJSON` gerado pelo Phoenix. A pipeline está lá desde o gerador; a porta nunca foi aberta.

Isso é bom — greenfield é onde a decisão é barata. E é perigoso pela razão que a avaliação de segurança mediu: **toda garantia de acesso desta plataforma mora na pipeline `:browser` ou na `on_mount` das `live_session`**, e a pipeline `:api` não passa por nenhuma das duas.

Nove garantias que a API **não** herda: pessoa autenticada; tenant vindo da conta e nunca do parâmetro; sessão versionada; expiração por inatividade; senha temporária obrigando troca; espera crescente na entrada; mensagem única de recusa; alcance operacional; CSRF.

**A API não é uma tela sem HTML.** É uma segunda porta para o mesmo dado, e cada uma das nove tem de ser reconstruída ou explicitamente dispensada com motivo escrito.

### A pressão que existe, e por que ela não decide

Quem quer o mesmo número num painel próprio, numa planilha ou num agente não tem por onde entrar. É pedido legítimo e antigo. Mas a plataforma inteira existe para separar o que foi **observado** do que foi **derivado** e do que foi **declarado**, e uma resposta que entrega número sem essa marca destrói a distinção exatamente no ponto de entrega.

## Decisão

**Abrir uma API HTTP de leitura, autenticada por token, em que o token identifica *quem* e *onde* — e nada mais.**

Cinco decisões que compõem esta, e cada uma existe para fechar um caminho:

### 1. O token não traz permissão. Nenhuma.

Guarda `user_id` e `tenant_id` (`NOT NULL`). O *que pode* é **recomputado a cada requisição** por `Tenants.Access` — `scopes/2`, `pode_ver/3`, `pode_ver_equipe/3` —, que é o veredito que as telas já usam.

**Consequência que é o ganho principal**: cinco eventos surtem efeito na requisição seguinte sem trabalho adicional — concessão revogada, vínculo de equipe encerrado, elo revogado, papel rebaixado, observação da ferramenta encerrada. `access.ex` já diz por quê: *"encerrou o fato, fechou o escopo — sem job, sem coluna, sem segunda verdade"*.

**O que isto proíbe**: JWT com *claims*, token com escopos embutidos, qualquer veredito materializado na linha do token. Criariam a segunda verdade sobre acesso que `access.ex` foi escrito para não ter — e ela **envelhece no bolso de quem saiu**.

### 2. A v1 é somente leitura

Escrita fica fora porque a plataforma grava `declared_by_user_id` e **não há autor honesto** para um ato que um programa pratica. Não é limitação técnica: é a proveniência sendo levada a sério no ponto em que ela custa.

### 3. O segredo é guardado com hash irreversível, e comparado em tempo constante

SHA-256 do segredo com `Plug.Crypto.secure_compare/2`. A busca no banco é pelo **id público** indexado, e a conferência do hash é em memória.

### 4. Nenhum limiar em constante de módulo

Validade, expiração por desuso, aviso de vencimento, teto de página e limite de taxa vivem em `priv/knowledge_base/rules/api_access_thresholds.yaml`. FR-069, e aqui com consequência de segurança própria: prazo de expiração escondido num atributo é decisão sobre risco que ninguém revisa.

### 5. Sem cache de token

Revogação vale na requisição seguinte. Cache volta como decisão, se e quando o custo for problema **medido**, com prazo de invalidação declarado.

## Alternativas consideradas

| Alternativa | Por que não |
|---|---|
| **Token com escopos embutidos (JWT)** | recomputar por requisição custa uma consulta; embutir custa **a segunda verdade**. Um token emitido em janeiro afirma, em março, um alcance que a organização já desfez. Rejeitada pela razão que a decisão 1 explica |
| **Token do tenant, não da conta** | daria integração estável quando a pessoa muda de equipe. Mas o pedido é *"somente pessoas autorizadas"*, e sem `user_id` a frase perde o sujeito: não há a quem aplicar `pode_ver/3` |
| **Guardar o token cifrado com Cloak** (o padrão da casa para segredo) | é o padrão certo para credencial de **terceiro**, que a plataforma precisa recuperar para chamar o GitHub. Aqui o valor nunca é usado de volta, só conferido — guardar reversível manteria um segredo recuperável **sem ter uso para a recuperação**, e com a chave mestra devolveria todos |
| **Bcrypt, como a senha** | os ~100 ms são a proteção de um segredo de baixa entropia escolhido por gente. Num segredo de 32 bytes gerado por máquina não há dicionário a percorrer, e o custo vira auto-negação de serviço |
| **OAuth com a conta da pessoa** | é o caminho que um cliente como o claude.ai espera, e é mais trabalho. Fica para quando houver consumidor que o exija — e será ADR nova, não uma versão maior desta |
| **Não abrir API; oferecer exportação em arquivo** | resolve planilha e não resolve painel nem agente. E exportação sem a marca de origem tem o mesmo defeito da API sem ela, com menos controle |

## Consequências

### O que melhora

- o pedido antigo é atendido sem duplicar o modelo de acesso;
- a [spec 062](../../specs/062-servidor-mcp/spec.md) deixa de estar bloqueada — o item de backlog do servidor MCP dizia *"depende de decidir autenticação e tenant"*, e é isto;
- o veredito único ganha um segundo consumidor, e com ele um teste de paridade que hoje não existe: o que a tela recusa, a API recusa. Divergência passa a ser detectável.

### O que piora, e é aceito

- **uma consulta a mais por requisição** para recomputar o alcance. É o preço de não ter a segunda verdade, e é o inverso da troca que o JWT propõe;
- **o alcance da integração muda quando a pessoa muda de equipe**, e quem integra pode não entender por quê. A tela tem de tornar isso visível;
- **a superfície de ataque cresce de verdade.** Dez achados de severidade alta na avaliação, e nove garantias a reconstruir.

### O que esta decisão expõe sem introduzir

**Não existe estado de conta desativada nesta plataforma.** `users` tem `email`, `name`, `role` e `tenant_id`; `tenants` tem `status`, `users` não tem equivalente. A tela de contas oferece criar, redefinir senha, associar e revogar elo — não há desativar.

O desligamento hoje é implícito: quem administra redefine a senha, recebe a temporária uma vez, e não a entrega. **Esse mecanismo para de funcionar no dia em que existir token** — o token não é a senha, e trocar a senha não o invalida.

Uma pessoa que sai da organização continuaria lendo os dados dela por API, e quem administra não teria um ato que resolva. `users.disabled_at` é item de backlog **anterior** a esta feature; enquanto não existir, a revogação em massa por conta (FR-074 da 061) é o substituto, e a limitação vai escrita na documentação da API.

## O que falta antes do código

Esta ADR não autoriza implementação. Pelas regras da casa faltam: `plan.md`, `tasks.md`, sprint backlog aberto pela skill própria, e a confirmação desta ADR pela pessoa mantenedora — o status acima é **Proposta**.
