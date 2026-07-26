import { render, screen, waitFor } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import RuleFormPage from './RuleFormPage.svelte';

vi.mock('svelte-spa-router', () => ({ push: vi.fn() }));
vi.mock('../../lib/api/client', () => ({
  api: { GET: vi.fn(), POST: vi.fn() },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
  mockedApi.GET.mockImplementation((path: string) => {
    if (path === '/roles') {
      return Promise.resolve(mockResponse([{ id: 1, name: 'Senior Fellow' }]));
    }
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
    return Promise.resolve(mockResponse([]));
  });
});

describe('RuleFormPage', () => {
  it('creates a minimum-count rule scoped to a building by default', async () => {
    mockedApi.POST.mockResolvedValue(
      mockResponse({
        id: 1,
        rule_type: 'minimum_count',
        role_id: 1,
        building_id: 10,
        tag_id: null,
        minimum_count: 1,
      }),
    );

    render(RuleFormPage);
    await waitFor(() => expect(screen.getByText('Hospital')).toBeTruthy());

    const nameInput = screen.getByLabelText('Name') as HTMLInputElement;
    nameInput.value = 'ED minimum staffing';
    nameInput.dispatchEvent(new Event('input'));

    screen.getByText('Save').closest('form')?.requestSubmit();

    await waitFor(() =>
      expect(mockedApi.POST).toHaveBeenCalledWith('/rules', {
        body: {
          name: 'ED minimum staffing',
          rule_type: 'minimum_count',
          role_id: 1,
          minimum_count: 1,
          building_id: 10,
          tag_id: null,
        },
      }),
    );
  });

  it('creates an eligibility_restriction rule scoped to a tag', async () => {
    mockedApi.POST.mockResolvedValue(
      mockResponse({
        id: 2,
        rule_type: 'eligibility_restriction',
        role_id: 1,
        building_id: null,
        tag_id: 100,
      }),
    );

    render(RuleFormPage);
    await waitFor(() => expect(screen.getByText('Hospital')).toBeTruthy());

    const nameInput = screen.getByLabelText('Name') as HTMLInputElement;
    nameInput.value = 'ED eligibility';
    nameInput.dispatchEvent(new Event('input'));

    const user = userEvent.setup();
    await user.selectOptions(
      screen.getByLabelText('Rule type'),
      'eligibility_restriction',
    );
    await waitFor(() => expect(screen.queryByLabelText('Tag')).not.toBeNull());

    screen.getByText('Save').closest('form')?.requestSubmit();

    await waitFor(() =>
      expect(mockedApi.POST).toHaveBeenCalledWith('/rules', {
        body: {
          name: 'ED eligibility',
          rule_type: 'eligibility_restriction',
          role_id: 1,
          tag_id: 100,
        },
      }),
    );
  });
});
