# Purpose: Shared render tiers for player appearance art (showcase, combat, portrait).
# Public API: Context enum.
class_name CharacterVisualContext
extends RefCounted

enum Context {
	SHOWCASE,
	COMBAT,
	PORTRAIT,
}
