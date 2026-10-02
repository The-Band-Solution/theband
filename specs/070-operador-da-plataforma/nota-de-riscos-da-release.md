# Nota de riscos da release — spec 070, o operador da plataforma (T062)

Para a skill `release` e para o Product Owner. Escrita em 2026-10-02, depois das Fases 3 e 4. Cada
risco traz quem o aceitou e quando. **"Não medido" é o estado, e não uma pendência escondida**:
onde a medição depende de acesso à produção, ela não foi feita por quem escreveu esta nota.

## 1. As migrações, a medir contra a produção antes de publicar

As cinco migrações da feature rodam no `entrypoint` do deploy. Três delas **levantam** quando o dado
da produção não é o que a feature supõe, e o deploy para antes de servir:

| migração | o que ela faz com a produção | o que medir antes |
|---|---|---|
| `20261002120000_estado_da_organizacao_valido` (T013) | `CHECK tenants_status_valido`; **levanta** com a contagem se houver `status` fora de `active`/`suspended` | `SELECT status, count(*) FROM tenants GROUP BY status` |
| `20261002140000_episodio_de_suspensao` (T044) | cria `tenant_suspensions`, e grava um episódio `not_recorded`, sem autor, para cada organização já `suspended` | quantas estão `suspended` hoje: cada uma ganha esse episódio, e a lista do operador mostra "reason not recorded" |
| `20261002140100_estado_tem_episodio` (T044a) | `LOCK TABLE` e o trigger adiado; **levanta** se a consulta do SC-002 ou a recíproca não der zero | nada a medir à parte: depois da T044 dá zero por construção, e o `LOCK` impede a escrita entre as duas |
| `20261002130000_operador_da_plataforma`, `…130100_segundo_fator_do_operador` | tabelas novas, sem dado | — |
| `20261002140200_revogacao_por_suspensao` (T047) | coluna nova e dois `CHECK`s em `api_access_tokens`; as linhas antigas passam pelos dois | — |

As cinco foram ensaiadas em round trip (`migrate` / `rollback`) numa base isolada, com uma
organização `suspended` semeada antes. Os resultados estão nas mensagens de commit da T044 e da T047.
**Contra a produção: não medido.** A consulta da primeira linha é da pessoa mantenedora, que tem o
acesso.

## 2. Os riscos residuais declarados

| risco | o que sobra | quem aceitou, e quando |
|---|---|---|
| **A8**, mesma origem | um XSS de domínio usaria o cookie do operador pela mesma origem. A defesa é a CSP (`script-src 'self'`, sem `unsafe-inline`), provada em toda resposta de `/platform`, inclusive nas páginas de erro (#1135). O host próprio vem com `theband.dev` em produção | pessoa mantenedora, 2026-10-01 (`plan.md`, decisão 5) |
| **A17**, o código no terminal | o código de definição aparece no terminal do Dokploy. Não foi verificado se o Dokploy guarda o histórico. Mitigação: 30 min, uso único, e o roteiro (runbook §13.2) manda a pessoa rodar o comando ela mesma ou receber o código por voz | pessoa mantenedora, 2026-10-01 (`plan.md`, Riscos) |
| **A4**, sem limite por IP | **a T043 não entrou**: depende de medir se o Traefik sobrescreve `x-forwarded-for` (T004). Fica só a espera por conta, e com ela a negação de serviço de um operador, que alguém pode travar errando a senha dele | pessoa mantenedora, 2026-10-01 (`plan.md`, decisão 4); **a medição T004 está pendente** |
| **O16**, o aparelho do segundo fator | a conta do operador tomada derruba todas as organizações. O TOTP reduz o risco; o que sobra é o aparelho | pessoa mantenedora, 2026-10-01 (FR-016) |
| **T9**, sem aviso ao operador | (a) aparelho perdido: o código de recuperação dá uma entrada mas não revoga o aparelho, e o roteiro manda reiniciar pelo comando; (b) não há notificação na troca de fator nem no reuso. O sinal é o evento em `:warning` no log de acesso | pessoa mantenedora, 2026-10-01 (`seguranca-totp.md`, emenda T011) |
| **T10**, phishing em tempo real | o TOTP não resiste a um proxy que repasse a senha e o código em menos de 90 s. É aceitável em ASVS L2, e o WebAuthn seria feature própria | pessoa mantenedora, 2026-10-01 (`seguranca-totp.md`) |
| **T11**, o relógio do servidor | com deriva acima de 30 s, todo código é recusado e o segundo fator trava em 10 tentativas. **O NTP do VPS: não medido.** O roteiro manda conferir com `timedatectl` antes da primeira concessão (runbook §13.1) | pessoa mantenedora, 2026-10-01 (`seguranca-totp.md`); a medição é de quem conceder |
| **G1**, o dono das tabelas | o trigger adiado e os triggers somente-acréscimo protegem de código, e não de quem tem o banco: o papel da aplicação migra com o mesmo `DATABASE_URL`, e é dono | pessoa mantenedora, 2026-10-02: "abrir a issue agora, fazer depois da 070" (#1131) |

## 3. O que pede decisão antes ou depois da release

- **As frases fora do protótipo aprovado** (conferência T060, D-7 e D-10 a D-13):
  - a recusa de confirmação de senha diferente;
  - as duas frases de sucesso do ato;
  - a recusa de nota na reativação;
  - a frase de `:sem_episodio_aberto`;
  - `never suspended` sob o histórico vazio.

  Elas não bloqueiam a release por segurança, mas a regra da casa é que a tela implementada seja
  exatamente a aprovada.
- **O 403 de CSRF** usa a página genérica do `ErrorHTML`, que diz *"Your account is signed in…"*, e
  isso não é verdade para quem não entrou.
- **O `totp_secret` ilegível** faz `autenticar/3` levantar 500 em vez de recusar. A decisão está em
  aberto desde a #1134.
- **A captura das telas** (G.1 e G.2 da conferência): colorida, em cinza e em 360 px. Ainda não foi
  feita.
- **A aceitação em produção do lado autenticado** do operador: depende de uma conta de operador
  concedida em produção, que só a pessoa mantenedora concede.
