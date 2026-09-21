extends Control

var current_speed: float = 0
var batt_pct: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$Grid/Speed.text = "%2.1f" % [current_speed]
	$Grid/Batt.text = "%3d" % [round(batt_pct)]
