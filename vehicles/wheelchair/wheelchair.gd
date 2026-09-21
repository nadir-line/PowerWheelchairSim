extends VehicleBody3D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

@export var WHEELBASE_WIDTH: float = 1
@export var WHEEL_RADIUS_REAR: float = 1

var batt_lvl: float = 1

var input_joystick: Vector2 = Vector2.ZERO

var linear_velocity_local: Vector3 = Vector3.ZERO
var angular_velocity_local: Vector3 = Vector3.ZERO

var steering_angle_target_l: float = 0
var steering_angle_target_r: float = 0

var steering_lerp_factor: float = 0.2

var wheel_speed_rear_left: float = 0
var wheel_speed_rear_right: float = 0

var turn_radius: float = 0
var wheel_velocity_ratio: float = 0

var wheel_speed_rear_left_tgt: float = 0
var wheel_speed_rear_right_tgt: float = 0

@export_range(0.1, 2, 0.1) var speed_limit: float = 1.5

@export_range(0.1, 8, 0.1) var turn_rate_scalar: float = 4

var use_vr: bool = false
const VR_SCENE: PackedScene = preload("res://uires/cardboard_vr/cardboard_vr.tscn")
var vr_instance = VR_SCENE.instantiate()


# Called when the node enters the scene tree for the first time.
func _ready():
#	DebugOverlay.stats.add_property(self, "input_joystick", "round")
#	DebugOverlay.stats.add_property(self, "angular_velocity", "round")
#	DebugOverlay.stats.add_property(self, "steering_angle_target", "round")
#	DebugOverlay.stats.add_property(self, "steering", "round")
#	DebugOverlay.stats.add_property(self, "wheel_velocity_ratio", "")
#	DebugOverlay.stats.add_property(self, "turn_radius", "")
	#DebugOverlay.stats.add_property(self, "linear_velocity_local", "round")
	DebugOverlay.stats.add_property(self, "batt_lvl", "")
	pass # Replace with function body.

func interpolate_linear(value_current, value_target, rate, delta_time):
	if (abs(value_current - value_target) > delta_time):
		if (value_current < value_target):
			return value_current + rate * delta_time
		if (value_current > value_target):
			return value_current - rate * delta_time
		else:
			return value_target
	else:
		return value_target

# Called every physics frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	get_input(delta)
	
	linear_velocity_local = (linear_velocity) * self.transform.basis
	angular_velocity_local = global_transform.basis.z * (angular_velocity)
	
