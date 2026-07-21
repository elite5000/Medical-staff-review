import { render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import RoleFormPage from './RoleFormPage.svelte';

vi.mock('svelte-spa-router', () => ({ push: vi.fn() }));
vi.mock('../../lib/api/client', () => ({
  api: { GET: vi.fn(), POST: vi.fn(), PATCH: vi.fn() },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
});

describe('RoleFormPage', () => {
  it('creates a role', async () => {
    mockedApi.POST.mockResolvedValue(
      mockResponse({ id: 1, name: 'Junior Fellow' }),
    );

    render(RoleFormPage, { props: { params: {} } });
    const nameInput = screen.getByLabelText('Name') as HTMLInputElement;
    nameInput.value = 'Junior Fellow';
    nameInput.dispatchEvent(new Event('input'));
    screen.getByText('Save').closest('form')?.requestSubmit();

    await waitFor(() =>
      expect(mockedApi.POST).toHaveBeenCalledWith('/roles', {
        body: { name: 'Junior Fellow' },
      }),
    );
  });
});
