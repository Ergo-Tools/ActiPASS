# tools

- `engine-smoke.mjs`: protocol smoke test of the MATLAB engine without the app
  (`node tools/engine-smoke.mjs [projectDir]`; env `ACTIPASS_MATLAB` = MATLAB executable).
- `engine-batch.mjs`: run one real batch through the engine (to compare with a GUI batch).
- `engine-client.mjs`: small client used by the scripts. Env `ACTIPASS_ENGINE_EXE` = compiled
  engine to test instead of `matlab -batch`.
- `build_engine.m`: compile the engine and its installer (run in MATLAB R2024b; see
  engine-matlab/README.md).
- `build-release.mjs` (`npm run build:release` in `app/`): builds `Actipass_<version>_x64-setup.exe`,
  which runs the engine installer. Version from `ActiPASS_UI_MATLAB2024.prj` (one source for app,
  engine and both installers); stops if the engine installer in `engine-matlab/build/dist` has
  another version. A copy of the installer goes to `dist/` (not tracked).
- `clean-build.mjs` (`npm run clean` in `app/`): removes build output after a release build: the
  Rust release build (`target/release`), `app/build` and engine builds of older versions. `--all` also
  removes the whole `target/` (the next `npm run dev:app` rebuilds Rust from scratch), `.svelte-kit`
  and the current engine build; `--dry-run` only lists. Keeps `dist/` and `engine-matlab/build/dist`.

Planned: mlapp → `settings.schema.json` extractor; mock engine (replays recorded responses
and progress) so the UI can be developed and tested without MATLAB.
