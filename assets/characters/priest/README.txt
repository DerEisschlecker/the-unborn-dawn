Priest character art (runtime uses baked atlases only).

Runtime files per folder (idle/ and hit/):
- showcase_atlas.png
- combat_atlas.png
- portrait.png (idle only)

Source frames (stand_*.png / hit_*.png) are not stored in the repo.
To rebake after art changes, place 98 frames in idle/ or hit/, then run:
  Godot --headless --path . --script res://scripts/dev/run_character_atlas_bake.gd
