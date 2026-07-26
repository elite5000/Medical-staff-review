import createClient from 'openapi-fetch';

import type { paths } from './schema';

// Points at the FastAPI backend directly (see e2e/playwright.config.mts for how the two
// dev servers are wired together in tests). No trailing slash — openapi-fetch appends
// each path's own leading slash.
const BASE_URL = 'http://localhost:8000';

export const api = createClient<paths>({ baseUrl: BASE_URL });
