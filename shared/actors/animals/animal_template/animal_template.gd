extends CharacterBody2D

const ANIM_BLEND = 0.2

enum States {
	Idle,
	Wander,
	Dead
}

var state: States = States.Idle # по умолчанию

@onready var idle_timer: Timer = %IdleTimer # бездействие
@onready var wander_timer: Timer = %WanderTimer # передвижение
@onready var disappear_after_death_timer: Timer = %DisappearAfterDeathTimer # исчезнуть после смерти

@onready var main_collision_shape: CollisionShape2D = %CollisionShape2D
@onready var meat_spawn_marker: Marker2D = %MeatSpawnMarker
@onready var animation_player: AnimationPlayer = %AnimationPlayer

@onready var hitbox: Hitbox = %Hitbox
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D



@export var normal_speed := 100
@export var max_health := 80.0
@export var idle_animations: Array[String] = []
@export var turn_speed_weight := 0.07
@export var min_idle_time := 2.0
@export var max_idle_time := 7.0
@export var min_wander_time := 2.0
@export var max_wander_time := 4.0

var gravity: float = ProjectSettings.get_setting('physics/2d/default_gravity')
var health := max_health


func _ready() -> void:
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	
	idle_timer.timeout.connect(_on_idle_timer)
	wander_timer.timeout.connect(_on_wander_timer)
	disappear_after_death_timer.timeout.connect(_on_disappear_after_death_timer)
	
	hitbox.register_hit.connect(_on_register_hit)


func _physics_process(_delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * _delta

	
	if state == States.Wander:
		wander_loop()
	elif state == States.Idle:
		velocity.x = 0.0
	
	move_and_slide()


func wander_loop() -> void:
	look_forward()


func look_forward() -> void:
	rotation = 0
	pass


func pick_wander_velocity() -> void:
	var number = randi_range(0, 1)
	var dir := Vector2(1 if number else -1, 0)
	
	if dir.x == 1:
		animated_sprite_2d.flip_h = false
	if dir.x == -1:
		animated_sprite_2d.flip_h = true
	velocity += dir * normal_speed


func set_state(new_state: States) -> void:
	state = new_state
	
	match state:
		States.Idle:
			idle_timer.start(randf_range(min_idle_time, max_idle_time))
			animated_sprite_2d.play("idle")
		States.Wander:
			pick_wander_velocity() # направление движения
			wander_timer.start(randf_range(min_wander_time, max_wander_time))
			animated_sprite_2d.play('walk') # Walk - ходить
		States.Dead:
			animated_sprite_2d.play('death')
			main_collision_shape.disabled = true
			
			var meat_scene := ItemConfig.get_pickuppable_item(ItemConfig.Keys.RawMeat)
			
			EventSystem.SPA_spawn_scene.emit(meat_scene, meat_spawn_marker.global_transform)
			idle_timer.stop()
			wander_timer.stop()
			set_physics_process(false)
			disappear_after_death_timer.start(10)

# Сигналы
func _on_animation_finished() -> void:
	if state == States.Idle:
		animated_sprite_2d.play("idle")


func _on_idle_timer() -> void:
	set_state(States.Wander)


func _on_wander_timer() -> void:
	set_state(States.Idle)


func _on_disappear_after_death_timer() -> void:
	queue_free()


func _on_register_hit(weapon_item_resource: WeaponItemResource) -> void:
	print(weapon_item_resource, 'weapon_item_resource [TEST]')
	health -= weapon_item_resource.damage
	
	if state != States.Dead and health <= 0:
		set_state(States.Dead)
