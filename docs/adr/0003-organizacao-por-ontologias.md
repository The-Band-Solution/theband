# ADR 0003 — Domínio organizado pelas ontologias, não pelas ferramentas

## Status

Aceita — 2026-08-08

## Contexto

Há duas formas óbvias de organizar um integrador de dados.

A primeira é **por fonte**: um módulo `GitHub`, um `Jira`, um `Sonar`, cada um com seus
schemas espelhando os payloads da API correspondente. É a organização que o trabalho de
integração sugere naturalmente, e a que aparece sozinha quando ninguém decide o
contrário.

A segunda é **por conceito**: módulos que representam o que os dados significam —
pessoa, projeto, solicitação de mudança, processo de integração contínua — com as
fontes entrando como adaptadores nas bordas.

A primeira parece pragmática e é uma armadilha. Quando o domínio espelha as APIs, o
modelo de dados do fornecedor vira o modelo do sistema. Métricas passam a ser definidas
em termos de "campo X da API do GitHub", quebram quando a API muda, e não podem ser
comparadas entre fontes: "tarefa" no Jira e "issue" no GitHub viram colunas parecidas
com semânticas diferentes, somadas sem que ninguém perceba.

Isso destrói exatamente o que justifica o The Band existir.

## Decisão

O núcleo do domínio é organizado **pelas ontologias**, espelhando a rede UFO → SEON →
Continuum:

```text
lib/the_band/ontology/
├── ufo/
├── seon/{eo,spo,sys_swo,rsro,cmpo,roost,qapo,osdef}/
└── continuum/{sro,ciro,cdro}/
```

Não existe módulo `TheBand.GitHub` no domínio. GitHub é fonte, não conceito. Os
conectores vivem em `integrations/` e `priv/connectors/`, e a travessia entre os dois
mundos é feita por **mapeamentos semânticos declarados**, com equivalência,
justificativa e limitações explícitas.

Regras que acompanham a decisão:

- o conector grava payload bruto e proveniência, depois chama a **API pública** do
  módulo ontológico — nunca escreve em schema Ecto de domínio;
- uma entidade externa pode alimentar várias ontologias, cada uma com seu mapeamento;
- conceito existente em ontologia mais geral é reutilizado, nunca duplicado —
  `Person` mora em EO, e SRO, CIRO e CDRO apenas a referenciam em papéis;
- a direção das dependências vai do específico para o geral, e é verificada
  automaticamente;
- tabelas são prefixadas pela ontologia dona do conceito (`eo_`, `spo_`, `cmpo_`, …).

## Alternativas consideradas

**Organizar por fonte.** Mais rápido para o primeiro conector e mais difícil para todos
os outros. Cada nova fonte adiciona um vocabulário paralelo, e comparar dados entre
fontes vira trabalho manual de reconciliação — feito em query, sem registro, por quem
estiver montando o relatório.

**Modelo canônico próprio, sem ontologias de referência.** Resolveria a comparabilidade
sem exigir a rede ontológica, mas jogaria fora o que a tese oferece pronto: distinções
já validadas (planejado vs. executado, defect vs. fault vs. failure, papel vs. pessoa) e
uma fundamentação que sustenta as escolhas quando surgir divergência. Um modelo
canônico caseiro tende a ser decidido por quem grita mais alto na reunião.

**Camada de tradução em cima de schemas por fonte.** Mantém os schemas espelhando as
APIs e traduz na leitura. Adia o problema: a tradução vira lógica implícita espalhada
por queries, sem proveniência e sem revisão semântica.

## Consequências

**Positivas**

- Métricas são definidas em termos de conceitos, não de campos de API.
- Dados de fontes diferentes tornam-se comparáveis por construção.
- Mudança de API externa fica contida no conector e no mapeamento.
- A rastreabilidade "de onde veio este número" é estrutural, não reconstruída depois.
- A rede ontológica dá critério para resolver divergência conceitual.

**Negativas**

- O primeiro conector custa mais: exige mapear conceitos antes de escrever código.
- Exige que a equipe conheça a rede ontológica — há curva de aprendizado real.
- Conceitos das ferramentas que não cabem em nenhuma ontologia exigem decisão explícita,
  e não podem ser simplesmente persistidos "por precaução".

**Mitigações**

- Documentação gerada da base: [rede de ontologias](../ontology/README.md) e
  [índice de conceitos](../ontology/concept-index.md).
- Glossário que liga o vocabulário das ferramentas aos conceitos formais.
- Payload bruto sempre preservado: o que não foi mapeado ainda não é perdido, apenas
  não promovido ao domínio.
