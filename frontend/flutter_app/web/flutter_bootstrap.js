{{flutter_js}}
{{flutter_build_config}}

(function () {
  const flutterViewSelector = "flt-glass-pane, flutter-view, flt-scene-host";

  if (location.hostname === "localhost" && "serviceWorker" in navigator) {
    navigator.serviceWorker.getRegistrations().then(function (registrations) {
      registrations.forEach(function (registration) {
        registration.unregister();
      });
    });
  }

  function hasFlutterView() {
    return !!document.querySelector(flutterViewSelector);
  }

  async function startEntrypoint(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  }

  _flutter.loader.load({
    onEntrypointLoaded: async function (engineInitializer) {
      try {
        await startEntrypoint(engineInitializer);
      } catch (error) {
        console.error("Error iniciando Flutter:", error);
      }
    },
  });

  function startLegacyFallbackLoop() {
    let attempts = 0;
    const maxAttempts = 60;
    const timer = window.setInterval(function () {
      attempts += 1;

      if (hasFlutterView()) {
        window.clearInterval(timer);
        return;
      }

      if (typeof window.$dartRunMain !== "function") {
        if (attempts >= maxAttempts) {
          window.clearInterval(timer);
        }
        return;
      }

      try {
        window.$dartRunMain();
      } catch (_) {
      }

      if (hasFlutterView() || attempts >= maxAttempts) {
        window.clearInterval(timer);
      }
    }, 1500);
  }

  if (document.readyState === "complete") {
    window.setTimeout(startLegacyFallbackLoop, 600);
  } else {
    window.addEventListener("load", function () {
      window.setTimeout(startLegacyFallbackLoop, 600);
    });
  }
})();
