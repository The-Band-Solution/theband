# Requirements Quality Checklist: a rodada de geração

**Purpose**: testar a **escrita** dos requisitos da 027 — se estão completos, sem ambiguidade, mensuráveis e coerentes entre si. Não testa implementação.
**Created**: 2026-08-16
**Feature**: [spec.md](../spec.md)

**Foco pedido**: o que esta feature pode quebrar em silêncio — rodada que não executa e parece que executou, pessoa pulada sem motivo nomeado, custo que só aparece na fatura, credencial de uma organização usada por outra, e texto novo que fala só do delta em vez da trajetória.

**Profundidade**: padrão. **Público**: quem revisa o PR, antes do `/speckit-plan`.

## Completude dos requisitos

- [x] CHK001 O momento exato da rodada está especificado — dia do mês, hora e fuso? O caso-limite fala em "um único momento de referência declarado", e nenhum requisito diz qual é. [Gap, Spec §FR-001, §Edge Cases]
- [x] CHK002 Existe requisito para **desligar** a automação de uma organização? Só o ato de ligar está escrito. [Gap, Spec §FR-018, §FR-019]
- [x] CHK003 O registro de quem **desligou** e quando está exigido, como o de quem ligou? [Gap, Spec §FR-019]
- [x] CHK004 A lista de motivos de pulo está enumerada num requisito, e não apenas descrita em Key Entities? Sem enumeração normativa, "por motivo" é interpretável. [Completeness, Spec §FR-014, §Key Entities]
- [x] CHK005 Está especificado **quem** pode disparar a rodada manualmente? [Gap, Spec §FR-004]
- [x] CHK006 Está especificado onde a tela da rodada vive, e se é tela própria ou seção de uma existente? O princípio X da constituição exige que uma tela faça uma coisa. [Gap, Spec §FR-017]
- [x] CHK007 Existe requisito sobre **retenção** dos registros de rodada — por quanto tempo, e se são somente-acréscimo como os perfis? [Gap, Spec §FR-014]
- [x] CHK008 O comportamento das organizações **já existentes** no momento em que a feature sobe está escrito como requisito de dados, e não só como intenção? [Completeness, Spec §FR-018a]
- [x] CHK009 Existe requisito de teto de custo por rodada, ou está declarado explicitamente que não há teto nesta versão? Silêncio aqui é a diferença entre decisão e esquecimento. [Gap, Spec §FR-020]
- [x] CHK010 Está especificado que a listagem de rodadas é **por organização**, e que uma não alcança a da outra? [Gap, Spec §FR-017]

## Clareza e ausência de ambiguidade

- [x] CHK011 "Consumo de entrada" está definido em unidade — tokens, caracteres, ou custo em moeda? Três leituras diferentes produzem três telas diferentes. [Ambiguity, Spec §FR-014, §FR-020]
- [x] CHK012 "Tarefas concluídas desde o recorte do perfil vigente" define **qual** extremo do recorte é a referência? [Clarity, Spec §FR-006]
- [x] CHK013 "Perfil vigente mais velho que M" mede a idade a partir da geração ou do fim do recorte? As duas datas existem e divergem. [Ambiguity, Spec §FR-006]
- [x] CHK014 "Falha do provedor que impeça continuar" está caracterizada? Chave revogada e limite de taxa pedem desfechos diferentes, e o requisito trata as duas como uma. [Ambiguity, Spec §FR-016]
- [x] CHK015 "Histórico inteiro observado" está definido em relação ao que a 026 já monta — os três períodos por volume continuam valendo? [Clarity, Spec §FR-022]
- [x] CHK016 "A origem do pedido MUST ser registrada" diz **onde** ela é registrada e se aparece em algum lugar? Um dado gravado que ninguém vê não é requisito verificável. [Clarity, Spec §FR-015]
- [x] CHK017 A rodada disparada manualmente conta como "rodada" para efeito da proibição de simultaneidade? [Ambiguity, Spec §FR-003, §FR-004]

## Consistência entre requisitos

- [x] CHK018 A `FR-011` — organização sem chave não executa — está consistente com a `FR-021` da 026, que exigia credencial do ambiente? A contradição está declarada, mas está declarada **como emenda** à 026? [Consistency, Spec §FR-010–013]
- [x] CHK019 A `FR-023` (perfil novo não apaga anterior) e a `FR-015` da 026 dizem a mesma coisa sem divergir na redação? Duas frases para a mesma regra envelhecem em direções diferentes. [Consistency, Spec §FR-023]
- [x] CHK020 A cadência mensal da `FR-001` e o M de três meses da `FR-006` estão explicitamente reconciliados no corpo dos requisitos, e não só em Assumptions? [Consistency, Spec §FR-001, §FR-006]
- [x] CHK021 A `FR-005` (pisos da 026) e a `FR-007` (quem nunca teve perfil) descrevem conjuntos que não se sobrepõem de forma contraditória? [Consistency, Spec §FR-005, §FR-007]
- [x] CHK022 O `SC-002` fixa 6 de 34 com N=10, e a `FR-021` obriga recontar o custo antes de fixar os limiares. O critério declara que muda junto com a recontagem? [Conflict, Spec §SC-002, §FR-021]

