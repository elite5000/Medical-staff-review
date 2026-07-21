<script lang="ts">
  import { link } from 'svelte-spa-router';

  import { api } from '../../lib/api/client';
  import { extractErrorMessage } from '../../lib/api/errors';
  import type { components } from '../../lib/api/schema';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';

  type Roster = components['schemas']['RosterRead'];

  let rosters: Roster[] = $state([]);
  let error: string | null = $state(null);

  async function load() {
    const { data, error: err } = await api.GET('/rosters');
    if (err) {
      error = 'Failed to load rosters';
      return;
    }
    rosters = data ?? [];
  }

  load();

  // Every generation is retained permanently (see CONTEXT.md's Roster entry) — only the
  // most recent generation for a given date range gets a "Regenerate" action; older
  // generations for the same range are viewable read-only history.
  const latestIdByRange = $derived.by(() => {
    // Plain Map: a local scratch value discarded at the end of this computation, not
    // reactive state that needs SvelteMap's fine-grained mutation tracking.
    // eslint-disable-next-line svelte/prefer-svelte-reactivity
    const latest = new Map<string, Roster>();
    for (const roster of rosters) {
      const key = `${roster.start_date}_${roster.end_date}`;
      const current = latest.get(key);
      if (!current || roster.generated_at > current.generated_at) {
        latest.set(key, roster);
      }
    }
    return new Set(Array.from(latest.values()).map((r) => r.id));
  });

  async function regenerate(id: number) {
    error = null;
    const { error: err } = await api.POST('/rosters/{roster_id}/regenerate', {
      params: { path: { roster_id: id } },
    });
    if (err) {
      error = extractErrorMessage(err, 'Could not regenerate roster');
      return;
    }
    await load();
  }
</script>

<h1>Rosters</h1>
<ErrorBanner message={error} />

<div class="actions">
  <a href="/rosters/generate" use:link>Generate Roster</a>
</div>

<table>
  <thead>
    <tr>
      <th>Date range</th>
      <th>Generated at</th>
      <th>Violations</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    {#each rosters as roster (roster.id)}
      <tr>
        <td>{roster.start_date} – {roster.end_date}</td>
        <td>{roster.generated_at}</td>
        <td>{roster.has_violations ? 'Yes' : 'No'}</td>
        <td>
          <a href={`/rosters/${roster.id}`} use:link>View</a>
          {#if latestIdByRange.has(roster.id)}
            <button onclick={() => regenerate(roster.id)}>Regenerate</button>
          {/if}
        </td>
      </tr>
    {/each}
  </tbody>
</table>
