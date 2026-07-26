<script lang="ts">
  import { link } from 'svelte-spa-router';

  import { api } from '../../lib/api/client';
  import { resizableColumns } from '../../lib/actions/resizableColumns';
  import type { components } from '../../lib/api/schema';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';
  import TableSearch from '../../lib/components/TableSearch.svelte';

  type Role = components['schemas']['RoleRead'];

  let roles: Role[] = $state([]);
  let error: string | null = $state(null);
  let query = $state('');

  const filteredRoles = $derived(
    roles.filter((r) => r.name.toLowerCase().includes(query.toLowerCase())),
  );

  async function load() {
    const { data, error: err } = await api.GET('/roles');
    if (err) {
      error = 'Failed to load roles';
      return;
    }
    roles = data ?? [];
  }

  async function remove(id: number) {
    if (!confirm('Delete this role?')) return;
    const { error: err } = await api.DELETE('/roles/{role_id}', {
      params: { path: { role_id: id } },
    });
    if (err) {
      error =
        'Could not delete role — it may still be held by staff or referenced by rules';
      return;
    }
    await load();
  }

  load();
</script>

<h1>Roles</h1>
<ErrorBanner message={error} />

<div class="actions">
  <a href="/roles/new" use:link>New Role</a>
</div>

<TableSearch bind:value={query} placeholder="Search roles…" />

<table use:resizableColumns>
  <thead>
    <tr>
      <th>Name</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    {#each filteredRoles as role (role.id)}
      <tr>
        <td>{role.name}</td>
        <td>
          <a href={`/roles/${role.id}/edit`} use:link>Edit</a>
          <button onclick={() => remove(role.id)}>Delete</button>
        </td>
      </tr>
    {/each}
  </tbody>
</table>
