const MIN_COLUMN_WIDTH = 40;

/**
 * Svelte action: lets the user drag a handle on each `<th>`'s right edge to widen/narrow that
 * column. Switches the table to `table-layout: fixed` and freezes each header's current
 * rendered width as an inline style first, so the switch itself doesn't jump the layout —
 * `fixed` tables size columns from the first row's widths rather than content.
 */
export function resizableColumns(table: HTMLTableElement) {
  const headers = Array.from(table.querySelectorAll('thead th'));
  if (headers.length === 0) {
    return {};
  }

  table.style.tableLayout = 'fixed';

  let activeHeader: HTMLElement | null = null;
  let startX = 0;
  let startWidth = 0;

  function onPointerMove(event: PointerEvent) {
    if (!activeHeader) return;
    const delta = event.clientX - startX;
    activeHeader.style.width = `${Math.max(MIN_COLUMN_WIDTH, startWidth + delta)}px`;
  }

  function onPointerUp() {
    activeHeader = null;
    document.removeEventListener('pointermove', onPointerMove);
    document.removeEventListener('pointerup', onPointerUp);
  }

  const cleanupFns: (() => void)[] = [];

  for (const header of headers) {
    const th = header as HTMLElement;
    th.style.width = `${th.getBoundingClientRect().width}px`;
    th.style.position = 'relative';

    const handle = document.createElement('span');
    handle.className = 'col-resize-handle';
    handle.setAttribute('aria-hidden', 'true');

    function onPointerDown(event: PointerEvent) {
      event.preventDefault();
      activeHeader = th;
      startX = event.clientX;
      startWidth = th.getBoundingClientRect().width;
      document.addEventListener('pointermove', onPointerMove);
      document.addEventListener('pointerup', onPointerUp);
    }

    handle.addEventListener('pointerdown', onPointerDown);
    th.appendChild(handle);
    cleanupFns.push(() =>
      handle.removeEventListener('pointerdown', onPointerDown),
    );
  }

  return {
    destroy() {
      document.removeEventListener('pointermove', onPointerMove);
      document.removeEventListener('pointerup', onPointerUp);
      for (const cleanup of cleanupFns) cleanup();
    },
  };
}
