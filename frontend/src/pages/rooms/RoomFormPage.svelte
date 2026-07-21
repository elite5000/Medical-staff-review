<script lang="ts">
  import { push } from 'svelte-spa-router';
  import { SvelteSet } from 'svelte/reactivity';

  import { extractErrorMessage } from '../../lib/api/errors';
  import { api } from '../../lib/api/client';
  import type { components } from '../../lib/api/schema';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';

  type Building = components['schemas']['BuildingRead'];
  type Tag = components['schemas']['TagRead'];

  let { params = {} }: { params?: { id?: string } } = $props();
  const roomId = $derived(params.id ? Number(params.id) : null);

  let name = $state('');
  let buildingId: number | null = $state(null);
  const selectedTagIds = new SvelteSet<number>();
  let buildings: Building[] = $state([]);
  let tags: Tag[] = $state([]);
  let error: string | null = $state(null);

  async function loadOptions() {
    const [buildingsRes, tagsRes] = await Promise.all([
      api.GET('/buildings'),
      api.GET('/tags'),
    ]);
    buildings = buildingsRes.data ?? [];
    tags = tagsRes.data ?? [];
    if (buildingId === null && buildings[0]) {
      buildingId = buildings[0].id;
    }
  }

  async function loadRoom(id: number) {
    const { data, error: err } = await api.GET('/rooms/{room_id}', {
      params: { path: { room_id: id } },
    });
    if (err || !data) {
      error = 'Failed to load room';
      return;
    }
    name = data.name;
    buildingId = data.building_id;
    selectedTagIds.clear();
    for (const tag of data.tags) selectedTagIds.add(tag.id);
  }

  loadOptions();
  $effect(() => {
    if (roomId !== null) loadRoom(roomId);
  });

  function toggleTag(id: number) {
    if (selectedTagIds.has(id)) {
      selectedTagIds.delete(id);
    } else {
      selectedTagIds.add(id);
    }
  }

  async function save(event: SubmitEvent) {
    event.preventDefault();
    error = null;
    if (buildingId === null) {
      error = 'A building is required';
      return;
    }
    const body = {
      name,
      building_id: buildingId,
      tag_ids: Array.from(selectedTagIds),
    };
    const { error: err } =
      roomId === null
        ? await api.POST('/rooms', { body })
        : await api.PATCH('/rooms/{room_id}', {
            params: { path: { room_id: roomId } },
            body,
          });
    if (err) {
      error = extractErrorMessage(err, 'Could not save room');
      return;
    }
    await push('/rooms');
  }
</script>

<h1>{roomId === null ? 'New Room' : 'Edit Room'}</h1>
<ErrorBanner message={error} />

<form onsubmit={save}>
  <label>
    Name
    <input type="text" bind:value={name} required />
  </label>
  <label>
    Building
    <select bind:value={buildingId} required>
      {#each buildings as building (building.id)}
        <option value={building.id}>{building.name}</option>
      {/each}
    </select>
  </label>
  <fieldset>
    <legend>Tags</legend>
    {#each tags as tag (tag.id)}
      <label class="checkbox-row">
        <input
          type="checkbox"
          checked={selectedTagIds.has(tag.id)}
          onchange={() => toggleTag(tag.id)}
        />
        {tag.name}
      </label>
    {/each}
  </fieldset>
  <button type="submit">Save</button>
</form>
