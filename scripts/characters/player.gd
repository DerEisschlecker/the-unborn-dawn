# Purpose: Scene-facing player facade for the global player statistics; it contains no movement controls.
# Public API: take_damage(), heal(), spend_stamina().
# Dependencies: GameState and EventBus.
extends Node


func take_damage(amount: float) -> void:
	GameState.change_stat("health", -amount)


func heal(amount: float) -> void:
	GameState.change_stat("health", amount)


func spend_stamina(amount: float) -> void:
	GameState.change_stat("stamina", -amount)

