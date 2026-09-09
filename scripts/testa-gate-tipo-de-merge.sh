#!/bin/bash
# Extrai o script do workflow e roda os casos. O gate tem de REPROVAR o que deve.
rodar() {
  export CORPO="$1" BASE="$2" TITULO="$3"
  bash -c "$(python3 - <<'PY'
import yaml,io
d=yaml.safe_load(io.open('.github/workflows/pr-tipo-de-merge.yml',encoding='utf-8'))
print(d['jobs']['declarado']['steps'][0]['run'])
PY
)" >/tmp/saida.txt 2>&1
  echo "$?"
}

t() { # nome, esperado, corpo, base, titulo
  got=$(rodar "$3" "${4:-development}" "${5:-feat: algo}")
  if [ "$got" = "$2" ]; then echo "  ✓ $1 (saída $got)"; else echo "  ✗ $1 — esperava $2, deu $got"; grep -o 'title=[^:]*' /tmp/saida.txt | head -1; fi
}

echo "DEVE REPROVAR:"
t "corpo sem declaração" 1 "## O que muda

Uma coisa qualquer."
t "as duas marcadas" 1 "- [x] **Squash** — a
- [x] **Merge commit** — b

**Motivo:** sei lá"
t "marcada sem motivo" 1 "- [x] **Squash** — a branch morre no merge"
t "motivo só com o comentário do template" 1 "- [x] **Squash** — a

**Motivo:** <!-- ex.: alguma coisa -->"
t "squash num PR para main" 1 "- [x] **Squash** — a

**Motivo:** release" "main" "release: v0.7.0"
t "squash num back-merge" 1 "- [x] **Squash** — a

**Motivo:** volta" "development" "chore: back-merge da v0.6.0"

echo "DEVE APROVAR:"
t "squash com motivo" 0 "- [x] **Squash** — a branch morre no merge

**Motivo:** ninguém ramifica dela"
t "merge commit com motivo" 0 "- [ ] **Squash**
- [x] **Merge commit** — alguém depende do histórico

**Motivo:** branch empilhada sobre a #758"
t "merge commit para main" 0 "- [x] **Merge commit** — release

**Motivo:** release para main" "main" "release: v0.7.0"
t "forma livre" 0 "**Tipo de merge:** squash

**Motivo:** feature simples"
