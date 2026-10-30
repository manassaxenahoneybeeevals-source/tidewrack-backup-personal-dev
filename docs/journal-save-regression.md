# Journal save/load — regression cases

Manual checks for the journal persistence change (`fix/journal-save-persistence`).
Run them in an exported build as well as the editor before a demo release.
Each case lists the steps, what must be true afterwards, and which line of
code guarantees it, so a failure points straight at the cause.

The save lives at `user://save.json` (per-OS user data dir). Until a graph
uses the `"journal"` hook, trigger discoveries from the debug console or a
test graph; the expected ids below assume the keeper's log records
`entry_ledger`.

## 1. Normal save, then Continue

1. New Game. Read the keeper's log; pick either answer at both choices.
2. Esc → Save. Esc → Main Menu.
3. Continue.

Expected:
- Resumes on the ground floor with the same choices in effect
  (`skeptic`/`believer`, `trusted_edith`).
- `Journal.entries()` is `["entry_ledger"]`.
- `save.json` contains `"version": 2` and `"journal": ["entry_ledger"]`.

Where: `GameState.save_game()` writes the `journal` key; `load_game()` reads
it through `_read_journal()`.

## 2. Old save with no journal (pre-change demo save)

1. Take a `save.json` written by the current public demo build:
   `{"version": 1, "scene": "...", "flags": {...}}` — no `journal` key.
   Keep a copy of a real one as a fixture rather than hand-writing it.
2. Place it at `user://save.json`. Launch. Continue.

Expected:
- Loads without error or warning. Same scene, every flag unchanged —
  including `trusted_edith: false`, which must stay present-and-false, not
  disappear.
- Journal is empty.
- The file on disk is **not** rewritten by loading; it is still v1 until the
  player next saves, after which it is v2 with a `journal` key.

Where: the `scene` and `flags` lines in `load_game()` are unchanged from
`main`; `data.get("journal", [])` supplies the empty default.

Reverse direction (only matters if players can get back onto the old build):
the old build ignores the `journal` key, loads flags normally, and if it
saves it writes v1 and the journal is lost. Flags are never at risk.

## 3. New Game after playing

1. Continue into a save that has journal entries. Confirm `Journal.entries()`
   is non-empty.
2. Esc → Main Menu. New Game.

Expected:
- `Journal.entries()` is `[]` and `GameState.flags` is `{}` immediately,
  before any save.
- Reading the keeper's log again fires `Journal.entry_added` (it is new to
  this run).
- The old `save.json` is untouched until the player saves. Quitting without
  saving and pressing Continue brings back the old flags *and* the old
  journal together — same behaviour flags have always had.

Where: `GameState.new_game()` calls `journal.clear()` beside `flags.clear()`.
`Journal` has no storage of its own, so there is no second copy to leak.

## 4. Same log picked up twice

1. Read the keeper's log. Save. Main Menu. Continue.
2. Read the keeper's log again, all the way through.

Expected:
- `Journal.entries()` is still `["entry_ledger"]` — one entry, not two.
- `Journal.entry_added` does **not** fire on the second read.
- Flags are re-applied by the replayed choice nodes. Picking the opposite
  answer leaves both `skeptic` and `believer` true. That is pre-existing
  dialogue behaviour, not a journal bug; note it for the content pass.

Where: `Journal.discover()` returns early when `id in GameState.journal`.

## 5. Mangled journal data

Edit `user://save.json` by hand, launch, Continue. Flags and scene must load
normally in every sub-case; only the journal degrades.

| `"journal"` value in file                        | Expected journal after load |
|--------------------------------------------------|-----------------------------|
| `"entry_ledger"` (string, not array)             | `[]`                        |
| `42` or `{}`                                     | `[]`                        |
| `[42, "", null, "entry_ledger", "entry_ledger"]` | `["entry_ledger"]`          |
| `["entry_b", "entry_a"]`                         | `["entry_b", "entry_a"]` (order kept) |
| key missing entirely                             | `[]` (same as case 2)       |

Where: `_read_journal()` returns `[]` for non-arrays and keeps only
non-empty, first-seen strings. Repairs are silent; add a `push_warning`
there if "my journal vanished" reports need a trail in the log.

If the **whole file** is not valid JSON (stray comma, truncated write),
`load_game()` returns false, exactly as on `main`. Known pre-existing gap:
the Continue button is enabled by `has_save()`, which only checks that the
file exists, so a corrupt file shows an enabled button that does nothing.
Tracked separately.

## Not covered by this change

- No autosave: a discovery survives only if the player saves from the pause
  menu before quitting.
- No `.bak` or atomic write: a crash mid-save can still corrupt the file.
- No reader UI: entries are recorded but not shown.
