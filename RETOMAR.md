# Retomar — 2026-08-16 (noite)

## Onde parou

Árvore limpa, branch `029-competencias-da-equipe`, tudo commitado e empurrado.
**CI verde no `b512dcf`** (quality-gates + cobertura).

## A única ação pendente de VOCÊ

**Mergear o PR #396** — https://github.com/The-Band-Solution/theband/pull/396

O PR acumula, tudo verde e verificado ao vivo:

1. **Feature 029 completa** — competências da equipe na tela do time: barras de
   cobertura, resumo calculado, evolução por sparkline, matriz adaptativa
   (lista por pessoa quando nenhum domínio repete — o caso do time IA).
2. **Associação equipe↔projeto pelos dois lados** (tela do time e do projeto).
3. **Avisos de processo na tela do time** (anti-padrões; não-avaliado nunca
   vira saúde).
4. **Regra do título** — issue sem corpo usa o título como texto.
5. **Regra da primeira geração** — sem perfil anterior, pega TUDO que tem
   texto; pisos só valem da 2ª geração em diante. Censo real: 30 → 47 elegíveis.
6. **Report "why not everyone?"** em /profiles — pessoa a pessoa, motivo fino
   recalculado na leitura. Base real: 24 no_assignment, 13 below_floor,
   13 geraria_hoje, 4 observation_ended (+34 geradas = 88).

No merge, fecha #395 (closing keyword conferida: "Closes", em inglês).
**Depois do merge, conferir se #395 fechou de fato** — regra da casa.

## Depois do merge

- #397 — equipe formada por equipes (rollup como segundo modo de
  `TeamSkills.coverage`; depende do #396 mergeado).
- #81 — filtro por organização nas telas.
- #398 — organizar o report "why not everyone?" (agrupar por motivo, texto do
  motivo dito uma vez, contagem por grupo).
- Rodar a rodada de novo (botão "run now — everyone" em /profiles): os 13
  "geraria hoje" viram perfis com a regra nova. Esperado: ~47 gerados.
- Sprint 018: escrever `sprint-review.md` e consolidar lições.

## Decisões suas em aberto (backlog)

#356 (pisos N/M), #358 (quickstart), #367 (Conecta Fapes), #368 (prazo),
#369 (FR-012), #370 (FR-007), #176 (iterações), #363/#364 (competência como
unidade — adiado por você).

## Achado de gestão (não é código)

24 pessoas sem NENHUMA issue designada nos repositórios coletados — ou o
trabalho está em repositório não observado, ou chega por outro canal. O report
na tela agora nomeia cada uma.
