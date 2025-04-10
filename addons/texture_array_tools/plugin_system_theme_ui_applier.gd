@tool
# plugin_system_theme_ui_applier.gd'
# This script required some serious assistance from Gemini AI! I was lost in the sauce for way too long on this lmao.
## Applies theme settings from the Godot Editor's theme to a target Control node.
## This resource reads theme properties like StyleBoxes, Colors, Fonts, etc.,
## based on a set of configurable rules and applies them as overrides to Controls
## within the target panel (typically your plugin's main UI container).
## Assign this resource (.tres file) to an exported variable in your plugin's UI script.
class_name PluginSystemThemeUIApplier
extends Resource

#region Enums

## Defines the types of Control nodes we might want to theme.
## Used in rules to specify which editor theme item to fetch (e.g., Button's style).
enum ControlType {
	PANEL, LABEL, BUTTON, OPTION_BUTTON, CHECK_BUTTON, LINE_EDIT,
	H_SEPARATOR, V_SEPARATOR, HBOX_CONTAINER, VBOX_CONTAINER, GRID_CONTAINER,
	SPIN_BOX, PROGRESS_BAR, TREE, TEXT_EDIT, RICH_TEXT_LABEL, SCROLL_CONTAINER
}

## Defines the types of theme items we can fetch and apply.
## Like choosing the right tool for the job: StyleBox for looks, Color for... color!
enum ThemeItemType {
	STYLE_BOX, COLOR, FONT, ICON, CONSTANT, FONT_SIZE, CURSOR
}

#endregion

#region Configuration

## A prefix for log messages printed by this script. Helps identify where messages come from!
## Example: "[T2DATheme]: StyleBox 'panel' applied."
@export var log_prefix: String = "[PluginTheme]: "