## Qualidade dos critérios de aceitação

- [x] CHK023 O `SC-004` — "menos de 30 segundos e sem consultar log" — é verificável sem instrumentar a pessoa que lê? [Measurability, Spec §SC-004]
- [x] CHK024 O `SC-009` define como comparar "trajetória inteira" contra "só os meses desde o perfil anterior" de forma objetiva? [Measurability, Spec §SC-009]
- [x] CHK025 O `SC-006` — nenhuma rodada consome a credencial de outra — é verificável a partir do que a plataforma registra, e não só por inspeção de código? [Measurability, Spec §SC-006]
- [x] CHK026 Cada FR tem um SC que o alcança, e cada SC aponta para um FR? [Traceability, Spec §Requirements, §Success Criteria]

## Cobertura de cenários

- [x] CHK027 Existem requisitos para o fluxo de **exceção** em que a rodada começa e o provedor falha na primeira pessoa — a rodada é "executada" ou "não executada"? [Coverage, Exception Flow, Spec §FR-016]
- [x] CHK028 Existem requisitos de **recuperação**: quem foi pulado por falha volta na rodada seguinte, ou fica esperando o próximo mês? [Gap, Recovery, Spec §FR-016]
- [x] CHK029 Existem requisitos para a organização que liga a automação **no meio do mês** — a primeira rodada é imediata ou espera o próximo momento de referência? [Gap, Alternate Flow, Spec §FR-018]
- [x] CHK030 Está coberto o caso da pessoa cuja observação é encerrada **entre** a seleção e a geração dentro da mesma rodada? [Coverage, Edge Case, Spec §FR-008]

## Requisitos não-funcionais

- [x] CHK031 A tela da rodada tem requisito de **proveniência** — os números exibidos são observados, e o design system exige que a marca leve texto além da cor? [Gap, Non-Functional, `AGENTS.md` §11.1]
- [x] CHK032 Está declarado que a interface desta feature fala inglês, como as demais telas? [Gap, Non-Functional, `AGENTS.md` §11.1]
- [x] CHK033 Os requisitos de observabilidade da rodada — o que vai para log, e o que fica fora — estão escritos, dado que a `FR-013` proíbe a chave em log? [Completeness, Non-Functional, Spec §FR-013]
- [x] CHK034 Existe requisito sobre o que acontece quando a rodada demora mais que o intervalo entre duas rodadas? [Gap, Non-Functional, Spec §FR-003]

## Dependências e suposições

- [x] CHK035 A suposição "os valores iniciais são N=10 e M=3 meses" está marcada como revisável **e** com o mecanismo de revisão nomeado? [Assumption, Spec §Assumptions, §FR-009]
- [x] CHK036 A dependência da feature 026 — pisos, material, formato — está declarada como dependência, e não absorvida como se fosse desta feature? [Dependency, Spec §Assumptions]
- [x] CHK037 A suposição de que o provedor externo responde em tempo aceitável para 34 gerações seguidas está declarada? [Assumption, Gap]

## Notes

- Marcar `[x]` quando o requisito estiver escrito, não quando o código existir. Esta lista testa a spec.
- Item que reprova vira alteração na `spec.md` **antes** do `/speckit-plan` — ou vira exclusão declarada, com a razão.
- **Resultado da passagem de 2026-08-16: 37 de 37.** Trinta e três itens reprovaram na primeira
  leitura e viraram emenda na `spec.md`, não justificativa: `FR-001a` (momento da rodada),
  `FR-004a` (primeira rodada ao ligar), `FR-016a` (quem falhou volta), `FR-017a` (retenção),
  `FR-018b` e `FR-018c` (desligar, e organização que já existe), `FR-020a` (sem teto, declarado),
  e `FR-024` a `FR-027` (tela própria, proveniência, inglês, log sem chave nem material).
- Três critérios de sucesso foram reescritos por não serem verificáveis como estavam: `SC-004`
  media a pessoa que lê, `SC-009` não dizia como comparar dois recortes, e `SC-006` não tinha
  registro que o sustentasse — a rodada passou a gravar os quatro últimos da chave usada.
- **CHK021 passou sem emenda**: a `FR-007` já condiciona a "e passa nos pisos", então os dois
  conjuntos não se contradizem.
