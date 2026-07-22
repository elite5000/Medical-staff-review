<script lang="ts">
  import type { components } from '../api/schema';
  import { DAY_NAMES } from '../utils/time';

  type Staff = components['schemas']['StaffRead'];

  let {
    staff,
    highlightStaffId = null,
  }: {
    staff: Staff[];
    highlightStaffId?: number | null;
  } = $props();

  const today = new Date();
  let viewYear = $state(today.getFullYear());
  let viewMonth = $state(today.getMonth());

  function toISO(y: number, m: number, d: number): string {
    return `${y}-${String(m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
  }

  function shiftMonth(delta: number) {
    let m = viewMonth + delta;
    let y = viewYear;
    if (m < 0) {
      m = 11;
      y -= 1;
    } else if (m > 11) {
      m = 0;
      y += 1;
    }
    viewMonth = m;
    viewYear = y;
  }

  // Golden-angle-ish spread keeps adjacent staff ids visually distinct.
  function colorFor(id: number): string {
    return `hsl(${(id * 137) % 360} 65% 45%)`;
  }

  const monthLabel = $derived(
    new Date(viewYear, viewMonth, 1).toLocaleDateString(undefined, {
      month: 'long',
      year: 'numeric',
    }),
  );

  const daysInMonth = $derived(new Date(viewYear, viewMonth + 1, 0).getDate());

  const weeks = $derived.by(() => {
    const firstOfMonth = new Date(viewYear, viewMonth, 1);
    // Monday-first, matching DAY_NAMES: convert JS's 0=Sun..6=Sat to 0=Mon..6=Sun.
    const firstWeekday = (firstOfMonth.getDay() + 6) % 7;
    const cells: (number | null)[] = [
      ...Array(firstWeekday).fill(null),
      ...Array.from({ length: daysInMonth }, (_, i) => i + 1),
    ];
    while (cells.length % 7 !== 0) cells.push(null);
    const result: (number | null)[][] = [];
    for (let i = 0; i < cells.length; i += 7)
      result.push(cells.slice(i, i + 7));
    return result;
  });

  const unavailableByDay = $derived.by(() => {
    const map = new Map<number, { staff: Staff; reason: string | null }[]>();
    const monthStart = toISO(viewYear, viewMonth, 1);
    const monthEnd = toISO(viewYear, viewMonth, daysInMonth);
    for (const person of staff) {
      for (const u of person.unavailabilities) {
        // ISO 'YYYY-MM-DD' strings sort lexicographically, so plain comparison clamps
        // the range to the visible month without needing a Date parse.
        const start = u.start_date > monthStart ? u.start_date : monthStart;
        const end = u.end_date < monthEnd ? u.end_date : monthEnd;
        if (start > end) continue;
        for (
          let d = Number(start.slice(8, 10));
          d <= Number(end.slice(8, 10));
          d++
        ) {
          const list = map.get(d) ?? [];
          list.push({ staff: person, reason: u.reason });
          map.set(d, list);
        }
      }
    }
    return map;
  });

  const legendStaff = $derived.by(() => {
    const ids = new Set<number>();
    for (const list of unavailableByDay.values()) {
      for (const entry of list) ids.add(entry.staff.id);
    }
    return staff.filter((person) => ids.has(person.id));
  });
</script>

<div class="unavailability-calendar">
  <div class="calendar-header">
    <button
      type="button"
      onclick={() => shiftMonth(-1)}
      aria-label="Previous month">‹</button
    >
    <strong>{monthLabel}</strong>
    <button type="button" onclick={() => shiftMonth(1)} aria-label="Next month"
      >›</button
    >
  </div>
  <table class="calendar-grid">
    <thead>
      <tr>
        {#each DAY_NAMES as dayName (dayName)}
          <th>{dayName}</th>
        {/each}
      </tr>
    </thead>
    <tbody>
      {#each weeks as week, weekIndex (weekIndex)}
        <tr>
          {#each week as day, dayIndex (dayIndex)}
            <td class:empty={day === null}>
              {#if day !== null}
                <div class="day-number">{day}</div>
                <div class="day-dots">
                  {#each unavailableByDay.get(day) ?? [] as entry, entryIndex (entryIndex)}
                    <span
                      class="dot"
                      class:highlighted={entry.staff.id === highlightStaffId}
                      style="background-color: {colorFor(entry.staff.id)}"
                      title={entry.reason
                        ? `${entry.staff.name}: ${entry.reason}`
                        : entry.staff.name}
                    ></span>
                  {/each}
                </div>
              {/if}
            </td>
          {/each}
        </tr>
      {/each}
    </tbody>
  </table>
  {#if legendStaff.length > 0}
    <ul class="calendar-legend">
      {#each legendStaff as person (person.id)}
        <li class:highlighted={person.id === highlightStaffId}>
          <span class="dot" style="background-color: {colorFor(person.id)}"
          ></span>
          {person.name}
        </li>
      {/each}
    </ul>
  {/if}
</div>
