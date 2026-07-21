<script lang="ts">
  import Router from 'svelte-spa-router';

  import { routes } from './routes';

  const navItems = [
    { href: '#/rosters', label: 'Rosters' },
    { href: '#/buildings', label: 'Buildings' },
    { href: '#/rooms', label: 'Rooms' },
    { href: '#/tags', label: 'Tags' },
    { href: '#/roles', label: 'Roles' },
    { href: '#/staff', label: 'Staff' },
    { href: '#/rules', label: 'Rules' },
    { href: '#/settings', label: 'Settings' },
  ];
</script>

<nav>
  <ul>
    {#each navItems as item (item.href)}
      <li><a href={item.href}>{item.label}</a></li>
    {/each}
  </ul>
</nav>

<main>
  <Router {routes} />
</main>
