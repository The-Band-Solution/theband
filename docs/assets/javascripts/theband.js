/* O comportamento do tema que o CSS sozinho não faz (075).
 *
 * Uma coisa só: tabela com mais de três colunas ganha o nome da coluna em
 * cada célula (data-label), para empilhar no telefone (M8). Sem este script, a
 * tabela continua rolando dentro do próprio quadro, que é o comportamento seguro.
 * O diagrama sem Mermaid é tratado em overrides/main.html, onde o Material o pede.
 */
(function () {
  "use strict";

  function rotularTabelas(raiz) {
    var tabelas = raiz.querySelectorAll(".md-typeset table");
    for (var i = 0; i < tabelas.length; i++) {
      var t = tabelas[i];
      var cabecalhos = t.querySelectorAll("thead th");
      if (cabecalhos.length <= 3 || t.hasAttribute("data-tb-empilha")) continue;
      var nomes = [];
      for (var c = 0; c < cabecalhos.length; c++) nomes.push(cabecalhos[c].textContent.trim());
      var linhas = t.querySelectorAll("tbody tr");
      for (var l = 0; l < linhas.length; l++) {
        var celulas = linhas[l].children;
        for (var k = 0; k < celulas.length && k < nomes.length; k++) {
          celulas[k].setAttribute("data-label", nomes[k]);
        }
      }
      t.setAttribute("data-tb-empilha", "");
    }
  }

  function aplicar() {
    var raiz = document.querySelector(".md-content") || document;
    rotularTabelas(raiz);
  }

  // Com `navigation.instant`, o Material troca o conteúdo sem recarregar a página;
  // `document$` avisa a cada troca.
  if (window.document$ && typeof window.document$.subscribe === "function") {
    window.document$.subscribe(aplicar);
  } else if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", aplicar);
  } else {
    aplicar();
  }
})();
