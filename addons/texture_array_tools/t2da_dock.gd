@tool
# t2da_dock.gd
## Texture 2D Array Generator, combined with an Image Resizer - all in one!
## Stop leaving the editor when images are either mis-matched or the wrong format(s) for T2DA generation.
## Large WIP, full of unusually cramped functions.
## Frustratingly immature comment style.
extends Panel

#region Constants and Enums

## IDs for Resize Aspect Modes. Because magic numbers are for chumps.
const ASPECT_MODE_STRETCH = 0 # Whether we stretch an image and risk it all, or not.
const ASPECT_MODE_PAD = 1 # Keep aspect, add tasteful (or not) padding.
const ASPECT_MODE_CROP = 2 # Keep aspect, aggressively crop the excess.

## Default color for padding. Void black, very slimming.
const DEFAULT_PAD_COLOR = Color(0.0, 0.0, 0.0, 0.0)
## Default quality for lossy formats (0-100). 87 is pretty good, right?
const DEFAULT_LOSSY_QUALITY = 87

#endregion

#region Exports & Configuration

## Log prefix. So you know who's spamming your console.
@export_category("Texture 2D Array Generator")
@export_subgroup("Config")
@export var log_prefix: String = "[T2DAGenerator]: "
## Default name for the output array. Be creative! Or not.
@export var default_output_array_name: String = "MyT2DA"
## Default save folder for the T2DA. Throw it somewhere organized. Maybe.
@export var default_output_path: String = "res://_generated_t2darrays"
## Default save folder for resized pics. Throw it somewhere organized. Maybe.
@export var default_image_resize_output_path: String = "res://_resized_images"

## Theming resource slot. Drag your theme applier .tres file here!
## Makes this plugin look less like a default UI disaster. My standards could be more strict.
@export var theme_applier: PluginSystemThemeUIApplier

#endregion

#region Internal Variables

## Godot Editor Interface. Our connection to the mothership.
var editor_interface: EditorInterface
## File Dialog. The gatekeeper for files and folders.
var file_selection_dialog: EditorFileDialog

# --- State Variables ---
## Resizer: Use largest dimensions? True = Auto, False = Manual Input.
var _use_largest_image_dimensions: bool = true
## Resizer: Paths for images waiting to be resized.
var _resize_input_image_paths: PackedStringArray = []
## T2DA Gen: Actual Texture2D resources loaded. Precious cargo. Handle with care.
var _t2da_input_textures: Array[Texture2D] = []

# --- T2DA Generator Specific ---
## T2DA Gen: Should we force all input images into one format? The great equalizer.
var _t2da_ensure_format: bool = false
## T2DA Gen: If ensuring format, which one? RGBA8 is usually the safe bet.
var _t2da_target_format: Image.Format = Image.FORMAT_RGBA8
## T2DA Gen: Create a subfolder named after the array? For the organizationally inclined.
var _t2da_create_subfolder: bool = false
## T2DA Gen: Allow overwriting existing T2DA files? Live dangerously?
var _t2da_allow_overwrite: bool = false

# --- Resizer Specific ---
## Resizer: Optional text to add BEFORE the original filename. Branding!
var _resizer_output_prefix: String = ""
## Resizer: Optional text to add AFTER the original filename (before ext/counter).
var _resizer_output_suffix: String = ""
## Resizer: Output file format extension ("png", "jpg", "detect", etc). Choose wisely.
var _resizer_output_format_ext: String = "detect"
## Resizer: Color used for padding when using ASPECT_MODE_PAD.
var _resizer_pad_color: Color = DEFAULT_PAD_COLOR
## Resizer: Should we generate mipmaps for resized images? Controlled by checkbox AND import detection.
var _resizer_use_mipmaps: bool = false
## Resizer: Output quality for lossy formats (JPG/WebP), range 0-100.
var _resizer_output_quality: int = DEFAULT_LOSSY_QUALITY
## Resizer: Create a timestamped subfolder?
var _resizer_create_subfolder: bool = false
## Resizer: Trim, replace and remove whitespace from filenames?
var _resizer_remove_whitespace: bool = false
## Resizer: Enable batch renaming? Give 'em all the same base name!
var _resizer_batch_rename_enabled: bool = false
## Resizer: The base name to use for batch renaming.
var _resizer_batch_rename_pattern: String = "image"

## Transfer: Auto-send resized images to T2DA Gen?
var _transfer_images_to_array_generator_after_resize: bool = false

# --- Other ---
## Stores the default mipmap state detected from first image's .import.
var _default_mipmap_state: bool = false
## Reset color constant. Back to black (transparent).
const RESET_COLOR = Color(0, 0, 0, 0)

#endregion

#region UI Node References (@onready)
# Grabbing UI nodes. If these fail, you probably broke the scene file. No pressure.

@onready var t2da_tools_doc_title_label: Label = %Label_T2DAToolTitle

# --- T2DA Generator ---
@onready var t2da_title_label: Label = %Label_Texture2DArrayGeneratorTitle
@onready var output_array_name_line_edit: LineEdit = %LineEdit_ArrayName
@onready var output_array_name_button: Button = %Button_ArrayName
@onready var input_files_count_label: Label = %Label_InputFilesCount
@onready var browse_input_files_button: Button = %Button_BrowseInputFiles
@onready var output_path_line_edit: LineEdit = %LineEdit_OutputPath
@onready var browse_output_folder_button: Button = %Button_OutputPath
@onready var input_files_status_label: Label = %Label_ImageStatus
@onready var ensure_format_check_button: CheckButton = %"CheckButton_EnsureFormat?"
@onready var ensure_format_option_button: OptionButton = %OptionButton_EnsureFormatOptions
@onready var generate_subfolder_from_array_name_check_button: CheckButton = %CheckButton_GenerateSubfolderFromArrayName
@onready var overwrite_existing_array_check_button: CheckButton = %CheckButton_OverwriteExistingArray
@onready var ready_to_generate_label: Label = %Label_ReadyToGenerate
@onready var build_t2da_button: Button = %Button_GenerateArray

# --- Transfer Section ---
@onready var transfer_to_resizer_section_title_label: Label = %Label_TransferGenToResizer
@onready var transfer_array_input_files_to_resizer_button: Button = %Button_GenTransferToImageResizer

# --- Image Resizer ---
@onready var resizer_title_label: Label = %Label_ImageResizerTitle
@onready var resize_input_files_count_label: Label = %Label_InputFilesCount2
@onready var image_resize_browse_input_files_button: Button = %Button_BrowseInputFiles2
@onready var image_resize_output_path_line_edit: LineEdit = %LineEdit_OutputPath2
@onready var image_resize_browse_output_folder_button: Button = %Button_OutputPath2
@onready var largest_image_size_label: Label = %Label_CurrentLargestSizeDisplay
@onready var use_largest_size_check_button: CheckButton = %CheckButton_UseLargestSize
@onready var custom_image_width_line_edit: LineEdit = %LineEdit_NewSize_Width
@onready var custom_image_height_line_edit: LineEdit = %LineEdit_NewSize_Height
@onready var resize_mode_option_button: OptionButton = %OptionButton_ResizeMode # Aspect mode
@onready var resize_filter_option_button: OptionButton = %OptionButton_ResizeFilter # Interpolation filter
@onready var output_prefix_line_edit: LineEdit = %LineEdit_OutputPrefix
@onready var output_suffix_line_edit: LineEdit = %LineEdit_OutputSuffix
@onready var output_format_option_button: OptionButton = %OptionButton_OutputFormat
@onready var output_quality_label: Label = %Label_FormatImageOutputQuality
@onready var format_image_output_quality_h_slider: HSlider = %HSlider_FormatImageOutputQuality
@onready var output_quality_value_label: Label = %Label_OutputQualityValue
@onready var padding_color_picker: ColorPickerButton = %ColorPickerButton_PaddingColor
@onready var use_mipmaps_check_button: CheckButton = %CheckButton_UseMipmaps
@onready var resizer_create_subfolder_check_button: CheckButton = %CheckButton_ResizerCreateSubfolder
@onready var remove_whitespace_from_file_names_check_button: CheckButton = %CheckButton_RemoveWhitespaceFromFileNames
@onready var batch_rename_image_output_files_check_button: CheckButton = %CheckButton_BatchRenameImageOutputFiles
@onready var batch_rename_output_images_line_edit: LineEdit = %LineEdit_BatchRenameOutputImages
@onready var resize_image_status_label: Label = %Label_ResizeImageStatus
@onready var resize_images_button: Button = %Button_ResizeImages
@onready var ready_to_resize_label: Label = %Label_ReadyToResize

