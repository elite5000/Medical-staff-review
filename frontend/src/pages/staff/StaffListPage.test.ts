import { render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import StaffListPage from './StaffListPage.svelte';

vi.mock('../../lib/api/client', () => ({
  api: { GET: vi.fn(), DELETE: vi.fn() },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
  window.confirm = vi.fn(() => true);
});

describe('StaffListPage', () => {
  it('renders staff with roles', async () => {
    mockedApi.GET.mockResolvedValue(
      mockResponse([
        {
          id: 1,
          name: 'Dr. Alice',
          active: true,
          roles: [{ id: 1, name: 'Senior Fellow' }],
          preferred_days: [],
          unavailabilities: [],
        },
      ]),
    );

    render(StaffListPage);

    await waitFor(() => expect(screen.getByText('Dr. Alice')).toBeTruthy());
    expect(screen.getByText('Senior Fellow')).toBeTruthy();
  });
});
