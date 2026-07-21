import { render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import SettingsPage from './SettingsPage.svelte';

vi.mock('../../lib/api/client', () => ({
  api: { GET: vi.fn(), PATCH: vi.fn() },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
});

describe('SettingsPage', () => {
  it('loads and displays current settings', async () => {
    mockedApi.GET.mockResolvedValue(
      mockResponse({
        shift_length_minutes: 240,
        travel_time_minutes: 30,
        max_daily_minutes: 720,
      }),
    );

    render(SettingsPage);

    await waitFor(() =>
      expect(
        (screen.getByLabelText('Shift length (minutes)') as HTMLInputElement)
          .value,
      ).toBe('240'),
    );
  });

  it('saves updated settings', async () => {
    mockedApi.GET.mockResolvedValue(
      mockResponse({
        shift_length_minutes: 240,
        travel_time_minutes: 30,
        max_daily_minutes: 720,
      }),
    );
    mockedApi.PATCH.mockResolvedValue(
      mockResponse({
        shift_length_minutes: 240,
        travel_time_minutes: 30,
        max_daily_minutes: 600,
      }),
    );

    render(SettingsPage);
    await waitFor(() =>
      expect(
        (screen.getByLabelText('Shift length (minutes)') as HTMLInputElement)
          .value,
      ).toBe('240'),
    );

    const maxDailyInput = screen.getByLabelText(
      'Max daily hours (minutes)',
    ) as HTMLInputElement;
    maxDailyInput.value = '600';
    maxDailyInput.dispatchEvent(new Event('input'));
    screen.getByText('Save').closest('form')?.requestSubmit();

    await waitFor(() =>
      expect(mockedApi.PATCH).toHaveBeenCalledWith('/settings', {
        body: {
          shift_length_minutes: 240,
          travel_time_minutes: 30,
          max_daily_minutes: 600,
        },
      }),
    );
    await waitFor(() => expect(screen.getByText('Saved.')).toBeTruthy());
  });
});
