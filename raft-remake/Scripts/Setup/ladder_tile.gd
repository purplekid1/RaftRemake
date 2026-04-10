extends Area3D

func _ready():
	# Manually connect signals in case the Editor UI missed it
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# This MUST print when you start the game. If it doesn't, the script isn't attached.
	print("Ladder system initialized. Monitoring is: ", monitoring)

func _on_body_entered(body):
	print("Contact detected with: ", body.name)
	if body.has_method("set_climbing"):
		body.set_climbing(true)
		print("Player is now climbing.")

func _on_body_exited(body):
	if body.has_method("set_climbing"):
		body.set_climbing(false)
		print("Player stopped climbing.")
