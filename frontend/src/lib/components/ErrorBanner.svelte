<script lang="ts">
  let { message }: { message: string | null } = $props();
</script>

{#if message}
  <p class="error-banner" role="alert">{message}</p>
{/if}
