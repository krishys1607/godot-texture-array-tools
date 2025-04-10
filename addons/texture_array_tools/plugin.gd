@tool
## Main EditorPlugin script for the Texture Array Tools plugin.
## Handles adding the plugin's UI panel directly to an editor dock slot
## and removing it when the plugin is disabled.
extends EditorPlugin

## Reference to the instantiated main dock scene (t2da_dock.tscn).
var main_dock_panel: Control # Or Panel if you know the root type

## Title displayed on the plugin's tab in the dock. (Still used when docked)
const DOCK_TITLE = "Texture Array Tools"

## Called when the plugin is activated (enters the editor tree).
## Instantiates the UI scene and adds it to a specific editor dock slot.
func _enter_tree():
	# Load the scene file containing the plugin's UI.
	var dock_scene: PackedScene = preload("res://addons/texture_array_tools/t2da_dock.tscn")
	if dock_scene == null:
		# Log error if the scene file itself couldn't be loaded. Critical issue.
		printerr("[T2DATools]: {{ERROR}} Failed to preload dock scene! Check the path.")
		return

	# Create an instance of the scene.
	main_dock_panel = dock_scene.instantiate()
	if not is_instance_valid(main_dock_panel):
		# Log error if the scene exists but couldn't be instantiated. Scene might be broken.
		printerr("[T2DATools]: {{ERROR}} Failed to instantiate dock scene! Is the scene file valid?")
		main_dock_panel = null # Clear the potentially invalid reference
		return

	add_control_to_dock(DOCK_SLOT_LEFT_UL, main_dock_panel)
	print("[T2DATools]: Plugin UI added to DOCK_SLOT_LEFT_UL.")

	# Pass the editor interface reference to the dock script if it needs it.
	# This allows the dock script to interact with editor features.
	if main_dock_panel.has_method("set_editor_interface"):
		main_dock_panel.set_editor_interface(get_editor_interface())
	else:
		printerr("[T2DATools]: {{ERROR}} Dock scene script does not have a 'set_editor_interface' method. Did something go wrong with `t2da_dock.gd` or `t2da_dock.tscn`?")


## Called when the plugin is deactivated (exits the editor tree).
## Removes the plugin's UI panel from the docks and frees the instance.
func _exit_tree():
	# Check if we have a valid reference to our UI panel before trying to remove it.
	if is_instance_valid(main_dock_panel):
		# --- REMOVE FROM DOCKS ---
		# Use remove_control_from_docks() which corresponds to add_control_to_dock().
		remove_control_from_docks(main_dock_panel)
		print("[T2DATools]: Plugin UI removed from docks.")

		# Queue the panel instance for deletion. This is important for cleanup.
		main_dock_panel.queue_free()

	# Always clear the reference after cleanup or if it was invalid initially.
	main_dock_panel = null