# --- Transfer Area ---
@onready var transfer_to_generator_section_title_label: Label = %Label_TransferResizerToGen
@onready var transfer_resizer_input_files_to_array_gen_button: Button = %Button_TransferInputFilesToArrayGen
@onready var transfer_resizer_output_images_to_array_gen_button: Button = %Button_TransferResizedToArrayGen
@onready var transfer_images_to_array_generator_check_button: CheckButton = %CheckButton_TransferToArrayGen

#endregion

#region Initialization & Setup

## Called by plugin.gd. Gets the holy EditorInterface. Essential.
## Also applies icons and styles that depend on the editor interface being available.
func set_editor_interface(ei: EditorInterface):
	editor_interface = ei
	print(log_prefix + "Editor Interface received. We have contact!")
	# Apply icons and styles AFTER we have the interface
	_apply_button_icons()
	_apply_title_label_styles()

## _ready(): Where the UI comes alive (or tries to). Sets initial states.
func _ready():
	print(log_prefix + "Dock panel reporting for duty! _ready() firing.")

	# --- Initialize File Dialog ---
	file_selection_dialog = EditorFileDialog.new()
	add_child(file_selection_dialog)
	file_selection_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_selection_dialog.title = "File Dialog - Choose Wisely..."

	# --- Set Initial UI Values ---
	# Check instance validity just to be super safe, though @onready should handle it
	if is_instance_valid(output_array_name_line_edit):
		output_array_name_line_edit.text = default_output_array_name
	if is_instance_valid(output_path_line_edit):
		output_path_line_edit.text = default_output_path
	if is_instance_valid(image_resize_output_path_line_edit):
		image_resize_output_path_line_edit.text = default_image_resize_output_path
	if is_instance_valid(output_prefix_line_edit):
		output_prefix_line_edit.text = _resizer_output_prefix
	if is_instance_valid(output_suffix_line_edit):
		output_suffix_line_edit.text = _resizer_output_suffix
	if is_instance_valid(padding_color_picker):
		padding_color_picker.color = _resizer_pad_color
	if is_instance_valid(batch_rename_output_images_line_edit):
		batch_rename_output_images_line_edit.text = _resizer_batch_rename_pattern
	# Quality slider/label init
	if is_instance_valid(format_image_output_quality_h_slider):
		format_image_output_quality_h_slider.value = DEFAULT_LOSSY_QUALITY
	if is_instance_valid(output_quality_value_label):
		output_quality_value_label.text = "%d%%" % DEFAULT_LOSSY_QUALITY

	# --- Set Initial UI States & Populate Dropdowns ---
	_update_use_largest_size_ui()
	_populate_resize_mode_option_button()
	_populate_resize_filter_option_button()
	_populate_ensure_format_options()
	_populate_output_format_options()
	_update_t2da_input_files_status()
	_update_resize_input_files_status() # Also sets mipmap default
	_update_quality_slider_visibility() # Initial visibility check

	# --- Initial Control Disabling ---
	if is_instance_valid(resize_images_button):
		resize_images_button.disabled = true
	if is_instance_valid(ensure_format_option_button):
		ensure_format_option_button.disabled = true # Controlled by checkbox
	if is_instance_valid(padding_color_picker):
		padding_color_picker.disabled = true # Controlled by resize mode
	if is_instance_valid(batch_rename_output_images_line_edit):
		batch_rename_output_images_line_edit.editable = false # Controlled by checkbox
	if is_instance_valid(format_image_output_quality_h_slider):
		format_image_output_quality_h_slider.editable = false # Controlled by format selection
	if is_instance_valid(output_quality_value_label):
		output_quality_value_label.visible = false # Controlled by format selection
	if is_instance_valid(output_quality_label):
		output_quality_label.visible = false

	# --- Connect Signals ---
	_connect_signals()

	# --- Apply Theme ---
	if theme_applier != null and theme_applier is PluginSystemThemeUIApplier:
		print(log_prefix + "Applying theme makeover!")
		theme_applier.apply_theming(self)
		print(log_prefix + "Theme applied.")
	else:
		push_warning(log_prefix + "No valid Theme Applier resource found! UI might look basic.")

## Connects ALL the signals. The central switchboard.
func _connect_signals():
	# --- T2DA Generation ---
	if is_instance_valid(output_array_name_button):
		output_array_name_button.pressed.connect(_on_save_file_name_button_pressed)
	if is_instance_valid(browse_input_files_button):
		browse_input_files_button.pressed.connect(_on_browse_t2da_input_files_button_pressed)
	if is_instance_valid(browse_output_folder_button):
		browse_output_folder_button.pressed.connect(_on_browse_t2da_output_folder_pressed)
	if is_instance_valid(build_t2da_button):
		build_t2da_button.pressed.connect(_on_build_texture_array_button_pressed)
	if is_instance_valid(output_array_name_line_edit):
		output_array_name_line_edit.text_changed.connect(_on_output_array_name_changed)
	if is_instance_valid(output_path_line_edit):
		output_path_line_edit.text_changed.connect(_on_output_path_changed)
	if is_instance_valid(ensure_format_check_button):
		ensure_format_check_button.toggled.connect(_on_ensure_format_toggled)
	if is_instance_valid(ensure_format_option_button):
		ensure_format_option_button.item_selected.connect(_on_ensure_format_selected)
	if is_instance_valid(generate_subfolder_from_array_name_check_button):
		generate_subfolder_from_array_name_check_button.toggled.connect(func(p): _t2da_create_subfolder = p)
	if is_instance_valid(overwrite_existing_array_check_button):
		overwrite_existing_array_check_button.toggled.connect(func(p): _t2da_allow_overwrite = p)

	# --- Image Resizing ---
	if is_instance_valid(image_resize_browse_input_files_button):
		image_resize_browse_input_files_button.pressed.connect(_on_image_resize_browse_input_files_button_pressed)
	if is_instance_valid(image_resize_browse_output_folder_button):
		image_resize_browse_output_folder_button.pressed.connect(_on_image_resize_browse_output_folder_button_pressed)
	if is_instance_valid(use_largest_size_check_button):
		use_largest_size_check_button.toggled.connect(_on_use_largest_size_check_button_toggled)
	if is_instance_valid(custom_image_width_line_edit):
		custom_image_width_line_edit.text_changed.connect(_on_custom_image_size_changed)
	if is_instance_valid(custom_image_height_line_edit):
		custom_image_height_line_edit.text_changed.connect(_on_custom_image_size_changed)
	if is_instance_valid(resize_images_button):
		resize_images_button.pressed.connect(_on_resize_images_button_pressed)
	if is_instance_valid(resize_mode_option_button):
		resize_mode_option_button.item_selected.connect(_on_resize_mode_selected)
	if is_instance_valid(output_prefix_line_edit):
		output_prefix_line_edit.text_changed.connect(_on_output_prefix_changed)
	if is_instance_valid(output_suffix_line_edit):
		output_suffix_line_edit.text_changed.connect(_on_output_suffix_changed)
	if is_instance_valid(output_format_option_button):
		output_format_option_button.item_selected.connect(_on_output_format_selected)
	if is_instance_valid(format_image_output_quality_h_slider):
		format_image_output_quality_h_slider.value_changed.connect(_on_output_quality_slider_changed)
	if is_instance_valid(padding_color_picker):
		padding_color_picker.color_changed.connect(_on_padding_color_changed)
	if is_instance_valid(use_mipmaps_check_button):
		use_mipmaps_check_button.toggled.connect(_on_use_mipmaps_toggled)
	if is_instance_valid(resizer_create_subfolder_check_button):
		resizer_create_subfolder_check_button.toggled.connect(func(p): _resizer_create_subfolder = p)
	if is_instance_valid(remove_whitespace_from_file_names_check_button):
		remove_whitespace_from_file_names_check_button.toggled.connect(func(p): _resizer_remove_whitespace = p)
	if is_instance_valid(batch_rename_image_output_files_check_button):
		batch_rename_image_output_files_check_button.toggled.connect(_on_batch_rename_toggled)
	if is_instance_valid(batch_rename_output_images_line_edit):
		batch_rename_output_images_line_edit.text_changed.connect(_on_batch_rename_pattern_changed)

	# --- Transfer Area ---
	if is_instance_valid(transfer_resizer_input_files_to_array_gen_button):
		transfer_resizer_input_files_to_array_gen_button.pressed.connect(_on_transfer_resizer_input_files_to_array_gen_pressed)
	if is_instance_valid(transfer_resizer_output_images_to_array_gen_button):
		transfer_resizer_output_images_to_array_gen_button.pressed.connect(_on_transfer_resizer_output_images_to_array_gen_pressed)
	if is_instance_valid(transfer_array_input_files_to_resizer_button):
		transfer_array_input_files_to_resizer_button.pressed.connect(_on_transfer_array_input_files_to_resizer_pressed)
	if is_instance_valid(transfer_images_to_array_generator_check_button):
		transfer_images_to_array_generator_check_button.toggled.connect(func(p): _transfer_images_to_array_generator_after_resize = p)

