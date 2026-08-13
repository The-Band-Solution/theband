# Specification Quality Checklist: a página da pessoa que não varre tudo

**Propósito**: validar a completude da spec antes do planejamento
**Criada em**: 2026-08-12 · **Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Sem detalhe de implementação nos requisitos — os nomes de tabela aparecem só na medida, que é
      onde eles **são** a evidência
- [x] Focada no valor: a tela abre no tempo do que ela mostra
- [x] Legível por quem não programa
- [x] Todas as seções obrigatórias preenchidas

## Requirement Completeness

- [x] Nenhum marcador `[NEEDS CLARIFICATION]`
- [x] Requisitos testáveis — inclusive o FR-010, que exige teste que falhe se o custo voltar a
      crescer com o histórico
- [x] Critérios mensuráveis: 85 → 40 ms, 322 → 200 ms, 44 289 → 25 linhas, 3 882 descartes → 0
- [x] Critérios independentes de tecnologia — falam de tempo, de linhas lidas e de conteúdo idêntico
- [x] Cenários de aceitação nas três user stories
- [x] Casos de borda identificados — seis, incluindo o empate de instante e a coleta concorrente
- [x] Escopo delimitado: reduzir ou arquivar histórico fica **fora**, e está escrito
- [x] Premissas identificadas — a forma de medir, o dobro do LiveView conectado, e a máquina

## Feature Readiness

- [x] Todo requisito funcional tem critério correspondente
- [x] As user stories cobrem os dois custos medidos e a consequência nas outras telas
- [x] Fatia vertical: a melhoria é **na tela**, e a verificação é na tela
- [x] Nenhuma mudança de interface — e isso é requisito (FR-008), não efeito colateral

## Notas

**Esta spec nasceu de medir a aplicação em execução**, não de suspeita. Os números vieram do log do
servidor rodando, do `EXPLAIN (ANALYZE, BUFFERS)` no banco de desenvolvimento e de cinco medidas
repetidas por tela.

**A medida mudou o pedido, e está registrado no corpo**: a tela de pessoas responde em 25 ms na
lista e 85 ms no detalhe; quem está em **322 ms** é `/work`, que ninguém mencionou. A causa é a
mesma, e otimizar só a tela pedida deixaria a causa de pé em outros quinze lugares.

**Uma coisa que a spec deliberadamente não decide**: *como* a promoção vigente passa a ser
resolvida. Materializar, indexar de outro jeito, restringir a subconsulta ao conjunto exibido — é
decisão de plano, e tem consequência de proveniência que o `/speckit-plan` precisa pesar contra a
ADR 0004 D7, que proíbe materializar situação derivada.
