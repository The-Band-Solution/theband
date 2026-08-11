# Specification Quality Checklist: Issues e projetos das organizações observadas

**Purpose**: Validar completude e qualidade da especificação antes do planejamento
**Created**: 2026-08-10
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] Sem detalhes de implementação (linguagem, framework, API)
- [x] Focada em valor de usuário e necessidade de negócio
- [x] Escrita para quem não implementa
- [x] Todas as seções obrigatórias preenchidas

## Requirement Completeness

- [x] Nenhum marcador [NEEDS CLARIFICATION] restante
- [x] Requisitos testáveis e sem ambiguidade
- [x] Critérios de sucesso mensuráveis
- [x] Critérios de sucesso independentes de tecnologia
- [x] Todos os cenários de aceitação definidos
- [x] Edge cases identificados
- [x] Escopo delimitado
- [x] Dependências e suposições identificadas

## Feature Readiness

- [x] Todo requisito funcional tem critério de aceitação claro
- [x] Os cenários de usuário cobrem os fluxos principais
- [x] A feature atende aos resultados mensuráveis dos critérios de sucesso
- [x] Nenhum detalhe de implementação vazou para a especificação

## Notas da validação

**Zero NEEDS CLARIFICATION, e as três decisões que poderiam virar um estão
resolvidas com o motivo escrito:**

| Poderia ser dúvida | Decidido | Por quê |
|---|---|---|
| todos os repositórios, ou escolher quais? | **todos por padrão** | escolher antes da primeira coleta seria selecionar sobre dados que não existem. Restringir é a US3 |
| iteração vira sprint? | **só depois de começar** | iteração é configuração, sprint é processo executado. Um sprint que não começou não ocorreu |
| tipo de issue desconhecido? | **não promove, conta como lacuna** | a regra versionada já decide `fallback: skip`. Chutar contamina toda medida de escopo |

**Três verificações que este checklist fez e valem registro:**

**Nenhum SC é afirmação de que algo funciona.** Sete dos doze são pela violação —
"nenhuma issue de repositório não coletado é marcada", "nenhum épico sem partes",
"nenhum ciclo", "nenhum campo sem mapeamento convertido". É a forma que a L18
pediu: um critério atendido não basta, é preciso conferir que o proibido não
ocorreu.

**A L19 aparece como requisito, não como lembrete.** FR-010 exige o escopo por
repositório, e SC-003 o verifica pela violação. Sem isso, uma coleta de issues
repetiria o defeito num volume muito maior — dezenas de repositórios em vez de
três organizações.

**FR-015 impede a repetição do defeito que a ADR 0004 D7 já nomeia.** A
classificação épico/atômica é derivada da existência de partes. Gravá-la como
valor escolhido reintroduziria situação materializada, que é a dívida do
`connected_tools.status` ainda em aberto.