## Populates Resize Mode (Aspect Ratio) dropdown.
func _populate_resize_mode_option_button():
	if not is_instance_valid(resize_mode_option_button):
		printerr(log_prefix + "{{ERROR}} Resize Mode OptionButton missing!")
		return
	resize_mode_option_button.clear()
	resize_mode_option_button.add_item("Stretch", ASPECT_MODE_STRETCH)
	resize_mode_option_button.add_item("Keep Aspect (Pad)", ASPECT_MODE_PAD)
	resize_mode_option_button.add_item("Keep Aspect (Crop)", ASPECT_MODE_CROP)

## Populates Resize Filter (Interpolation) dropdown.
func _populate_resize_filter_option_button():
	if not is_instance_valid(resize_filter_option_button):
		printerr(log_prefix + "{{ERROR}} Resize Filter OptionButton missing!")
		return
	resize_filter_option_button.clear()
	resize_filter_option_button.add_item("Nearest (Pixelated)", Image.INTERPOLATE_NEAREST)
	resize_filter_option_button.add_item("Bilinear (Smooth)", Image.INTERPOLATE_BILINEAR)
	resize_filter_option_button.add_item("Cubic (Smoother)", Image.INTERPOLATE_CUBIC)
	resize_filter_option_button.add_item("Lanczos (Sharpest)", Image.INTERPOLATE_LANCZOS)

## Populates T2DA Ensure Format dropdown.
func _populate_ensure_format_options():
	if not is_instance_valid(ensure_format_option_button):
		printerr(log_prefix + "{{ERROR}} Ensure Format OptionButton missing!")
		return
	ensure_format_option_button.clear()
	ensure_format_option_button.add_item("RGBA8 (Default)", Image.FORMAT_RGBA8)
	ensure_format_option_button.add_item("RGB8 (No Alpha)", Image.FORMAT_RGB8)
	ensure_format_option_button.add_item("LA8 (Luminance+Alpha)", Image.FORMAT_LA8)
	ensure_format_option_button.add_item("L8 (Grayscale)", Image.FORMAT_L8)
	ensure_format_option_button.add_item("RGBAF (HDR)", Image.FORMAT_RGBAF)
	_t2da_target_format = Image.FORMAT_RGBA8 # Default internal state

## Populates Resizer Output Format dropdown. Includes metadata for extensions.
func _populate_output_format_options():
	if not is_instance_valid(output_format_option_button):
		printerr(log_prefix + "{{ERROR}} Output Format OptionButton missing!")
		return
	output_format_option_button.clear()
	output_format_option_button.add_item("Detect from Input", 0)
	output_format_option_button.add_item("PNG (Lossless)", 1)
	output_format_option_button.add_item("JPG (Lossy)", 2)
	output_format_option_button.add_item("WebP (Lossy/Lossless)", 3)
	output_format_option_button.set_item_metadata(0, "detect")
	output_format_option_button.set_item_metadata(1, "png")
	output_format_option_button.set_item_metadata(2, "jpg")
	output_format_option_button.set_item_metadata(3, "webp")
	_resizer_output_format_ext = "detect" # Default internal state

#endregion

#region T2DA Generation Callbacks & Logic

## T2DA Output Name changed. Updates internal state.
func _on_output_array_name_changed(new_text: String):
	default_output_array_name = new_text

## T2DA Output Path changed. Updates internal state.
func _on_output_path_changed(new_text: String):
	default_output_path = new_text

## T2DA Save As button pressed. Shows file dialog.
func _on_save_file_name_button_pressed():
	_configure_file_dialog(
		EditorFileDialog.FILE_MODE_SAVE_FILE,
		"Save Texture2DArray As (.tres)",
		default_output_path,
		default_output_array_name + ".tres",
		PackedStringArray(["*.tres, *.res ; Godot Resource"]),
		_on_output_array_name_selected
	)

## T2DA Save As path selected by user. Updates UI fields.
func _on_output_array_name_selected(path: String):
	default_output_array_name = path.get_file().get_basename()
	default_output_path = path.get_base_dir()
	if is_instance_valid(output_array_name_line_edit):
		output_array_name_line_edit.text = default_output_array_name
	if is_instance_valid(output_path_line_edit):
		output_path_line_edit.text = default_output_path

## T2DA Browse Input button pressed. Shows file dialog for images.
func _on_browse_t2da_input_files_button_pressed():
	_configure_file_dialog(
		EditorFileDialog.FILE_MODE_OPEN_FILES,
		"Select Input Images for Texture Array",
		"res://",
		"",
		PackedStringArray(["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.tga", "*.exr", "*.hdr; Image Files"]),
		_on_t2da_input_files_selected
	)

## T2DA Input files selected by user. Loads them into memory.
func _on_t2da_input_files_selected(paths: PackedStringArray):
	_t2da_input_textures.clear()
	var loaded_count = 0
	var failed_count = 0
	print(log_prefix + "Loading %d images for T2DA..." % paths.size())
	for path in paths:
		var image: Image = Image.load_from_file(path)
		if image != null and not image.is_empty():
			var texture: ImageTexture = ImageTexture.create_from_image(image)
			if is_instance_valid(texture):
				texture.resource_path = path # Store path for transfers!
				_t2da_input_textures.append(texture)
				loaded_count += 1
			else:
				printerr(log_prefix + "ERR: Failed create ImageTexture for: %s" % path.get_file())
				failed_count += 1
		else:
			printerr(log_prefix + "ERR: Failed load image: %s" % path.get_file())
			failed_count += 1

	if is_instance_valid(input_files_count_label):
		input_files_count_label.text = "Images (%d)" % loaded_count
	_update_t2da_input_files_status() # Validate the loaded images

	if failed_count > 0:
		push_warning(log_prefix + "%d T2DA image(s) failed load." % failed_count)
	elif loaded_count > 0:
		print(log_prefix + "Loaded %d T2DA image(s)." % loaded_count)

## T2DA Browse Output Folder button pressed. Shows folder dialog.
func _on_browse_t2da_output_folder_pressed():
	_configure_file_dialog(
		EditorFileDialog.FILE_MODE_OPEN_DIR,
		"Select Output Folder for Texture Array",
		default_output_path,
		"",
		PackedStringArray([]),
		_on_t2da_output_folder_selected
	)

## T2DA Output folder selected by user. Updates path field.
func _on_t2da_output_folder_selected(path: String):
	default_output_path = path
	if is_instance_valid(output_path_line_edit):
		output_path_line_edit.text = path

## T2DA Ensure Format checkbox toggled. Enables/disables dropdown.
func _on_ensure_format_toggled(button_pressed: bool):
	_t2da_ensure_format = button_pressed
	if is_instance_valid(ensure_format_option_button):
		ensure_format_option_button.disabled = not button_pressed
	if not button_pressed:
		print(log_prefix + "Ensure Format disabled.")
		_update_t2da_input_files_status() # Re-validate originals
	else:
		print(log_prefix + "Ensure Format enabled. Target: %s" % _get_image_format_name(_t2da_target_format))

## T2DA Ensure Format dropdown selection changed. Updates target format.
func _on_ensure_format_selected(index: int):
	if is_instance_valid(ensure_format_option_button):
		_t2da_target_format = ensure_format_option_button.get_selected_id()
		print(log_prefix + "T2DA target format set to: %s" % _get_image_format_name(_t2da_target_format))

## BUILD T2DA button pressed! Coordinates conversion, validation, building.
func _on_build_texture_array_button_pressed():
	if _t2da_input_textures.is_empty():
		printerr(log_prefix + "Build cancelled: No inputs.")
		_set_status_label(input_files_status_label, "Need images first!", Color.ORANGE)
		return

	# Step 1: Convert formats if requested
	if _t2da_ensure_format:
		if not _convert_t2da_input_images_to_target_format():
			printerr(log_prefix + "Build cancelled: Format conversion failed.")
			# Status label set by conversion function
			return

	# Step 2: Validate textures (size, maybe format)
	if not _validate_t2da_input_textures():
		printerr(log_prefix + "Build cancelled: Validation failed.")
		# Status label set by validation function
		return

	# Step 3: Build! Defer for UI responsiveness.
	_set_status_label(input_files_status_label, "Building array...", Color.BLUE)
	call_deferred("_build_texture_array", _t2da_input_textures)

