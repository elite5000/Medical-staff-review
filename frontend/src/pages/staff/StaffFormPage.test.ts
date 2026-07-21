import { render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import StaffFormPage from './StaffFormPage.svelte';

vi.mock('svelte-spa-router', () => ({ push: vi.fn() }));
vi.mock('../../lib/api/client', () => ({
  api: { GET: vi.fn(), POST: vi.fn(), PATCH: vi.fn(), DELETE: vi.fn() },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
  mockedApi.GET.mockImplementation((path: string) => {
    if (path === '/roles') {
      return Promise.resolve(mockResponse([{ id: 1, name: 'Senior Fellow' }]));
    }
    return Promise.resolve(mockResponse(undefined));
  });
});

describe('StaffFormPage', () => {
  it('creates a staff member with selected role and preferred day', async () => {
    mockedApi.POST.mockResolvedValue(
      mockResponse({
        id: 1,
        name: 'Dr. Alice',
        active: true,
        roles: [],
        preferred_days: [],
        unavailabilities: [],
      }),
    );

    render(StaffFormPage, { props: { params: {} } });
    await waitFor(() => expect(screen.getByText('Senior Fellow')).toBeTruthy());

    const nameInput = screen.getByLabelText('Name') as HTMLInputElement;
    nameInput.value = 'Dr. Alice';
    nameInput.dispatchEvent(new Event('input'));

    screen.getByLabelText('Senior Fellow').click();
    screen.getByLabelText('Mon').click();
    screen.getByText('Save').closest('form')?.requestSubmit();

    await waitFor(() =>
      expect(mockedApi.POST).toHaveBeenCalledWith('/staff', {
        body: {
          name: 'Dr. Alice',
          active: true,
          role_ids: [1],
          preferred_days: [0],
        },
      }),
    );
  });

  it('adds an unavailability for an existing staff member', async () => {
    mockedApi.GET.mockImplementation((path: string) => {
      if (path === '/roles') {
        return Promise.resolve(mockResponse([]));
      }
      return Promise.resolve(
        mockResponse({
          id: 7,
          name: 'Dr. Bob',
          active: true,
          roles: [],
          preferred_days: [],
          unavailabilities: [],
        }),
      );
    });
    mockedApi.POST.mockResolvedValue(
      mockResponse({
        id: 99,
        staff_id: 7,
        start_date: '2026-08-01',
        end_date: '2026-08-05',
        reason: 'Leave',
      }),
    );

    render(StaffFormPage, { props: { params: { id: '7' } } });
    await waitFor(() =>
      expect((screen.getByLabelText('Name') as HTMLInputElement).value).toBe(
        'Dr. Bob',
      ),
    );

    const startInput = screen.getByLabelText('Start date') as HTMLInputElement;
    startInput.value = '2026-08-01';
    startInput.dispatchEvent(new Event('input'));
    const endInput = screen.getByLabelText('End date') as HTMLInputElement;
    endInput.value = '2026-08-05';
    endInput.dispatchEvent(new Event('input'));

    screen.getByText('Add Unavailability').closest('form')?.requestSubmit();

    await waitFor(() =>
      expect(mockedApi.POST).toHaveBeenCalledWith(
        '/staff/{staff_id}/unavailabilities',
        {
          params: { path: { staff_id: 7 } },
          body: {
            start_date: '2026-08-01',
            end_date: '2026-08-05',
            reason: null,
          },
        },
      ),
    );
  });
});