#	steering_angle = atan2((linear_velocity_local.x - angular_velocity.y * 0.22), -linear_velocity_local.z)
#	steering_angle = atan2(angular_velocity.y * 0.22, -linear_velocity_local.z)

	# Simulate castering front wheels
	steering_angle_target_l = atan2(0.391, (turn_radius + $WheelFrontLeft.position.x))
	steering_angle_target_r = atan2(0.391, (turn_radius + $WheelFrontRight.position.x))
	
	# PIDs
	
	wheel_speed_rear_left_tgt = \
		-( \
			+$PIDCalcTurnRate.calc_PID_output(input_joystick.x * 4, -angular_velocity.y) \
			+$PIDCalcVelocity.calc_PID_output(input_joystick.y * 1.5, -linear_velocity_local.z) \
		) \
		* speed_limit / WHEEL_RADIUS_REAR
	
	wheel_speed_rear_right_tgt = \
		-( \
			-$PIDCalcTurnRate.calc_PID_output(input_joystick.x * 4, -angular_velocity.y) \
			+$PIDCalcVelocity.calc_PID_output(input_joystick.y * 1.5, -linear_velocity_local.z) \
		) \
		* speed_limit / WHEEL_RADIUS_REAR
	
	$WheelRearLeft.engine_force = \
		$PIDCalcWheelLeft.calc_PID_output(wheel_speed_rear_left_tgt, wheel_speed_rear_left)
	$WheelRearRight.engine_force = \
		$PIDCalcWheelRight.calc_PID_output(wheel_speed_rear_right_tgt, wheel_speed_rear_right)
	
	
	# Increase caster turn rate as velocity increases
	# Clamping from 0 to 1
	steering_lerp_factor = clamp((linear_velocity_local.length()), 0, 1)
	
	wheel_speed_rear_left = $WheelRearLeft.get_rpm() * 0.1047 * $WheelRearLeft.wheel_radius
	wheel_speed_rear_right = $WheelRearRight.get_rpm() * 0.1047 * $WheelRearRight.wheel_radius
	
	if (wheel_speed_rear_left - wheel_speed_rear_right) != 0:
		wheel_velocity_ratio = \
			(wheel_speed_rear_left + wheel_speed_rear_right) / \
			(wheel_speed_rear_left - wheel_speed_rear_right)
	else:
		wheel_velocity_ratio = INF
	
	turn_radius = -wheel_velocity_ratio * WHEEL_RADIUS_REAR
	
	$WheelFrontLeft.steering = rad_to_deg(lerp_angle( 
		deg_to_rad($WheelFrontLeft.steering), 
		steering_angle_target_l, 
		steering_lerp_factor
		))
	$WheelFrontRight.steering = rad_to_deg(lerp_angle( 
		deg_to_rad($WheelFrontRight.steering), 
		steering_angle_target_r, 
		steering_lerp_factor
		))
	
	# Battery
	batt_lvl -= 0.00000001 * abs($WheelRearLeft.engine_force)
	batt_lvl -= 0.00000001 * abs($WheelRearRight.engine_force)
	batt_lvl = clamp(batt_lvl, 0, 1)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Animations 
	$Model/WheelRearLeft.rotation = $WheelRearLeft.rotation
	$Model/WheelRearRight.rotation = $WheelRearRight.rotation
	$Model/WheelRearLeft.position = $WheelRearLeft.position
	$Model/WheelRearRight.position = $WheelRearRight.position
	
	# Fix inverted rims
	$Model/WheelRearLeft.rotation.x = -$WheelRearLeft.rotation.x
	$Model/WheelRearLeft.rotation.y = $WheelRearLeft.rotation.y + PI
	$Model/WheelRearRight.rotation.x = -$WheelRearRight.rotation.x
	$Model/WheelRearRight.rotation.y = $WheelRearRight.rotation.y + PI
	
	$Model/CastorLeft.rotation.y = deg_to_rad($WheelFrontLeft.steering)
	$Model/CastorRight.rotation.y = deg_to_rad($WheelFrontRight.steering)
	
	$Model/CastorLeft/WheelFrontLeft.rotation.x = $WheelFrontLeft.rotation.x
	$Model/CastorRight/WheelFrontRight.rotation.x = $WheelFrontRight.rotation.x
	
	# Gauges
	$HUDBasic.current_speed = linear_velocity.length()
	$SubViewport/SystemsDisplay.current_speed = linear_velocity.length()
	$SubViewport/SystemsDisplay.batt_pct = 100 * batt_lvl
	
	# 3D model joystick
	$AttachPtArm/PvArm/PvCon/Con/Joystick.rotation.z = -0.2 * input_joystick.x
	$AttachPtArm/PvArm/PvCon/Con/Joystick.rotation.x = -0.2 * input_joystick.y
	
	if Input.is_action_just_pressed("vr_toggle"):
		use_vr = not use_vr
		if use_vr:
			add_child(vr_instance)
			vr_instance.position.y = 0.5
		else:
			remove_child(vr_instance)
	
	if abs(rotation_degrees.z) > 60:
		get_tree().reload_current_scene()


func get_input(delta):
	# Joystick input as axes
	input_joystick.x = Input.get_axis("joystick_left", "joystick_right")
	input_joystick.y = Input.get_axis("joystick_down", "joystick_up")
	
	# Camera
	$CameraFPV.rotation.x = \
		lerp($CameraFPV.rotation.x, Input.get_axis("cam_down", "cam_up") - 0.15, 0.1)
	$CameraFPV.rotation.y = \
		lerp($CameraFPV.rotation.y, Input.get_axis("cam_left", "cam_right") * -3, 0.1)
	$CameraFPV.position.x = \
		lerp($CameraFPV.position.x, Input.get_axis("cam_left", "cam_right") * 0.1, 0.1)
	
	# Camera translation
	if use_vr:
		if vr_instance.rotation_degrees.x > 30:
			vr_instance.position.z = (vr_instance.rotation_degrees.x - 30) / 500
		elif vr_instance.rotation_degrees.x < -15:
			vr_instance.position.z = (vr_instance.rotation_degrees.x + 15) / 500
		else:
			vr_instance.position.z = 0
	else:
		# Fwd/aft
		if $CameraFPV.rotation_degrees.x > 30:
			$CameraFPV.position.z = ($CameraFPV.rotation_degrees.x - 30) / 200
		elif $CameraFPV.rotation_degrees.x < -15:
			$CameraFPV.position.z = ($CameraFPV.rotation_degrees.x + 15) / 200
			$CameraFPV.position.y = 0.5 + ($CameraFPV.rotation_degrees.x + 15) / 300
		else:
			$CameraFPV.position.z = 0
			$CameraFPV.position.y = 0.5
		
		$CameraFPV.position.x = -$CameraFPV.rotation_degrees.y / 300
	
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
