import { render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import BuildingsListPage from './BuildingsListPage.svelte';

vi.mock('../../lib/api/client', () => ({
  api: {
    GET: vi.fn(),
    DELETE: vi.fn(),
  },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
  window.confirm = vi.fn(() => true);
});

describe('BuildingsListPage', () => {
  it('renders buildings fetched from the API', async () => {
    mockedApi.GET.mockResolvedValue(
      mockResponse([
        {
          id: 1,
          name: 'Hospital',
          opening_minutes: 480,
          closing_minutes: 1080,
        },
      ]),
    );

    render(BuildingsListPage);

    await waitFor(() => expect(screen.getByText('Hospital')).toBeTruthy());
    expect(screen.getByText('08:00–18:00')).toBeTruthy();
  });

  it('deletes a building after confirmation', async () => {
    mockedApi.GET.mockResolvedValue(
      mockResponse([
        {
          id: 1,
          name: 'Hospital',
          opening_minutes: 480,
          closing_minutes: 1080,
        },
      ]),
    );
    mockedApi.DELETE.mockResolvedValue(mockResponse(undefined));

    render(BuildingsListPage);
    await waitFor(() => expect(screen.getByText('Hospital')).toBeTruthy());

    screen.getByText('Delete').click();

    await waitFor(() =>
      expect(mockedApi.DELETE).toHaveBeenCalledWith(
        '/buildings/{building_id}',
        {
          params: { path: { building_id: 1 } },
        },
      ),
    );
  });
});
