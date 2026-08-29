# Data model — 047 Mensagens internacionalizadas

Nenhuma entidade de banco. O "modelo" desta feature são arquivos de catálogo:

```text
priv/gettext/
├── errors.pot                      # template extraído (mecanismo nativo)
├── sistema.pot
├── en/LC_MESSAGES/
│   ├── errors.po                   # idioma padrão: msgstr pode ficar vazio
│   └── sistema.po                  #   (msgid JÁ É a frase en — research R2/R5)
└── pt/LC_MESSAGES/
    ├── errors.po                   # segundo idioma: lacunas visíveis (FR-006)
    └── sistema.po
```

Regras de integridade (valem como validação, provadas por teste):

- msgid nunca vazio, nunca com `#{}` (interpolação Elixir) — placeholder é `%{nome}`;
- comentário de decisão (`#.`) preservado pela extração (`mix gettext.extract --merge`);
- pendências de tela vivem em `specs/047-mensagens-internacionalizadas/pendencias.md`,
  uma linha por tela com contagem medida — documento de backlog, não allowlist de gate.