## An array of dictionaries defining the theming rules.
## Each rule specifies:
## - "control_type": The ControlType enum string (e.g., "BUTTON") - used to look up the item in the *editor's* theme.
## - "theme_item_type": The ThemeItemType enum string (e.g., "STYLE_BOX") - what kind of item to get.
## - "theme_item_name": The specific name of the theme item (e.g., "normal", "font_color", "panel").
## - "target_node_type": The exact class name string (e.g., "Button", "Label", "Panel") of the node in *your* plugin UI to apply the override to.
##
## IMPORTANT: Be thorough! A Button needs rules for "normal", "hover", "pressed", "disabled", "focus", "font_color", etc.
## Use tools like the Editor Theme Explorer plugin (AssetLib) to find the correct names and types.
@export var theming_rules: Array[Dictionary] = [
	# --- Panel ---
	{"control_type": "Panel", "theme_item_type": "STYLE_BOX", "theme_item_name": "panel", "target_node_type": "Panel"},

	# --- Button --- (Gotta catch 'em all: states, colors, fonts!)
	{"control_type": "Button", "theme_item_type": "STYLE_BOX", "theme_item_name": "normal", "target_node_type": "Button"},
	{"control_type": "Button", "theme_item_type": "STYLE_BOX", "theme_item_name": "hover", "target_node_type": "Button"},
	{"control_type": "Button", "theme_item_type": "STYLE_BOX", "theme_item_name": "pressed", "target_node_type": "Button"},
	{"control_type": "Button", "theme_item_type": "STYLE_BOX", "theme_item_name": "disabled", "target_node_type": "Button"},
	{"control_type": "Button", "theme_item_type": "STYLE_BOX", "theme_item_name": "focus", "target_node_type": "Button"},
	{"control_type": "Button", "theme_item_type": "COLOR", "theme_item_name": "font_color", "target_node_type": "Button"},
	{"control_type": "Button", "theme_item_type": "COLOR", "theme_item_name": "font_pressed_color", "target_node_type": "Button"},
	{"control_type": "Button", "theme_item_type": "COLOR", "theme_item_name": "font_hover_color", "target_node_type": "Button"},
	{"control_type": "Button", "theme_item_type": "COLOR", "theme_item_name": "font_focus_color", "target_node_type": "Button"},
	{"control_type": "Button", "theme_item_type": "COLOR", "theme_item_name": "font_disabled_color", "target_node_type": "Button"},
	{"control_type": "Button", "theme_item_type": "FONT", "theme_item_name": "font", "target_node_type": "Button"},
	{"control_type": "Button", "theme_item_type": "FONT_SIZE", "theme_item_name": "font_size", "target_node_type": "Button"},

	# --- Label ---
	{"control_type": "Label", "theme_item_type": "COLOR", "theme_item_name": "font_color", "target_node_type": "Label"},
	{"control_type": "Label", "theme_item_type": "FONT", "theme_item_name": "font", "target_node_type": "Label"},
	{"control_type": "Label", "theme_item_type": "FONT_SIZE", "theme_item_name": "font_size", "target_node_type": "Label"},

	# --- LineEdit ---
	{"control_type": "LineEdit", "theme_item_type": "STYLE_BOX", "theme_item_name": "normal", "target_node_type": "LineEdit"},
	{"control_type": "LineEdit", "theme_item_type": "STYLE_BOX", "theme_item_name": "focus", "target_node_type": "LineEdit"},
	{"control_type": "LineEdit", "theme_item_type": "STYLE_BOX", "theme_item_name": "read_only", "target_node_type": "LineEdit"},
	{"control_type": "LineEdit", "theme_item_type": "COLOR", "theme_item_name": "font_color", "target_node_type": "LineEdit"},
	{"control_type": "LineEdit", "theme_item_type": "COLOR", "theme_item_name": "font_selected_color", "target_node_type": "LineEdit"},
	{"control_type": "LineEdit", "theme_item_type": "COLOR", "theme_item_name": "font_uneditable_color", "target_node_type": "LineEdit"},
	{"control_type": "LineEdit", "theme_item_type": "COLOR", "theme_item_name": "caret_color", "target_node_type": "LineEdit"},
	{"control_type": "LineEdit", "theme_item_type": "COLOR", "theme_item_name": "selection_color", "target_node_type": "LineEdit"},
	{"control_type": "LineEdit", "theme_item_type": "FONT", "theme_item_name": "font", "target_node_type": "LineEdit"},
	{"control_type": "LineEdit", "theme_item_type": "FONT_SIZE", "theme_item_name": "font_size", "target_node_type": "LineEdit"},

	# --- OptionButton --- (Inherits from Button, but might have specifics)
	{"control_type": "OptionButton", "theme_item_type": "STYLE_BOX", "theme_item_name": "normal", "target_node_type": "OptionButton"},
	{"control_type": "OptionButton", "theme_item_type": "STYLE_BOX", "theme_item_name": "hover", "target_node_type": "OptionButton"},
	{"control_type": "OptionButton", "theme_item_type": "STYLE_BOX", "theme_item_name": "pressed", "target_node_type": "OptionButton"},
	{"control_type": "OptionButton", "theme_item_type": "STYLE_BOX", "theme_item_name": "disabled", "target_node_type": "OptionButton"},
	{"control_type": "OptionButton", "theme_item_type": "STYLE_BOX", "theme_item_name": "focus", "target_node_type": "OptionButton"},
	{"control_type": "OptionButton", "theme_item_type": "COLOR", "theme_item_name": "font_color", "target_node_type": "OptionButton"},
	# ... (add other color/font states if needed, check editor theme)
	{"control_type": "OptionButton", "theme_item_type": "ICON", "theme_item_name": "arrow", "target_node_type": "OptionButton"},
	{"control_type": "OptionButton", "theme_item_type": "CONSTANT", "theme_item_name": "arrow_margin", "target_node_type": "OptionButton"},
	{"control_type": "OptionButton", "theme_item_type": "CONSTANT", "theme_item_name": "modulate_arrow", "target_node_type": "OptionButton"}, # 0 or 1

	# --- CheckButton --- (Needs styles/icons for on/off states)
	{"control_type": "CheckButton", "theme_item_type": "STYLE_BOX", "theme_item_name": "normal", "target_node_type": "CheckButton"},
	{"control_type": "CheckButton", "theme_item_type": "STYLE_BOX", "theme_item_name": "pressed", "target_node_type": "CheckButton"},
	{"control_type": "CheckButton", "theme_item_type": "STYLE_BOX", "theme_item_name": "hover", "target_node_type": "CheckButton"},
	{"control_type": "CheckButton", "theme_item_type": "STYLE_BOX", "theme_item_name": "hover_pressed", "target_node_type": "CheckButton"},
	{"control_type": "CheckButton", "theme_item_type": "STYLE_BOX", "theme_item_name": "disabled", "target_node_type": "CheckButton"},
	{"control_type": "CheckButton", "theme_item_type": "STYLE_BOX", "theme_item_name": "focus", "target_node_type": "CheckButton"},
	{"control_type": "CheckButton", "theme_item_type": "ICON", "theme_item_name": "on", "target_node_type": "CheckButton"},
	{"control_type": "CheckButton", "theme_item_type": "ICON", "theme_item_name": "on_disabled", "target_node_type": "CheckButton"},
	{"control_type": "CheckButton", "theme_item_type": "ICON", "theme_item_name": "off", "target_node_type": "CheckButton"},
	{"control_type": "CheckButton", "theme_item_type": "ICON", "theme_item_name": "off_disabled", "target_node_type": "CheckButton"},
	{"control_type": "CheckButton", "theme_item_type": "COLOR", "theme_item_name": "font_color", "target_node_type": "CheckButton"},
	# ... (add other color/font states if needed)

	# --- Separators ---
	{"control_type": "HSeparator", "theme_item_type": "STYLE_BOX", "theme_item_name": "separator", "target_node_type": "HSeparator"},
	{"control_type": "HSeparator", "theme_item_type": "CONSTANT", "theme_item_name": "separation", "target_node_type": "HSeparator"},
	{"control_type": "VSeparator", "theme_item_type": "STYLE_BOX", "theme_item_name": "separator", "target_node_type": "VSeparator"},
	{"control_type": "VSeparator", "theme_item_type": "CONSTANT", "theme_item_name": "separation", "target_node_type": "VSeparator"},

	# --- ProgressBar ---
	{"control_type": "ProgressBar", "theme_item_type": "STYLE_BOX", "theme_item_name": "background", "target_node_type": "ProgressBar"},
	{"control_type": "ProgressBar", "theme_item_type": "STYLE_BOX", "theme_item_name": "fill", "target_node_type": "ProgressBar"},
	{"control_type": "ProgressBar", "theme_item_type": "COLOR", "theme_item_name": "font_color", "target_node_type": "ProgressBar"},
	{"control_type": "ProgressBar", "theme_item_type": "FONT", "theme_item_name": "font", "target_node_type": "ProgressBar"},
	{"control_type": "ProgressBar", "theme_item_type": "FONT_SIZE", "theme_item_name": "font_size", "target_node_type": "ProgressBar"},

	# Add rules for SpinBox, Tree, TextEdit, RichTextLabel, ScrollContainer etc. as needed...
	# Example for TextEdit:
	{"control_type": "TextEdit", "theme_item_type": "STYLE_BOX", "theme_item_name": "normal", "target_node_type": "TextEdit"},
	{"control_type": "TextEdit", "theme_item_type": "STYLE_BOX", "theme_item_name": "focus", "target_node_type": "TextEdit"},
	{"control_type": "TextEdit", "theme_item_type": "STYLE_BOX", "theme_item_name": "read_only", "target_node_type": "TextEdit"},
	{"control_type": "TextEdit", "theme_item_type": "COLOR", "theme_item_name": "font_color", "target_node_type": "TextEdit"},
	# ... and so on for TextEdit colors, fonts, constants...
]
#endregion

