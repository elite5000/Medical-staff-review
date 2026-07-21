import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: 'html',
  use: {
    trace: 'on-first-retry',
    baseURL: 'http://localhost:5173',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
  webServer: [
    {
      // Wipes/re-migrates a dedicated e2e SQLite file before starting, so e2e runs never
      // share state with a developer's local dev.db or with each other across runs.
      command:
        "uv run python -c \"import pathlib; d = pathlib.Path('.e2e-data'); d.mkdir(exist_ok=True); (d / 'e2e.db').unlink(missing_ok=True)\" && uv run alembic upgrade head && uv run uvicorn app.main:app --port 8000",
      cwd: 'backend',
      env: { APP_DATABASE_URL: 'sqlite:///.e2e-data/e2e.db' },
      url: 'http://localhost:8000/health',
      reuseExistingServer: !process.env.CI,
      timeout: 60_000,
    },
    {
      command: 'npm run dev --workspace=frontend',
      url: 'http://localhost:5173',
      reuseExistingServer: !process.env.CI,
      timeout: 60_000,
    },
  ],
});
