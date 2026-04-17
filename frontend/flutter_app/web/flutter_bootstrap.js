{{flutter_js}}
{{flutter_build_config}}

(function () {
  if (window.__REUMA_FLUTTER_BOOTSTRAP_STARTED__) {
    return;
  }
  window.__REUMA_FLUTTER_BOOTSTRAP_STARTED__ = true;

  async function prepareBrowserForLocalDebug() {
    if (location.hostname !== "localhost" || !("serviceWorker" in navigator)) {
      return;
    }

    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(
      registrations.map(function (registration) {
        return registration.unregister();
      })
    );
  }

  async function startEntrypoint(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  }

  prepareBrowserForLocalDebug()
    .catch(function (error) {
      console.warn("No fue posible limpiar service workers locales:", error);
    })
    .finally(function () {
      _flutter.loader.load({
        onEntrypointLoaded: async function (engineInitializer) {
          try {
            await startEntrypoint(engineInitializer);
          } catch (error) {
            console.error("Error iniciando Flutter:", error);
          }
        },
      });
    });
})();
