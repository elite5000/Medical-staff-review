# Medical Staff Review

A fortnightly roster builder for a multi-building medical practice. Staff are assigned to rooms for shifts, subject to role rules, ensuring every room is covered by qualified personnel during opening hours.

## Table of Contents

1. [Domain Concepts & Vocabulary](#domain-concepts--vocabulary)
2. [Architecture & Project Structure](#architecture--project-structure)
3. [Constraint Solver Hierarchy](#constraint-solver-hierarchy)
4. [Getting Started & Local Setup](#getting-started--local-setup)
   - [Prerequisites](#prerequisites)
   - [Backend Setup](#backend-setup)
   - [Frontend Setup](#frontend-setup)
5. [Running the Application](#running-the-application)
6. [Testing](#testing)
   - [Backend Unit/Integration Tests](#backend-unitintegration-tests)
   - [Frontend Unit Tests](#frontend-unit-tests)
   - [End-to-End (E2E) Tests](#end-to-end-e2e-tests)
7. [Code Quality & Styling](#code-quality--styling)

---

## Domain Concepts & Vocabulary

To understand and work on the codebase, you should familiarize yourself with the following domain-specific terms:

- **Role**:
  The single source of truth for what a Staff member is qualified to do (e.g., _Senior Fellow_, _Junior Fellow_, _Emergency Medicine_, _Nurse Practitioner_). Rules, room eligibility, and rostering all key off Roles. A Staff member can hold multiple Roles simultaneously. One Shift assignment counts toward every Rule matched by any Role they hold.
  _Avoid_: "Doctor", "Nurse" — these are not modeled entities, at most cosmetic labels never referenced by Rules.

- **Tag**:
  A label attached to a Room describing what kind of work happens there (e.g., _General Practice_, _Surgery_, _Nurse Practitioner Room_, _Emergency Department_). Rules attach to Tags to restrict or require Roles. A Room may carry multiple Tags; when more than one Tag carries an eligibility-restriction rule, a staff member need only satisfy one of them (union, not intersection) to be eligible for the room.

- **Rule**:
  A constraint the roster must satisfy. Rules come in exactly two shapes:
  1. **Minimum-count rule**: "This Building or Tag needs at least $N$ staff holding Role $X$ present".
  2. **Eligibility-restriction rule**: "Only Role $X$ may work in rooms with Tag $Y$".

- **Shift**:
  A block of time of the app-wide Shift Length, during which one Staff member occupies one Room.

- **Preferred Days**:
  A Staff member's standing, recurring day-of-week preference (e.g., "Mon, Wed, Fri"), set independently per week of the fortnight — a Staff member may prefer Monday in week 1 and Tuesday in week 2. The pattern repeats every two weeks for rosters longer than a fortnight. This is a soft goal that the solver optimizes for but may break if necessary.
  _Avoid_: "Availability" (use "Unavailability" instead for hard blocks).

- **Unavailability**:
  A hard, date-specific block on a Staff member (e.g., approved leave). The roster must never assign a Shift to a Staff member on their Unavailability date.

- **Roster**:
  A generated 14-day schedule of Shift assignments for a practice, tied to a specific date range. Assignments that a user has manually edited become **pinned**; regenerating the Roster treats pinned assignments as fixed and only solves around the remaining open Shifts. Every Roster ever generated is retained permanently for review/audit.

---

## Architecture & Project Structure

The project is structured as a monorepo containing a Python backend and a Svelte frontend:

- **`backend/`**: A Python-based FastAPI application using SQLAlchemy and SQLite for data persistence, Alembic for database migrations, and Google OR-Tools for constraint satisfaction optimization.
- **`frontend/`**: A modern Svelte application built with Vite and Svelte-SPA-Router, fully typed with TypeScript.
- **`e2e/`**: End-to-end integration tests written with Playwright.
- **`docs/`**: Architecture Decision Records (ADR) and additional documentation.

---

## Constraint Solver Hierarchy

The roster builder relies on Google OR-Tools to solve the complex rostering constraints. The solver distinguishes between hard constraints (which must never be violated) and prioritized soft goals (which it optimizes for):

### Hard Constraints (Never Violated)

- **Eligibility-restriction rules**: Staff must be qualified for the room's tags.
- **Max Daily Hours**: No staff member may exceed daily working hours limits.
- **Unavailability**: No shifts assigned during approved leave/unavailability.
- **Travel Time**: Incorporates travel time between buildings if assignments change.
- **Single-occupancy**: One person per room per shift limit.

### Soft Goals (Optimized in Priority Order)

1. **Minimum-count rules**: Ensuring the building/tag has the required minimum role counts.
2. **Room-fill goal**: Maximizing the number of rooms covered with staff.
3. **Preferred Days**: Aligning assignments with staff's standing weekday preferences.

This hierarchy ensures that during understaffing periods, the solver still outputs a usable roster rather than failing completely. Violations of minimum-count rules are surfaced as loud, explicit flags in the UI for human intervention.

---

## Getting Started & Local Setup

### Prerequisites

- **Node.js**: `v20` or higher
- **Python**: `v3.13` or higher
- **uv**: Fast Python package installer and resolver (highly recommended)

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install Python dependencies using `uv`:
   ```bash
   uv sync
   ```
3. Run database migrations to set up the SQLite database:
   ```bash
   uv run alembic upgrade head
   ```
4. Start the FastAPI development server:
   ```bash
   uv run uvicorn app.main:app --reload --port 8000
   ```
   The backend API will be available at `http://localhost:8000` and the interactive OpenAPI docs at `http://localhost:8000/docs`.

### Frontend Setup

1. Install all npm dependencies from the repository root:
   ```bash
   npm install
   ```
2. Start the Vite development server:
   ```bash
   npm run dev --workspace=frontend
   ```
   The frontend will be accessible at `http://localhost:5173`.

---

## Running the Application

To run the full stack locally for development:

1. In one terminal, start the FastAPI backend:
   ```bash
   cd backend
   uv run uvicorn app.main:app --reload --port 8000
   ```
2. In another terminal, start the Svelte frontend:
   ```bash
   npm run dev --workspace=frontend
   ```

---

## Testing

The codebase includes comprehensive test suites across the stack:

### Backend Unit/Integration Tests

Run Python tests with `pytest` inside the `backend` directory:

```bash
cd backend
uv run pytest
```

### Frontend Unit Tests

Run the Svelte unit tests with Vitest:

```bash
npm run test:unit
```

### End-to-End (E2E) Tests

We use Playwright for complete integration flow testing. Playwright is configured to automatically spin up a dedicated e2e database, run backend migrations, and start both the backend and frontend servers:

```bash
npm run test
```

---

## Code Quality & Styling

This project enforces strict formatting and linting rules to maintain clean, high-quality code.

- **Check Code Formatting**:
  ```bash
  npm run format:check
  ```
- **Automatically Format Code** (via Prettier & Ruff):
  ```bash
  npm run format
  ```
- **Run Linters** (ESLint, Svelte-Check, Ruff):
  ```bash
  npm run lint
  ```
- **TypeScript Typecheck**:
  ```bash
  npm run typecheck
  ```
