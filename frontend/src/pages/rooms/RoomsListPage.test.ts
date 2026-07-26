import { render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import RoomsListPage from './RoomsListPage.svelte';

vi.mock('../../lib/api/client', () => ({
  api: { GET: vi.fn(), DELETE: vi.fn() },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
  window.confirm = vi.fn(() => true);
});

describe('RoomsListPage', () => {
  it('renders rooms with their building name and tags', async () => {
    mockedApi.GET.mockImplementation((path: string) => {
      if (path === '/rooms') {
        return Promise.resolve(
          mockResponse([
            {
              id: 1,
              name: 'Trauma Room',
              building_id: 10,
              tags: [{ id: 100, name: 'Emergency Department' }],
            },
          ]),
        );
      }
      return Promise.resolve(
        mockResponse([
          {
            id: 10,
            name: 'Hospital',
            opening_minutes: 480,
            closing_minutes: 1080,
          },
        ]),
      );
    });

    render(RoomsListPage);

    await waitFor(() => expect(screen.getByText('Trauma Room')).toBeTruthy());
    expect(screen.getByText('Hospital')).toBeTruthy();
    expect(screen.getByText('Emergency Department')).toBeTruthy();
  });
});
