# Evidência da #1162 — a distribuição Erlang só no loopback, com o cookie por contêiner

Medido em 2026-10-02 na imagem construída deste branch (`docker build`, `BUILD_EXIT=0`). Havia um
contêiner vizinho na mesma rede Docker (`m1162net`) e uma base descartável, todos apagados
depois.

| cenário | resultado |
|---|---|
| portas em escuta (`/proc/net/tcp`, estado `0A`) | epmd `0100007F:1111` (127.0.0.1:4369) e a distribuição `0100007F:…` (127.0.0.1); em IPv6, o epmd só em `::1`. A única porta em todas as interfaces é a 4000, do Phoenix |
| o vizinho na rede Docker | `nc -z <ip> 4369` dá **fechada**; o controle, a porta 4000, dá aberta |
| o cookie | `/run/the_band/cookie`, `-r--r----- root band`, novo a cada start; `/app/releases/COOKIE` **não existe** na imagem |
| o `rpc` como root | responde `the_band@127.0.0.1`, como `band` (a guarda A1 da #1140 continua) |
| o HEALTHCHECK | `/app/bin/saude` responde `ok` |
| **defeito injetado:** sem `inet_dist_use_interface` no `vm.args` | a distribuição passou a `00000000:B55F` (0.0.0.0), e o vizinho a **alcançou**. Restaurado, voltou ao `127.0.0.1` |
| B1: o `rpc` sem o arquivo do cookie | `RECUSADO: /run/the_band/cookie ausente ou ilegível (#1162)`, sem voltar ao cookie da imagem |
| o `eval` sem o arquivo | funciona, com `Node.alive?` igual a `false`: não abre distribuição |

Não medidos aqui:
- a topologia da rede do Dokploy no VPS (um `network_mode: host` faria o loopback ser o do host);
- a distribuição em IPv6 a partir do vizinho;
- os comandos `restart`, `stop` e `daemon`.
