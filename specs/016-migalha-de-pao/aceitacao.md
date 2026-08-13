# Aceitação — feature 016, a migalha de pão

**Avaliada em**: 2026-08-13

| # | Requisito | Veredito | Evidência |
|---|---|---|---|
| FR-001 | detalhe tem, raiz não tem | **aceito** | o teste percorre as rotas, não uma amostra |
| FR-002 | último nível não é ligação | **aceito** | `refute` do `<a aria-current="page">` |
| FR-003 | nível sem destino não vira ligação | **aceito** | destino `nil` renderiza `<span>` |
| FR-004 | caminho da issue | **aceito** | o estrutural, pelo repositório dono |
| FR-005 | teclado | **aceito** | `<.link>` gera `<a href>` real |
| FR-006 | leitor de tela | **aceito** | `<nav aria-label>` e `aria-current="page"` |
| FR-007 | os dois botões saem | **aceito** | `refute ">voltar<"` e `refute "back to people"` |
| FR-008 | 360 px preserva o primeiro nível | **aceito em markup** | `truncate max-w` só no último — **olho humano pendente** |
| FR-009 | um componente | **aceito** | `core_components.ex`, quatro telas declarando |
| FR-010 | nenhuma consulta nova | **aceito** | os rótulos já estavam carregados; 542 testes verdes |

| # | Critério | Veredito |
|---|---|---|
| SC-001 | detalhes com, raízes sem | **aceito** |
| SC-002 | três formas viram uma, e `voltar` some | **aceito** |
| SC-003 | nenhum destino inexistente | **aceito** — os destinos são `~p`, verificados em compilação |
| SC-004 | 360 px | **pendente de olho humano** |
| SC-005 | consultas por render | **aceito** |
| SC-006 | mesmo componente nas telas | **aceito** |

## O que ficou pendente, e por quê

**SC-004 exige olhar.** A asserção é sobre a classe que encurta o último nível; se o caminho cabe
em 360 px é pergunta para quem tem a tela. É o quinto item desta família em `RETOMAR.md`, e continua
declarado em vez de contado como cumprido.

## Veredito

**Aceita**, com o item de 360 px declarado como pendente.
