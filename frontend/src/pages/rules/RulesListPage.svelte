<script lang="ts">
  import { link } from 'svelte-spa-router';

  import { api } from '../../lib/api/client';
  import { resizableColumns } from '../../lib/actions/resizableColumns';
  import type { components } from '../../lib/api/schema';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';
  import TableSearch from '../../lib/components/TableSearch.svelte';

  type Rule = components['schemas']['RuleRead'];
  type Role = components['schemas']['RoleRead'];
  type Building = components['schemas']['BuildingRead'];
  type Tag = components['schemas']['TagRead'];

  let rules: Rule[] = $state([]);
  let rolesById: Map<number, Role> = $state(new Map());
  let buildingsById: Map<number, Building> = $state(new Map());
  let tagsById: Map<number, Tag> = $state(new Map());
  let error: string | null = $state(null);
  let query = $state('');

  const filteredRules = $derived(
    rules.filter((r) => r.name.toLowerCase().includes(query.toLowerCase())),
  );

  async function load() {
    const [rulesRes, rolesRes, buildingsRes, tagsRes] = await Promise.all([
      api.GET('/rules'),
      api.GET('/roles'),
      api.GET('/buildings'),
      api.GET('/tags'),
    ]);
    if (rulesRes.error) {
      error = 'Failed to load rules';
      return;
    }
    rules = rulesRes.data ?? [];
    rolesById = new Map((rolesRes.data ?? []).map((r) => [r.id, r]));
    buildingsById = new Map((buildingsRes.data ?? []).map((b) => [b.id, b]));
    tagsById = new Map((tagsRes.data ?? []).map((t) => [t.id, t]));
  }

  function target(rule: Rule): string {
    if (rule.building_id != null)
      return `Building: ${buildingsById.get(rule.building_id)?.name ?? '—'}`;
    if (rule.tag_id != null)
      return `Tag: ${tagsById.get(rule.tag_id)?.name ?? '—'}`;
    return '—';
  }

  async function remove(id: number) {
    if (!confirm('Delete this rule?')) return;
    const { error: err } = await api.DELETE('/rules/{rule_id}', {
      params: { path: { rule_id: id } },
    });
    if (err) {
      error =
        'Could not delete rule — it may be referenced by past roster violation history';
      return;
    }
    await load();
  }

  load();
</script>

<h1>Rules</h1>
<ErrorBanner message={error} />

<div class="actions">
  <a href="/rules/new" use:link>New Rule</a>
</div>

<TableSearch bind:value={query} placeholder="Search rules…" />

<table use:resizableColumns>
  <thead>
    <tr>
      <th>Name</th>
      <th>Type</th>
      <th>Role</th>
      <th>Target</th>
      <th>Minimum count</th>
      <th></th>
    </tr>
  </thead>
  <tbody>
    {#each filteredRules as rule (rule.id)}
      <tr>
        <td>{rule.name}</td>
        <td
          >{rule.rule_type === 'minimum_count'
            ? 'Minimum count'
            : 'Eligibility restriction'}</td
        >
        <td>{rolesById.get(rule.role_id)?.name ?? '—'}</td>
        <td>{target(rule)}</td>
        <td>{rule.minimum_count ?? ''}</td>
        <td><button onclick={() => remove(rule.id)}>Delete</button></td>
      </tr>
    {/each}
  </tbody>
</table>
