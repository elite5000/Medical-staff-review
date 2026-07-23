<script lang="ts">
  import { link } from 'svelte-spa-router';

  import { api } from '../../lib/api/client';
  import { resizableColumns } from '../../lib/actions/resizableColumns';
  import type { components } from '../../lib/api/schema';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';

  type Room = components['schemas']['RoomRead'];
  type Building = components['schemas']['BuildingRead'];

  let rooms: Room[] = $state([]);
  let buildingsById: Map<number, Building> = $state(new Map());
  let error: string | null = $state(null);

  async function load() {
    const [roomsRes, buildingsRes] = await Promise.all([
      api.GET('/rooms'),
      api.GET('/buildings'),
    ]);
    if (roomsRes.error || buildingsRes.error) {
      error = 'Failed to load rooms';
      return;
    }
    rooms = roomsRes.data ?? [];
    buildingsById = new Map((buildingsRes.data ?? []).map((b) => [b.id, b]));
  }

  async function remove(id: number) {
    if (!confirm('Delete this room?')) return;
    const { error: err } = await api.DELETE('/rooms/{room_id}', {
      params: { path: { room_id: id } },
    });
    if (err) {
      error = 'Could not delete room — it may appear in a generated roster';
      return;
    }
    await load();
  }

  load();
</script>

<h1>Rooms</h1>
<ErrorBanner message={error} />

<div class="actions">
  <a href="/rooms/new" use:link>New Room</a>
</div>

<table use:resizableColumns>
  <thead>
    <tr>
      <th>Name</th>
      <th>Building</th>
      <th>Tags</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    {#each rooms as room (room.id)}
      <tr>
        <td>{room.name}</td>
        <td>{buildingsById.get(room.building_id)?.name ?? '—'}</td>
        <td>{room.tags.map((t) => t.name).join(', ')}</td>
        <td>
          <a href={`/rooms/${room.id}/edit`} use:link>Edit</a>
          <button onclick={() => remove(room.id)}>Delete</button>
        </td>
      </tr>
    {/each}
  </tbody>
</table>
