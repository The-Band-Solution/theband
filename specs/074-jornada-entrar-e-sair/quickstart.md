# Quickstart: ver a J1 no SigNoz, localmente e em produção

Guia de **validação**, não de implementação. Os nomes de módulo e arquivo vêm de
[contracts/jornada.md](contracts/jornada.md) e do [plan](plan.md). **Nenhum segredo aparece aqui**:
onde um valor é necessário, o guia diz de onde ele vem.

Todo comando de verificação redireciona a saída para arquivo e lê o código de saída **antes** de
ler o arquivo (AGENTS §4).

## 0. Pré-requisitos

- a ADR 0005 e as dependências aceitas (2026-10-03);
- `development` com o PR #1227 (#1222) mergeado (D6);
- Docker de pé. **Não tocar** no `the_band_postgres` nem na porta 5432.

## 1. Subir o SigNoz local (profile `telemetria`)

```bash
docker compose --profile telemetria up -d > /tmp/signoz-up.log 2>&1; echo "EXIT=$?"
docker compose ps > /tmp/signoz-ps.log 2>&1; echo "EXIT=$?"
```

Esperado: os serviços do profile de pé, com portas **só** em `127.0.0.1` (painel 3301, OTLP 4318).
O `the_band_postgres` continua com o mesmo `CREATED` de antes.

**Conferir que o coletor RECEBE, e não só que subiu** — o defeito medido na ADR (E3) foi um
coletor *healthy* com pipeline `nop`:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X POST -H 'Content-Type: application/json' \
  -d '{"resourceSpans":[]}' http://127.0.0.1:4318/v1/traces > /tmp/otlp.txt 2>&1; echo "EXIT=$?"
cat /tmp/otlp.txt        # 200. Conexão recusada ou resposta vazia = pipeline nop.
```

Abrir `http://127.0.0.1:3301` e criar a conta de administração **local** (não é a de produção).

## 2. Rodar a aplicação apontando para o coletor local

```bash
THE_BAND_OTLP_ENDPOINT=http://127.0.0.1:4318 iex -S mix phx.server
```

Sem a variável, o log diz *"telemetria desligada"* e a aplicação sobe igual (FR-015).

## 3. Produzir a J1 à mão

Em `http://localhost:4000/sign-in`, com as contas do seed de desenvolvimento:

| ação | passo esperado no SigNoz |
|---|---|
| abrir a tela | `the_band.acesso.abrir_a_entrada`, `outcome=concluiu`, `journey.id` presente |
| senha certa | `entrar_com_senha`, `concluiu`, com o **mesmo** `journey.id` |
| senha errada | `entrar_com_senha`, `falhou`, `failure.reason=senha_errada` |
| e-mail que não existe | `falhou`, `identificador_nao_resolveu`, **sem** `user.ref` |
| sair | `sair`, `concluiu` |
| sair de novo com o cookie velho (DevTools → repetir o `DELETE`) | `sessao_derrubada` com `encerrada` **e** `sair` com `sessao_ja_nao_existia` |

E a tela: as três recusas mostraram **a mesma frase**.

No SigNoz, *Traces → filtro `service.name = the_band`*. Conferir, em **cada** span, que a lista
de atributos é a de `contracts/jornada.md` §3 e nenhuma outra.

## 4. Os testes que provam o que a mão não prova

```bash
mix test test/the_band/telemetria/ > /tmp/telemetria.log 2>&1; echo "EXIT=$?"
tail -30 /tmp/telemetria.log
```

| arquivo | prova |
|---|---|
| `test/the_band/telemetria/regua_test.exs` | as 15 linhas de *A régua*, uma por caso, com desfecho e motivo (SC-001) |
| `test/the_band/telemetria/sentinelas_test.exs` | nenhuma sentinela em nenhum span exportado; com o filtro desligado, reprova (SC-002) |
| `test/the_band/telemetria/taxonomia_test.exs` | motivo não declarado reprova; motivo declarado e nunca emitido reprova (FR-007) |
| `test/the_band/telemetria/handler_resiliente_test.exs` | o handler que levanta continua anexado, e a perda é contada (FR-008) |
| `test/the_band/telemetria/tempo_por_motivo_test.exs` | a mediana da emissão não difere entre motivos (FR-009) |
| `test/the_band_web/live/login_test.exs` (já existe) | a recusa continua byte-idêntica (SC-003) |

## 5. Produção — o que a pessoa mantenedora faz no Dokploy 👤

**Variáveis, nunca valores.** Nenhum valor é escrito em lugar nenhum além do painel do Dokploy.

1. **Medir antes** (ADR 0005, E3): `free -m` e `docker stats --no-stream` no VPS, com a aplicação
   e o Postgres de pé. Registrar na tarefa. **Menos de 4 GB disponíveis = não subir aqui.**
2. **Criar o serviço do SigNoz** no Dokploy como *Compose*, a partir do arquivo versionado no
   repositório (gerado por `foundryctl forge`, imagens fixadas). **Sem domínio** no Traefik.
3. **Variável do serviço do SigNoz**: `SIGNOZ_TOKENIZER_JWT_SECRET` — gerar com
   `openssl rand -hex 32` na máquina de quem opera e colar direto no painel.
4. **Abrir o túnel e criar a conta de administração do SigNoz antes de qualquer outra coisa**:
   `ssh -L 3301:<host interno do painel>:8080 <vps>`, e `http://127.0.0.1:3301`. A primeira conta
   criada é a administradora.
5. **Retenção** (*Settings → General → Retention*): traços 7 dias, métricas 30 dias.
6. **Variável da aplicação** (lista fechada do runbook §2, acrescida de uma):
   `THE_BAND_OTLP_ENDPOINT` — o nome do serviço do coletor **na rede dedicada** aplicação↔coletor,
   porta 4318. **Nenhuma `OTEL_*`** no ambiente da aplicação: o SDK as leria por conta própria
   (seguranca.md, S10).
7. **Conferir que nenhuma porta do SigNoz foi publicada — de dentro E de fora** (S6): o compose
   sem chave `ports:`; `ss -ltnp` no VPS sem 8080, 4317, 4318, 8123, 9000 e 2181; **e** uma tentativa
   de conexão a essas portas a partir de **outra máquina**, recusada. Conferir o `ufw` não prova
   nada: porta publicada pelo Docker passa por cima dele.
7a. **Redes** (S7): a aplicação só na rede dedicada com o coletor; ClickHouse, ZooKeeper e painel
   noutra. O coletor com `--config` versionado e **sem OpAMP**. ClickHouse com senha vinda do
   ambiente. Imagens por resumo (`@sha256:`).
7b. **O que sai pelo SigNoz** (S8): telemetria de uso do produto desligada, conferida pelo
   **tráfego de saída** do contêiner; canal do alerta declarado no runbook.
7c. **Retenção real** (S13): o volume do ClickHouse **fora** do backup; depois de oito dias, a
   idade do traço mais antigo conferida por consulta, e não pela tela de configuração.
8. **Medir depois**: `docker stats --no-stream` com o SigNoz ocioso há 5 minutos; o número
   substitui a medida local na ADR 0005, E3.
9. **Aceitação**: entrar com a própria conta e sair; os dois passos aparecem no SigNoz pelo túnel.
