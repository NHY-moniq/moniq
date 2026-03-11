# Moniq MVP Spec

## 1. Product Summary

Moniq is a mobile-first shift scheduling app for shift workers such as nurses. The MVP focuses on three jobs:

1. Let users see their own shift schedule clearly.
2. Let eligible teams generate and manage team duty schedules.
3. Let users request shift swaps or change requests with minimal friction.

The app supports two team types:
- **Organization**: a shared work team such as a hospital unit, police team, or shift department. This type can use schedule generation and team duty management features.
- **Personal**: a private team-like space for individual or small private use. This type does not expose schedule generation.

The product should optimize for **fast first release**, **low cognitive load**, and **clear calendar UX**.

---

## 2. Problem Statement

Shift workers currently experience several recurring problems:

- Duty schedules are often created manually, which wastes time.
- Manual scheduling often feels unfair or requires some people to sacrifice more often.
- Finished schedules still need to be entered into personal calendars manually.
- Existing apps make it hard to compare schedules with coworkers.
- It is hard to tell who is working with you on a given day.
- Existing UI/UX is often outdated or unattractive. 

---

## 3. Product Goals

### Primary goal
Ship an MVP as fast as possible with a complete end-to-end user flow.

### MVP success criteria
- A user can sign in.
- A user can join or create a team.
- An Organization team admin can define shift types and rules.
- An Organization team admin can generate a schedule for a selected period.
- A user can view their own calendar.
- A user can view a team calendar.
- A user can submit a swap/change request.

### Non-goals for MVP
- Community/social feed
- Advanced analytics dashboards
- Deep payroll features
- Multi-org enterprise admin panels
- Highly complex AI optimization beyond a usable first version

---

## 4. Target Users

### Primary user
Shift workers, especially nurses.

### Secondary users
- Team leaders / charge nurses / schedule managers
- Later expansion: police, firefighters, factory shift workers, etc.

---

## 5. Product Principles

1. **Mobile-first, with selective web support**: MVP is optimized for iOS/Android first, but admin-heavy flows such as schedule generation should also be available on web.
2. **Calendar-first**: Calendars are the main surface, not a secondary feature.
3. **One primary action per screen**: Avoid overloaded screens.
4. **Fast access to today's shift**: Today's status should always be obvious.
5. **Team context is essential**: Users should easily see who is working on a specific day.
6. **Admin actions are separated from daily user actions**: Schedule generation and rule editing belong in team management, not on the home screen.
7. **Modern UX over raw feature density**: Keep flows short, predictable, and lightweight panel/side-menu driven where appropriate.
8. **Admin-heavy tasks can use larger surfaces**: Complex setup flows such as schedule generation should work well on web and tablet-sized layouts, not only on mobile.

---

## 6. UX Direction and Flow Adjustments

This spec keeps that structure, but adjusts the flow for a more modern app UX:

### Key UX refinements

1. **No separate onboarding gate after login**
   - After login, route to Home tab directly.
   - Team join/create guidance should be handled inside Teams tab empty states.

2. **Home tab is personal, Team tab is collaborative**
   - Home = my schedule
   - Team = selected favorite team's shared calendar
   - This separation reduces confusion and follows modern productivity app patterns.

3. **Team selection is persistent**
   - User can belong to multiple teams.
   - Exactly one team can be favorited/pinned as the default collaborative team.
   - Team tab always opens on the favorited team.

4. **Date interactions prioritize inline context**
   - Tapping a day in team calendar should update an inline roster panel on the same screen.
   - Users can review who is on duty without additional page transitions.

5. **Swap/change is request-driven**
   - Users should not directly overwrite schedules.
   - They submit requests that can later be approved/rejected according to role and business rules.

6. **Admin pages stay behind team detail**
   - Shift rule setup and schedule generation are admin tools and should live under Team Detail.

---

## 7. Core User Flows

## 7.1 Authentication Flow

### Login screen
- Email / password login
- Social login buttons
- Sign up
- Find ID/password or password reset

### Post-login routing
- Always go to Home tab first.
- If user has no teams, Teams tab shows empty state with:
  - Create team
  - Join via invite link/code

---

