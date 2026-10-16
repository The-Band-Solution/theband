#!/bin/bash
# 200 entradas certas, sequenciais, cada uma com o seu cookie e o seu token; imprime a mediana e o p90 em ms.
# Uso: t030-medir.sh <base, ex.: http://localhost:4074> <arquivo com a senha da conta de teste> <arquivo de saída>
B=$1; S=$(cat $2); out=$3; : > $out
for i in $(seq 1 200); do
  j=$(mktemp); csrf=$(curl -s -c $j -b $j $B/sign-in | grep -o 'name="csrf-token" content="[^"]*"' | sed 's/.*content="//;s/"$//')
  curl -s -o /dev/null -w '%{time_total}\n' -c $j -b $j --data-urlencode "_csrf_token=$csrf" --data-urlencode "identifier=j1-ok@example.test" --data-urlencode "password=$S" $B/session >> $out
  rm -f $j
done
sort -n $out | awk '{a[NR]=$1} END {printf "n=%d mediana=%.1f ms p90=%.1f ms\n", NR, a[int(NR/2)+1]*1000, a[int(NR*0.9)]*1000}'
