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
    Module.setStatus(left ? "Preparing cyber engine…" : "Starting Neon Runner…");
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

// Auto-resume Web Audio context on user gesture
function unlockAudio() {
  if (Module && Module.SDL2 && Module.SDL2.audioContext && Module.SDL2.audioContext.state === "suspended") {
    Module.SDL2.audioContext.resume().catch(function () {});
  }
}
["click", "touchstart", "keydown"].forEach(function (evt) {
  window.addEventListener(evt, unlockAudio, { passive: true });
});

/* Mobile On-Screen Arrow and Action Controls */
(function setupMobileControls() {
  var controls = document.getElementById("mobile-controls");
  var toggleBtn = document.getElementById("toggle-controls");
  var soundBtn = document.getElementById("btn-sound");
  var isMuted = false;
  if (!controls) return;

  function dispatchVirtualKey(type, code, key, keyCode) {
    var event;
    var eventInit = {
      key: key,
      code: code,
      keyCode: keyCode,
      which: keyCode,
      bubbles: true,
      cancelable: true,
      composed: true,
      view: window
    };
    try {
      event = new KeyboardEvent(type, eventInit);
    } catch (_) {
      event = document.createEvent("Event");
      event.initEvent(type, true, true);
      event.key = key;
      event.code = code;
      event.keyCode = keyCode;
      event.which = keyCode;
    }

    if (gameCanvas) {
      try { gameCanvas.focus(); } catch (_) {}
      gameCanvas.dispatchEvent(event);
    }
    window.dispatchEvent(event);
    document.dispatchEvent(event);
  }

  if (soundBtn) {
    soundBtn.addEventListener("click", function () {
      isMuted = !isMuted;
      soundBtn.textContent = isMuted ? "MUTED 🔇" : "SOUND 🔊";
      soundBtn.setAttribute("aria-pressed", (!isMuted).toString());
      dispatchVirtualKey("keydown", "KeyM", "m", 77);
      setTimeout(function () {
        dispatchVirtualKey("keyup", "KeyM", "m", 77);
      }, 50);
      unlockAudio();
      if (gameCanvas) {
        try { gameCanvas.focus(); } catch (_) {}
      }
    });
  }

  if (toggleBtn) {
    toggleBtn.addEventListener("click", function () {
      var isHidden = controls.classList.toggle("is-hidden");
      toggleBtn.setAttribute("aria-pressed", (!isHidden).toString());
      if (gameCanvas) {
        try { gameCanvas.focus(); } catch (_) {}
      }
    });
  }

  function bindTouchButton(button) {
    var key = button.getAttribute("data-key");
    var code = button.getAttribute("data-code");
    var keyCode = parseInt(button.getAttribute("data-keycode"), 10) || 0;
    var pressed = false;

    function handlePress(e) {
      if (e) {
        if (e.cancelable) e.preventDefault();
        e.stopPropagation();
      }
      if (pressed) return;
      pressed = true;
      button.classList.add("is-active");

      unlockAudio();
      if (navigator.vibrate) {
        try { navigator.vibrate(12); } catch (_) {}
      }

      dispatchVirtualKey("keydown", code, key, keyCode);
    }

    function handleRelease(e) {
      if (e) {
        if (e.cancelable) e.preventDefault();
        e.stopPropagation();
      }
      if (!pressed) return;
      pressed = false;
      button.classList.remove("is-active");

      dispatchVirtualKey("keyup", code, key, keyCode);
    }

    // Touch events for mobile
    button.addEventListener("touchstart", handlePress, { passive: false });
    button.addEventListener("touchend", handleRelease, { passive: false });
    button.addEventListener("touchcancel", handleRelease, { passive: false });

    // Mouse events for testing on desktop
    button.addEventListener("mousedown", handlePress);
    button.addEventListener("mouseup", handleRelease);
    button.addEventListener("mouseleave", handleRelease);
  }

  var buttons = controls.querySelectorAll("[data-code]");
  for (var i = 0; i < buttons.length; i++) {
    bindTouchButton(buttons[i]);
  }
})();
