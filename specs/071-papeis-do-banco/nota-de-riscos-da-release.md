# Nota de riscos da release — spec 071, os papéis do banco (T016)

Escrita em 2026-10-02, para a skill `release` e o Product Owner.

## Enquanto a conferência não disser "em vigor" em produção

**O G1 continua aberto.** A aplicação migra e serve com o mesmo papel, e quem executar SQL por ela
desliga as guardas do banco. Se esse papel for superusuário (provável, S11; a medir em §14.1),
alcança também comando e arquivo no contêiner do banco.

O merge desta feature **não** fecha a #1131. O que fecha é a pessoa mantenedora seguir o runbook
§14 e a conferência dizer "separação em vigor" (SC-004).

## Depois de em vigor, o que continua aberto

| risco | quem aceitou, e quando |
|---|---|
| **acesso a dado**: quem executa SQL ou código pelo processo que serve lê e escreve todo dado de todo tenant | a spec, no escopo (Assumptions), 2026-10-02 |
| **quem tem o Dokploy tem a credencial que migra**: o painel, `docker inspect` e o terminal | a spec, 2026-10-02 |
| **S5**: o `HEALTHCHECK` e todo `docker exec` recebem a credencial que migra, e código no processo que serve pode lê-la em `/proc`. Medido em 2026-10-02: 0 no PID 1, e 1 no processo aberto por `docker exec` (`evidencia-do-conteiner.md`) | a pessoa mantenedora, 2026-10-02: aceitar e declarar; a correção é a #1140 |
| **FR-008**: a produção pode ficar indefinidamente em "NÃO em vigor" | a pessoa mantenedora, 2026-10-02: manter a produção no ar. Quem impede isso é a #1131 aberta até a conferência |
| **tabela criada à mão por outro papel** nasce sem privilégio para quem serve | a spec; a falha é barulhenta, e não silenciosa |
