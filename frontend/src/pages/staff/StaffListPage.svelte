<script lang="ts">
  import { link } from 'svelte-spa-router';

  import { api } from '../../lib/api/client';
  import type { components } from '../../lib/api/schema';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';

  type Staff = components['schemas']['StaffRead'];

  let staff: Staff[] = $state([]);
  let error: string | null = $state(null);

  async function load() {
    const { data, error: err } = await api.GET('/staff');
    if (err) {
      error = 'Failed to load staff';
      return;
    }
    staff = data ?? [];
  }

  async function remove(id: number) {
    if (!confirm('Delete this staff member?')) return;
    const { error: err } = await api.DELETE('/staff/{staff_id}', {
      params: { path: { staff_id: id } },
    });
    if (err) {
      error =
        'Could not delete staff member who appears in a generated roster — deactivate instead';
      return;
    }
    await load();
  }

  load();
</script>

<h1>Staff</h1>
<ErrorBanner message={error} />

<div class="actions">
  <a href="/staff/new" use:link>New Staff Member</a>
</div>

<table>
  <thead>
    <tr>
      <th>Name</th>
      <th>Active</th>
      <th>Roles</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    {#each staff as person (person.id)}
      <tr>
        <td>{person.name}</td>
        <td>{person.active ? 'Yes' : 'No'}</td>
        <td>{person.roles.map((r) => r.name).join(', ')}</td>
        <td>
          <a href={`/staff/${person.id}/edit`} use:link>Edit</a>
          <button onclick={() => remove(person.id)}>Delete</button>
        </td>
      </tr>
    {/each}
  </tbody>
</table>
