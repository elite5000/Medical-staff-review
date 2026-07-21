import { render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import BuildingFormPage from './BuildingFormPage.svelte';

vi.mock('svelte-spa-router', () => ({ push: vi.fn() }));
vi.mock('../../lib/api/client', () => ({
  api: {
    GET: vi.fn(),
    POST: vi.fn(),
    PATCH: vi.fn(),
  },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
});

describe('BuildingFormPage', () => {
  it('creates a building with times converted to minutes', async () => {
    mockedApi.POST.mockResolvedValue(
      mockResponse({
        id: 1,
        name: 'Clinic',
        opening_minutes: 540,
        closing_minutes: 1020,
      }),
    );

    render(BuildingFormPage, { props: { params: {} } });

    const nameInput = screen.getByLabelText('Name') as HTMLInputElement;
    nameInput.value = 'Clinic';
    nameInput.dispatchEvent(new Event('input'));

    screen.getByText('Save').closest('form')?.requestSubmit();

    await waitFor(() =>
      expect(mockedApi.POST).toHaveBeenCalledWith('/buildings', {
        body: { name: 'Clinic', opening_minutes: 480, closing_minutes: 1080 },
      }),
    );
  });

  it('loads an existing building for editing', async () => {
    mockedApi.GET.mockResolvedValue(
      mockResponse({
        id: 5,
        name: 'Hospital',
        opening_minutes: 420,
        closing_minutes: 1200,
      }),
    );

    render(BuildingFormPage, { props: { params: { id: '5' } } });

    await waitFor(() =>
      expect((screen.getByLabelText('Name') as HTMLInputElement).value).toBe(
        'Hospital',
      ),
    );
    expect(mockedApi.GET).toHaveBeenCalledWith('/buildings/{building_id}', {
      params: { path: { building_id: 5 } },
    });
  });
});
