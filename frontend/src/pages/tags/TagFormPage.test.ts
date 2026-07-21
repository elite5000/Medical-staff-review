import { render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import TagFormPage from './TagFormPage.svelte';

vi.mock('svelte-spa-router', () => ({ push: vi.fn() }));
vi.mock('../../lib/api/client', () => ({
  api: { GET: vi.fn(), POST: vi.fn(), PATCH: vi.fn() },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
});

describe('TagFormPage', () => {
  it('creates a tag', async () => {
    mockedApi.POST.mockResolvedValue(mockResponse({ id: 1, name: 'Surgery' }));

    render(TagFormPage, { props: { params: {} } });
    const nameInput = screen.getByLabelText('Name') as HTMLInputElement;
    nameInput.value = 'Surgery';
    nameInput.dispatchEvent(new Event('input'));
    screen.getByText('Save').closest('form')?.requestSubmit();

    await waitFor(() =>
      expect(mockedApi.POST).toHaveBeenCalledWith('/tags', {
        body: { name: 'Surgery' },
      }),
    );
  });

  it('updates an existing tag', async () => {
    mockedApi.GET.mockResolvedValue(mockResponse({ id: 3, name: 'Old Name' }));
    mockedApi.PATCH.mockResolvedValue(mockResponse(undefined));

    render(TagFormPage, { props: { params: { id: '3' } } });
    await waitFor(() =>
      expect((screen.getByLabelText('Name') as HTMLInputElement).value).toBe(
        'Old Name',
      ),
    );

    const nameInput = screen.getByLabelText('Name') as HTMLInputElement;
    nameInput.value = 'New Name';
    nameInput.dispatchEvent(new Event('input'));
    screen.getByText('Save').closest('form')?.requestSubmit();

    await waitFor(() =>
      expect(mockedApi.PATCH).toHaveBeenCalledWith('/tags/{tag_id}', {
        params: { path: { tag_id: 3 } },
        body: { name: 'New Name' },
      }),
    );
  });
});
