extends Node3D
## Entry scene for the project foundation.


func _ready() -> void:
	_update_labels()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_labels()


func _update_labels() -> void:
	$HUD/Content/Title.text = tr("GAME_TITLE")
	$HUD/Content/Description.text = tr("GAME_DESCRIPTION")
	$HUD/Content/Status.text = tr("PROJECT_STATUS")
