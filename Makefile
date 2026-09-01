# ══════════════════════════════════════════════════════════════════════════════
# The Band — atalhos dos comandos que já existem.
#
# O Makefile NÃO define comportamento: ele nomeia o que `mix`, `docker compose` e
# o quickstart da 050 já fazem. Onde houver divergência, a definição é a de lá —
# `mix gates` é a definição dos gates, e este arquivo só o chama.
#
# Nenhum alvo canaliza a saída de um comando cujo veredito importa: `cmd | tee`
# devolve o código do `tee`, e um gate que reprovou passaria por verde (L60).
# Onde há log, ele é escrito por redirecionamento e o EXIT é anotado depois.
# ══════════════════════════════════════════════════════════════════════════════

SHELL := /bin/bash
.DEFAULT_GOAL := ajuda

PORTA_APP ?= 4001
LOG_GATES ?= /tmp/gates.log
LOG_BUILD ?= /tmp/build_050.log
LOG_SEM_ENV ?= /tmp/run_sem_env.log
IMAGEM ?= theband:dev

.PHONY: ajuda run down setup servidor teste gates gates-log formatar mensagens \
        chave banco-sobe banco-derruba imagem imagem-sem-env producao-sobe \
        producao-derruba producao-logs producao-confere producao-sem-chave \
        ensaio-restauracao limpar

ajuda:
	@echo ""
	@echo "  tudo"
	@echo "    make run                  sobe tudo: banco + aplicação, e espera ficar de pé"
	@echo "    make down                 derruba tudo (os volumes ficam — o dado sobrevive)"
	@echo ""
	@echo "  desenvolvimento"
	@echo "    make setup                instala dependências, cria o banco e monta os assets"
	@echo "    make servidor             sobe o Phoenix em desenvolvimento (localhost:4000)"
	@echo "    make banco-sobe           sobe só o Postgres de desenvolvimento"
	@echo "    make banco-derruba        derruba o Postgres de desenvolvimento"
	@echo ""
	@echo "  qualidade"
	@echo "    make teste                mix test"
	@echo "    make gates                os quality gates — o veredito é o código de saída"
	@echo "    make gates-log            idem, com o log em $(LOG_GATES) e o EXIT na última linha"
	@echo "    make formatar             mix format"
	@echo "    make mensagens            literais fora do catálogo + lacunas de tradução"
	@echo ""
	@echo "  produção (ensaio local da MESMA imagem que o CD publica)"
	@echo "    make imagem               builda a imagem, log em $(LOG_BUILD)"
	@echo "    make imagem-sem-env       A VIOLAÇÃO: sem env o contêiner recusa NOMEANDO"
	@echo "    make producao-sem-chave   A VIOLAÇÃO: sem a chave mestra o compose recusa NOMEANDO"
	@echo "    make producao-sobe        sobe Postgres + aplicação com as env do .env"
	@echo "    make producao-confere     /sign-in 200 e a varredura das rotas sem sessão"
	@echo "    make producao-logs        acompanha o log da aplicação"
	@echo "    make producao-derruba     derruba o ensaio (o banco de dev fica de pé)"
	@echo "    make ensaio-restauracao   backup → restore em banco vazio → números conferidos"
	@echo ""
	@echo "    make chave                gera uma chave mestra nova (NUNCA sobre uma em uso)"
	@echo "    make limpar               remove _build, deps e os logs deste arquivo"
	@echo ""

# ── tudo ──────────────────────────────────────────────────────────────────────

# Sobe o conjunto inteiro e SÓ TERMINA quando a aplicação responde. Um alvo que
# volta antes disso deixa a pessoa achando que subiu, e o erro aparece adiante,
# longe da causa — que é o defeito que este projeto persegue em toda parte.
run:
	docker compose --profile producao up -d --build
	@echo "── esperando a aplicação responder em localhost:$(PORTA_APP)…"
	@tentativas=0; \
	  until [ "$$(curl -s -o /dev/null -w '%{http_code}' localhost:$(PORTA_APP)/sign-in)" = "200" ]; do \
	    tentativas=$$((tentativas+1)); \
	    if [ $$tentativas -ge 60 ]; then \
	      echo "NÃO SUBIU em 120s — o log diz por quê:"; \
	      docker compose --profile producao logs --tail 30 app; \
	      exit 1; \
	    fi; \
	    sleep 2; \
	  done; \
	  echo "── no ar: http://localhost:$(PORTA_APP)  (migrações aplicadas antes do endpoint)"

# Derruba o ensaio E o Postgres de desenvolvimento. Sem `-v`: os volumes ficam, e
# o dado de desenvolvimento sobrevive. Para apagar também o volume do ensaio,
# `docker compose --profile producao down -v` — que é destrutivo, e por isso não
# tem atalho aqui.
down:
	docker compose --profile producao down
	docker compose stop postgres
	@echo "── derrubado. Os volumes ficaram: 'make run' e 'make banco-sobe' voltam com o dado."

# ── desenvolvimento ───────────────────────────────────────────────────────────

setup:
	mix setup

servidor:
	mix phx.server

banco-sobe:
	docker compose up -d postgres

banco-derruba:
	docker compose stop postgres

