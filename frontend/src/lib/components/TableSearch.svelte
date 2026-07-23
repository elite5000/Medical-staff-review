<script lang="ts">
  let {
    value = $bindable(''),
    placeholder = 'Search…',
  }: { value?: string; placeholder?: string } = $props();
</script>

<input
  type="search"
  class="table-search"
  {placeholder}
  aria-label={placeholder}
  bind:value
/>