## Converts T2DA input images to target format in-place. Returns success/failure.
func _convert_t2da_input_images_to_target_format() -> bool:
	if not _t2da_ensure_format or _t2da_input_textures.is_empty():
		return true # Nothing to do
	var target_format_name = _get_image_format_name(_t2da_target_format)
	print(log_prefix + "Ensuring T2DA images format: %s..." % target_format_name)
	_set_status_label(input_files_status_label, "Converting format to %s..." % target_format_name, Color.BLUE)
	var all_ok = true
	for i in range(_t2da_input_textures.size()):
		var texture = _t2da_input_textures[i]
		if not is_instance_valid(texture):
			continue
		var image = texture.get_image()
		if not is_instance_valid(image) or image.is_empty():
			continue
		if image.get_format() != _t2da_target_format:
			var original_format_name = _get_image_format_name(image.get_format())
			print(log_prefix + "Converting T2DA img %d ('%s'): %s -> %s" % [i + 1, texture.resource_path.get_file(), original_format_name, target_format_name])
			image.convert(_t2da_target_format) # Modifies in-place
			if image.get_format() != _t2da_target_format: # Verify!
				printerr(log_prefix + "ERR: Failed converting T2DA img %d ('%s')!" % [i + 1, texture.resource_path.get_file()])
				_set_status_label(input_files_status_label, "[ERR] Format convert fail img %d!" % (i + 1), Color.RED)
				all_ok = false
				break # Stop on first failure
	if all_ok:
		print(log_prefix + "Format conversion step OK.")
		_set_status_label(input_files_status_label, "Format conversion OK.", Color.GREEN)
	return all_ok

## Validates T2DA input textures (size, format unless ensured). Sets status label.
func _validate_t2da_input_textures() -> bool:
	if is_instance_valid(ready_to_generate_label):
		ready_to_generate_label.text = "Ready? (Checking...)"
	if _t2da_input_textures.size() < 1:
		_set_status_label(input_files_status_label, "Need 1+ image.", Color.ORANGE)
		if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
		return false
	var first_texture = _t2da_input_textures[0]
	if not is_instance_valid(first_texture):
		_set_status_label(input_files_status_label, "[ERR] First tex invalid!", Color.RED)
		if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
		return false
	var first_image = first_texture.get_image()
	if not is_instance_valid(first_image) or first_image.is_empty():
		_set_status_label(input_files_status_label, "[ERR] First image data invalid!", Color.RED)
		if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
		return false
	var first_size: Vector2i = first_image.get_size()
	var first_format: Image.Format = first_image.get_format()
	var first_format_name: String = _get_image_format_name(first_format)
	if _t2da_input_textures.size() == 1:
		_set_status_label(input_files_status_label, "1 image (%s, %s). Needs 2+." % [str(first_size), first_format_name], Color.YELLOW)
	for i in range(1, _t2da_input_textures.size()):
		var current_texture = _t2da_input_textures[i]
		if not is_instance_valid(current_texture):
			_set_status_label(input_files_status_label, "[ERR] Image %d invalid!" % (i + 1), Color.RED)
			if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
			return false
		var img = current_texture.get_image()
		if not is_instance_valid(img) or img.is_empty():
			_set_status_label(input_files_status_label, "[ERR] Image %d data invalid!" % (i + 1), Color.RED)
			if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
			return false
		var current_size = img.get_size()
		if current_size != first_size:
			_set_status_label(input_files_status_label, "[WARN] Size mismatch! Img %d (%s) vs Img 1 (%s)" % [i + 1, str(current_size), str(first_size)], Color.ORANGE)
			transfer_array_input_files_to_resizer_button.grab_focus()
			if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
			return false
		var current_format = img.get_format()
		var current_format_name = _get_image_format_name(current_format)
		if _t2da_ensure_format: # If ensuring, verify against target
			if current_format != _t2da_target_format:
				printerr(log_prefix + "Validation ERR: Img %d format mismatch post-convert!" % (i + 1))
				_set_status_label(input_files_status_label, "[ERR] Format mismatch post-convert!", Color.RED)
				if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
				return false
		elif current_format != first_format: # Otherwise, compare against first
			_set_status_label(input_files_status_label, "[WARN] Format mismatch! Img %d (%s) vs Img 1 (%s). Use Ensure?" % [i + 1, current_format_name, first_format_name], Color.ORANGE)
			if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
			return false
	if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (Yes!)"
	_set_status_label(input_files_status_label, "%d images OK (%s, %s)" % [_t2da_input_textures.size(), str(first_size), first_format_name], Color.GREEN)
	return true

## Creates and saves the T2DA resource. The grand finale.
func _build_texture_array(textures: Array[Texture2D]):
	if textures.is_empty():
		printerr(log_prefix + "Build ERR: Empty texture list!");
		_set_status_label(input_files_status_label, "[ERROR] Build fail: No textures!", Color.RED)
		return
	print(log_prefix + "Building T2DA with %d textures..." % textures.size())
	var images_array: Array[Image] = []
	for tex in textures: # Extract raw Image data
		var img = tex.get_image()
		if is_instance_valid(img) and not img.is_empty():
			images_array.append(img)
		else:
			printerr(log_prefix + "Build ERR: Invalid img data for %s" % tex.resource_path)
			_set_status_label(input_files_status_label, "[ERROR] Build fail: Bad image data!", Color.RED)
			return
	if images_array.is_empty():
		printerr(log_prefix + "Build ERR: No valid images gathered!")
		_set_status_label(input_files_status_label, "[ERROR] Build fail: No image data!", Color.RED)
		return

	var array_texture = Texture2DArray.new()
	print(log_prefix + "T2DA resource created, calling create_from_images()...")
	var error_code = array_texture.create_from_images(images_array)
	if error_code != OK:
		printerr(log_prefix + "Create ERR: create_from_images() failed! Code: %d" % error_code)
		_set_status_label(input_files_status_label, "[ERROR] Create fail! Code: %d" % error_code, Color.RED)
		return
	else:
		print(log_prefix + "T2DA data populated!")

	# --- Determine Final Save Path (Handle Subfolder & Overwrite) ---
	var final_save_dir = default_output_path
	var final_array_name = default_output_array_name
	if _t2da_create_subfolder:
		var subfolder_name = default_output_array_name.replace(" ", "_").strip_edges()
		if subfolder_name == "":
			subfolder_name = "t2da_output" # Fallback
		final_save_dir = default_output_path.path_join(subfolder_name)
		print(log_prefix + "Using subfolder for T2DA: " + final_save_dir)
	var save_path_str = final_save_dir.path_join(final_array_name + ".tres")
	if not _t2da_allow_overwrite:
		var counter = 1
		while FileAccess.file_exists(save_path_str):
			final_array_name = default_output_array_name + "_" + str(counter)
			save_path_str = final_save_dir.path_join(final_array_name + ".tres")
			counter += 1
		if counter > 1:
			print(log_prefix + "Output exists, overwrite disabled. Using name: " + final_array_name)

	# --- Ensure Output Directory Exists ---
	var dir_access = DirAccess.open("res://")
	if not dir_access:
		printerr(log_prefix + "Save ERR: DirAccess fail!")
		_set_status_label(input_files_status_label, "Save Error: DirAccess fail!", Color.RED)
		return
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(final_save_dir)):
		print(log_prefix + "Creating output directory: " + final_save_dir)
		var mk_err = dir_access.make_dir_recursive(final_save_dir)
		if mk_err != OK:
			printerr(log_prefix + "Save ERR: Cannot create folder %s (Err: %d)" % [final_save_dir, mk_err])
			_set_status_label(input_files_status_label, "Save ERR: Create folder fail!", Color.RED)
			return

	# --- Save the Resource ---
	print(log_prefix + "Saving T2DA resource to: " + save_path_str)
	var save_err = ResourceSaver.save(array_texture, save_path_str)
	if save_err == OK:
		print(log_prefix + "T2DA Save SUCCESS: " + save_path_str)
		_set_status_label(input_files_status_label, "Array saved! Nice!", Color.GREEN)
		if is_instance_valid(editor_interface):
			print(log_prefix + "Scanning filesystem...")
			editor_interface.get_resource_filesystem().scan()
	else:
		printerr(log_prefix + "Save ERR: Failed save '%s' (Code: %d)" % [save_path_str, save_err])
		_set_status_label(input_files_status_label, "Save ERR! Code: %d" % save_err, Color.RED)

## Updates T2DA status label. Runs validation.
func _update_t2da_input_files_status():
	if not is_instance_valid(input_files_status_label):
		return
	if _t2da_input_textures.is_empty():
		_set_status_label(input_files_status_label, "No T2DA images loaded.", Color.AQUA)
		if is_instance_valid(ready_to_generate_label):
			ready_to_generate_label.text = "Ready? (No)"
	else:
		_validate_t2da_input_textures() # Validation sets the label

#endregion

#region Image Resizing Callbacks & Logic

## Resizer Browse Input button pressed.
func _on_image_resize_browse_input_files_button_pressed():
	_configure_file_dialog(EditorFileDialog.FILE_MODE_OPEN_FILES, "Select Images to Resize", "res://", "",
		PackedStringArray(["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.tga", "*.exr", "*.hdr; Image Files"]),
		_on_image_resize_input_files_selected)

