import { render, screen, waitFor } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import RosterViewPage from './RosterViewPage.svelte';

vi.mock('../../lib/api/client', () => ({
  api: { GET: vi.fn(), PATCH: vi.fn() },
}));

const mockedApi = api as unknown as MockApi;

function mockRosterDetail() {
  return {
    id: 1,
    start_date: '2026-08-03',
    end_date: '2026-08-03',
    generated_at: '2026-07-25T10:00:00',
    generated_from_roster_id: null,
    has_violations: true,
    shifts: [
      {
        id: 100,
        room_id: 1,
        staff_id: 1,
        date: '2026-08-03',
        shift_index: 0,
        pinned: false,
      },
    ],
    violations: [
      {
        id: 1,
        violation_type: 'room_unfilled',
        rule_id: null,
        building_id: null,
        tag_id: null,
        room_id: 2,
        date: '2026-08-03',
        shift_index: 0,
        detail: null,
      },
    ],
  };
}

function mockRosterSummary() {
  const detail = mockRosterDetail();
  return {
    id: detail.id,
    start_date: detail.start_date,
    end_date: detail.end_date,
    generated_at: detail.generated_at,
    generated_from_roster_id: detail.generated_from_roster_id,
    has_violations: detail.has_violations,
  };
}

beforeEach(() => {
  vi.resetAllMocks();
  mockedApi.GET.mockImplementation((path: string) => {
    if (path === '/rosters/{roster_id}') {
      return Promise.resolve(mockResponse(mockRosterDetail()));
    }
    if (path === '/rosters') {
      return Promise.resolve(mockResponse([mockRosterSummary()]));
    }
    if (path === '/rooms') {
      return Promise.resolve(
        mockResponse([
          { id: 1, name: 'Room A', building_id: 10, tags: [] },
          { id: 2, name: 'Room B', building_id: 10, tags: [] },
        ]),
      );
    }
    if (path === '/staff') {
      return Promise.resolve(
        mockResponse([
          {
            id: 1,
            name: 'Dr. Alice',
            active: true,
            roles: [],
            preferred_days: [],
            unavailabilities: [],
          },
          {
            id: 2,
            name: 'Dr. Bob',
            active: true,
            roles: [],
            preferred_days: [],
            unavailabilities: [],
          },
        ]),
      );
    }
    return Promise.resolve(mockResponse([]));
  });
});

describe('RosterViewPage', () => {
  it('renders the shift grid and violations with resolved names', async () => {
    render(RosterViewPage, { props: { params: { id: '1' } } });

    await waitFor(() => expect(screen.getByText('Room A')).toBeTruthy());
    expect(
      screen.getByText('Room B unfilled on 2026-08-03 (shift 0)'),
    ).toBeTruthy();
  });

  it('reassigns a shift to a different staff member', async () => {
    mockedApi.PATCH.mockResolvedValue(
      mockResponse({
        id: 100,
        room_id: 1,
        staff_id: 2,
        date: '2026-08-03',
        shift_index: 0,
        pinned: true,
      }),
    );

    render(RosterViewPage, { props: { params: { id: '1' } } });
    await waitFor(() => expect(screen.getByText('Room A')).toBeTruthy());

    const user = userEvent.setup();
    await user.selectOptions(screen.getByRole('combobox'), 'Dr. Bob');

    await waitFor(() =>
      expect(mockedApi.PATCH).toHaveBeenCalledWith(
        '/rosters/{roster_id}/shifts/{shift_id}',
        {
          params: { path: { roster_id: 1, shift_id: 100 } },
          body: { staff_id: 2 },
        },
      ),
    );
  });

  it('shows staff as read-only text when a newer roster exists for the same range', async () => {
    mockedApi.GET.mockImplementation((path: string) => {
      if (path === '/rosters/{roster_id}') {
        return Promise.resolve(mockResponse(mockRosterDetail()));
      }
      if (path === '/rosters') {
        return Promise.resolve(
          mockResponse([
            mockRosterSummary(),
            { ...mockRosterSummary(), id: 2, generated_at: '2026-07-25T11:00:00' },
          ]),
        );
      }
      if (path === '/staff') {
        return Promise.resolve(
          mockResponse([
            {
              id: 1,
              name: 'Dr. Alice',
              active: true,
              roles: [],
              preferred_days: [],
              unavailabilities: [],
            },
          ]),
        );
      }
      if (path === '/rooms') {
        return Promise.resolve(
          mockResponse([{ id: 1, name: 'Room A', building_id: 10, tags: [] }]),
        );
      }
      return Promise.resolve(mockResponse([]));
    });

    render(RosterViewPage, { props: { params: { id: '1' } } });

    await waitFor(() => expect(screen.getByText('Room A')).toBeTruthy());
    expect(screen.getByText('Dr. Alice')).toBeTruthy();
    expect(screen.queryByRole('combobox')).toBeNull();
  });
});