#region Helper Functions (Get Editor Theme Items)
# These little helpers dive into the editor's theme pool and fish out the goodies.
# They handle the boring checks so apply_theming() stays clean.

## Fetches a generic theme item from the editor's theme.
## Use this for types not covered by specific helpers (like Cursor).
## Parameters:
##   - editor_base_control: The root Control node of the editor UI.
##   - theme_item_name: The name of the item (e.g., "busy_cursor").
##   - theme_type_lookup: The editor's theme type name (e.g., "Editor").
## Returns: The theme item Variant, or null if not found or invalid control.
func _get_editor_theme_item(editor_base_control: Control, theme_item_name: String, theme_type_lookup: String):
	if not is_instance_valid(editor_base_control):
		printerr(log_prefix + "Editor base control went AWOL. Cannot fetch item.")
		return null
	# Editor theme usually uses Capitalized names like "Button", "Label"
	var type_name_capitalized = theme_type_lookup.capitalize()
	if editor_base_control.has_theme_item(theme_item_name, type_name_capitalized):
		return editor_base_control.get_theme_item(theme_item_name, type_name_capitalized)
	else:
		# Don't spam errors for common misses like 'focus' on simple controls.
		# You might want to make this quieter or conditional later.
		# printerr(log_prefix + "Theme item '%s' not found in type '%s'" % [theme_item_name, type_name_capitalized])
		return null

