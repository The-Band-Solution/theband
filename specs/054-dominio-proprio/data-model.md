# Fase 1 — Modelo de dados: nenhuma entidade nova, e por quê

**Esta feature não cria entidade, tabela, migração nem conceito de ontologia.**
A ausência está escrita aqui porque ausência não declarada é lida como
esquecimento — e no dia em que alguém procurar "onde ficam os endereços", a
resposta precisa existir.

## O que se pensou em modelar, e a razão de não modelar

**"Endereço público declarado"**, com nome, quem declarou, quando, e revogação —
o formato de relator que este projeto usa para toda declaração de tenant.

Não entra, por três razões que se somam:

1. **Não é dado do domínio.** Endereço público é onde a plataforma atende, não
   algo que ela observou sobre uma organização. Nenhuma ontologia da rede tem
   conceito para isso, e inventar um conceito para caber um dado de ambiente é o
   caminho de volta: contamina a rede com o que não é observação.
2. **O FR-006 exige mudar sem release.** Uma tabela exigiria migração para
   nascer; e para mudar sem release exigiria tela, permissão e cuidado de tenant
   — três coisas novas para um valor que quem opera já escreve no painel de quem
   hospeda.
3. **O escopo é a instalação inteira, não o tenant.** A aceitação de origem
   acontece antes de existir sessão, logo antes de existir tenant. Um dado com
   escopo de instalação numa base multitenant é uma exceção à regra do princípio
   V, e exceção sem necessidade é dívida.

## Onde o dado vive, então

Em **variável de ambiente**, lida uma vez no boot:

| Nome | Conteúdo | Quem escreve |
|---|---|---|
| `PHX_HOST` | o endereço que a plataforma usa para **gerar links** | quem opera, no painel |
| `THE_BAND_ORIGENS_EXTRAS` | os **outros** endereços por onde as pessoas chegam, separados por vírgula | quem opera, no painel |

A separação entre os dois é o requisito FR-004, e é a causa raiz da P1 da 050:
hoje o segundo valor não existe, e o primeiro faz os dois papéis.

## O que muda se um dia isto virar dado

Se a administração de endereços pela interface passar a ter demanda real — e não
a previsão de que teria —, o lugar da mudança é este arquivo, e o formato é o
relator com autor e revogação, como em toda declaração deste projeto. Registrado
aqui para que a decisão futura não recomece do zero.
