<script lang="ts">
  import { link } from 'svelte-spa-router';

  import { api } from '../../lib/api/client';
  import { resizableColumns } from '../../lib/actions/resizableColumns';
  import type { components } from '../../lib/api/schema';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';
  import TableSearch from '../../lib/components/TableSearch.svelte';
  import { minutesToTime } from '../../lib/utils/time';

  type Building = components['schemas']['BuildingRead'];

  let buildings: Building[] = $state([]);
  let error: string | null = $state(null);
  let query = $state('');

  const filteredBuildings = $derived(
    buildings.filter((b) => b.name.toLowerCase().includes(query.toLowerCase())),
  );

  async function load() {
    const { data, error: err } = await api.GET('/buildings');
    if (err) {
      error = 'Failed to load buildings';
      return;
    }
    buildings = data ?? [];
  }

  async function remove(id: number) {
    if (!confirm('Delete this building?')) return;
    const { error: err } = await api.DELETE('/buildings/{building_id}', {
      params: { path: { building_id: id } },
    });
    if (err) {
      error =
        'Could not delete building — it may still have rooms or rules attached';
      return;
    }
    await load();
  }

  load();
</script>

<h1>Buildings</h1>
<ErrorBanner message={error} />

<div class="actions">
  <a href="/buildings/new" use:link>New Building</a>
</div>

<TableSearch bind:value={query} placeholder="Search buildings…" />

<table use:resizableColumns>
  <thead>
    <tr>
      <th>Name</th>
      <th>Opening hours</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    {#each filteredBuildings as building (building.id)}
      <tr>
        <td>{building.name}</td>
        <td
          >{minutesToTime(building.opening_minutes)}–{minutesToTime(
            building.closing_minutes,
          )}</td
        >
        <td>
          <a href={`/buildings/${building.id}/edit`} use:link>Edit</a>
          <button onclick={() => remove(building.id)}>Delete</button>
        </td>
      </tr>
    {/each}
  </tbody>
</table>
