<script lang="ts">
  export type NavIconName =
    | 'rosters'
    | 'buildings'
    | 'rooms'
    | 'tags'
    | 'roles'
    | 'staff'
    | 'rules'
    | 'settings';

  let { name }: { name: NavIconName } = $props();
</script>

<svg
  viewBox="0 0 24 24"
  fill="none"
  stroke="currentColor"
  stroke-width="1.6"
  stroke-linecap="round"
  stroke-linejoin="round"
  aria-hidden="true"
>
  {#if name === 'rosters'}
    <rect x="3.5" y="4.5" width="17" height="16" rx="2" />
    <line x1="3.5" y1="9.5" x2="20.5" y2="9.5" />
    <line x1="8" y1="2.5" x2="8" y2="6.5" />
    <line x1="16" y1="2.5" x2="16" y2="6.5" />
  {:else if name === 'buildings'}
    <rect x="4.5" y="3.5" width="15" height="17" rx="1" />
    <rect x="9.5" y="14" width="5" height="6.5" />
    <rect x="7.2" y="7" width="1.6" height="1.6" />
    <rect x="11.2" y="7" width="1.6" height="1.6" />
    <rect x="15.2" y="7" width="1.6" height="1.6" />
    <rect x="7.2" y="10.5" width="1.6" height="1.6" />
    <rect x="15.2" y="10.5" width="1.6" height="1.6" />
  {:else if name === 'rooms'}
    <rect x="6" y="3" width="12" height="18" rx="1" />
    <circle cx="14.5" cy="12" r="0.9" fill="currentColor" stroke="none" />
  {:else if name === 'tags'}
    <path
      d="M3.5 11.5 11.5 3.5h7a2 2 0 0 1 2 2v7l-8 8a2 2 0 0 1-2.8 0l-6.2-6.2a2 2 0 0 1 0-2.8Z"
    />
    <circle cx="16" cy="8" r="1.4" />
  {:else if name === 'roles'}
    <path d="M12 3.5 19 6.5v5c0 4.5-2.9 7.3-7 8.5-4.1-1.2-7-4-7-8.5v-5Z" />
  {:else if name === 'staff'}
    <circle cx="12" cy="8" r="3.4" />
    <path d="M5 20.5c0-4.1 3.1-6.5 7-6.5s7 2.4 7 6.5" />
  {:else if name === 'rules'}
    <rect x="4" y="4.5" width="3" height="3" rx="0.5" />
    <line x1="9.5" y1="6" x2="20" y2="6" />
    <rect x="4" y="10.5" width="3" height="3" rx="0.5" />
    <line x1="9.5" y1="12" x2="20" y2="12" />
    <rect x="4" y="16.5" width="3" height="3" rx="0.5" />
    <line x1="9.5" y1="18" x2="20" y2="18" />
  {:else if name === 'settings'}
    <line x1="6.5" y1="4" x2="6.5" y2="20" />
    <circle cx="6.5" cy="9" r="2" />
    <line x1="12" y1="4" x2="12" y2="20" />
    <circle cx="12" cy="16" r="2" />
    <line x1="17.5" y1="4" x2="17.5" y2="20" />
    <circle cx="17.5" cy="7" r="2" />
  {/if}
</svg>
