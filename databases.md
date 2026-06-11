# Postgres Databases

Stand: 2026-06-01

Quelle: Laufende Instanz `infra-postgres` (`postgres:16`), ausgelesen per `psql`.

## Datenbanken und Owner

| Datenbank | Owner |
|-----------|-------|
| `audio2knowledge` | `postgres` |
| `hoppscotch_db` | `apps_rw_user` |
| `infisical_db` | `apps_rw_user` |
| `omi_db` | `apps_rw_user` |
| `postgres` | `postgres` |
| `second_brain` | `apps_rw_user` |
| `twenty_db` | `apps_rw_user` |

## Schemas je Datenbank

| Datenbank | Schemas |
|-----------|---------|
| `audio2knowledge` | `public` |
| `hoppscotch_db` | `public` |
| `infisical_db` | `public` |
| `omi_db` | `public` |
| `postgres` | `public` |
| `second_brain` | `honcho`, `public` |
| `twenty_db` | `core`, `public`, `workspace_8vlg4mwbhz75ivvkmky2lrjle` |

## Pflegehinweis

Bei neuen Datenbanken, neuen Anwendungsschemas oder Änderungen an Ownership/Zuordnung dieses Inventar im selben Change aktualisieren.
