# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Multi-audiência de verdade, papéis distintos com telas e decisões próprias (confirmado 2026-08-17):

- **Gestor de engenharia** — coordena times e alocação; usa perfis de competência, cobertura da equipe e anti-padrões para decidir staffing e desenvolvimento de pessoas.
- **Diretoria / gestão executiva** — visão de portfólio: projetos, sprints, medidas de fluxo; decide prioridade e investimento.
- **Tech lead** — olha o próprio time: processo, issues paradas, quem demonstra o quê.
- **Admin da plataforma** — configura fontes, credenciais (chave de LLM do tenant), coleta e geração; hoje é quem opera o piloto.

## Product Purpose

Plataforma de **integração semântica de dados de Engenharia de Software**. Coleta dados das ferramentas de desenvolvimento (hoje GitHub; a arquitetura prevê GitLab, Azure DevOps, Jira, Sonar, CI/CD), harmoniza contra ontologias de referência (rede SEON), preserva a proveniência de cada registro e entrega informação rastreável para decisão.

Sucesso no piloto (Conecta/LEDS): sustentar **as três frentes juntas**, sem prioridade única —
1. alocação e desenvolvimento de pessoas (perfis, competências da equipe, lacunas, pontos únicos de falha);
2. saúde do processo (anti-padrões, issues paradas, medidas de fluxo);
3. validação do modelo ontológico com dados reais — o produto é a tese em produção.

A régua interna já existente: toda necessidade de informação declara `decision_supported` antes de existir medida. Informação que ninguém usa para decidir não é o produto.

## Positioning

O que um vizinho não copia de verdade: **a rede de ontologias como partitura**. Um ETL move notas; The Band as toca segundo ontologias de referência — e por isso consegue (e é obrigado a) distinguir **observado** de **derivado**, preservar proveniência registro a registro, e nunca deixar ausência parecer zero. Base científica: tese de doutorado de Paulo Sérgio dos Santos Júnior (UFES, 2023), orientação Monalessa Perini Barcellos, coorientação João Paulo Andrade Almeida.

## Operating Context

- Multitenant; toda consulta escopada por tenant (consulta sem tenant é bug de segurança, não estilo).
- Piloto com dados reais: organização Conecta/LEDS, ~88 pessoas coletadas, times, repositórios e Projects v2 do GitHub.
- Geração mensal de perfis de competência por LLM, com a chave do provedor pertencendo ao tenant; rodada roda sozinha (Oban) e a tela presta contas do que fez, pessoa a pessoa.
- Telas atuais: People, Teams, Work, Projects, Boards, Process, Syncs, Tools, AI, Profiles.
- Desenvolvimento guiado por Spec Kit (spec → plan → tasks → issues) e sprints documentados em `docs/sprints/`; o próprio repositório é planejado como fonte de dados a ingerir (dogfooding da SRO).

## Capabilities and Constraints

Regras da casa que qualquer trabalho futuro preserva (são produto, não convenção):

- **Marca, nunca apaga** — tabelas somente-acréscimo; remoção é `unlinked_at`/`removed_at`/`no_longer_observed_at`.
- **Ausência nomeada, nunca zero** — quem não tem perfil aparece nomeado; campo vazio é desconhecido, não zero.
- **Derivado se declara** — todo número calculado carrega a marca visual (hachura) e o rótulo em texto.
- **Contagens derivam de entradas**, nunca de contadores armazenados.
- **Booleano no lugar de relator é antipadrão** — quem afirmou, quando, com que evidência.
- Saída de LLM é controlada por **schema estruturado**, nunca por pedido de formato em texto (regra em texto é ignorada; schema é obedecido).
- Qualidade: `mix gates` (13 gates) é a definição única de verde; veredito é código de saída.

Decisões de produto explicitamente em aberto (issues): pisos N/M da geração (#356), competência como unidade agregável (#363/#364), coleta de comentários (#400) e CI (#401) usando os modelos da ontologia, perfil em inglês (#402).

## Brand Commitments

- Nome **The Band** e a metáfora que o sustenta: músico = serviço/ontologia, instrumento = ontologia, nota = dado cru, música = informação, público = a organização. Notas não são música.
- Tagline: **"Orchestrating data into information organisations can act on"** — `orchestrating` é o maestro, não infraestrutura.
- `docs/design-system.md` é **normativo** para toda tela nova; a regra que decide o resto: *o preenchimento carrega a proveniência* (hachura = derivado).
- Landing page pública em https://the-band-solution.github.io/theband/ (bilíngue PT/EN).

## Evidence on Hand

- Tenant real com dados do GitHub da Conecta/LEDS: 88 pessoas consideradas na rodada, 34→47 elegíveis com as regras atuais, medições reais de custo (mediana ~12,6k tokens/pessoa — issue #356).
- Tese de doutorado (UFES 2023) como fundamento publicado.
- **Ausências que trabalho futuro não pode fabricar**: não há depoimentos, clientes pagantes, preços nem benchmarks públicos. A landing não os inventa; telas e materiais futuros também não.

## Product Principles

1. **Proveniência antes de estética** — se a tela não distingue observado de derivado, ela desfaz o produto.
2. **Prestação de contas** — o que roda sozinho explica o que fez e o que deixou de fazer, nomeando cada caso.
3. **Decisão declarada** — medida só existe amarrada à decisão que sustenta (`decision_supported`).
4. **O dado real manda** — regra de recorte se verifica contra a base do piloto antes de virar código; suíte verde não é evidência de número certo.
5. **Vertical slice** — nunca infraestrutura sem consumidor visível na tela.

## Language

Interface em inglês hoje, como convenção — **internacionalização/PT-BR na tela é decisão futura em aberto**, não compromisso fechado (confirmado 2026-08-17). Documentação interna, commits e specs em português.
