import { render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import RosterListPage from './RosterListPage.svelte';

vi.mock('../../lib/api/client', () => ({
  api: { GET: vi.fn(), POST: vi.fn() },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
});

describe('RosterListPage', () => {
  it('only shows Regenerate for the latest generation of each date range', async () => {
    mockedApi.GET.mockResolvedValue(
      mockResponse([
        {
          id: 1,
          start_date: '2026-08-03',
          end_date: '2026-08-16',
          generated_at: '2026-07-25T10:00:00',
          generated_from_roster_id: null,
          has_violations: false,
        },
        {
          id: 2,
          start_date: '2026-08-03',
          end_date: '2026-08-16',
          generated_at: '2026-07-26T10:00:00',
          generated_from_roster_id: 1,
          has_violations: true,
        },
      ]),
    );

    render(RosterListPage);

    await waitFor(() => expect(screen.getAllByText('View')).toHaveLength(2));
    expect(screen.getAllByText('Regenerate')).toHaveLength(1);
  });

  it('regenerates a roster', async () => {
    mockedApi.GET.mockResolvedValue(
      mockResponse([
        {
          id: 1,
          start_date: '2026-08-03',
          end_date: '2026-08-16',
          generated_at: '2026-07-25T10:00:00',
          generated_from_roster_id: null,
          has_violations: false,
        },
      ]),
    );
    mockedApi.POST.mockResolvedValue(mockResponse(undefined));

    render(RosterListPage);
    await waitFor(() => expect(screen.getByText('Regenerate')).toBeTruthy());

    screen.getByText('Regenerate').click();

    await waitFor(() =>
      expect(mockedApi.POST).toHaveBeenCalledWith(
        '/rosters/{roster_id}/regenerate',
        {
          params: { path: { roster_id: 1 } },
        },
      ),
    );
  });
});