## 7.2 Home Tab Flow

### Purpose
Personal schedule dashboard.

### Components
- Bottom navigation tabs: Home / Teams / Settings
- Monthly personal calendar
- Today card (shown when schedule exists)
  - Today's shift type
  - Shift time range
  - Team name
- Top right action: Edit personal schedule view/preferences

### Interactions
- Tap a date on monthly calendar:
  - Show date-level shift details (panel/modal implementation can vary):
    - My shift for that date
    - Shift type and time
    - Optional note
    - Quick action: Request change (if team-linked shift exists)

### UX notes
- This tab is not for editing the official team schedule directly.
- It is for viewing personal assignments quickly.

---

## 7.3 Teams Tab Flow

### Purpose
Shared team schedule and collaboration.

### Default state
- Show the favorited team's calendar.
- If no favorited team exists but user has teams, prompt user to pick one.
- If user has no teams, show empty state with create/join CTAs in Teams tab.

### Components
- Top app bar title: Team name
- Top right menu (hamburger) opens right-side drawer:
  - Team list
  - Swap/change request entry
- View mode segmented control:
  - Month / Week / Day
- Team shared calendar
- Inline roster panel (workers grouped by shift type) for selected date

### Interactions
#### Tap a date
Update inline roster panel with:
- Date header
- All workers assigned that day
- Shift types grouped by type
- CTA: Request swap/change (via menu or request screens)

#### Change view mode
- Month = overview
- Week = better density for team planning
- Day = detailed roster

---

## 7.4 Team List Flow

### Purpose
Manage all teams the user belongs to.

### Components
- My Teams list
- Each team row includes:
  - Team icon
  - Team name
  - Member count (optional if available)
  - Favorite indicator if pinned
- Floating action button or primary button: Create Team

### Gestures and actions
#### Team row actions
- Open Team Detail via row trailing button
- Leave team (optional MVP if business rules allow)
- Set as favorite team (action menu/secondary action)

### Create Team flow
Fields:
- Team name
- Team icon/color
- Optional description

After creation:
- Generate invite link/code
- Route to Team Detail

### Join Team flow
- Paste invite link or enter invite code

---

## 7.5 Team Detail Flow

### Purpose
Admin and team management hub.

### Sections
1. Team profile
   - Name
   - Icon
   - Invite link/code
2. Members
   - Member list
   - Add member button
3. Team settings
   - Minimum staffing by shift
   - Optional max staffing by shift
   - Team-level preferences
4. Shift rules
   - Open Shift Rule Management page
5. Auto-generate schedule
   - Open Schedule Generation page
6. Requests
   - Open swap/change request list

---

## 7.6 Shift Rule Management Flow

### Purpose
Configure reusable rules used by schedule generation.

### MVP capabilities
- Define shift types
  - Day / Evening / Night / Off, etc.
  - Start and end time
  - Active/inactive toggle
- Define staffing rules
  - Minimum people per shift type
- Define worker constraints
  - Max consecutive work days
  - Max monthly shifts
  - Max monthly night shifts
  - Minimum rest after night shifts

### UX
- Rule list page
- Add/edit rule page
- Preset templates for common hospital schedules if possible

---

## 7.7 Schedule Generation Flow

### Purpose
Generate team schedules for a selected period.

### Entry point
Team Detail > Auto-generate schedule

### Inputs
- Generation period (start date, end date)
- Active shift rules
- Optional worker preferences / wanted days off (stretch goal inside MVP if simple)
- Preview mode toggle

### Output
- Generated schedule preview
- Validation summary
  - Conflicts
  - Understaffed shifts
  - Rule violations
- Confirm and publish

### Publish behavior
- Save generated shifts into official team schedule
- Notify affected members (if notifications enabled)

### Important product rule
Generation is not final until user explicitly confirms publish.

---

## 7.8 Swap / Change Request Flow

### Purpose
Allow controlled changes after the schedule is published.

### Entry points
- Teams tab > top-right menu (drawer) > request entry
- Team calendar selected-date panel > Request swap/change
- Team Detail > Requests

### Types
1. **Swap request**
   - User proposes swapping one shift with another user