## Resizer Input files selected. Update state & UI.
func _on_image_resize_input_files_selected(paths: PackedStringArray):
	_resize_input_image_paths = paths.duplicate()
	print(log_prefix + "Resizer received %d file path(s)." % paths.size())
	_update_resize_input_files_status()
	_update_largest_image_size_label(paths)
	if is_instance_valid(resize_images_button):
		resize_images_button.disabled = paths.is_empty()

## Resizer Browse Output Folder button pressed.
func _on_image_resize_browse_output_folder_button_pressed():
	_configure_file_dialog(EditorFileDialog.FILE_MODE_OPEN_DIR, "Select Image Resizer Output Folder",
		default_image_resize_output_path, "", PackedStringArray([]), _on_image_resize_output_folder_selected)

## Resizer Output folder selected. Update UI.
func _on_image_resize_output_folder_selected(path: String):
	default_image_resize_output_path = path
	if is_instance_valid(image_resize_output_path_line_edit):
		image_resize_output_path_line_edit.text = path

## Updates Resizer status labels and sets default mipmap state based on .import.
func _update_resize_input_files_status():
	var count = _resize_input_image_paths.size()
	if is_instance_valid(resize_input_files_count_label):
		resize_input_files_count_label.text = "Selected Images! (%d)" % count
	if is_instance_valid(ready_to_resize_label):
		ready_to_resize_label.text = "Ready? (%s)" % ("Yes" if count > 0 else "No")
	if is_instance_valid(resize_image_status_label):
		if count == 0:
			_set_status_label(resize_image_status_label, "Select images to resize.", Color.AQUA)
		else:
			_set_status_label(resize_image_status_label, "%d image(s) ready for resizing!" % count, Color.MAGENTA)
	# Update Mipmap Checkbox Default
	if count > 0:
		_set_default_mipmap_state_from_import(_resize_input_image_paths[0])
	else:
		_set_mipmap_checkbox_state(false) # Reset if no files

## Calculates max WxH from paths. Uses load_from_file now.
func _update_largest_image_size_label(paths: PackedStringArray):
	if not is_instance_valid(largest_image_size_label):
		return
	var max_w = 0
	var max_h = 0
	var ok_count = 0
	var fail_count = 0
	for p in paths:
		var image: Image = Image.load_from_file(p)
		if image != null and not image.is_empty():
			var img_size: Vector2i = image.get_size()
			max_w = max(max_w, img_size.x)
			max_h = max(max_h, img_size.y)
			ok_count += 1
		else:
			printerr(log_prefix + "WARN: Failed load/get size for: %s" % p.get_file())
			fail_count += 1
	largest_image_size_label.text = "%dx%d" % [max_w, max_h]
	if fail_count > 0 and is_instance_valid(resize_image_status_label):
		_set_status_label(resize_image_status_label, "[WARN] Couldn't read size for %d img(s)." % fail_count, Color.YELLOW)
	elif ok_count > 0 and (max_w == 0 or max_h == 0) and is_instance_valid(resize_image_status_label):
		_set_status_label(resize_image_status_label, "[WARN] Couldn't determine largest size?", Color.YELLOW)

## Reads .import file of first image to set default mipmap state.
func _set_default_mipmap_state_from_import(first_image_path: String):
	var import_mip_value = _read_import_setting(first_image_path, "params/mipmaps", null)
	if import_mip_value != null and import_mip_value is bool:
		_default_mipmap_state = import_mip_value
		print(log_prefix + "Detected mipmap state from '%s': %s" % [first_image_path.get_file(), str(_default_mipmap_state)])
	else:
		_default_mipmap_state = false
		print(log_prefix + "Could not detect mipmap state for '%s'. Default: false." % first_image_path.get_file())
	_set_mipmap_checkbox_state(_default_mipmap_state) # Set UI based on detection

## Helper sets mipmap checkbox state AND internal variable.
func _set_mipmap_checkbox_state(state: bool):
	if is_instance_valid(use_mipmaps_check_button):
		if use_mipmaps_check_button.button_pressed != state:
			use_mipmaps_check_button.button_pressed = state
	_resizer_use_mipmaps = state # Update internal state

## "Use Largest Size" checkbox toggled.
func _on_use_largest_size_check_button_toggled(pressed: bool):
	_use_largest_image_dimensions = pressed
	_update_use_largest_size_ui()

## Updates custom size input editability/placeholders.
func _update_use_largest_size_ui():
	if not (is_instance_valid(custom_image_width_line_edit) and is_instance_valid(custom_image_height_line_edit)):
		return
	var allow_custom_edit = not _use_largest_image_dimensions
	custom_image_width_line_edit.editable = allow_custom_edit
	custom_image_height_line_edit.editable = allow_custom_edit
	custom_image_width_line_edit.placeholder_text = "Width" if allow_custom_edit else "(Uses Largest Width)"
	custom_image_height_line_edit.placeholder_text = "Height" if allow_custom_edit else "(Uses Largest Height)"
	if not allow_custom_edit:
		custom_image_width_line_edit.clear()
		custom_image_height_line_edit.clear()

## Custom size text changed. Placeholder.
func _on_custom_image_size_changed(new_text: String):
	pass

## Aspect Ratio Mode selected. Enables/disables padding color picker.
func _on_resize_mode_selected(index: int):
	if not is_instance_valid(resize_mode_option_button):
		return
	var selected_id = resize_mode_option_button.get_selected_id()
	print(log_prefix + "Resize aspect mode selected: ID " + str(selected_id))
	if is_instance_valid(padding_color_picker):
		var should_be_enabled = (selected_id == ASPECT_MODE_PAD)
		padding_color_picker.disabled = not should_be_enabled
		if should_be_enabled:
			print(log_prefix + "Padding color picker enabled.")
		else:
			print(log_prefix + "Padding color picker disabled.")
	else:
		printerr(log_prefix + "[WARN] Padding Color Picker node missing!")

## Resizer Output Prefix changed. Update var.
func _on_output_prefix_changed(new_text: String):
	_resizer_output_prefix = new_text.strip_edges()

## Resizer Output Suffix changed. Update var.
func _on_output_suffix_changed(new_text: String):
	_resizer_output_suffix = new_text.strip_edges()

## Resizer Output Format selected. Update var & quality slider visibility.
func _on_output_format_selected(index: int):
	if is_instance_valid(output_format_option_button):
		_resizer_output_format_ext = output_format_option_button.get_item_metadata(index)
		print(log_prefix + "Resizer output format set to: %s" % _resizer_output_format_ext)
		_update_quality_slider_visibility() # Show/hide slider based on format

## Shows/hides the quality slider based on selected format.
func _update_quality_slider_visibility():
	var show_quality = false
	var current_format = _resizer_output_format_ext
	if current_format == "detect": # Check first input file's format if detecting
		if not _resize_input_image_paths.is_empty():
			var first_ext = _resize_input_image_paths[0].get_extension().to_lower()
			if first_ext == "jpg" or first_ext == "jpeg" or first_ext == "webp":
				show_quality = true
		# else: Keep false if no files or non-lossy first file
	elif current_format == "jpg" or current_format == "webp": # Explicitly selected lossy
		show_quality = true

	if is_instance_valid(format_image_output_quality_h_slider):
		format_image_output_quality_h_slider.visible = show_quality
		format_image_output_quality_h_slider.editable = show_quality
	if is_instance_valid(output_quality_value_label):
		output_quality_value_label.visible = show_quality
	if is_instance_valid(output_quality_label):
		output_quality_label.visible = show_quality

	if show_quality: print(log_prefix + "Output quality slider visible.")
	else: print(log_prefix + "Output quality slider hidden.")

## Output Quality Slider value changed. Update label and var.
func _on_output_quality_slider_changed(value: float):
	_resizer_output_quality = roundi(value) # Store as int 0-100
	if is_instance_valid(output_quality_value_label):
		output_quality_value_label.text = "%d%%" % _resizer_output_quality # Display with %

## Resizer Padding Color changed. Update var.
func _on_padding_color_changed(new_color: Color):
	_resizer_pad_color = new_color
	print(log_prefix + "Resizer padding color set to: %s" % str(new_color))

## Resizer "Use Mipmaps" checkbox toggled by user. Update var.
func _on_use_mipmaps_toggled(button_pressed: bool):
	_resizer_use_mipmaps = button_pressed
	print(log_prefix + "Mipmap usage manually set to: %s" % str(_resizer_use_mipmaps))

