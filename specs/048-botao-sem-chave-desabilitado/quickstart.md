# Quickstart — validar a 048

Pré: dev server no ar; tenant de dev SEM `API_KEY` no ambiente para os cenários de
lacuna (subir o server sem a variável) e com credencial gravável em AI provider.

## 1. O botão diz antes do clique (US1 cenários 1–2)

Sem chave (nem tenant, nem ambiente): abrir a página de uma pessoa com perfil —
"Generate again" `disabled` com a frase; abrir a geração mensal — "Run now"/"Turn
on" `disabled` com a frase. Esperado: nenhum clique possível; frase presente ao
lado de cada botão.

## 2. A frase se adapta a quem lê (US1 cenário 5)

Logar como quem opera (admin) → a frase nomeia AI provider. Logar como member sem
concessão → a frase diz que quem opera configura, sem link. Esperado: duas frases
diferentes, mesmo estado.

## 3. Configurar habilita sem passo extra (US1 cenário 3 / SC-002)

Gravar a chave em AI provider; voltar às duas telas. Esperado: botões habilitados,
frase da lacuna ausente.

## 4. A defesa é do domínio (US1 cenário 4 / SC-003)

```bash
MIX_ENV=test mix test test/the_band/profiles_test.exs
```

Esperado: o teste da violação — `Profiles.request/3` sem chave devolve
`{:error, :sem_chave}` e a fila Oban fica vazia. E o teste do run screen
inalterado: a recusa nomeada de hoje continua.

## 5. Assimetria dos caminhos (research R2)

Com `API_KEY` só no ambiente (sem credencial do tenant): página da pessoa
HABILITADA (dev roda assim); geração mensal DESABILITADA (tenant-only, FR-011 da
044). Esperado: exatamente essa assimetria, com as duas frases dizendo o porquê.
