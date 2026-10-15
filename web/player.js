/* Loader for the original Lua game, not a JavaScript reimplementation. */
var gameCanvas = document.getElementById("canvas");
var gameIsReady = false;

function showLoadError(message) {
  document.getElementById("loading").hidden = false;
  document.getElementById("status").textContent = "Unable to start the game";
  document.getElementById("loading-hint").textContent = String(message);
  document.getElementById("retry").hidden = false;
}

var Module = {
  arguments: ["./game.love"],
  INITIAL_MEMORY: 67108864,
  canvas: gameCanvas,
  totalDependencies: 0,
  remainingDependencies: 0,
  print: function (text) { console.log(text); },
  printErr: function (text) { console.error(text); },
  setStatus: function (text) {
    if (text) {
      document.getElementById("status").textContent = text;
    } else if (Module.remainingDependencies === 0) {
      gameIsReady = true;
      document.getElementById("loading").hidden = true;
    }
  },
  monitorRunDependencies: function (left) {
    this.remainingDependencies = left;
    this.totalDependencies = Math.max(this.totalDependencies, left);
    Module.setStatus(left ? "Preparing the game…" : "Starting Neon Runner…");
  },
  onAbort: function (reason) { showLoadError(reason || "Reload the page and try again."); }
};

function startLove() {
  try {
    var started = Love(Module);
    if (started && typeof started.catch === "function") started.catch(showLoadError);
  } catch (error) {
    showLoadError(error.message || error);
  }
}

gameCanvas.addEventListener("click", function () { gameCanvas.focus(); });
gameCanvas.addEventListener("contextmenu", function (event) { event.preventDefault(); });
gameCanvas.addEventListener("webglcontextlost", function (event) {
  event.preventDefault();
  showLoadError("The graphics context was lost. Reload to start a new run.");
});
document.getElementById("retry").addEventListener("click", function () { location.reload(); });
document.getElementById("fullscreen").addEventListener("click", function () {
  var request = gameCanvas.requestFullscreen || gameCanvas.webkitRequestFullscreen;
  if (!request) return;
  var result = request.call(gameCanvas);
  if (result && typeof result.catch === "function") result.catch(console.warn);
  gameCanvas.focus();
});
window.addEventListener("keydown", function (event) {
  if (event.code === "F5") {
    event.preventDefault();
    event.stopImmediatePropagation();
    location.reload();
    return;
  }
  if (gameIsReady && ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Space"].indexOf(event.code) !== -1) {
    event.preventDefault();
  }
}, true);
window.addEventListener("error", function (event) {
  if (event.message && event.message.indexOf("unwind") === -1) showLoadError(event.message);
});
window.addEventListener("unhandledrejection", function (event) {
  showLoadError(event.reason && event.reason.message || event.reason || "Loading failed.");
});