## Resizer "Batch Rename" checkbox toggled. Enable/disable LineEdit.
func _on_batch_rename_toggled(button_pressed: bool):
	_resizer_batch_rename_enabled = button_pressed
	if is_instance_valid(batch_rename_output_images_line_edit):
		batch_rename_output_images_line_edit.editable = button_pressed
	if button_pressed: print(log_prefix + "Batch rename enabled.")
	else: print(log_prefix + "Batch rename disabled.")

## Resizer Batch Rename pattern text changed. Update var.
func _on_batch_rename_pattern_changed(new_text: String):
	# Allow spaces here if user wants them, whitespace removal is separate option
	_resizer_batch_rename_pattern = new_text


## RESIZE button pressed! Gather ALL settings, defer the heavy work.
func _on_resize_images_button_pressed():
	if _resize_input_image_paths.is_empty():
		_set_status_label(resize_image_status_label, "Select images first!", Color.ORANGE)
		return

	var target_width: int = 0
	var target_height: int = 0
	# Determine Target Size...
	if _use_largest_image_dimensions:
		var size_text = largest_image_size_label.text; var size_parts = size_text.split("x")
		if size_parts.size() == 2 and size_parts[0].is_valid_int() and size_parts[1].is_valid_int():
			target_width = int(size_parts[0]); target_height = int(size_parts[1])
		else:
			_set_status_label(resize_image_status_label, "[ERR] Cannot parse size label!", Color.RED)
			printerr(log_prefix + "Parse ERR largest size: '%s'" % size_text); return
	else:
		var width_text = custom_image_width_line_edit.text; var height_text = custom_image_height_line_edit.text
		if width_text.is_valid_int() and height_text.is_valid_int():
			target_width = int(width_text); target_height = int(height_text)
		else:
			_set_status_label(resize_image_status_label, "[ERR] Custom W/H must be numbers.", Color.RED); return
	if target_width <= 0 or target_height <= 0:
		_set_status_label(resize_image_status_label, "[ERR] Target size must be > 0!", Color.RED); return

	# Get other settings...
	var aspect_mode_id: int = resize_mode_option_button.get_selected_id()
	var interpolation_filter: Image.Interpolation = resize_filter_option_button.get_selected_id() as Image.Interpolation
	var output_dir_base = default_image_resize_output_path
	var final_output_dir = output_dir_base

	# Handle Resizer Subfolder...
	if _resizer_create_subfolder:
		var timestamp = Time.get_unix_time_from_system()
		var subfolder_name = "resized_" + str(timestamp)
		final_output_dir = output_dir_base.path_join(subfolder_name)
		print(log_prefix + "Resizer using timestamped subfolder: " + final_output_dir)

	# Ensure Output Directory Exists...
	var dir_access = DirAccess.open("res://")
	if not dir_access:
		printerr(log_prefix + "Resize ERR: DirAccess fail!")
		_set_status_label(resize_image_status_label, "[ERR] DirAccess Fail!", Color.RED); return
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(final_output_dir)):
		print(log_prefix + "Creating output directory: " + final_output_dir)
		var mkdir_err = dir_access.make_dir_recursive(final_output_dir)
		if mkdir_err != OK:
			printerr(log_prefix + "Resize ERR: Cannot create folder %s (Err: %d)" % [final_output_dir, mkdir_err])
			_set_status_label(resize_image_status_label, "[ERR] Create folder fail!", Color.RED); return

	# Defer Processing...
	_set_status_label(resize_image_status_label, "Resizing %d images..." % _resize_input_image_paths.size(), Color.BLUE)
	call_deferred("_process_resize_batch", target_width, target_height, aspect_mode_id, interpolation_filter,
					_resizer_output_prefix, _resizer_output_suffix, _resizer_output_format_ext,
					_resizer_output_quality, # Pass quality
					_resizer_pad_color,
					_resizer_use_mipmaps,
					_resizer_remove_whitespace, # Pass whitespace flag
					_resizer_batch_rename_enabled, # Pass batch rename flag
					_resizer_batch_rename_pattern, # Pass batch rename pattern
					final_output_dir) # Pass potentially modified output dir


## The Resizer workhorse function. Now handles even MORE options!
func _process_resize_batch(target_width: int, target_height: int,
						   aspect_mode_id: int, interpolation_filter: Image.Interpolation,
						   output_prefix: String, output_suffix: String, output_format_ext: String, output_quality: int,
						   pad_color: Color, generate_mipmaps: bool,
						   remove_whitespace: bool, batch_rename: bool, batch_rename_pattern: String,
						   output_dir: String): # Now takes quality, whitespace, batch rename args
	var success_count = 0
	var fail_count = 0
	var resized_output_paths: PackedStringArray = []
	var batch_rename_counter = 1 # Start counter at 1 for batch renaming

	print(log_prefix + "Resize Batch START: Target=%dx%d, Aspect=%d, Filter=%d, Prefix='%s', Suffix='%s', Format='%s', Quality=%d, Mips=%s, Pad=%s, Whitespace=%s, Batch=%s(%s), OutDir=%s" %
		[target_width, target_height, aspect_mode_id, interpolation_filter, output_prefix, output_suffix, output_format_ext, output_quality, str(generate_mipmaps), str(pad_color), str(remove_whitespace), str(batch_rename), batch_rename_pattern, output_dir])

	# --- Process Each Image ---
	for input_path in _resize_input_image_paths:
		var image: Image = Image.load_from_file(input_path)
		if image == null or image.is_empty():
			printerr(log_prefix + "Resize ERR: Load fail %s" % input_path.get_file())
			fail_count += 1
			continue # Skip this dud

		var original_width: float = image.get_width()
		var original_height: float = image.get_height()
		var processed_image: Image = image # Assume modification unless padding/cropping

		# --- Apply Resizing (Stretch/Pad/Crop) ---
		match aspect_mode_id:
			ASPECT_MODE_STRETCH:
				processed_image.resize(target_width, target_height, interpolation_filter)
			ASPECT_MODE_PAD:
				var target_ratio = float(target_width) / target_height
				var original_ratio = original_width / original_height
				var scale = 1.0
				if original_ratio > target_ratio:
					scale = float(target_width) / original_width
				else:
					scale = float(target_height) / original_height
				var sw = roundi(original_width * scale)
				var sh = roundi(original_height * scale)
				var padded = Image.create(target_width, target_height, false, image.get_format())
				padded.fill(pad_color) # Use specified padding color
				var temp = image.duplicate()
				temp.resize(sw, sh, interpolation_filter)
				var px = (target_width - sw) / 2
				var py = (target_height - sh) / 2
				padded.blit_rect(temp, Rect2i(0, 0, sw, sh), Vector2i(px, py))
				processed_image = padded
			ASPECT_MODE_CROP:
				var target_ratio = float(target_width) / target_height
				var original_ratio = original_width / original_height
				var scale = 1.0
				if original_ratio < target_ratio:
					scale = float(target_width) / original_width
				else:
					scale = float(target_height) / original_height
				var sw = roundi(original_width * scale)
				var sh = roundi(original_height * scale)
				var temp = image.duplicate()
				temp.resize(sw, sh, interpolation_filter)
				var cx = (sw - target_width) / 2
				var cy = (sh - target_height) / 2
				processed_image = temp.get_region(Rect2i(cx, cy, target_width, target_height))

		# --- Generate Mipmaps (Optional) ---
		if generate_mipmaps:
			print(log_prefix + "Generating mipmaps for %s..." % input_path.get_file())
			var mip_err = processed_image.generate_mipmaps()
			if mip_err != OK:
				printerr(log_prefix + "Mipmap ERR for %s (Code: %d)" % [input_path.get_file(), mip_err])

		# --- Construct Filename ---
		var base_name = ""
		var current_extension = input_path.get_extension()
		# Determine final extension (handle "detect" case)
		var final_extension = output_format_ext
		if final_extension == "detect":
			final_extension = current_extension if current_extension != "" else "png"

		# Determine base name (batch rename or original)
		if batch_rename:
			# Use pattern + suffix + counter
			# Ensure pattern is not empty, use default if it is
			var pattern = batch_rename_pattern if batch_rename_pattern.strip_edges() != "" else "image"
			# Add user suffix first (if any), then counter
			var counter_str = "_%03d" % batch_rename_counter # Pad counter e.g., _001
			base_name = pattern + output_suffix + counter_str # CORRECT ORDER: Pattern_UserSuffix_Counter
			batch_rename_counter += 1
		else:
			# Use original base name + user suffix
			base_name = input_path.get_file().get_basename()
			# Optionally remove whitespace
			if remove_whitespace:
				# Use Regex for more robust whitespace removal (includes tabs, etc.)
				var regex = RegEx.new()
				regex.compile("\\s+") # Compile regex to find one or more whitespace characters
				base_name = regex.sub(base_name, "", true) # Replace all occurrences with empty string
				# base_name = base_name.replace(" ", "") # Old simple space removal
			base_name = base_name + output_suffix # Add user suffix AFTER potential whitespace removal

		# Combine parts: Prefix + BaseName (which now includes suffix/counter) + Extension
		var new_filename = output_prefix + base_name + "." + final_extension
		var output_path = output_dir.path_join(new_filename)

		# --- Save Image ---
		var save_err = ERR_UNAVAILABLE
		var quality_float_jpg = float(output_quality) / 100.0 # For JPG save (expects 0.0-1.0)
		var quality_float_webp = float(output_quality) # For WebP save (expects 0-100 float)

		match final_extension.to_lower():
			"png":
				save_err = processed_image.save_png(output_path)
			"jpg", "jpeg":
				save_err = processed_image.save_jpg(output_path, quality_float_jpg)
			"webp":
				# Add UI toggle for lossless later? For now, assume lossy based on quality slider being visible.
				var webp_lossless = (output_quality >= 100) # Simple heuristic: 100% = try lossless
				save_err = processed_image.save_webp(output_path, webp_lossless, quality_float_webp)
			"bmp":
				save_err = processed_image.save_bmp(output_path)
			"tga":
				save_err = processed_image.save_tga(output_path)
			_:
				printerr(log_prefix + "Save ERR: Unsupported format '%s'" % final_extension)
				save_err = ERR_INVALID_PARAMETER

		if save_err == OK:
			success_count += 1
			resized_output_paths.append(output_path)
		else:
			printerr(log_prefix + "Save ERR: Failed saving '%s' (Code: %d)" % [new_filename, save_err])
			fail_count += 1

	# --- Final Update & Transfer ---
	var final_status_text = "Resize complete: %d succeeded, %d failed." % [success_count, fail_count]
	var final_color = Color.RED if success_count == 0 and fail_count > 0 else Color.YELLOW if fail_count > 0 else Color.GREEN
	_set_status_label(resize_image_status_label, final_status_text, final_color)
	print(log_prefix + final_status_text)
	transfer_resizer_output_images_to_array_gen_button.grab_focus(); # Focus button after processing
	if is_instance_valid(editor_interface):
		editor_interface.get_resource_filesystem().scan()
	if _transfer_images_to_array_generator_after_resize and success_count > 0:
		print(log_prefix + "Auto-transferring %d images to T2DA..." % success_count)
		call_deferred("_transfer_paths_to_t2da_generator", resized_output_paths)

