import { svelte } from '@sveltejs/vite-plugin-svelte';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [svelte()],
  server: {
    port: 5173,
  },
  // 'browser' condition: without it, Vitest resolves svelte's server-only build (mount()
  // isn't available there), even though tests run against a browser-like (jsdom) DOM.
  resolve: {
    conditions: ['browser'],
  },
  test: {
    // jsdom, not happy-dom: happy-dom doesn't implement the `:checked` CSS pseudo-selector
    // for <option> elements, which Svelte 5's bind:value on <select> depends on internally
    // — under happy-dom, changing a <select>'s value in a test silently never updates the
    // bound state.
    environment: 'jsdom',
    globals: false,
    setupFiles: ['./src/test-setup.ts'],
  },
});
