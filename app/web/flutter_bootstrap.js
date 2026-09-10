{{flutter_js}}
{{flutter_build_config}}

// Force the 'full' CanvasKit variant so the loader serves it directly from
// /canvaskit/canvaskit.{js,wasm} (local, vendored) instead of fetching the
// chromium variant from the gstatic CDN.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "/canvaskit/",
    canvasKitVariant: "full",
  },
});