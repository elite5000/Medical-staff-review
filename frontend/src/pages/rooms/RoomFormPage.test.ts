import { render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import RoomFormPage from './RoomFormPage.svelte';

vi.mock('svelte-spa-router', () => ({ push: vi.fn() }));
vi.mock('../../lib/api/client', () => ({
  api: { GET: vi.fn(), POST: vi.fn(), PATCH: vi.fn() },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
  mockedApi.GET.mockImplementation((path: string) => {
    if (path === '/buildings') {
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
    }
    if (path === '/tags') {
      return Promise.resolve(
        mockResponse([{ id: 100, name: 'Emergency Department' }]),
      );
    }
    return Promise.resolve(mockResponse(undefined));
  });
});

describe('RoomFormPage', () => {
  it('creates a room with the selected building and tags', async () => {
    mockedApi.POST.mockResolvedValue(
      mockResponse({ id: 1, name: 'Trauma Room', building_id: 10, tags: [] }),
    );

    render(RoomFormPage, { props: { params: {} } });
    await waitFor(() => expect(screen.getByText('Hospital')).toBeTruthy());

    const nameInput = screen.getByLabelText('Name') as HTMLInputElement;
    nameInput.value = 'Trauma Room';
    nameInput.dispatchEvent(new Event('input'));

    screen.getByLabelText('Emergency Department').click();
    screen.getByText('Save').closest('form')?.requestSubmit();

    await waitFor(() =>
      expect(mockedApi.POST).toHaveBeenCalledWith('/rooms', {
        body: { name: 'Trauma Room', building_id: 10, tag_ids: [100] },
      }),
    );
  });
});
