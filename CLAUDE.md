# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Immich is a self-hosted photo and video management solution. The repo is a **pnpm monorepo** with multiple independently-built components. Node `24.15.0` and pnpm `10.33.1` are pinned (see `.nvmrc` / `mise.toml`).

## Components

| Path                | Stack                          | Produces                          |
| ------------------- | ------------------------------ | --------------------------------- |
| `server/`           | TypeScript, NestJS, Express    | `immich-server` image (API, jobs) |
| `web/`              | TypeScript, SvelteKit, Svelte 5, Tailwind v4 | web client            |
| `mobile/`           | Dart, Flutter                  | Android & iOS apps                |
| `machine-learning/` | Python, FastAPI                | `immich-machine-learning` image   |
| `packages/cli`      | TypeScript                     | `@immich/cli` npm package         |
| `packages/sdk`      | TypeScript (**generated**)     | `@immich/sdk` — OpenAPI client    |
| `packages/plugins`  | TypeScript, Extism             | server plugin runtime             |
| `e2e/`              | TypeScript, Vitest + Playwright| end-to-end tests                  |
| `docs/`             | Docusaurus                     | https://immich.app                |

## Task runner

The repo uses **`mise`** as a monorepo task runner. Each component has its own `mise.toml` with tasks. Run a component's task from anywhere with `mise //<component>:<task>` (e.g. `mise //server:test`, `mise //web:lint`, `mise //mobile:codegen`). Within a component directory, the corresponding `pnpm run` scripts also work.

## Common commands

### Server (`cd server`)

- `pnpm run build` — `nest build`
- `pnpm test` — unit tests (Vitest). Run a single file: `pnpm test path/to/file.spec.ts`
- `pnpm run test:medium` — medium/integration tests; **requires a Postgres database** (config `test/vitest.config.medium.mjs`)
- `pnpm run check` — typecheck (`tsc --noEmit`)
- `pnpm run lint` / `pnpm run format`
- `pnpm run check:all` — format + lint + typecheck + tests (run before a PR)

### Web (`cd web`)

- `pnpm run dev` — dev server on port 3000 (expects a running server)
- `pnpm test` — unit tests (Vitest)
- `pnpm run check:svelte` / `pnpm run check:typescript` — type checks
- `pnpm run check:all` — format + lint + checks + tests

### Mobile (`cd mobile`)

- `mise //mobile:codegen` — run `build_runner` (required after editing models/entities/drift schemas)
- `mise //mobile:pigeon` — regenerate platform-channel code from `pigeon/`
- `mise //mobile:test`, `mise //mobile:lint`, `mise //mobile:format`
- `mise //mobile:checklist` — full pre-PR pipeline

### Machine learning (`cd machine-learning`)

- Python deps managed with `uv`. `pytest` for tests, `ruff` for lint, `mypy` for typing.

### Local dev environment

- `make dev` — full dockerized dev stack (`docker/docker-compose.dev.yml`)
- `make e2e` — start a test environment, then `mise //e2e:test` to run e2e tests
- A devcontainer is provided (`.devcontainer/`).

## Architecture

### Server — Hexagonal architecture

The server loosely follows hexagonal architecture: **separate technology-specific code from business logic**.

- `src/controllers/` — HTTP endpoints, one per resource. Map requests to services.
- `src/services/` — core business logic. Services have a corresponding `*.spec.ts`.
- `src/repositories/` — all I/O: database (Kysely), Redis, filesystem, ML service, etc. Business logic must go through repositories, never touch infrastructure directly.
- `src/dtos/` — Domain Transfer Objects; public input/output shapes for endpoints. DTOs define the OpenAPI schema, which drives all generated client code.
- `src/schema/` — database schema (`tables/`, `enums/`, `functions/`) and `migrations/`.

`src/app.module.ts` defines four NestJS modules sharing the same repositories/services: **ApiModule** (HTTP), **MicroservicesModule** (background jobs only), **MaintenanceModule**, and **ImmichAdminModule** (CLI). Background jobs run via **BullMQ on Redis**; some jobs chain into others (e.g. thumbnail generation triggers smart search & facial recognition).

### Database migrations

After changing anything in `server/src/schema/`, generate a migration:

```bash
cd server && pnpm run migrations:generate <name>
```

Review the generated file, then move it into `server/src/schema/migrations/`. Migrations run automatically on server start. `pnpm run migrations:revert` rolls back the latest.

### OpenAPI / SDK — generated code

`open-api/immich-openapi-specs.json` and `packages/sdk/` are **auto-generated — never edit by hand**. After changing server DTOs/controllers, regenerate everything with `mise //:open-api` (rebuilds the server, syncs the spec, regenerates the TypeScript SDK and the Dart SDK in `mobile/openapi/`). The web client, CLI, and e2e tests all consume `@immich/sdk`.

### Mobile

Target architecture: pages → providers (Riverpod state) → services → repositories. Repositories are the only layer allowed to use foreign data classes (e.g. OpenAPI DTOs); their interfaces must expose only domain Entities/Models. Generated files (`*.g.dart`, `*.gr.dart`, `*.drift.dart`) are produced by codegen — do not edit them.

## Contributing notes

- Keep PRs small and focused on one thing.
- **Feature freezes**: PRs are generally not accepted for *Sharing / Asset ownership* or *(External) libraries* — only minor bug fixes.
- The project does not accept LLM-generated PRs.
