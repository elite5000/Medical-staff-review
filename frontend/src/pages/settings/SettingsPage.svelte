<script lang="ts">
  import { api } from '../../lib/api/client';
  import { extractErrorMessage } from '../../lib/api/errors';
  import ErrorBanner from '../../lib/components/ErrorBanner.svelte';

  let shiftLengthMinutes = $state(240);
  let travelTimeMinutes = $state(30);
  let maxDailyMinutes = $state(720);
  let error: string | null = $state(null);
  let saved = $state(false);

  async function load() {
    const { data, error: err } = await api.GET('/settings');
    if (err || !data) {
      error = 'Failed to load settings';
      return;
    }
    shiftLengthMinutes = data.shift_length_minutes;
    travelTimeMinutes = data.travel_time_minutes;
    maxDailyMinutes = data.max_daily_minutes;
  }

  load();

  async function save(event: SubmitEvent) {
    event.preventDefault();
    error = null;
    saved = false;
    const { error: err } = await api.PATCH('/settings', {
      body: {
        shift_length_minutes: shiftLengthMinutes,
        travel_time_minutes: travelTimeMinutes,
        max_daily_minutes: maxDailyMinutes,
      },
    });
    if (err) {
      error = extractErrorMessage(err, 'Could not save settings');
      return;
    }
    saved = true;
  }
</script>

<h1>Settings</h1>
<ErrorBanner message={error} />
{#if saved}<p>Saved.</p>{/if}

<form onsubmit={save}>
  <label>
    Shift length (minutes)
    <input type="number" min="1" bind:value={shiftLengthMinutes} required />
  </label>
  <label>
    Travel time between buildings (minutes)
    <input type="number" min="0" bind:value={travelTimeMinutes} required />
  </label>
  <label>
    Max daily hours (minutes)
    <input type="number" min="1" bind:value={maxDailyMinutes} required />
  </label>
  <button type="submit">Save</button>
</form>
