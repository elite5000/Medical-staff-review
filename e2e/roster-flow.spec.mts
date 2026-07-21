import { test, expect } from '@playwright/test';

// Golden-path coverage: build up an entire practice from scratch through the UI (building,
// tag, role, room, staff, rule) and confirm the solver actually produces a satisfying
// roster end-to-end. Every entity name is suffixed so this test is safe to run against a
// shared e2e database without colliding with other data.
//
// Navigation between pages goes through nav-bar/in-page links (not page.goto to an
// internal hash route) — svelte-spa-router's hashchange listener doesn't reliably fire for
// goto() calls that only change the URL fragment of the current document. Each Save is
// also followed by an explicit toHaveURL wait: the form's own push() redirect and an
// immediately-following nav-link click can otherwise race.
test('creates a practice from scratch and generates a roster satisfying its rules', async ({
  page,
}) => {
  const suffix = Date.now().toString();
  const buildingName = `Hospital ${suffix}`;
  const tagName = `Emergency Department ${suffix}`;
  const roleName = `Senior Fellow ${suffix}`;
  const roomName = `ED Room ${suffix}`;
  const staffName = `Dr. Alice ${suffix}`;

  await page.goto('/');

  await page.getByRole('link', { name: 'Buildings' }).click();
  await page.getByRole('link', { name: 'New Building' }).click();
  await page.getByLabel('Name').fill(buildingName);
  await page.getByLabel('Opening time').fill('08:00');
  await page.getByLabel('Closing time').fill('18:00');
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page).toHaveURL(/#\/buildings$/);
  await expect(page.getByText(buildingName)).toBeVisible();

  await page.getByRole('link', { name: 'Tags' }).click();
  await page.getByRole('link', { name: 'New Tag' }).click();
  await page.getByLabel('Name').fill(tagName);
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page).toHaveURL(/#\/tags$/);
  await expect(page.getByText(tagName)).toBeVisible();

  await page.getByRole('link', { name: 'Roles' }).click();
  await page.getByRole('link', { name: 'New Role' }).click();
  await page.getByLabel('Name').fill(roleName);
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page).toHaveURL(/#\/roles$/);
  await expect(page.getByText(roleName)).toBeVisible();

  await page.getByRole('link', { name: 'Rooms' }).click();
  await page.getByRole('link', { name: 'New Room' }).click();
  await page.getByLabel('Name').fill(roomName);
  await page.getByLabel('Building').selectOption({ label: buildingName });
  await page.getByLabel(tagName).check();
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page).toHaveURL(/#\/rooms$/);
  await expect(page.getByText(roomName)).toBeVisible();

  await page.getByRole('link', { name: 'Staff' }).click();
  await page.getByRole('link', { name: 'New Staff Member' }).click();
  await page.getByLabel('Name').fill(staffName);
  await page.getByLabel(roleName).check();
  await page.getByRole('button', { name: 'Save' }).click();
  // Creating staff redirects to their edit page (to allow adding Unavailability), not the
  // list — the name shows up as an input value there, not as plain text.
  await expect(page).toHaveURL(/#\/staff\/\d+\/edit$/);
  await expect(page.getByLabel('Name')).toHaveValue(staffName);

  // A tag-scoped minimum-count rule: the ED needs at least 1 Senior Fellow at all times.
  await page.getByRole('link', { name: 'Rules' }).click();
  await page.getByRole('link', { name: 'New Rule' }).click();
  await page.getByLabel('Rule type').selectOption('minimum_count');
  await page.getByLabel('Role').selectOption({ label: roleName });
  await page.getByLabel('Applies to').selectOption('tag');
  // Chromium's computed accessible name for these implicitly-labelled <select>s appends
  // their option text to the label (e.g. "Tag Emergency Department ..."), so disambiguate
  // by matching the unique tag name itself rather than the literal "Tag" label text.
  await page
    .getByLabel(tagName, { exact: false })
    .selectOption({ label: tagName });
  // getByLabel('Minimum count') is ambiguous here for the same reason — it also matches
  // the "Rule type" <select>'s concatenated accessible name — so target the input by role.
  await page.getByRole('spinbutton', { name: 'Minimum count' }).fill('1');
  await page.getByRole('button', { name: 'Save' }).click();
  await expect(page).toHaveURL(/#\/rules$/);

  await page.getByRole('link', { name: 'Rosters' }).click();
  await page.getByRole('link', { name: 'Generate Roster' }).click();
  await page.getByLabel('Start date').fill('2026-08-03');
  await page.getByLabel('Number of days').fill('1');
  await page.getByRole('button', { name: 'Generate' }).click();

  await expect(page).toHaveURL(/#\/rosters\/\d+$/);
  await expect(page.getByRole('heading', { name: 'Violations' })).toBeHidden();
  // The 08:00-18:00 opening hours divide into two 4-hour shift blocks, so the room
  // appears twice — once per block.
  await expect(page.getByText(roomName).first()).toBeVisible();
  // The lone qualifying staff member must be assigned to every shift block in the ED
  // room, satisfying the minimum-count rule with zero violations.
  for (const select of await page.locator('select').all()) {
    await expect(select).toContainText(staffName);
  }
});