# ── qualidade ─────────────────────────────────────────────────────────────────

teste:
	mix test

# O veredito é o código de saída deste comando, e nada roda depois dele.
gates:
	mix gates

gates-log:
	@mix gates > $(LOG_GATES) 2>&1; echo "EXIT=$$?" >> $(LOG_GATES); tail -1 $(LOG_GATES)

formatar:
	mix format

mensagens:
	mix mensagens.verificar
	mix mensagens.lacunas

chave:
	@echo "Gera uma chave NOVA. Se já existe uma em uso, trocá-la torna ilegível"
	@echo "toda credencial já cifrada — para trocar de verdade, use mix the_band.rotate_key."
	@echo ""
	mix the_band.gen_key

# ── produção: o ensaio local ──────────────────────────────────────────────────
#
# Os dois primeiros alvos são as VIOLAÇÕES, e vêm antes do caminho feliz de
# propósito: um contêiner que sobe sem as env é o defeito que este ensaio existe
# para pegar.

imagem:
	@docker build -t $(IMAGEM) . > $(LOG_BUILD) 2>&1; echo "EXIT=$$?" >> $(LOG_BUILD); tail -1 $(LOG_BUILD)

imagem-sem-env:
	@docker run --rm $(IMAGEM) > $(LOG_SEM_ENV) 2>&1; echo "EXIT=$$?" >> $(LOG_SEM_ENV); cat $(LOG_SEM_ENV)
	@echo "esperado: a recusa NOMEIA a variável, e o EXIT é diferente de zero"

producao-sem-chave:
	@THE_BAND_MASTER_KEY= docker compose --profile producao config --quiet; \
	  echo "EXIT=$$?  (esperado 1, nomeando THE_BAND_MASTER_KEY)"

producao-sobe:
	docker compose --profile producao up -d --build
	@echo "aplicação em http://localhost:$(PORTA_APP) — 'make producao-confere' mede"

producao-logs:
	docker compose --profile producao logs -f app

producao-derruba:
	docker compose --profile producao down

producao-confere:
	@codigo=$$(curl -s -o /dev/null -w '%{http_code}' localhost:$(PORTA_APP)/sign-in); \
	  echo "/sign-in -> HTTP $$codigo (esperado 200)"
	@echo ""
	@echo "rotas de dados sem sessão (SC-005) — /sign-in e /set-password são públicas:"
	@grep -oE 'live "/[a-z0-9/_-]*"' lib/the_band_web/router.ex | sed 's/live "//;s/"//' | sort -u > /tmp/rotas_050.txt; \
	  total=0; recusa=0; abertas=""; \
	  while IFS= read -r r; do \
	    codigo=$$(curl -s -o /dev/null -w '%{http_code}' "localhost:$(PORTA_APP)$$r"); \
	    total=$$((total+1)); \
	    case "$$codigo" in 302|401|403) recusa=$$((recusa+1));; *) abertas="$$abertas  $$r -> $$codigo";; esac; \
	  done < /tmp/rotas_050.txt; \
	  echo "  rotas live: $$total | recusaram: $$recusa"; \
	  [ -n "$$abertas" ] && echo "  não recusaram:$$abertas" || true

# O ensaio da FR-008/SC-003: a cópia só vale se o número do outro lado bater.
# Usa o Postgres do ensaio como ferramenta (pg_dump/pg_restore), lendo o banco de
# desenvolvimento pelo host.
ensaio-restauracao:
	@docker compose --profile producao up -d postgres_prod
	@echo "── números na origem, ANTES"
	@docker compose --profile producao exec -T -e PGPASSWORD=postgres postgres_prod \
	  psql -h host.docker.internal -U postgres -d the_band_dev -t \
	  -c "select 'eo_people='||(select count(*) from eo_people)||' eo_teams='||(select count(*) from eo_teams)||' eo_organizations='||(select count(*) from eo_organizations);"
	@echo "── backup"
	@docker compose --profile producao exec -T -e PGPASSWORD=postgres postgres_prod \
	  pg_dump -h host.docker.internal -U postgres -Fc -d the_band_dev -f /tmp/dev.dump
	@echo "── restauração num banco VAZIO"
	@docker compose --profile producao exec -T postgres_prod psql -U postgres -q -c 'DROP DATABASE IF EXISTS band_restore;' > /dev/null
	@docker compose --profile producao exec -T postgres_prod psql -U postgres -q -c 'CREATE DATABASE band_restore;' > /dev/null
	@docker compose --profile producao exec -T postgres_prod \
	  pg_restore -U postgres -d band_restore --no-owner --no-privileges /tmp/dev.dump > /dev/null 2>&1 || true
	@echo "── números DEPOIS (têm de bater, um a um)"
	@docker compose --profile producao exec -T postgres_prod \
	  psql -U postgres -d band_restore -t \
	  -c "select 'eo_people='||(select count(*) from eo_people)||' eo_teams='||(select count(*) from eo_teams)||' eo_organizations='||(select count(*) from eo_organizations);"

limpar:
	rm -rf _build deps
	rm -f $(LOG_GATES) $(LOG_BUILD) $(LOG_SEM_ENV) /tmp/rotas_050.txt
