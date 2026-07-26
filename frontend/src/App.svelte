<script lang="ts">
  import Router, { link } from 'svelte-spa-router';
  import active from 'svelte-spa-router/active';

  import { routes } from './routes';
  import NavIcon from './lib/components/NavIcon.svelte';
  import type { NavIconName } from './lib/components/NavIcon.svelte';

  // Prefix-matched (not exact) so e.g. viewing /rosters/42 or /buildings/7/edit still
  // highlights the parent section's nav item, not just its bare list route.
  const navItems: {
    href: string;
    label: string;
    icon: NavIconName;
    activePath: RegExp;
  }[] = [
    {
      href: '#/rosters',
      label: 'Rosters',
      icon: 'rosters',
      activePath: /^\/rosters(\/|$)/,
    },
    {
      href: '#/buildings',
      label: 'Buildings',
      icon: 'buildings',
      activePath: /^\/buildings(\/|$)/,
    },
    {
      href: '#/rooms',
      label: 'Rooms',
      icon: 'rooms',
      activePath: /^\/rooms(\/|$)/,
    },
    {
      href: '#/tags',
      label: 'Tags',
      icon: 'tags',
      activePath: /^\/tags(\/|$)/,
    },
    {
      href: '#/roles',
      label: 'Roles',
      icon: 'roles',
      activePath: /^\/roles(\/|$)/,
    },
    {
      href: '#/staff',
      label: 'Staff',
      icon: 'staff',
      activePath: /^\/staff(\/|$)/,
    },
    {
      href: '#/rules',
      label: 'Rules',
      icon: 'rules',
      activePath: /^\/rules(\/|$)/,
    },
    {
      href: '#/settings',
      label: 'Settings',
      icon: 'settings',
      activePath: /^\/settings(\/|$)/,
    },
  ];
</script>

<nav>
  <div class="nav-brand">
    <span class="nav-brand-mark"></span>
    Medical Staff Review
  </div>
  <ul>
    {#each navItems as item (item.href)}
      <li>
        <a href={item.href} use:link use:active={{ path: item.activePath }}>
          <NavIcon name={item.icon} />
          {item.label}
        </a>
      </li>
    {/each}
  </ul>
</nav>

<main>
  <Router {routes} />
</main>