## Fetches a Color item from the editor's theme. Returns white on failure.
## Parameters: (See _get_editor_theme_item)
## Returns: The Color, or Color.WHITE if not found.
func _get_editor_theme_color(editor_base_control: Control, theme_color_name: String, theme_type_lookup: String) -> Color:
	if not is_instance_valid(editor_base_control):
		printerr(log_prefix + "Editor base control vanished! Returning default color.")
		return Color.WHITE
	var type_name_capitalized = theme_type_lookup.capitalize()
	if editor_base_control.has_theme_color(theme_color_name, type_name_capitalized):
		return editor_base_control.get_theme_color(theme_color_name, type_name_capitalized)
	else:
		# printerr(log_prefix + "Theme color '%s' not found in type '%s'" % [theme_color_name, type_name_capitalized])
		return Color.WHITE # A safe default

## Fetches a Font item from the editor's theme. Returns null on failure.
## Parameters: (See _get_editor_theme_item)
## Returns: The Font resource, or null if not found.
func _get_editor_theme_font(editor_base_control: Control, theme_font_name: String, theme_type_lookup: String) -> Font:
	if not is_instance_valid(editor_base_control):
		printerr(log_prefix + "Editor base control is playing hide-and-seek. No font for you.")
		return null
	var type_name_capitalized = theme_type_lookup.capitalize()
	if editor_base_control.has_theme_font(theme_font_name, type_name_capitalized):
		return editor_base_control.get_theme_font(theme_font_name, type_name_capitalized)
	else:
		# printerr(log_prefix + "Theme font '%s' not found in type '%s'" % [theme_font_name, type_name_capitalized])
		return null

## Fetches a StyleBox item from the editor's theme. Returns null on failure.
## Parameters: (See _get_editor_theme_item)
## Returns: The StyleBox resource, or null if not found.
## REMEMBER: Duplicate the returned StyleBox before applying it as an override!
func _get_editor_theme_stylebox(editor_base_control: Control, theme_stylebox_name: String, theme_type_lookup: String) -> StyleBox:
	if not is_instance_valid(editor_base_control):
		printerr(log_prefix + "Where did the editor base go? No StyleBox found.")
		return null
	var type_name_capitalized = theme_type_lookup.capitalize()
	if editor_base_control.has_theme_stylebox(theme_stylebox_name, type_name_capitalized):
		return editor_base_control.get_theme_stylebox(theme_stylebox_name, type_name_capitalized)
	else:
		# printerr(log_prefix + "Theme stylebox '%s' not found in type '%s'" % [theme_stylebox_name, type_name_capitalized])
		return null

