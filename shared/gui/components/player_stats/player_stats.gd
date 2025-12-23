extends VBoxContainer


@onready var energy_bar: TextureProgressBar = %EnergyBar
@onready var health_bar: TextureProgressBar = %HealthBar
@onready var mana_bar: TextureProgressBar = %ManaBar


func _enter_tree() -> void:
	EventSystem.PLA_updated_energy.connect(on_updated_energy)
	EventSystem.PLA_updated_health.connect(on_updated_health)
	EventSystem.PLA_updated_mana.connect(on_updated_mana)


func on_updated_energy(max_value: float, current_value: float) -> void:
	energy_bar.max_value = max_value
	energy_bar.value = current_value


func on_updated_health(max_value: float, current_value: float) -> void:
	health_bar.max_value = max_value
	health_bar.value = current_value


func on_updated_mana(max_value: float, current_value: float) -> void:
	mana_bar.max_value = max_value
	mana_bar.value = current_value