2. **Change request**
   - User asks to change/remove/adjust an assigned shift

### MVP fields
- Request type
- Original date/shift
- Target user (for swap)
- Requested target date/shift (optional for change)
- Reason

### Statuses
- Pending
- Approved
- Rejected
- Cancelled

### UX
- Create request screen
- Requests list screen
- Request detail modal/page

---

## 7.9 Settings Tab Flow

### Sections
#### App Settings
- Light / dark mode
- Font size
- Calendar first day of week (Sunday / Monday)

#### Account
- Profile
- Notification settings
- Calendar integration

---

## 8. Information Architecture

## Bottom navigation
1. Home
2. Teams
3. Settings

## Top-level routes
- /login
- /signup
- /forgot-password
- /home
- /teams
- /teams/list
- /teams/detail
- /teams/create
- /teams/join
- /teams/rules
- /teams/generate
- /teams/requests
- /requests
- /requests/create
- /requests/detail
- /settings

---

## 9. Screen Specifications

## 9.1 Login Screen
### Required UI
- Logo
- Email input
- Password input
- Login button
- Social login buttons
- Sign up link
- Password reset link

### Validation
- Email format validation
- Password required

### Empty/Error states
- Invalid credentials
- Network/server error

---

## 9.2 Home Screen
### Required UI
- Monthly calendar
- Today card (optional when schedule exists)
- Bottom nav
- Top right action menu

### States
- Loading
- Empty (calendar-only default)
- Normal

---

## 9.3 Teams Screen
### Required UI
- Team calendar for selected favorite team
- Month/Week/Day toggle
- Top-right menu icon and right-side drawer
- Drawer entries: Team list, swap/change request
- Selected-date roster panel showing workers by shift type

### States
- Empty (no favorited team)
- No teams joined
- Normal

---

## 9.4 Team List Screen
### Required UI
- Team rows
- Favorite indicator
- Create team CTA
- Join team CTA

---

## 9.5 Team Detail Screen
### Required UI
- Team summary card
- Members section
- Team settings section
- Rule management entry
- Schedule generation entry
- Requests entry

---

## 9.6 Rule Management Screen
### Required UI
- Rule cards/list
- Add rule button
- Edit rule flow

---

## 9.7 Schedule Generation Screen
### Required UI
- Date range input
- Rule summary
- Generate button
- Preview results
- Publish button

---

## 9.8 Requests Screen
### Required UI
- Pending / Approved / Rejected tabs or filters
- Request list
- Create request CTA

---

## 9.9 Settings Screen
### Required UI
- Theme controls
- Font controls
- Calendar preferences
- Profile and account section
- Notification and calendar integration section

---

## 10. Roles and Permissions

## Roles
### Member
- View personal calendar
- View team calendar
- Submit swap/change requests

### Admin / Manager
- Manage team members
- Edit team settings
- Manage shift rules
- Generate and publish schedules
- Approve/reject requests

---

## 11. Functional Requirements

## Must-have
- Authentication
- Team creation / joining
- Favorite one team
- Personal monthly calendar
- Team calendar with month/week/day views
- Selected-date roster panel with worker list
- Team detail management
- Shift rule configuration
- Schedule generation
- Swap/change request submission
- Settings (theme, font size, start day)

## Nice-to-have if simple
- Invite link deep linking
- Calendar integration
- Push notifications
- Export image/excel

---

## 12. Non-Functional Requirements

- Mobile-first responsive design
- Fast calendar rendering for month/week/day views
- Accessible touch targets
- Clear empty states
- Clean dark mode support
- Stable offline behavior for cached reads if feasible
- Error handling for schedule generation and requests

---

## 13. Recommended Tech Stack

## Frontend
- Flutter
- Riverpod 3.x
- go_router
- Freezed + json_serializable

## Application Architecture
- Layer-centered MVVM architecture
  - **Presentation layer**: screens, widgets, view models, routing, UI state
  - **Domain/Application layer**: use cases, business rules, validation, scheduling logic interfaces
  - **Data layer**: repositories, DTOs, Supabase data sources, local cache adapters