## Fetches an Icon (Texture2D) item from the editor's theme. Returns null on failure.
## Parameters: (See _get_editor_theme_item)
## Returns: The Texture2D resource, or null if not found.
func _get_editor_theme_icon(editor_base_control: Control, theme_icon_name: String, theme_type_lookup: String) -> Texture2D:
	if not is_instance_valid(editor_base_control):
		printerr(log_prefix + "Base control missing, cannot fetch icon.")
		return null
	var type_name_capitalized = theme_type_lookup.capitalize()
	if editor_base_control.has_theme_icon(theme_icon_name, type_name_capitalized):
		return editor_base_control.get_theme_icon(theme_icon_name, type_name_capitalized)
	else:
		# printerr(log_prefix + "Theme icon '%s' not found in type '%s'" % [theme_icon_name, type_name_capitalized])
		return null

## Fetches a theme constant (int) item from the editor's theme. Returns 0 on failure.
## Parameters: (See _get_editor_theme_item)
## Returns: The integer constant value, or 0 if not found.
func _get_editor_theme_constant(editor_base_control: Control, theme_constant_name: String, theme_type_lookup: String) -> int:
	if not is_instance_valid(editor_base_control):
		printerr(log_prefix + "Base control MIA, returning default constant.")
		return 0
	var type_name_capitalized = theme_type_lookup.capitalize()
	if editor_base_control.has_theme_constant(theme_constant_name, type_name_capitalized):
		return editor_base_control.get_theme_constant(theme_constant_name, type_name_capitalized)
	else:
		# printerr(log_prefix + "Theme constant '%s' not found in type '%s'" % [theme_constant_name, type_name_capitalized])
		return 0 # Sensible default? Maybe -1 sometimes? Depends on the constant.

## Fetches a theme font size (int) item from the editor's theme. Returns -1 on failure.
## Parameters: (See _get_editor_theme_item)
## Returns: The font size, or -1 if not found.
func _get_editor_theme_font_size(editor_base_control: Control, theme_font_size_name: String, theme_type_lookup: String) -> int:
	if not is_instance_valid(editor_base_control):
		printerr(log_prefix + "Can't find base control, font size defaulted.")
		return -1 # Using -1 to indicate "not found" clearly
	var type_name_capitalized = theme_type_lookup.capitalize()
	if editor_base_control.has_theme_font_size(theme_font_size_name, type_name_capitalized):
		return editor_base_control.get_theme_font_size(theme_font_size_name, type_name_capitalized)
	else:
		# printerr(log_prefix + "Theme font size '%s' not found in type '%s'" % [theme_font_size_name, type_name_capitalized])
		return -1
#endregion

#region Main Theming Logic

