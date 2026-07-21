import { render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import RosterGeneratePage from './RosterGeneratePage.svelte';

vi.mock('svelte-spa-router', () => ({ push: vi.fn() }));
vi.mock('../../lib/api/client', () => ({
  api: { POST: vi.fn() },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
});

describe('RosterGeneratePage', () => {
  it('generates a roster for the chosen date range', async () => {
    mockedApi.POST.mockResolvedValue(
      mockResponse({
        id: 1,
        start_date: '2026-08-03',
        end_date: '2026-08-16',
        generated_at: '2026-07-25T10:00:00',
        generated_from_roster_id: null,
        has_violations: false,
      }),
    );

    render(RosterGeneratePage);

    const startDateInput = screen.getByLabelText(
      'Start date',
    ) as HTMLInputElement;
    startDateInput.value = '2026-08-03';
    startDateInput.dispatchEvent(new Event('input'));

    screen.getByText('Generate').closest('form')?.requestSubmit();

    await waitFor(() =>
      expect(mockedApi.POST).toHaveBeenCalledWith('/rosters', {
        body: { start_date: '2026-08-03', num_days: 14 },
      }),
    );
  });
});
