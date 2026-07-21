# Medical Staff Review

A fortnightly roster builder for a multi-building medical practice. Staff are assigned to rooms for shifts, subject to role rules, so every room is covered by a qualified person during opening hours.

## Language

**Role**:
The single source of truth for what a Staff member is qualified to do (e.g. Senior Fellow, Junior Fellow, Emergency Medicine, Nurse Practitioner). Rules, room eligibility, and rostering all key off Role. A Staff member can hold multiple Roles at once, and one Shift assignment counts toward every Rule matched by any Role they hold.
_Avoid_: Doctor, Nurse — not modeled entities, at most a cosmetic label never referenced by Rules.

**Tag**:
A label attached to a Room describing what kind of work happens there (e.g. General Practice, Surgery, Nurse Practitioner Room, Emergency Department). Rules attach to Tags to restrict or require Roles. A Room may carry multiple Tags; when more than one carries an eligibility-restriction rule, a staff member need only satisfy one of them (union, not intersection) to be eligible for the room.

**Rule**:
A constraint the roster must satisfy. Exactly two shapes: a **minimum-count rule** ("this Building or Tag needs at least N staff holding Role X present"), and an **eligibility-restriction rule** ("only Role X may work in rooms with Tag Y").

**Shift**:
A block of time of the app-wide Shift Length, during which one Staff member occupies one Room.

**Preferred Days**:
A Staff member's standing, recurring day-of-week preference (e.g. "Mon, Wed, Fri"), applied to both weeks of every fortnightly roster. A soft goal — the roster may break it.
_Avoid_: Availability (see Unavailability, which is the hard counterpart)

**Unavailability**:
A hard, date-specific block on a Staff member (e.g. approved leave). The roster must never assign a Shift on an Unavailability date.

**Roster**:
A generated 14-day schedule of Shift assignments for a practice, tied to a specific date range. Assignments a user has manually edited become **pinned** — regenerating the Roster treats pinned assignments as fixed and only solves around the remaining open Shifts. Every Roster ever generated is retained permanently for review/audit — nothing is discarded once its date range passes.
