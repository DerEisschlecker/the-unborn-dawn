# Purpose: Defines global signals so independent game systems can communicate safely.
# Public API: UI refresh, time, wave, story, save, message, and game-over events.
# Dependencies: None.
extends Node

@warning_ignore("unused_signal")
signal stats_changed
@warning_ignore("unused_signal")
signal inventory_changed
@warning_ignore("unused_signal")
signal time_changed(day: int, phase: String)
@warning_ignore("unused_signal")
signal wave_due(day: int)
@warning_ignore("unused_signal")
signal story_due(story_id: String)
@warning_ignore("unused_signal")
signal message_posted(text: String)
@warning_ignore("unused_signal")
signal save_completed(slot: int)
@warning_ignore("unused_signal")
signal game_over(reason: String)


func post_message(text: String) -> void:
	message_posted.emit(text)
