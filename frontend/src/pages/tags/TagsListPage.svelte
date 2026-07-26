<script lang="ts">
  import { link } from 'svelte-spa-router';

  import { api } from '../../lib/api/client';
  import { resizableColumns } from '../../lib/actions/resizableColumns';
  import type { components } from '../../lib/api/schema';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';
  import TableSearch from '../../lib/components/TableSearch.svelte';

  type Tag = components['schemas']['TagRead'];

  let tags: Tag[] = $state([]);
  let error: string | null = $state(null);
  let query = $state('');

  const filteredTags = $derived(
    tags.filter((t) => t.name.toLowerCase().includes(query.toLowerCase())),
  );

  async function load() {
    const { data, error: err } = await api.GET('/tags');
    if (err) {
      error = 'Failed to load tags';
      return;
    }
    tags = data ?? [];
  }

  async function remove(id: number) {
    if (!confirm('Delete this tag?')) return;
    const { error: err } = await api.DELETE('/tags/{tag_id}', {
      params: { path: { tag_id: id } },
    });
    if (err) {
      error =
        'Could not delete tag — it may still be attached to rooms or rules';
      return;
    }
    await load();
  }

  load();
</script>

<h1>Tags</h1>
<ErrorBanner message={error} />

<div class="actions">
  <a href="/tags/new" use:link>New Tag</a>
</div>

<TableSearch bind:value={query} placeholder="Search tags…" />

<table use:resizableColumns>
  <thead>
    <tr>
      <th>Name</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    {#each filteredTags as tag (tag.id)}
      <tr>
        <td>{tag.name}</td>
        <td>
          <a href={`/tags/${tag.id}/edit`} use:link>Edit</a>
          <button onclick={() => remove(tag.id)}>Delete</button>
        </td>
      </tr>
    {/each}
  </tbody>
</table>