- Reason for choosing it:
  - Easy for Claude Code and developers to implement feature by feature
  - Clear separation between UI, business logic, and data access
  - Scales better than putting logic directly inside widgets
  - Works well with Riverpod 3.x Notifier/AsyncNotifier based state management

## Backend
- Supabase
  - Auth
  - Postgres
  - RLS
  - Realtime
  - Storage (optional in MVP)
  - Edge Functions

## Why this stack
- Fast MVP delivery
- Mobile-first development
- Good fit for calendar-heavy UI
- Minimal backend operations burden
- Clear architectural boundaries with layer-centered MVVM

---

## 14. Suggested Data Model (MVP)

### users
- id
- email
- display_name
- avatar_url
- created_at

### teams
- id
- name
- icon
- invite_code
- favorite_by_user_id (do not store directly if favorite is per user; use separate table)
- created_by
- created_at

### team_members
- id
- team_id
- user_id
- role (member/admin)
- joined_at
- is_favorite

### shift_types
- id
- team_id
- name
- code
- start_time
- end_time
- color
- is_active

### shift_rules
- id
- team_id
- rule_type
- rule_payload_json
- created_at

### schedules
- id
- team_id
- period_start
- period_end
- status (draft/published)
- created_by
- created_at

### shifts
- id
- schedule_id
- team_id
- user_id
- shift_date
- shift_type_id
- note

### requests
- id
- team_id
- requester_user_id
- request_type (swap/change)
- source_shift_id
- target_user_id
- target_shift_id (nullable)
- reason
- status
- created_at
- reviewed_by
- reviewed_at

### app_settings
- user_id
- theme_mode
- font_scale
- calendar_start_day
- notifications_enabled
- external_calendar_connected

---

## 15. Edge Cases

- User logs in but belongs to no teams
- User belongs to multiple teams but no favorite is selected
- Schedule generation produces conflicts or incomplete staffing
- User requests swap with a user outside the team
- User tries to submit a request for an unpublished schedule
- Favorite team is deleted or user is removed from it
- Shift type is disabled while existing schedule data still references it

---

## 16. Open Questions for Implementation

1. Will swap requests require admin approval only, or can the counterpart user approve first?
2. Can one user belong to multiple organizations in MVP, or only multiple teams within one org concept?
3. Should personal calendar edits be allowed only as requests, or as private annotations too?
4. Is calendar integration in MVP read-only, write-only, or both?
5. Is wanted day-off input included in MVP generation or Phase 2?

---

## 17. Build Priorities for Claude Code

Implement in this order:

### Phase 1: Foundation
- Auth
- App shell with bottom navigation
- Empty states
- Team create/join flow

### Phase 2: Core calendar
- Home personal monthly calendar
- Teams tab shared calendar
- Selected-date roster panel
- Favorite team behavior

### Phase 3: Team management
- Team list
- Team detail
- Members section
- Shift type management
- Rules management

### Phase 4: Schedule generation
- Generation form
- Preview
- Publish flow

### Phase 5: Requests
- Swap/change request creation
- Request list and status handling

### Phase 6: Settings
- Theme
- Font size
- Calendar first day of week
- Account settings surface

---

## 18. UX Acceptance Criteria

- A first-time user can create or join a team from Teams tab within a short flow.
- A returning user can access personal calendar immediately on app open.
- A user can identify who is working on a selected team date without navigating through multiple pages.
- A team admin can reach schedule generation from team detail in one tap.
- A swap/change request can be submitted in under one minute.

---

## 19. References
## Web Support Scope

The product is still mobile-first, but MVP should support **web access for selected admin workflows**, especially for Organization teams.

### Web in MVP
- Login/authentication
- Basic calendar viewing
- Team management screens
- **Schedule generation flow**
- Rule/staffing setup for Organization teams

### Why web is included
Schedule generation and rule configuration often involve more options, more data density, and longer review time. These tasks benefit from a wider layout, even if day-to-day usage remains mobile-first.

### UX guidance
- Daily use flows should be optimized for phone screens first.
- Admin and setup flows should support responsive layouts that expand gracefully on web/tablet.
- Web does not need every mobile interaction pattern; dense forms and side panels are acceptable for admin workflows.
