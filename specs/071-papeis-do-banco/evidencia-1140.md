# Evidência da #1140 — a credencial que migra em arquivo só de root

Medido em 2026-10-02, na imagem construída deste branch (`docker build`, `BUILD_EXIT=0`), contra uma
base e dois papéis descartáveis no Postgres local. As senhas foram geradas na hora e eram
**diferentes** entre o dono e quem serve: com a mesma senha, a varredura casava com o `DATABASE_URL`
legítimo, e uma primeira medição saiu errada por isso.

A credencial foi montada como num File Mount do Dokploy: um volume com o arquivo `0400` de root, em
`/run/secrets/database_migration_url`, somente leitura. Os cenários são os de `seguranca-1140.md`.
Depois de medir, a base, os papéis, os contêineres e os volumes foram apagados, e a contagem de
cada um deu 0.

| # | cenário | resultado |
|---|---|---|
| T11 | funcionalidade | migrou, `papéis: privilégios de quem serve concedidos`, boot com `separação em vigor`; `conferir_papeis()` por `rpc` como root respondeu `em vigor` |
| T8 | o PID 1 depois do `exec` | `Uid 1000`, `CapEff` e `CapBnd` = 0, `NoNewPrivs` = 1, `HOME=/home/band`; `DATABASE_MIGRATION_URL` 0 vezes e `DATABASE_URL` 1 vez no `environ` (a guarda de que mediu) |
| T1 | código como `band` varre `/proc` e o disco atrás da senha do dono | **0** em `/proc` (13 arquivos legíveis) e 0 em arquivos. Controle positivo: a senha de quem serve, que está no ambiente, aparece 6 vezes. O padrão vai pela entrada padrão: pela linha de comando, o medidor se achava a si mesmo (1 ocorrência falsa) |
| T2 | `band` lê o arquivo montado | não lê; root lê, e não está vazio |
| T3 | o arquivo legível por `band` na subida | **não sobe** (`exit=1`), com `chown: … Read-only file system`, e 0 ocorrências da credencial no log |
| T4 | **A1**: o nó que serve, armado, executa código no nó do `rpc` que o root abre | com a guarda de `rel/env.sh.eex`: `uid 1000`, `NAO_LEU`. **Com a guarda retirada** (o defeito injetado): `uid 0`, `LEU`. Com a guarda restaurada: `uid 1000`, `NAO_LEU` |
| T5 | o HEALTHCHECK | `CMD-SHELL /app/bin/saude | grep -qx ok`; `/app/bin/saude` respondeu `ok`, com o `rpc` como `band` |
| T7 | `/app` como persistência para o próximo start root | `find /app -writable`, como `band`, dá 0; `touch /app/entrypoint.sh` é negado; `/tmp` continua gravável |
| T10 | `docker inspect` no modo arquivo | 0 ocorrências do usuário dono |
| T12 | capacidades mínimas | subiu e ficou `em vigor` com `--cap-drop ALL --cap-add SETUID --cap-add SETGID --cap-add CHOWN --cap-add FOWNER --security-opt no-new-privileges` |

Não medidos aqui: T6 (o modo variável em laço), T9 (o crash dump) e o comportamento real do
Dokploy (o File Mount, com que dono e modo chega, e quem entra no terminal).
