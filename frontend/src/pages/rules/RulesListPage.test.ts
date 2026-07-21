import { render, screen, waitFor } from '@testing-library/svelte';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { api } from '../../lib/api/client';
import type { MockApi } from '../../lib/api/test-mock';
import { mockResponse } from '../../lib/api/test-mock';
import RulesListPage from './RulesListPage.svelte';

vi.mock('../../lib/api/client', () => ({
  api: { GET: vi.fn(), DELETE: vi.fn() },
}));

const mockedApi = api as unknown as MockApi;

beforeEach(() => {
  vi.resetAllMocks();
  window.confirm = vi.fn(() => true);
  mockedApi.GET.mockImplementation((path: string) => {
    if (path === '/rules') {
      return Promise.resolve(
        mockResponse([
          {
            id: 1,
            rule_type: 'minimum_count',
            role_id: 1,
            building_id: null,
            tag_id: 100,
            minimum_count: 1,
          },
        ]),
      );
    }
    if (path === '/roles') {
      return Promise.resolve(mockResponse([{ id: 1, name: 'Senior Fellow' }]));
    }
    if (path === '/tags') {
      return Promise.resolve(
        mockResponse([{ id: 100, name: 'Emergency Department' }]),
      );
    }
    return Promise.resolve(mockResponse([]));
  });
});

describe('RulesListPage', () => {
  it('renders a minimum-count rule with its role and tag target', async () => {
    render(RulesListPage);

    await waitFor(() => expect(screen.getByText('Senior Fellow')).toBeTruthy());
    expect(screen.getAllByText('Minimum count')).toHaveLength(2); // column header + cell
    expect(screen.getByText('Tag: Emergency Department')).toBeTruthy();
  });
});
