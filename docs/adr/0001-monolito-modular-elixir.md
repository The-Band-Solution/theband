# ADR 0001 — Monólito modular em Elixir/Phoenix, não microserviços

## Status

Aceita — 2026-08-08

## Contexto

A tese que fundamenta o The Band descreve sua arquitetura como um *Federated
Information System*: serviços autônomos baseados em ontologia (OBS), cada um com seu
repositório próprio (OBDR), comunicando-se por um message broker para propagar
mudanças e manter consistência entre repositórios.

Lida literalmente, essa descrição sugere uma implementação com um serviço por
ontologia — doze serviços, doze bancos, um broker, e a operação toda que isso implica.

O que a tese exige de fato é **autonomia semântica** entre as ontologias: um módulo não
pode depender do modelo interno de outro, conceitos reutilizados não podem ser
duplicados, e cada dado precisa ser rastreável até sua origem. Nada disso exige
processos separados.

O projeto começa com uma equipe pequena, sem demanda de escala conhecida, e com o risco
principal concentrado na **corretude semântica** — não na capacidade de processamento.
Distribuir cedo transforma erro de modelagem em erro distribuído, que é mais caro de
diagnosticar e mais lento de corrigir.

## Decisão

The Band nasce como **monólito modular multitenant em Elixir/Phoenix**, com PostgreSQL,
Ecto e Oban.

As camadas da tese viram fronteiras internas:

- cada ontologia é um módulo com API pública e schemas privados;
- a comunicação entre módulos passa exclusivamente pela API pública;
- filas, retries, agendamento e propagação usam **Oban** sobre o PostgreSQL existente,
  no lugar do message broker;
- as tabelas são prefixadas pela ontologia dona do conceito, preservando a separação
  dos OBDRs em um único banco.

A autonomia é mantida por disciplina de fronteira verificada em revisão e teste, e não
por fronteira de rede.

## Alternativas consideradas

**Um serviço por ontologia, com broker (leitura literal da tese).** Fiel ao texto,
mas paga custo operacional alto — deploy, observabilidade distribuída, consistência
eventual entre doze repositórios — antes de existir qualquer evidência de que a escala
justifique. Erros de modelagem, que são o risco real nesta fase, ficariam mais caros de
corrigir.

**Monólito sem fronteiras internas explícitas.** Mais rápido no começo, mas dissolve
justamente a propriedade que a tese exige: se qualquer módulo pode ler o schema de
outro, a autonomia semântica desaparece em poucos meses e não volta sem reescrita.

**Kafka ou RabbitMQ como espinha dorsal desde o início.** Resolveria propagação e
desacoplamento, mas adiciona um componente de infraestrutura que precisa ser operado,
monitorado e versionado — sem carga que o justifique. Oban cobre o caso atual usando um
banco que já é obrigatório.

## Consequências

**Positivas**

- Um deploy, um banco, uma stack de observabilidade.
- Refatoração conceitual é local e barata enquanto o modelo ainda está sendo validado.
- Transações locais garantem consistência sem coordenação distribuída.
- Oban entrega filas, retries e agendamento sem infraestrutura adicional.

**Negativas**

- Escala é do processo inteiro, não por ontologia.
- A autonomia depende de disciplina: sem revisão, a fronteira erode silenciosamente.
- Uma ontologia com carga muito maior que as outras não pode ser escalada isoladamente
  sem antes ser extraída.

**Mitigações**

- API pública por módulo com `defdelegate`; acesso a schema de outro módulo é falha de
  revisão, não estilo.
- Tabelas prefixadas por ontologia, mantendo a separação lógica dos repositórios.
- Extrair um módulo para serviço permanece viável: a fronteira já existe no código.

**Gatilhos para revisitar**

- Uma ontologia precisar de escala ou ciclo de release independente.
- O volume de ingestão exceder o que Oban sustenta confortavelmente.
- Necessidade real de consumidores externos independentes por ontologia.

Qualquer um desses exige nova ADR — esta não é revogada por preferência.
