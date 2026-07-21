<script lang="ts">
  import { push } from 'svelte-spa-router';

  import { extractErrorMessage } from '../../lib/api/errors';
  import { api } from '../../lib/api/client';
  import type { components } from '../../lib/api/schema';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';

  type Role = components['schemas']['RoleRead'];
  type Building = components['schemas']['BuildingRead'];
  type Tag = components['schemas']['TagRead'];
  type RuleType = components['schemas']['RuleType'];

  let ruleType: RuleType = $state('minimum_count');
  let roleId: number | null = $state(null);
  let targetType: 'building' | 'tag' = $state('building');
  let buildingId: number | null = $state(null);
  let tagId: number | null = $state(null);
  let minimumCount = $state(1);

  let roles: Role[] = $state([]);
  let buildings: Building[] = $state([]);
  let tags: Tag[] = $state([]);
  let error: string | null = $state(null);

  async function loadOptions() {
    const [rolesRes, buildingsRes, tagsRes] = await Promise.all([
      api.GET('/roles'),
      api.GET('/buildings'),
      api.GET('/tags'),
    ]);
    roles = rolesRes.data ?? [];
    buildings = buildingsRes.data ?? [];
    tags = tagsRes.data ?? [];
    roleId ??= roles[0]?.id ?? null;
    buildingId ??= buildings[0]?.id ?? null;
    tagId ??= tags[0]?.id ?? null;
  }

  loadOptions();

  async function save(event: SubmitEvent) {
    event.preventDefault();
    error = null;
    if (roleId === null) {
      error = 'A role is required';
      return;
    }
    const body =
      ruleType === 'eligibility_restriction'
        ? { rule_type: ruleType, role_id: roleId, tag_id: tagId }
        : {
            rule_type: ruleType,
            role_id: roleId,
            minimum_count: minimumCount,
            building_id: targetType === 'building' ? buildingId : null,
            tag_id: targetType === 'tag' ? tagId : null,
          };
    const { error: err } = await api.POST('/rules', { body });
    if (err) {
      error = extractErrorMessage(err, 'Could not save rule');
      return;
    }
    await push('/rules');
  }
</script>

<h1>New Rule</h1>
<ErrorBanner message={error} />

<form onsubmit={save}>
  <label>
    Rule type
    <select bind:value={ruleType}>
      <option value="minimum_count">Minimum count</option>
      <option value="eligibility_restriction">Eligibility restriction</option>
    </select>
  </label>
  <label>
    Role
    <select bind:value={roleId}>
      {#each roles as role (role.id)}
        <option value={role.id}>{role.name}</option>
      {/each}
    </select>
  </label>

  {#if ruleType === 'minimum_count'}
    <label>
      Applies to
      <select bind:value={targetType}>
        <option value="building">Building</option>
        <option value="tag">Tag</option>
      </select>
    </label>
    {#if targetType === 'building'}
      <label>
        Building
        <select bind:value={buildingId}>
          {#each buildings as building (building.id)}
            <option value={building.id}>{building.name}</option>
          {/each}
        </select>
      </label>
    {:else}
      <label>
        Tag
        <select bind:value={tagId}>
          {#each tags as tag (tag.id)}
            <option value={tag.id}>{tag.name}</option>
          {/each}
        </select>
      </label>
    {/if}
    <label>
      Minimum count
      <input type="number" min="1" bind:value={minimumCount} required />
    </label>
  {:else}
    <label>
      Tag
      <select bind:value={tagId}>
        {#each tags as tag (tag.id)}
          <option value={tag.id}>{tag.name}</option>
        {/each}
      </select>
    </label>
  {/if}

  <button type="submit">Save</button>
</form>
