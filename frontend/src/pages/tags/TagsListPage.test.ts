import { render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import TagsListPage from './TagsListPage.svelte';

vi.mock('../../lib/api/client', () => ({
  api: { GET: vi.fn(), DELETE: vi.fn() },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
  window.confirm = vi.fn(() => true);
});

describe('TagsListPage', () => {
  it('renders tags fetched from the API', async () => {
    mockedApi.GET.mockResolvedValue(
      mockResponse([{ id: 1, name: 'Emergency Department' }]),
    );

    render(TagsListPage);

    await waitFor(() =>
      expect(screen.getByText('Emergency Department')).toBeTruthy(),
    );
  });

  it('surfaces an error when deletion is rejected', async () => {
    mockedApi.GET.mockResolvedValue(
      mockResponse([{ id: 1, name: 'Emergency Department' }]),
    );
    mockedApi.DELETE.mockResolvedValue(
      mockResponse(undefined, { detail: 'in use' }),
    );

    render(TagsListPage);
    await waitFor(() =>
      expect(screen.getByText('Emergency Department')).toBeTruthy(),
    );

    screen.getByText('Delete').click();

    await waitFor(() => expect(screen.getByRole('alert')).toBeTruthy());
  });
});
