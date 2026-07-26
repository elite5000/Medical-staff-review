import js from '@eslint/js';
import tseslint from 'typescript-eslint';
import svelte from 'eslint-plugin-svelte';
import playwright from 'eslint-plugin-playwright';
import prettierConfig from 'eslint-config-prettier';
import globals from 'globals';

export default tseslint.config(
  {
    ignores: [
      '**/node_modules/**',
      '**/dist/**',
      '**/build/**',
      'playwright-report/**',
      'test-results/**',
      '.claude/**',
      'backend/**',
      'frontend/src/lib/api/schema.d.ts',
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...svelte.configs['flat/recommended'],
  {
    files: ['frontend/**/*.{ts,svelte}'],
    languageOptions: {
      globals: globals.browser,
    },
  },
  {
    files: ['frontend/**/*.svelte'],
    languageOptions: {
      parserOptions: {
        parser: tseslint.parser,
      },
    },
  },
  {
    files: [
      'e2e/**/*.{ts,tsx,mts,cts,js,jsx}',
      '**/*.spec.{ts,tsx,mts,cts,js,jsx}',
    ],
    ...playwright.configs['flat/recommended'],
  },
  prettierConfig,
  ...svelte.configs['flat/prettier'],
);
