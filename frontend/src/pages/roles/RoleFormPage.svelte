<script lang="ts">
  import { push } from 'svelte-spa-router';

  import { extractErrorMessage } from '../../lib/api/errors';
  import { api } from '../../lib/api/client';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';

  let { params = {} }: { params?: { id?: string } } = $props();
  const roleId = $derived(params.id ? Number(params.id) : null);

  let name = $state('');
  let error: string | null = $state(null);

  async function load(id: number) {
    const { data, error: err } = await api.GET('/roles/{role_id}', {
      params: { path: { role_id: id } },
    });
    if (err || !data) {
      error = 'Failed to load role';
      return;
    }
    name = data.name;
  }

  $effect(() => {
    if (roleId !== null) load(roleId);
  });

  async function save(event: SubmitEvent) {
    event.preventDefault();
    error = null;
    const { error: err } =
      roleId === null
        ? await api.POST('/roles', { body: { name } })
        : await api.PATCH('/roles/{role_id}', {
            params: { path: { role_id: roleId } },
            body: { name },
          });
    if (err) {
      error = extractErrorMessage(err, 'Could not save role');
      return;
    }
    await push('/roles');
  }
</script>

<h1>{roleId === null ? 'New Role' : 'Edit Role'}</h1>
<ErrorBanner message={error} />

<form onsubmit={save}>
  <label>
    Name
    <input type="text" bind:value={name} required />
  </label>
  <button type="submit">Save</button>
</form>
