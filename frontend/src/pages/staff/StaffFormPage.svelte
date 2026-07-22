<script lang="ts">
  import { push } from 'svelte-spa-router';
  import { SvelteSet } from 'svelte/reactivity';

  import { extractErrorMessage } from '../../lib/api/errors';
  import { api } from '../../lib/api/client';
  import type { components } from '../../lib/api/schema';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';
  import UnavailabilityCalendar from '../../lib/components/UnavailabilityCalendar.svelte';
  import { DAY_NAMES } from '../../lib/utils/time';

  type Role = components['schemas']['RoleRead'];
  type Staff = components['schemas']['StaffRead'];
  type Unavailability = components['schemas']['UnavailabilityRead'];

  let { params = {} }: { params?: { id?: string } } = $props();
  const staffId = $derived(params.id ? Number(params.id) : null);

  let name = $state('');
  let active = $state(true);
  const selectedRoleIds = new SvelteSet<number>();
  const selectedPreferredDays = new SvelteSet<number>();
  let roles: Role[] = $state([]);
  let allStaff: Staff[] = $state([]);
  let unavailabilities: Unavailability[] = $state([]);
  let error: string | null = $state(null);

  let newUnavailabilityStart = $state('');
  let newUnavailabilityEnd = $state('');
  let newUnavailabilityReason = $state('');

  async function loadOptions() {
    const { data } = await api.GET('/roles');
    roles = data ?? [];
  }

  // Re-fetched alongside the edited staff member (not in loadOptions) so navigating between
  // two staff edit pages — which svelte-spa-router may do without remounting this component —
  // always shows everyone's latest unavailability, not a snapshot from whenever this
  // component instance first mounted.
  async function loadAllStaff() {
    const { data } = await api.GET('/staff');
    allStaff = data ?? [];
  }

  async function loadStaff(id: number) {
    const { data, error: err } = await api.GET('/staff/{staff_id}', {
      params: { path: { staff_id: id } },
    });
    if (err || !data) {
      error = 'Failed to load staff member';
      return;
    }
    name = data.name;
    active = data.active;
    selectedRoleIds.clear();
    for (const role of data.roles) selectedRoleIds.add(role.id);
    selectedPreferredDays.clear();
    for (const day of data.preferred_days) selectedPreferredDays.add(day);
    unavailabilities = data.unavailabilities;
  }

  loadOptions();
  $effect(() => {
    loadAllStaff();
    if (staffId !== null) loadStaff(staffId);
  });

  // Keeps the calendar's view of the current staff member's unavailabilities live as they're
  // added/removed below, without waiting on a re-fetch of the whole staff list.
  const staffForCalendar = $derived(
    allStaff.map((person) =>
      person.id === staffId ? { ...person, unavailabilities } : person,
    ),
  );

  function toggle(set: SvelteSet<number>, id: number) {
    if (set.has(id)) {
      set.delete(id);
    } else {
      set.add(id);
    }
  }

  async function save(event: SubmitEvent) {
    event.preventDefault();
    error = null;
    const body = {
      name,
      active,
      role_ids: Array.from(selectedRoleIds),
      preferred_days: Array.from(selectedPreferredDays),
    };
    if (staffId === null) {
      const { data, error: err } = await api.POST('/staff', { body });
      if (err || !data) {
        error = extractErrorMessage(err, 'Could not save staff member');
        return;
      }
      await push(`/staff/${data.id}/edit`);
    } else {
      const { error: err } = await api.PATCH('/staff/{staff_id}', {
        params: { path: { staff_id: staffId } },
        body,
      });
      if (err) {
        error = extractErrorMessage(err, 'Could not save staff member');
      }
    }
  }

  async function addUnavailability(event: SubmitEvent) {
    event.preventDefault();
    if (staffId === null) return;
    const { data, error: err } = await api.POST(
      '/staff/{staff_id}/unavailabilities',
      {
        params: { path: { staff_id: staffId } },
        body: {
          start_date: newUnavailabilityStart,
          end_date: newUnavailabilityEnd,
          reason: newUnavailabilityReason || null,
        },
      },
    );
    if (err || !data) {
      error = extractErrorMessage(err, 'Could not add unavailability');
      return;
    }
    unavailabilities = [...unavailabilities, data];
    newUnavailabilityStart = '';
    newUnavailabilityEnd = '';
    newUnavailabilityReason = '';
  }

  async function removeUnavailability(id: number) {
    if (staffId === null) return;
    const { error: err } = await api.DELETE(
      '/staff/{staff_id}/unavailabilities/{unavailability_id}',
      {
        params: { path: { staff_id: staffId, unavailability_id: id } },
      },
    );
    if (err) {
      error = 'Could not remove unavailability';
      return;
    }
    unavailabilities = unavailabilities.filter((u) => u.id !== id);
  }
</script>

<h1>{staffId === null ? 'New Staff Member' : 'Edit Staff Member'}</h1>
<ErrorBanner message={error} />

<form onsubmit={save}>
  <label>
    Name
    <input type="text" bind:value={name} required />
  </label>
  <label class="checkbox-row">
    <input type="checkbox" bind:checked={active} />
    Active
  </label>
  <fieldset>
    <legend>Roles</legend>
    {#each roles as role (role.id)}
      <label class="checkbox-row">
        <input
          type="checkbox"
          checked={selectedRoleIds.has(role.id)}
          onchange={() => toggle(selectedRoleIds, role.id)}
        />
        {role.name}
      </label>
    {/each}
  </fieldset>
  <fieldset>
    <legend>Preferred days</legend>
    {#each DAY_NAMES as dayName, index (index)}
      <label class="checkbox-row">
        <input
          type="checkbox"
          checked={selectedPreferredDays.has(index)}
          onchange={() => toggle(selectedPreferredDays, index)}
        />
        {dayName}
      </label>
    {/each}
  </fieldset>
  <button type="submit">Save</button>
</form>

{#if staffId !== null}
  <h2>Unavailability</h2>
  <UnavailabilityCalendar staff={staffForCalendar} highlightStaffId={staffId} />
  <table>
    <thead>
      <tr>
        <th>Start</th>
        <th>End</th>
        <th>Reason</th>
        <th></th>
      </tr>
    </thead>
    <tbody>
      {#each unavailabilities as unavailability (unavailability.id)}
        <tr>
          <td>{unavailability.start_date}</td>
          <td>{unavailability.end_date}</td>
          <td>{unavailability.reason ?? ''}</td>
          <td
            ><button onclick={() => removeUnavailability(unavailability.id)}
              >Remove</button
            ></td
          >
        </tr>
      {/each}
    </tbody>
  </table>

  <form onsubmit={addUnavailability}>
    <label>
      Start date
      <input type="date" bind:value={newUnavailabilityStart} required />
    </label>
    <label>
      End date
      <input type="date" bind:value={newUnavailabilityEnd} required />
    </label>
    <label>
      Reason
      <input type="text" bind:value={newUnavailabilityReason} />
    </label>
    <button type="submit">Add Unavailability</button>
  </form>
{/if}
