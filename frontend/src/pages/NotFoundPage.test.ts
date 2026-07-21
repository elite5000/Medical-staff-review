import { render, screen } from '@testing-library/svelte';
import { describe, expect, it } from 'vitest';

import NotFoundPage from './NotFoundPage.svelte';

describe('NotFoundPage', () => {
  it('renders a not-found heading', () => {
    render(NotFoundPage);
    expect(
      screen.getByRole('heading', { name: /page not found/i }),
    ).toBeTruthy();
  });
});
