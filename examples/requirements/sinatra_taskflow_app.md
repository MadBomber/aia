# TaskFlow — Project & Task Management Web Application

## Overview

Build a standalone Ruby application using Sinatra as the web framework.
TaskFlow is a multi-user project and task management system similar to a
simplified Trello or Asana. The application must be a single deployable
Ruby process with no external service dependencies beyond SQLite.

## Technology Stack

- Ruby 3.x
- Sinatra 4.x (classic style, single `app.rb` entry point)
- SQLite via the Sequel ORM (migrations in `db/migrations/`)
- ERB templates in `views/` (layouts, partials)
- Bootstrap 5 via CDN for styling
- bcrypt for password hashing
- jwt gem for API token issuance
- Rack::Session::Cookie for browser sessions
- WEBrick for development; Puma for production

## Authentication & Authorization

- Users register with email, password (bcrypt), and display name
- Login issues a session cookie (browser) and a JWT (API clients)
- Passwords must be at least 8 characters; emails must be unique
- Sessions expire after 24 hours; JWT tokens after 1 hour
- Route protection: unauthenticated requests redirect to /login (browser)
  or return 401 JSON (API requests with Accept: application/json)
- Role system: each project has members with role `owner`, `editor`, or `viewer`
- Only owners may delete a project or change member roles
- Editors may create/update/delete tasks within the project
- Viewers may only read

## Data Model

### User
- id (integer, primary key)
- email (string, unique, not null)
- password_digest (string, not null)
- display_name (string, not null)
- created_at, updated_at (timestamps)

### Project
- id (integer, primary key)
- name (string, not null)
- description (text)
- owner_id (integer, FK → users.id)
- created_at, updated_at

### ProjectMember
- id (integer, primary key)
- project_id (integer, FK → projects.id)
- user_id (integer, FK → users.id)
- role (string: 'owner' | 'editor' | 'viewer')
- joined_at (timestamp)
- UNIQUE constraint on (project_id, user_id)

### Task
- id (integer, primary key)
- project_id (integer, FK → projects.id)
- title (string, not null)
- description (text)
- status (string: 'todo' | 'in_progress' | 'done', default 'todo')
- priority (string: 'low' | 'medium' | 'high', default 'medium')
- assigned_to (integer, FK → users.id, nullable)
- due_date (date, nullable)
- created_by (integer, FK → users.id)
- created_at, updated_at

## Web Routes (Browser)

- GET  /                   → redirect to /dashboard if logged in, else /login
- GET  /login              → login form
- POST /login              → authenticate, set session, redirect to /dashboard
- GET  /register           → registration form
- POST /register           → create user, auto-login, redirect to /dashboard
- POST /logout             → clear session, redirect to /login
- GET  /dashboard          → list all projects the current user is a member of
- GET  /projects/new       → form to create a project
- POST /projects           → create project, add user as owner
- GET  /projects/:id       → project detail: task list, member list
- GET  /projects/:id/edit  → edit project name/description
- PUT  /projects/:id       → update project
- DELETE /projects/:id     → delete project (owner only)
- GET  /projects/:id/tasks/new → new task form
- POST /projects/:id/tasks    → create task
- GET  /projects/:id/tasks/:tid/edit → edit task form
- PUT  /projects/:id/tasks/:tid     → update task
- DELETE /projects/:id/tasks/:tid   → delete task

## REST API Routes (JSON, prefix /api/v1)

- POST /api/v1/auth/login   → { token: "jwt..." }
- GET  /api/v1/projects     → array of projects for current user
- POST /api/v1/projects     → create project
- GET  /api/v1/projects/:id → project + tasks
- PUT  /api/v1/projects/:id → update project
- DELETE /api/v1/projects/:id → delete project
- GET  /api/v1/projects/:id/tasks   → task list
- POST /api/v1/projects/:id/tasks   → create task
- PUT  /api/v1/projects/:id/tasks/:tid → update task
- DELETE /api/v1/projects/:id/tasks/:tid → delete task
- GET  /api/v1/projects/:id/members → member list
- POST /api/v1/projects/:id/members → add member
- DELETE /api/v1/projects/:id/members/:uid → remove member

## Views (ERB)

- layout.erb           → HTML shell, nav bar, flash messages, Bootstrap 5
- dashboard.erb        → project cards grid, "New Project" button
- projects/show.erb    → task board (Kanban columns by status), member sidebar
- projects/form.erb    → shared create/edit form
- tasks/form.erb       → shared create/edit form
- auth/login.erb       → login form
- auth/register.erb    → registration form
- partials/_flash.erb  → flash message component
- partials/_task_card.erb → task card with status badge and priority indicator

## Infrastructure & Configuration

- `app.rb`             → Sinatra application class, requires all components
- `config.ru`          → Rack entry point, mounts the app
- `Gemfile`            → all dependencies with locked versions
- `db/migrations/`     → numbered Sequel migration files
- `db/schema.rb`       → auto-generated schema dump
- `lib/auth_helpers.rb` → session/JWT helpers, `current_user`, `require_login`
- `lib/api_helpers.rb` → JSON response helpers, token verification
- `config/database.rb` → Sequel connection setup (dev/test/prod environments)
- `config/settings.rb` → app constants: session secret, JWT secret, token TTL
- `.env.example`       → template for required environment variables

## Testing

- RSpec with rack-test for request specs
- Factory pattern for test data (no FactoryBot, plain Ruby factory methods)
- Tests in `spec/`: `spec/auth_spec.rb`, `spec/projects_spec.rb`,
  `spec/tasks_spec.rb`, `spec/api_spec.rb`
- Test database: separate SQLite file, schema reset before each suite
