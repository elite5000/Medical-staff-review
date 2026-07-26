<script lang="ts">
  import { push } from 'svelte-spa-router';

  import { extractErrorMessage } from '../../lib/api/errors';
  import { api } from '../../lib/api/client';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';

  let { params = {} }: { params?: { id?: string } } = $props();
  const tagId = $derived(params.id ? Number(params.id) : null);

  let name = $state('');
  let error: string | null = $state(null);

  async function load(id: number) {
    const { data, error: err } = await api.GET('/tags/{tag_id}', {
      params: { path: { tag_id: id } },
    });
    if (err || !data) {
      error = 'Failed to load tag';
      return;
    }
    name = data.name;
  }

  $effect(() => {
    if (tagId !== null) load(tagId);
  });

  async function save(event: SubmitEvent) {
    event.preventDefault();
    error = null;
    const { error: err } =
      tagId === null
        ? await api.POST('/tags', { body: { name } })
        : await api.PATCH('/tags/{tag_id}', {
            params: { path: { tag_id: tagId } },
            body: { name },
          });
    if (err) {
      error = extractErrorMessage(err, 'Could not save tag');
      return;
    }
    await push('/tags');
  }
</script>

<h1>{tagId === null ? 'New Tag' : 'Edit Tag'}</h1>
<ErrorBanner message={error} />

<form onsubmit={save}>
  <label>
    Name
    <input type="text" bind:value={name} required />
  </label>
  <button type="submit">Save</button>
</form>
