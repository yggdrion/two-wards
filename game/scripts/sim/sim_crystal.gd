class_name SimCrystal
extends RefCounted
## The core both players defend. The run is lost when its HP reaches 0.

signal destroyed

var max_hp: int = 20
var hp: int = max_hp
var position: Vector2


func take_damage(amount: int) -> void:
	if hp == 0:
		return
	hp = maxi(hp - amount, 0)
	if hp == 0:
		destroyed.emit()


## Heals up to max_hp. A destroyed crystal stays destroyed.
func heal(amount: int) -> void:
	if hp == 0 or amount <= 0:
		return
	hp = mini(hp + amount, max_hp)
