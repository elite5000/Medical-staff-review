<script lang="ts">
  import { push } from 'svelte-spa-router';

  import { api } from '../../lib/api/client';
  import { extractErrorMessage } from '../../lib/api/errors';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';

  let startDate = $state('');
  let numDays = $state(14);
  let error: string | null = $state(null);
  let generating = $state(false);

  async function generate(event: SubmitEvent) {
    event.preventDefault();
    error = null;
    generating = true;
    const { data, error: err } = await api.POST('/rosters', {
      body: { start_date: startDate, num_days: numDays },
    });
    generating = false;
    if (err || !data) {
      error = extractErrorMessage(err, 'Could not generate roster');
      return;
    }
    await push(`/rosters/${data.id}`);
  }
</script>

<h1>Generate Roster</h1>
<ErrorBanner message={error} />

<form onsubmit={generate}>
  <label>
    Start date
    <input type="date" bind:value={startDate} required />
  </label>
  <label>
    Number of days
    <input type="number" min="1" bind:value={numDays} required />
  </label>
  <button type="submit" disabled={generating}>
    {generating ? 'Generating…' : 'Generate'}
  </button>
</form>