#endregion

#region Transfer Actions & Logic
# (No changes needed here - expanded for consistency)

## Transfer Resizer Input -> T2DA button pressed.
func _on_transfer_resizer_input_files_to_array_gen_pressed():
	if _resize_input_image_paths.is_empty():
		printerr(log_prefix + "Transfer failed: No Resizer inputs.")
		_set_status_label(input_files_status_label, "[ERR] No resizer inputs!", Color.RED)
		return
	print(log_prefix + "Transferring %d Resizer inputs -> T2DA..." % _resize_input_image_paths.size())
	_transfer_paths_to_t2da_generator(_resize_input_image_paths)
	_set_status_label(resize_image_status_label, "Inputs transferred to T2DA!", Color.GREEN)

## Transfer Resizer Output -> T2DA button pressed. Scans output dir.
func _on_transfer_resizer_output_images_to_array_gen_pressed():
	var output_dir_path = default_image_resize_output_path
	var paths_to_transfer: PackedStringArray = []
	var dir = DirAccess.open(output_dir_path)
	if not dir:
		printerr(log_prefix + "ERR opening Resizer out dir: " + output_dir_path)
		_set_status_label(input_files_status_label, "[ERR] Cannot open resizer out folder!", Color.RED)
		_set_status_label(resize_image_status_label, "[ERR] Output folder not found!", Color.RED)
		return
	print(log_prefix + "Scanning '%s' for transfer..." % output_dir_path)
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var file_extension = file_name.get_extension().to_lower()
			const IMAGE_EXTENSIONS = ["png", "jpg", "jpeg", "webp", "bmp", "tga", "exr", "hdr"]
			if file_extension in IMAGE_EXTENSIONS:
				var full_path = output_dir_path.path_join(file_name)
				if FileAccess.file_exists(full_path):
					paths_to_transfer.append(full_path)
				else:
					printerr(log_prefix + "Listed file '%s' missing?" % full_path)
		file_name = dir.get_next()
	if paths_to_transfer.is_empty():
		printerr(log_prefix + "No images found in " + output_dir_path)
		_set_status_label(input_files_status_label, "[WARN] No images found in resizer out folder.", Color.YELLOW)
		_set_status_label(resize_image_status_label, "[WARN] No output images found.", Color.YELLOW)
		return
	print(log_prefix + "Found %d images. Transferring Resizer outputs -> T2DA..." % paths_to_transfer.size())
	_transfer_paths_to_t2da_generator(paths_to_transfer)
	_set_status_label(resize_image_status_label, "Outputs transferred to T2DA!", Color.GREEN)

## Transfer T2DA -> Resizer button pressed. Gets paths from loaded textures.
func _on_transfer_array_input_files_to_resizer_pressed():
	transfer_array_input_files_to_resizer_button.release_focus() # Defocus button
	if _t2da_input_textures.is_empty():
		printerr(log_prefix + "Transfer failed: No T2DA textures.")
		_set_status_label(resize_image_status_label, "[WARN] No T2DA images to transfer.", Color.YELLOW)
		return
	var paths: PackedStringArray = []
	var missing = 0
	var invalid = 0
	print(log_prefix + "Preparing T2DA -> Resizer transfer...")
	for texture in _t2da_input_textures:
		if is_instance_valid(texture):
			var path = texture.resource_path
			if path != null and path != "" and FileAccess.file_exists(path):
				paths.append(path)
			else:
				printerr(log_prefix + "WARN: T2DA tex missing path: '%s'" % path)
				missing += 1
		else:
			printerr(log_prefix + "WARN: Invalid T2DA tex instance!")
			invalid += 1
	_resize_input_image_paths = paths
	var issues = missing + invalid
	print(log_prefix + "Transferred %d T2DA paths -> Resizer (%d issues)." % [paths.size(), issues])
	_update_resize_input_files_status() # Update resizer UI
	_update_largest_image_size_label(_resize_input_image_paths)
	if is_instance_valid(resize_images_button):
		resize_images_button.disabled = _resize_input_image_paths.is_empty()
	if issues > 0:
		_set_status_label(resize_image_status_label, "Transferred %d from T2DA (%d issues)." % [paths.size(), issues], Color.ORANGE)
	elif paths.is_empty():
		_set_status_label(resize_image_status_label, "Transfer from T2DA done, no valid paths.", Color.ORANGE)
	else:
		_set_status_label(resize_image_status_label, "Transferred %d paths from T2DA!" % paths.size(), Color.GREEN)

## Loads images from given paths into the T2DA input list. Used by transfers.
func _transfer_paths_to_t2da_generator(paths: PackedStringArray):
	transfer_resizer_output_images_to_array_gen_button.release_focus() # Defocus button
	_t2da_input_textures.clear()
	var loaded = 0
	var failed = 0
	print(log_prefix + "Loading %d transferred paths -> T2DA..." % paths.size())
	for path in paths:
		var image: Image = Image.load_from_file(path)
		if image != null and not image.is_empty():
			var texture: ImageTexture = ImageTexture.create_from_image(image)
			if is_instance_valid(texture):
				texture.resource_path = path # Store path!
				_t2da_input_textures.append(texture)
				loaded += 1
			else:
				printerr(log_prefix + "Failed create ImageTexture during transfer for: " + path.get_file())
				failed += 1
		else:
			printerr(log_prefix + "Failed load image during transfer: %s" % path.get_file())
			failed += 1
	if is_instance_valid(input_files_count_label):
		input_files_count_label.text = "Images (%d)" % loaded
	_update_t2da_input_files_status() # Validate loaded images
	if failed > 0:
		push_warning(log_prefix + "Transfer load done, %d failed." % failed)
	elif loaded > 0:
		print(log_prefix + "Loaded %d transferred images into T2DA." % loaded)
	else:
		print(log_prefix + "Transfer load done, no images loaded.")

#endregion

#region Utility Functions

## Sets text & color for status labels. Resets color override properly.
func _set_status_label(label: Label, text: String, color: Color = RESET_COLOR):
	if not is_instance_valid(label):
		printerr(log_prefix + "ERR: Invalid status label!")
		return
	label.text = text
	var ovr = "font_color"
	if color == RESET_COLOR:
		if label.has_theme_color_override(ovr):
			label.remove_theme_color_override(ovr)
	else:
		label.add_theme_color_override(ovr, color)

