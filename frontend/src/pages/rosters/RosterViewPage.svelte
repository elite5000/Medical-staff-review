<script lang="ts">
  import { api } from '../../lib/api/client';
  import { extractErrorMessage } from '../../lib/api/errors';
  import type { components } from '../../lib/api/schema';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';

  type RosterDetail = components['schemas']['RosterDetailRead'];
  type Shift = components['schemas']['ShiftRead'];
  type Room = components['schemas']['RoomRead'];
  type Staff = components['schemas']['StaffRead'];
  type Building = components['schemas']['BuildingRead'];
  type Tag = components['schemas']['TagRead'];

  let { params = {} }: { params?: { id?: string } } = $props();
  const rosterId = $derived(params.id ? Number(params.id) : null);

  let roster: RosterDetail | null = $state(null);
  let roomsById: Map<number, Room> = $state(new Map());
  let buildingsById: Map<number, Building> = $state(new Map());
  let tagsById: Map<number, Tag> = $state(new Map());
  let staffOptions: Staff[] = $state([]);
  let error: string | null = $state(null);

  async function load(id: number) {
    const [rosterRes, roomsRes, staffRes, buildingsRes, tagsRes] =
      await Promise.all([
        api.GET('/rosters/{roster_id}', {
          params: { path: { roster_id: id } },
        }),
        api.GET('/rooms'),
        api.GET('/staff'),
        api.GET('/buildings'),
        api.GET('/tags'),
      ]);
    if (rosterRes.error || !rosterRes.data) {
      error = 'Failed to load roster';
      return;
    }
    roster = rosterRes.data;
    roomsById = new Map((roomsRes.data ?? []).map((r) => [r.id, r]));
    staffOptions = staffRes.data ?? [];
    buildingsById = new Map((buildingsRes.data ?? []).map((b) => [b.id, b]));
    tagsById = new Map((tagsRes.data ?? []).map((t) => [t.id, t]));
  }

  $effect(() => {
    if (rosterId !== null) load(rosterId);
  });

  const shiftsByDate = $derived.by(() => {
    // Plain Map: a local scratch value fully rebuilt (and returned as a snapshot) each
    // time this derived recomputes, not reactive state needing SvelteMap's mutation
    // tracking.
    // eslint-disable-next-line svelte/prefer-svelte-reactivity
    const groups = new Map<string, Shift[]>();
    for (const shift of roster?.shifts ?? []) {
      const list = groups.get(shift.date) ?? [];
      list.push(shift);
      groups.set(shift.date, list);
    }
    for (const list of groups.values()) {
      list.sort((a, b) => {
        const roomA = roomsById.get(a.room_id)?.name ?? '';
        const roomB = roomsById.get(b.room_id)?.name ?? '';
        return roomA.localeCompare(roomB) || a.shift_index - b.shift_index;
      });
    }
    return groups;
  });

  function violationLabel(
    v: components['schemas']['RosterViolationRead'],
  ): string {
    if (v.violation_type === 'room_unfilled') {
      const room =
        v.room_id !== null ? roomsById.get(v.room_id)?.name : undefined;
      return `${room ?? 'Room'} unfilled on ${v.date} (shift ${v.shift_index})`;
    }
    const scope =
      v.building_id !== null
        ? `Building: ${buildingsById.get(v.building_id)?.name ?? '—'}`
        : v.tag_id !== null
          ? `Tag: ${tagsById.get(v.tag_id)?.name ?? '—'}`
          : '—';
    return `Minimum-count rule unmet for ${scope} on ${v.date} (shift ${v.shift_index}) — ${v.detail ?? ''}`;
  }

  async function reassign(shiftId: number, staffId: number) {
    if (rosterId === null) return;
    error = null;
    const { error: err } = await api.PATCH(
      '/rosters/{roster_id}/shifts/{shift_id}',
      {
        params: { path: { roster_id: rosterId, shift_id: shiftId } },
        body: { staff_id: staffId },
      },
    );
    if (err) {
      error = extractErrorMessage(err, 'Could not reassign shift');
      return;
    }
    await load(rosterId);
  }
</script>

<h1>Roster</h1>
<ErrorBanner message={error} />

{#if roster}
  <p>
    {roster.start_date} – {roster.end_date} (generated {roster.generated_at})
  </p>

  {#if roster.violations.length > 0}
    <h2>Violations</h2>
    <ul>
      {#each roster.violations as violation (violation.id)}
        <li>{violationLabel(violation)}</li>
      {/each}
    </ul>
  {/if}

  {#each [...shiftsByDate.entries()] as [date, shifts] (date)}
    <h2>{date}</h2>
    <table>
      <thead>
        <tr>
          <th>Room</th>
          <th>Shift</th>
          <th>Staff</th>
          <th>Pinned</th>
        </tr>
      </thead>
      <tbody>
        {#each shifts as shift (shift.id)}
          <tr>
            <td>{roomsById.get(shift.room_id)?.name ?? '—'}</td>
            <td>{shift.shift_index}</td>
            <td>
              <select
                value={shift.staff_id}
                onchange={(e) =>
                  reassign(shift.id, Number(e.currentTarget.value))}
              >
                {#each staffOptions as person (person.id)}
                  <option value={person.id}>{person.name}</option>
                {/each}
              </select>
            </td>
            <td>{shift.pinned ? 'Yes' : 'No'}</td>
          </tr>
        {/each}
      </tbody>
    </table>
  {/each}
{/if}
