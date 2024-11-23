class_name DamageResource
extends TransmissionResource

@export var value:float = 1
@export var projectile_multiply:float = 1.0
@export var critical_multiply:float = 1.5
@export var critical_chance:float = 0.3
@export var direction:Vector2
@export var kickback_strength:float

## An information for a damage report
@export var is_critical:bool = false

## Exploiting that array is shared reference
## it will collect all same generation hits
@export var hit_list:Array

## pre-calculated value
@export var total_damage:float
## TODO: include information from source character
@export var report_callback:Callable


func _init()->void:
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		print("DamageResource [INFO]: predelete - ", resource_name)
		pass

## final value applied in HealthResource
## Projectiles can influence resulting value
func get_total_damage()->float:
	return total_damage * projectile_multiply

## Cache the calculation at the begining
## Can be done for each split if necessary
func initialize_generation()->void:
	# TODO: insert your open world MMO RPG damage calculation here
	is_critical = randf() < critical_chance
	if is_critical:
		total_damage = value * critical_multiply
	else:
		total_damage = value

## Create a new generation for a new attack action.
## Do it from root DamageResource
func new_generation()->DamageResource:
	var data:DamageResource = self.duplicate()
	data.resource_name += "_gen"
	data.initialize_generation()
	# create unique array
	data.hit_list = []
	return data

## Create new splitsh of the same generation, like shrapnels from a granade
func new_split()->DamageResource:
	var data:DamageResource = self.duplicate()
	data.resource_name += "_split"
	#data._print_info()
	return data

func _print_info()->void:
	print("DamageResource [INFO]: self - ", resource_name)
	print("DamageResource [INFO]: callable method - ", report_callback.get_method())
	print("DamageResource [INFO]: callable valid - ", report_callback.is_valid())
	print("DamageResource [INFO]: callable object - ", report_callback.get_object().resource_name)


## Receiving end should trigger this function
func process(resource_node:ResourceNode)->void:
	var _receive_damage_bool:BoolResource = resource_node.get_resource("receive_damage")
	if _receive_damage_bool == null:
		failed()
		return
	if _receive_damage_bool.value == false:
		try_again()
		return
	
	var _health_resource:HealthResource = resource_node.get_resource("health")
	if _health_resource.is_dead:
		denied()
		return
	assert(_health_resource.hp > 0)
	
	# It's sure to have a hit, so pull last possible updates, like hit direction
	update_requested.emit()
	
	# TODO: include more receiving end information & proper way to get an owner reference
	hit_list.append(resource_node.owner)
	_health_resource.add_hp( -get_total_damage() )
	
	# TODO: need a dedicated receiver data exchange
	# Used for showing received damage points
	_health_resource.damage_data.emit(self)
	
	var _push_resource:PushResource = resource_node.get_resource("push")
	if _push_resource != null:
		_push_resource.add_impulse(direction * kickback_strength)
	
	success()
	
	# Sends a report through resources self was duplicated from
	# TODO: Test if still works
	print("DamageResource [INFO]: self - ", resource_name)
	#print("DamageResource [INFO]: callable object - ", report_callback.get_object().resource_name)
	print("DamageResource [INFO]: callable object - ", report_callback.get_method())
	if report_callback.is_valid:
		report_callback.call(self)
