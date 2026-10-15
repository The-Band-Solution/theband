# O que fazer no servidor — o roteiro de 2026-10-15

**Para quem:** a pessoa mantenedora, no VPS e no painel do Dokploy.
**Para quê:** juntar num lugar só, em ordem, tudo o que a plataforma espera de um ato em
produção. Cada item aponta o procedimento detalhado que já existe; este documento não o repete.

**Ordem:** segurança primeiro (AGENTS.md §14.0), depois a aceitação das features, depois a
observabilidade.

**Regras de sempre:** nenhuma senha, token ou valor de variável sai do servidor, nem para chat,
issue, commit ou log. O que volta para as issues são **linhas de log e contagens**, nunca
valores. E `docker inspect` só com `--format`, porque a saída completa mostra o ambiente.

---

## 1. A porta 4000 está publicada no VPS? — 5 minutos · segurança

**Por quê:** atrás do Traefik, os avisos do `bandit` (EEF-CVE-2026-105659 e 105660, mitigados no
#1434) e o forjamento de `X-Forwarded-Proto` só são alcançáveis se a aplicação aceitar conexão
direto na 4000.

**O que fazer:** no terminal do VPS,

```bash
docker ps --format '{{.Names}}\t{{.Ports}}' | grep -i band
```

- se a coluna de portas tiver `0.0.0.0:4000->4000` (ou `:::4000`), **a porta está publicada:
  feche-a** no Dokploy, na aplicação, em *Advanced → Ports*, removendo o mapeamento. O tráfego
  continua pelo Traefik;
- se aparecer só `4000/tcp`, sem `->`, ela **não** está publicada.

**O que me mandar:** a linha, sem mais nada. Ela fecha o item 7 do runbook §15.2.

---

## 2. Separar os papéis do banco (#1131, #1140) — 30 a 40 minutos · segurança

**Por quê:** a aplicação conecta ao banco como **superusuário**, e por isso consegue desligar as
próprias guardas (os triggers somente-acréscimo, as `CHECK`, as FKs). O log da v0.12.0 mediu isso
em produção.

**O que fazer:** como ninguém usa a plataforma, recrie a base já com os papéis separados.
**[recriar-o-banco-com-papeis-separados.md](recriar-o-banco-com-papeis-separados.md)**, passos 1 a
7. O procedimento foi ensaiado localmente: as 116 migrações rodaram com o dono, e o resultado foi
`papéis: separação em vigor`. A base antiga fica intacta até a conferência, e é o caminho de volta.

**O que me mandar:**

- a linha `papéis: separação em vigor` do passo 5, que fecha a #1131;
- a confirmação de que o File Mount `/run/secrets/database_migration_url` existe e a variável
  `DATABASE_MIGRATION_URL` não existe, que fecha a #1140.

**Junto, no passo 7:** girar a senha do `postgres` e confirmar que o backup agendado continua
rodando.

---

## 3. A distribuição Erlang só no loopback (#1162) — 5 minutos · segurança

**Por quê:** o `epmd` (porta 4369) e a porta de distribuição escutavam em todas as interfaces do
contêiner, com o cookie dentro da imagem. O conserto foi para o ar; falta a evidência de
produção.

**O que fazer:** no Dokploy → a aplicação → *Terminal*,

```bash
for f in /proc/net/tcp /proc/net/tcp6; do awk 'NR>1 && $4=="0A" {print FILENAME, $2}' $f; done
```

O comando lista os endereços **escutando**. A porta vem depois dos dois-pontos, em hexadecimal:
`1111` é a 4369 (o `epmd`), e `0FA0` é a 4000 (a aplicação). A 4000 em todas as interfaces é
esperada, porque é ela que o Traefik alcança. Para **qualquer outra porta**, o endereço antes dos
dois-pontos diz onde ela escuta:

- `0100007F` (ou, no `tcp6`, `…0000000001000000`) é o loopback, o **esperado**;
- `00000000` (ou só zeros no `tcp6`) é todas as interfaces: a #1162 **não** está consertada em
  produção.

**O que me mandar:** as linhas que o comando imprimir. São endereços em hexadecimal, sem segredo.

---

## 4. Anotar o vencimento da credencial do ghcr — 1 minuto

**Por quê:** a credencial `read:packages` do registry venceu entre a v0.11.0 e a v0.12.0, e o
primeiro deploy da v0.12.0 falhou com `denied` (nota da v0.12.0, *O que se observou depois*).

**O que fazer:** no GitHub, em *Settings → Developer settings → Personal access tokens*, veja a
data de vencimento do token usado no Dokploy e **anote-a no seu calendário**, uma semana antes.

**O que me mandar:** nada. A data não é segredo, mas também não precisa vir.

---

## 5. Medir o Traefik e ligar o limite por origem (#1063, #1407) — 30 minutos · segurança

**Por quê:** o limite de tentativas por origem (077) foi para o ar **desligado**. Ligá-lo exige
saber o que o Traefik escreve no `X-Forwarded-For`.

**O que fazer:**

- **a medição**, no [runbook §15.2](runbook.md#152-a-medição-1063--pessoa-mantenedora): um eco
  temporário (`traefik/whoami`) num domínio `sslip.io`, os `curl` com cabeçalhos de teste, e
  depois derrubar o eco;
- **depois**, com o resultado, eu preparo os valores de `THE_BAND_ORIGEM*` para o
  [§15.3](runbook.md#153-ligar-o-estado-proxy---depois-da-1063-077t012-1407).

**O que me mandar:** o registro da #1063, como o §15.2 descreve (sobrescreve ou acrescenta, a
sub-rede e se há Cloudflare), só com endereços de documentação.

---

## 6. Aceitar a análise de rede (076, T054 — #1379) — 20 minutos · aceitação

**Por quê:** a 076 está no ar desde a v0.12.0, e falta a sua conferência contra a origem.

**O que fazer:** a folha está na #1379.

1. Abra *Network analysis* em `https://app.theband.dev`.
2. Conte à mão, no GitHub, os números da janela de 90 dias.
3. Compare com a tela.
4. Cronometre a pergunta *"quais grupos se formam e quem os liga?"*.

**O que me mandar:** os números dos dois lados e o tempo. Com isso eu fecho as US1–US9 e o épico
#1309.

---

## 7. Subir o SigNoz em produção (074, T024–T028) — 1 a 2 horas · observabilidade

**Por quê:** o painel e o alerta da entrada (US5) estão prontos e conferidos localmente (sprint
044). Eles só se aceitam em produção.

**O que fazer:** o [quickstart da 074, §5](../../specs/074-jornada-entrar-e-sair/quickstart.md),
nesta ordem:

1. **medir o VPS** (`free -m`, `docker stats --no-stream`, T024). Com menos de 4 GB disponíveis, o
   SigNoz não cabe no mesmo VPS (ADR 0005, E3);
2. a **#1162** fechada, que é o item 3 deste roteiro (T025);
3. **subir o SigNoz** no Dokploy, sem domínio e acessado por túnel SSH (T026);
4. **ligar a aplicação ao coletor** com `THE_BAND_OTLP_ENDPOINT` (T027);
5. **importar** `deploy/signoz/paineis/entrar-e-sair.json` e
   `deploy/signoz/alertas/enumeracao.json`, e definir o canal do alerta;
6. **medir depois** (T028).

**O que me mandar:** a saída da sonda de portas de fora do VPS (T026) e a confirmação de que entrar
e sair aparecem no painel pelo túnel (T027).

---

## 8. Antes do primeiro operador da plataforma — 1 minuto

**O que fazer:** no VPS, `timedatectl`. Deve aparecer `System clock synchronized: yes`
([runbook §13.1](runbook.md#131-antes-da-primeira-concessão-o-relógio-do-servidor)). Só é
necessário antes de conceder o papel de operador a alguém.

---

## Resumo

| # | o quê | tempo | fecha |
|---|---|---|---|
| 1 | porta 4000 | 5 min | runbook §15.2 item 7 |
| 2 | papéis do banco | 30–40 min | #1131, #1140 |
| 3 | distribuição Erlang | 5 min | #1162 |
| 4 | vencimento do ghcr | 1 min | — |
| 5 | Traefik e limite por origem | 30 min | #1063, depois #1407, #1229 |
| 6 | aceitar a 076 | 20 min | #1379, US1–US9, #1309 |
| 7 | SigNoz em produção | 1–2 h | #1258–#1262, US4 #1233, US5 #1234 |
| 8 | relógio | 1 min | antes do primeiro operador |
