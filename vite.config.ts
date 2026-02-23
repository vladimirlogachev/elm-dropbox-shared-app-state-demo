import { defineConfig } from "vite";
import path from "node:path";
import elmPlugin from "vite-plugin-elm";

// --------- User-adjustable

const host = "0.0.0.0"; // "0.0.0.0" = Allow clients from local network

const elmDevSettings = {
  debug: false, // true = enable Elm debugger and show debugger UI
  optimize: false,
  nodeElmCompilerOptions: {},
};

// --------- App-specific

const port = 7000;

// --------- Build version

const buildVersion = process.env.CI
  ? new Date()
      .toISOString()
      .replace("T", " ")
      .replace(/\.\d{3}Z$/, " UTC")
  : "local";

// --------- Common

export default defineConfig(({ command }) => {
  const elmProdSettings = {
    debug: false,
    optimize: true,
    nodeElmCompilerOptions: {},
  };
  const elmSettings = command === "build" ? elmProdSettings : elmDevSettings;

  return {
    plugins: [elmPlugin(elmSettings)],
    server: {
      host,
      port,
      strictPort: true,
    },
    build: {
      rollupOptions: {
        input: {
          main: path.resolve(__dirname, "index.html"),
          error: path.resolve(__dirname, "404.html"),
        },
      },
    },
    preview: { host, port, strictPort: true },
    define: {
      __BUILD_VERSION__: JSON.stringify(buildVersion),
    },
  };
});