## Configures and shows the EditorFileDialog. One dialog to rule them all.
func _configure_file_dialog(mode: EditorFileDialog.FileMode, title: String, current_dir: String, current_file: String, filters: PackedStringArray, callback_func: Callable):
	if not is_instance_valid(file_selection_dialog):
		printerr(log_prefix + "ERR: FileDialog invalid!")
		if is_instance_valid(editor_interface):
			editor_interface.get_base_control().show_warning("Plugin ERR: File Dialog missing!", "ERR")
		return
	var sig = ""
	match mode:
		EditorFileDialog.FILE_MODE_OPEN_FILE: sig = "file_selected"
		EditorFileDialog.FILE_MODE_OPEN_FILES: sig = "files_selected"
		EditorFileDialog.FILE_MODE_OPEN_DIR: sig = "dir_selected"
		EditorFileDialog.FILE_MODE_SAVE_FILE: sig = "file_selected"
		_:
			printerr(log_prefix + "ERR: Bad file dialog mode: %d" % mode)
			return
	# Disconnect previous signals to self for this specific signal type
	for c in file_selection_dialog.get_signal_connection_list(sig):
		var cb: Callable = c.get("callable")
		if cb != null and cb.is_valid() and cb.get_object() == self:
			file_selection_dialog.disconnect(sig, cb)
	# Configure
	file_selection_dialog.file_mode = mode
	file_selection_dialog.title = title
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(current_dir)):
		file_selection_dialog.current_dir = current_dir
	else:
		file_selection_dialog.current_dir = "res://"
	file_selection_dialog.current_file = current_file
	file_selection_dialog.clear_filters()
	for f in filters:
		file_selection_dialog.add_filter(f)
	file_selection_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	# Connect (one shot)
	var err = file_selection_dialog.connect(sig, callback_func, CONNECT_ONE_SHOT)
	if err != OK:
		printerr(log_prefix + "ERR connect file dialog sig '%s'! Code: %d" % [sig, err])
		return
	# Show
	file_selection_dialog.popup_centered_ratio(0.75)

## Converts Image.Format enum number to human-readable string. Enum -> String translator.
func _get_image_format_name(format_enum: int) -> String:
	match format_enum:
		Image.FORMAT_L8: return "L8"
		Image.FORMAT_LA8: return "LA8"
		Image.FORMAT_R8: return "R8"
		Image.FORMAT_RG8: return "RG8"
		Image.FORMAT_RGB8: return "RGB8"
		Image.FORMAT_RGBA8: return "RGBA8"
		Image.FORMAT_RGBA4444: return "RGBA4444"
		Image.FORMAT_RGB565: return "RGB565"
		Image.FORMAT_RF: return "RF"
		Image.FORMAT_RGF: return "RGF"
		Image.FORMAT_RGBF: return "RGBF"
		Image.FORMAT_RGBAF: return "RGBAF"
		Image.FORMAT_RH: return "RH"
		Image.FORMAT_RGH: return "RGH"
		Image.FORMAT_RGBH: return "RGBH"
		Image.FORMAT_RGBAH: return "RGBAH"
		Image.FORMAT_RGBE9995: return "RGBE9995"
		Image.FORMAT_DXT1: return "DXT1(BC1)"
		Image.FORMAT_DXT3: return "DXT3(BC2)"
		Image.FORMAT_DXT5: return "DXT5(BC3)"
		Image.FORMAT_RGTC_R: return "RGTC_R(BC4)"
		Image.FORMAT_RGTC_RG: return "RGTC_RG(BC5)"
		Image.FORMAT_BPTC_RGBA: return "BPTC_RGBA(BC7)"
		Image.FORMAT_BPTC_RGBF: return "BPTC_RGBF(BC6H SF)"
		Image.FORMAT_BPTC_RGBFU: return "BPTC_RGBFU(BC6H UF)"
		Image.FORMAT_ETC: return "ETC(Obsolete?)"
		Image.FORMAT_ETC2_R11: return "ETC2_R11(EAC R)"
		Image.FORMAT_ETC2_R11S: return "ETC2_R11S(EAC R Signed)"
		Image.FORMAT_ETC2_RG11: return "ETC2_RG11(EAC RG)"
		Image.FORMAT_ETC2_RG11S: return "ETC2_RG11S(EAC RG Signed)"
		Image.FORMAT_ETC2_RGB8: return "ETC2_RGB8"
		Image.FORMAT_ETC2_RGBA8: return "ETC2_RGBA8"
		Image.FORMAT_ETC2_RGB8A1: return "ETC2_RGB8A1"
		Image.FORMAT_ASTC_4x4: return "ASTC_4x4"
		Image.FORMAT_ASTC_4x4_HDR: return "ASTC_4x4_HDR"
		Image.FORMAT_ASTC_8x8: return "ASTC_8x8"
		Image.FORMAT_ASTC_8x8_HDR: return "ASTC_8x8_HDR"
		_: return "Unknown Format (%d)" % format_enum

## Reads a setting from a .import file using ConfigFile. Peeks at import settings.
func _read_import_setting(image_path: String, setting_key: String, default_value = null):
	var import_path = image_path + ".import"
	if not FileAccess.file_exists(import_path):
		return default_value # Not found, return default
	var config_file = ConfigFile.new()
	var err = config_file.load(import_path)
	if err != OK:
		printerr(log_prefix + "ERR loading import '%s': %s." % [import_path.get_file(), error_string(err)])
		return default_value # Load error, return default
	var value = config_file.get_value("params", setting_key, default_value)
	return value # Return found value or default

## Applies standard editor icons to buttons. Makes it look less custom (in a good way).
func _apply_button_icons():
	if not is_instance_valid(editor_interface):
		print(log_prefix + "Icon ERR: No EditorInterface.")
		return
	var base = editor_interface.get_base_control()
	if not is_instance_valid(base):
		print(log_prefix + "Icon ERR: Base control invalid.")
		return
	print(log_prefix + "Applying button icons...")
	var map = {
		browse_input_files_button: "Load", browse_output_folder_button: "Folder",
		output_array_name_button: "Save", image_resize_browse_input_files_button: "Load",
		image_resize_browse_output_folder_button: "Folder",
		transfer_resizer_input_files_to_array_gen_button: "ArrowUp",
		transfer_resizer_output_images_to_array_gen_button: "ArrowUp",
		transfer_array_input_files_to_resizer_button: "ArrowDown",
		build_t2da_button: "Array", resize_images_button: "ImageTexture"
	}
	for btn in map:
		var name = map[btn]
		if not is_instance_valid(btn):
			print(log_prefix + "WARN: Invalid node for icon '%s'." % name)
			continue
		var tex: Texture2D = base.get_theme_icon(name, "EditorIcons")
		if tex != null:
			btn.icon = tex
		else:
			printerr(log_prefix + "ERR: Icon '%s' not found." % name)
	print(log_prefix + "Finished applying icons.")

## Applies specific title styles using editor theme fonts/sizes. Makes titles POP!
func _apply_title_label_styles():
	if not is_instance_valid(editor_interface):
		print(log_prefix + "Style ERR: No EditorInterface.")
		return
	var base = editor_interface.get_base_control()
	if not is_instance_valid(base):
		print(log_prefix + "Style ERR: Base control invalid.")
		return
	print(log_prefix + "Applying title styles...")
	var bold = base.get_theme_font("bold", "EditorFonts")
	var doc_sz = base.get_theme_font_size("doc_title_size", "EditorFonts")
	var title_sz = base.get_theme_font_size("title_size", "EditorFonts")
	# Apply styles carefully, checking instances
	if is_instance_valid(t2da_tools_doc_title_label):
		if bold: t2da_tools_doc_title_label.add_theme_font_override("font", bold)
		if doc_sz > 0: t2da_tools_doc_title_label.add_theme_font_size_override("font_size", doc_sz)
	if is_instance_valid(t2da_title_label):
		if bold: t2da_title_label.add_theme_font_override("font", bold)
		if title_sz > 0: t2da_title_label.add_theme_font_size_override("font_size", title_sz)
	if is_instance_valid(resizer_title_label):
		if bold: resizer_title_label.add_theme_font_override("font", bold)
		if doc_sz > 0: resizer_title_label.add_theme_font_size_override("font_size", doc_sz)
	if is_instance_valid(transfer_to_resizer_section_title_label):
		if bold: transfer_to_resizer_section_title_label.add_theme_font_override("font", bold)
		if title_sz > 0: transfer_to_resizer_section_title_label.add_theme_font_size_override("font_size", title_sz)
	if is_instance_valid(transfer_to_generator_section_title_label):
		if bold: transfer_to_generator_section_title_label.add_theme_font_override("font", bold)
		if title_sz > 0: transfer_to_generator_section_title_label.add_theme_font_size_override("font_size", title_sz)
	print(log_prefix + "Finished applying title styles.")

#endregion