// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/the_band"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// ─────────────────────────────────────────────────────────────────────────────
// `the_band:copy` — o ouvinte que faltava.
//
// A tela de tokens despacha este evento desde a v0.8.0, e NINGUÉM o escutava: o
// `JS.dispatch` tinha exatamente uma ocorrência no repositório, a que dispara. O botão
// `Copy value` existia, não dava erro, e não copiava nada.
//
// É o pior lugar possível para um sucesso silencioso. O valor do token é mostrado UMA vez,
// a própria tela diz que ele não volta, e quem clica e sai perde a credencial que acabou
// de gerar — sem nunca ver um erro.
//
// Por isso este ouvinte **reporta as duas saídas**, e a que importa é a falha: a área de
// transferência recusa em contexto inseguro (http sem TLS) e recusa sem permissão. Quando
// recusa, a mensagem manda selecionar o valor à mão — e o valor tem `select-all`, então um
// clique o seleciona inteiro.
window.addEventListener("the_band:copy", event => {
  const texto = event.detail && event.detail.text
  const onde = event.target.querySelector("[data-copy-status]")

  const dizer = (mensagem, classe) => {
    if (!onde) return
    onde.textContent = mensagem
    onde.className = `self-center text-xs ${classe}`
  }

  const naoDeu = () =>
    dizer("could not copy — select the value above and copy it by hand", "text-error")

  if (!texto) return naoDeu()

  // Sem `navigator.clipboard` não há o que tentar: ele não existe fora de contexto seguro.
  if (!navigator.clipboard || !navigator.clipboard.writeText) return naoDeu()

  navigator.clipboard.writeText(texto).then(
    () => dizer("copied — paste it into your secret manager now", "text-success"),
    () => naoDeu()
  )
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

