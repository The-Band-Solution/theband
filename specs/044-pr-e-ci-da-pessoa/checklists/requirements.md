# Specification Quality Checklist: A solicitação de mudança e a verificação, na página da pessoa

**Purpose**: Validar completude e qualidade da spec antes do planejamento
**Created**: 2026-08-27
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Sem detalhe de implementação (linguagem, framework, API)
- [x] Focada em valor para quem usa
- [x] Escrita para quem decide, e não só para quem codifica
- [x] Todas as seções obrigatórias completas

**Nota sobre nomes de tabela e coluna.** A spec cita `collected_change_requests`,
`commit_authors`, `head_sha`. Isso **não** é detalhe de implementação vazando: é a
**evidência** de que o dado existe ou não existe, e é o que sustenta a decisão de deixar
"revisou" fora da entrega. Sem nomear a origem, "não tem dado" seria afirmação sem prova.

## Requirement Completeness

- [x] Nenhum marcador [NEEDS CLARIFICATION] — as duas partes sem dado foram **decididas**
      (ficam fora, declaradas), e não deixadas em aberto
- [x] Requisitos testáveis e sem ambiguidade
- [x] Critérios de sucesso mensuráveis
- [x] Critérios de sucesso agnósticos de tecnologia
- [x] Cenários de aceitação definidos para as três user stories
- [x] Casos de borda identificados — cinco, todos medidos
- [x] Escopo delimitado: FR-010 e FR-011 dizem o que a feature **não** faz
- [x] Dependências e premissas identificadas

## Feature Readiness

- [x] Todo requisito funcional tem critério de aceitação claro
- [x] As user stories cobrem os fluxos principais
- [x] A feature atende os critérios de sucesso
- [x] Nenhum detalhe de implementação vaza para a spec

## A primeira versão desta spec estava errada, e foi reescrita

A versão de 2026-08-27 de manhã **recusava metade do pedido**: dizia que "revisou" e
"aprovou" não tinham dado, e declarava a lacuna em vez de fechá-la.

Ela estava errada por não ter olhado a rede. O modelo já existia:

- `qapo.evaluation_participation` (issue #440) declara quem avalia — e a proveniência dele
  diz, com todas as letras, que existe para fechar
  `github.pull_request_review.to.qapo.artifact_evaluation`;
- o mapeamento existe com `status: proposed` desde então, e já tinha resolvido as decisões
  difíceis: separar `Bot` de `User`, usar `reviews` e não `reviewThreads`, e gravar
  `PENDING` sem `submittedAt`.

**A lição é a L61 pela terceira vez**: limitação declarada no mapeamento é requisito, e
não nota de rodapé. Foi a pessoa mantenedora que perguntou "vc irá acertar o erro ou
não?", e a pergunta estava certa.

## O que esta spec faz de diferente

**Ela entrega os três papéis que a rede já separa** — criador, revisor, integrador — e o
veredito da revisão traduzido para conceito da ontologia, e não para o enum do GitHub.

**E ela assume o custo em vez de adiá-lo**: a recoleta de 5.635 solicitações em 160
repositórios foi decidida, não deixada como "feature própria".

## Notes

- Nenhum item pendente. A spec está pronta para `/speckit-plan`.
- A decisão que o plano vai ter de tomar: **quantas consultas** as listas custam, e se
  cabem no teto de 23. As contagens por veredito e por desfecho podem sair numa consulta
  com `filter`, como a #369 fez — mas as listas em si são dado que ninguém carregou ainda.
- A segunda decisão do plano: se a revisão vira **tabela própria** ou colunas em
  `collected_change_requests`. Uma solicitação tem N revisões, então tabela — mas o plano
  é que declara.
