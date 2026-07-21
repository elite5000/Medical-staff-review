import { render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import RolesListPage from './RolesListPage.svelte';

vi.mock('../../lib/api/client', () => ({
  api: { GET: vi.fn(), DELETE: vi.fn() },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
  window.confirm = vi.fn(() => true);
});

describe('RolesListPage', () => {
  it('renders roles fetched from the API', async () => {
    mockedApi.GET.mockResolvedValue(
      mockResponse([{ id: 1, name: 'Senior Fellow' }]),
    );

    render(RolesListPage);

    await waitFor(() => expect(screen.getByText('Senior Fellow')).toBeTruthy());
  });

  it('deletes a role after confirmation', async () => {
    mockedApi.GET.mockResolvedValue(
      mockResponse([{ id: 1, name: 'Senior Fellow' }]),
    );
    mockedApi.DELETE.mockResolvedValue(mockResponse(undefined));

    render(RolesListPage);
    await waitFor(() => expect(screen.getByText('Senior Fellow')).toBeTruthy());
    screen.getByText('Delete').click();

    await waitFor(() =>
      expect(mockedApi.DELETE).toHaveBeenCalledWith('/roles/{role_id}', {
        params: { path: { role_id: 1 } },
      }),
    );
  });
});
