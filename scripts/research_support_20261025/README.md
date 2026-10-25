# Archived research support sources, 25 October 2026

This folder preserves the supporting code written while investigating Europa,
the flat/centered water tests, the cold lower half, and the advisor presentation.
The files are byte-for-byte copies of their original local working versions;
`source_archive_manifest.json` records their original paths and SHA-256 hashes.
The maintained simulation entry points and analysis scripts remain in
`model_and_dependencies/`.

`presentation/` includes the 27-slide deck builder, speaker notes, materials
manifest, video encoder, PowerPoint movie embedding/rendering scripts, package
verification, and finalization script. It uses the bundled `@oai/artifact-tool`,
MATLAB R2022b, Python with NumPy/Pillow, and Windows PowerPoint. The manifest
points to the exact local saved research runs; the numerical MAT outputs and
movies remain under ignored `Output/` and are not included in this source push.

These are historical support scripts, not a portable one-command pipeline.
Some retain absolute local paths, dated output names, or the original `tmp/`
location, and some scratch scripts create/patch other files. Inspect them and
adapt paths, or restore them to the original paths in the manifest, before
executing. In particular, the superseded flat/centered test setup generators
are preserved for provenance and should not replace the corrected S3 solver.
The presentation's final artifacts are preserved separately in
`Output/research_presentation_20261025/` on the originating machine.