## Applies the defined `theming_rules` to all relevant Control nodes within the `dock_panel`.
## It iterates through the panel's children, finds Controls, checks their type against the rules,
## fetches the corresponding item from the editor's theme, and applies it as an override.
## Parameters:
##   - dock_panel: The root Control node of the UI to apply themes to.
func apply_theming(dock_panel: Control):
	# Need the editor's main UI control to borrow its theme items.
	var editor_base_control = EditorInterface.get_base_control()

	if not is_instance_valid(editor_base_control):
		printerr(log_prefix + "Editor base control is invalid! Abandoning theme application. Your plugin might look a bit plain.")
		return

	# Let's gather all the Controls hiding inside the dock_panel.
	var nodes_to_theme: Array[Control] = []
	_collect_control_nodes(dock_panel, nodes_to_theme)
	nodes_to_theme.push_front(dock_panel) # Don't forget the root panel itself!

	print(log_prefix + "Found %d Control nodes to potentially theme." % nodes_to_theme.size())

	# Time for the makeover montage! Loop through each control.
	for node in nodes_to_theme:
		if not is_instance_valid(node):
			# Oops, this one disappeared during the process? Skip it.
			continue

		# What kind of control is this? "Button", "Label", etc.
		var node_type_name: String = node.get_class()

		# Now, check our rulebook for anything that applies to this type.
		for rule in theming_rules:
			var target_node_type: String = rule["target_node_type"] # Type name in *your* UI (from rule)
			var control_type_for_lookup: String = rule["control_type"] # Type name to find in *editor* theme (from rule)
			var theme_item_type: String = rule["theme_item_type"] # "STYLE_BOX", "COLOR", etc.
			var theme_item_name: String = rule["theme_item_name"] # "panel", "normal", "font_color", etc.

			# Does this rule apply to this node?
			if target_node_type == node_type_name:
				# Found a match! Let's grab the theme item from the editor.
				var theme_value = null # Prepare to catch the theme item

				# Use our trusty helper functions based on the item type.
				match theme_item_type:
					"STYLE_BOX":
						theme_value = _get_editor_theme_stylebox(editor_base_control, theme_item_name, control_type_for_lookup)
						# CRITICAL: StyleBoxes MUST be duplicated, or they'll be shared and cause chaos!
						if theme_value:
							theme_value = theme_value.duplicate()
					"COLOR":
						theme_value = _get_editor_theme_color(editor_base_control, theme_item_name, control_type_for_lookup)
					"FONT":
						theme_value = _get_editor_theme_font(editor_base_control, theme_item_name, control_type_for_lookup)
					"ICON":
						theme_value = _get_editor_theme_icon(editor_base_control, theme_item_name, control_type_for_lookup)
					"CONSTANT":
						theme_value = _get_editor_theme_constant(editor_base_control, theme_item_name, control_type_for_lookup)
					"FONT_SIZE":
						theme_value = _get_editor_theme_font_size(editor_base_control, theme_item_name, control_type_for_lookup)
					"CURSOR":
						# Cursors might be special, often set via constants or specific properties.
						# This generic fetch might work for some cases. Needs testing!
						theme_value = _get_editor_theme_item(editor_base_control, theme_item_name, control_type_for_lookup)
						printerr(log_prefix + "Warning: Applying CURSOR theme item generically. Verify result.")
					_:
						# We should only hit this if the rules contain bad data.
						printerr(log_prefix + "Yikes! Unknown theme item type in rule: '%s' for node type '%s'" % [theme_item_type, node_type_name])
						continue # Skip this broken rule

				# Did we successfully get a theme value?
				if theme_value != null:
					# Apply the override! Use the correct 'add_theme_*_override' method.
					match theme_item_type:
						"STYLE_BOX":
							node.add_theme_stylebox_override(theme_item_name, theme_value)
						"COLOR":
							node.add_theme_color_override(theme_item_name, theme_value)
						"FONT":
							node.add_theme_font_override(theme_item_name, theme_value)
						"ICON":
							node.add_theme_icon_override(theme_item_name, theme_value)
						"CONSTANT":
							node.add_theme_constant_override(theme_item_name, theme_value)
						"FONT_SIZE":
							# Special case: font size might return -1 if not found, don't override in that case.
							if theme_value >= 0:
								node.add_theme_font_size_override(theme_item_name, theme_value)
						"CURSOR":
							# How DO we apply a cursor override? Probably need a specific method or constant.
							# Control.mouse_default_cursor_shape might be relevant? Needs investigation.
							printerr(log_prefix + "Cursor override application not fully implemented for '%s'." % theme_item_name)
						_:
							# This case was handled in the fetch match, shouldn't happen here.
							pass
				#else:
					# Uncomment this if you want to know about every *single* missed theme item. Can be noisy!
					#print(log_prefix + "Did not find editor theme item '%s' of type '%s' for control type '%s'" % [theme_item_name, theme_item_type, control_type_for_lookup])


## Recursively searches through the children of `start_node` and adds all
## nodes inheriting from Control to the `collection` array.
## Parameters:
##   - start_node: The Node to start searching from.
##   - collection: The Array to append found Control nodes to.
func _collect_control_nodes(start_node: Node, collection: Array[Control]):
	# Look at all the direct children first.
	for child in start_node.get_children():
		# Is it a Control node? If yes, add it to our list.
		if child is Control:
			collection.append(child)
		# Does this child have its own children? Dive deeper! (Recursion FTW)
		if child.get_child_count() > 0:
			_collect_control_nodes(child, collection)

#endregion