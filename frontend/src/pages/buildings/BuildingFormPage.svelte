<script lang="ts">
  import { push } from 'svelte-spa-router';

  import { extractErrorMessage } from '../../lib/api/errors';
  import { api } from '../../lib/api/client';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';
  import { minutesToTime, timeToMinutes } from '../../lib/utils/time';

  let { params = {} }: { params?: { id?: string } } = $props();
  const buildingId = $derived(params.id ? Number(params.id) : null);

  let name = $state('');
  let openingTime = $state('08:00');
  let closingTime = $state('18:00');
  let error: string | null = $state(null);

  async function load(id: number) {
    const { data, error: err } = await api.GET('/buildings/{building_id}', {
      params: { path: { building_id: id } },
    });
    if (err || !data) {
      error = 'Failed to load building';
      return;
    }
    name = data.name;
    openingTime = minutesToTime(data.opening_minutes);
    closingTime = minutesToTime(data.closing_minutes);
  }

  $effect(() => {
    if (buildingId !== null) load(buildingId);
  });

  async function save(event: SubmitEvent) {
    event.preventDefault();
    error = null;
    const body = {
      name,
      opening_minutes: timeToMinutes(openingTime),
      closing_minutes: timeToMinutes(closingTime),
    };
    const { error: err } =
      buildingId === null
        ? await api.POST('/buildings', { body })
        : await api.PATCH('/buildings/{building_id}', {
            params: { path: { building_id: buildingId } },
            body,
          });
    if (err) {
      error = extractErrorMessage(err, 'Could not save building');
      return;
    }
    await push('/buildings');
  }
</script>

<h1>{buildingId === null ? 'New Building' : 'Edit Building'}</h1>
<ErrorBanner message={error} />

<form onsubmit={save}>
  <label>
    Name
    <input type="text" bind:value={name} required />
  </label>
  <label>
    Opening time
    <input type="time" bind:value={openingTime} required />
  </label>
  <label>
    Closing time
    <input type="time" bind:value={closingTime} required />
  </label>
  <button type="submit">Save</button>
</form>
