import type { RouteDefinition } from 'svelte-spa-router';

import BuildingFormPage from './pages/buildings/BuildingFormPage.svelte';
import BuildingsListPage from './pages/buildings/BuildingsListPage.svelte';
import NotFoundPage from './pages/NotFoundPage.svelte';
import RoleFormPage from './pages/roles/RoleFormPage.svelte';
import RolesListPage from './pages/roles/RolesListPage.svelte';
import RoomFormPage from './pages/rooms/RoomFormPage.svelte';
import RoomsListPage from './pages/rooms/RoomsListPage.svelte';
import RosterGeneratePage from './pages/rosters/RosterGeneratePage.svelte';
import RosterListPage from './pages/rosters/RosterListPage.svelte';
import RosterViewPage from './pages/rosters/RosterViewPage.svelte';
import RuleFormPage from './pages/rules/RuleFormPage.svelte';
import RulesListPage from './pages/rules/RulesListPage.svelte';
import SettingsPage from './pages/settings/SettingsPage.svelte';
import StaffFormPage from './pages/staff/StaffFormPage.svelte';
import StaffListPage from './pages/staff/StaffListPage.svelte';
import TagFormPage from './pages/tags/TagFormPage.svelte';
import TagsListPage from './pages/tags/TagsListPage.svelte';

export const routes: RouteDefinition = {
  '/': RosterListPage,
  '/rosters': RosterListPage,
  '/rosters/generate': RosterGeneratePage,
  '/rosters/:id': RosterViewPage,
  '/buildings': BuildingsListPage,
  '/buildings/new': BuildingFormPage,
  '/buildings/:id/edit': BuildingFormPage,
  '/rooms': RoomsListPage,
  '/rooms/new': RoomFormPage,
  '/rooms/:id/edit': RoomFormPage,
  '/tags': TagsListPage,
  '/tags/new': TagFormPage,
  '/tags/:id/edit': TagFormPage,
  '/roles': RolesListPage,
  '/roles/new': RoleFormPage,
  '/roles/:id/edit': RoleFormPage,
  '/staff': StaffListPage,
  '/staff/new': StaffFormPage,
  '/staff/:id/edit': StaffFormPage,
  '/rules': RulesListPage,
  '/rules/new': RuleFormPage,
  '/settings': SettingsPage,
  '*': NotFoundPage,
};
