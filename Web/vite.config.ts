import { defineConfig } from "vite";
import swiftWasm from "@elementary-swift/vite-plugin-swift-wasm";

export default defineConfig({
  plugins: [
    swiftWasm({
      // The FuelingWeb executable in this package's Package.swift.
      product: "FuelingWeb",
      // Non-embedded: the reused FuelingModel/CoreModel/FuelingAPI graph needs
      // full Foundation, so build with the standard `swift-6.3.3-RELEASE_wasm`
      // SDK rather than the embedded one.
      useEmbeddedSDK: false,
    }),
  ],
  server: {
    // Proxy API calls to the local test server (Scripts/test-server.py) so the
    // browser hits same-origin `/v1/...` instead of tripping CORS.
    proxy: {
      "/v1": "http://localhost:8080",
    },
  },
});
