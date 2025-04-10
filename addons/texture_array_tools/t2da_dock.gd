@tool
# t2da_dock.gd
## A dock plugin providing Texture 2D Array generation and Image Resizing utilities.
## Allows resizing images and generating Texture2DArrays without leaving the Godot editor.
extends Panel

#region Constants and Enums

## Identifiers for the different aspect ratio handling modes during resizing.
enum ResizeAspectMode {
	STRETCH, # Stretch the image to fit the target dimensions, ignoring aspect ratio.
	PAD, # Keep aspect ratio, add padding to fill the target dimensions.
	CROP # Keep aspect ratio, crop excess image data to fit the target dimensions.
}

## Default color used for padding when ResizeAspectMode.PAD is selected. (Transparent Black)
const DEFAULT_PAD_COLOR = Color(0.0, 0.0, 0.0, 0.0)
## Default quality setting (0-100) for lossy image formats like JPG and WebP.
const DEFAULT_LOSSY_QUALITY = 87
## Reset color constant used for status labels. (Transparent Black)
const RESET_COLOR = Color(0, 0, 0, 0)

#endregion

#region Exports & Configuration

## Prefix for log messages printed to the console by this plugin.
@export_category("Texture 2D Array Generator")
@export_subgroup("Config")
@export var log_prefix: String = "[T2DAGenerator]: "
## Default base name for the generated Texture2DArray resource file.
@export var default_output_array_name: String = "MyTextureArray"
## Default directory path where the generated Texture2DArray resource will be saved.
@export var default_output_path: String = "res://_generated_t2darrays"
## Default directory path where resized images will be saved.
@export var default_image_resize_output_path: String = "res://_resized_images"

## Optional PluginSystemThemeUIApplier resource to apply custom theming to this dock.
@export var theme_applier: PluginSystemThemeUIApplier

#endregion

#region Internal Variables

## Reference to the Godot Editor Interface.
var editor_interface: EditorInterface
## Reference to the shared EditorFileDialog used for browsing files and directories.
var file_selection_dialog: EditorFileDialog

# --- State Variables ---
## Resizer: If true, automatically use the largest dimensions found among input images. If false, use manually entered dimensions.
var _use_largest_image_dimensions: bool = true
## Resizer: Array of file paths for the images selected for resizing.
var _resize_input_image_paths: PackedStringArray = []
## Resizer: Array of file paths for the images *after* they have been successfully resized.
var _resize_output_image_paths: PackedStringArray = []
## T2DA Gen: Array of Texture2D resources loaded as input for the Texture2DArray.
var _t2da_input_textures: Array[Texture2D] = []

# --- T2DA Generator Specific ---
## T2DA Gen: If true, enforce conversion of all input images to the `_t2da_target_format`.
var _t2da_ensure_format: bool = false
## T2DA Gen: The target Image.Format to use when `_t2da_ensure_format` is true.
var _t2da_target_format: Image.Format = Image.FORMAT_RGBA8
## T2DA Gen: If true, create a subfolder named after the output array within the `default_output_path`.
var _t2da_create_subfolder: bool = false
## T2DA Gen: If true, allow overwriting an existing Texture2DArray file with the same name.
var _t2da_allow_overwrite: bool = false

# --- Resizer Specific ---
## Resizer: Optional text prepended to the output filename.
var _resizer_output_prefix: String = ""
## Resizer: Optional text appended to the output filename (before extension/counter).
var _resizer_output_suffix: String = ""
## Resizer: The desired output file format extension ("png", "jpg", "webp", "detect"). "detect" uses the input format.
var _resizer_output_format_ext: String = "detect"
## Resizer: The color used for padding when using ResizeAspectMode.PAD.
var _resizer_pad_color: Color = DEFAULT_PAD_COLOR
## Resizer: If true, generate mipmaps for the resized images. State can be influenced by import settings.
var _resizer_use_mipmaps: bool = false
## Resizer: Output quality (0-100) for lossy formats (JPG/WebP).
var _resizer_output_quality: int = DEFAULT_LOSSY_QUALITY
## Resizer: If true, create a timestamped subfolder within `default_image_resize_output_path` for the resized images.
var _resizer_create_subfolder: bool = false
## Resizer: If true, remove whitespace characters from output filenames.
var _resizer_remove_whitespace: bool = false
## Resizer: If true, enable batch renaming using `_resizer_batch_rename_pattern`.
var _resizer_batch_rename_enabled: bool = false
## Resizer: The base name pattern used for batch renaming output files.
var _resizer_batch_rename_pattern: String = "image"

## Transfer: If true, automatically transfer successfully resized images to the T2DA Generator input list.
var _transfer_images_to_array_generator_after_resize: bool = false

# --- Other ---
## Stores the mipmap generation state detected from the first input image's .import file.
var _default_mipmap_state: bool = false

#endregion

#region UI Node References (@onready)
# References to UI nodes within the scene. Assumes nodes are correctly named.

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

## Sets the EditorInterface reference provided by the plugin main script.
## Required for accessing editor functionalities like themes and filesystem scanning.
func set_editor_interface(ei: EditorInterface) -> void:
	if ei == null:
		printerr(log_prefix + "Error: Received null EditorInterface.")
		return
	editor_interface = ei
	print(log_prefix + "Editor Interface received.")
	# Apply icons and styles that depend on the editor interface
	_apply_button_icons()
	_apply_title_label_styles()

## Called when the node is added to the scene tree. Initializes UI elements and connects signals.
func _ready() -> void:
	print(log_prefix + "Dock panel initializing (_ready).")

	# --- Initialize File Dialog ---
	file_selection_dialog = EditorFileDialog.new()
	add_child(file_selection_dialog)
	file_selection_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_selection_dialog.title = "Select Files or Folder" # Default title

	# --- Set Initial UI Values ---
	# Use is_instance_valid for safety, although @onready should guarantee availability
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

	# --- Initial Control Disabling/Configuration ---
	if is_instance_valid(resize_images_button):
		resize_images_button.disabled = true # Disabled until images are selected
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
		print(log_prefix + "Applying custom theme.")
		theme_applier.apply_theming(self)
	else:
		print(log_prefix + "No valid Theme Applier resource found. Using default editor theme.")

## Connects signals from UI controls to their corresponding handler functions.
func _connect_signals() -> void:
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
		generate_subfolder_from_array_name_check_button.toggled.connect(func(p: bool): _t2da_create_subfolder = p)
	if is_instance_valid(overwrite_existing_array_check_button):
		overwrite_existing_array_check_button.toggled.connect(func(p: bool): _t2da_allow_overwrite = p)

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
		resizer_create_subfolder_check_button.toggled.connect(func(p: bool): _resizer_create_subfolder = p)
	if is_instance_valid(remove_whitespace_from_file_names_check_button):
		remove_whitespace_from_file_names_check_button.toggled.connect(func(p: bool): _resizer_remove_whitespace = p)
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
		transfer_images_to_array_generator_check_button.toggled.connect(func(p: bool): _transfer_images_to_array_generator_after_resize = p)

## Populates the Resize Mode (aspect ratio) OptionButton.
func _populate_resize_mode_option_button() -> void:
	if not is_instance_valid(resize_mode_option_button):
		printerr(log_prefix + "Error: Resize Mode OptionButton node is missing.")
		return
	resize_mode_option_button.clear()
	resize_mode_option_button.add_item("Stretch", ResizeAspectMode.STRETCH)
	resize_mode_option_button.add_item("Keep Aspect (Pad)", ResizeAspectMode.PAD)
	resize_mode_option_button.add_item("Keep Aspect (Crop)", ResizeAspectMode.CROP)

## Populates the Resize Filter (interpolation) OptionButton.
func _populate_resize_filter_option_button() -> void:
	if not is_instance_valid(resize_filter_option_button):
		printerr(log_prefix + "Error: Resize Filter OptionButton node is missing.")
		return
	resize_filter_option_button.clear()
	resize_filter_option_button.add_item("Nearest (Pixelated)", Image.INTERPOLATE_NEAREST)
	resize_filter_option_button.add_item("Bilinear (Smooth)", Image.INTERPOLATE_BILINEAR)
	resize_filter_option_button.add_item("Cubic (Smoother)", Image.INTERPOLATE_CUBIC)
	resize_filter_option_button.add_item("Lanczos (Sharpest)", Image.INTERPOLATE_LANCZOS)
	# Trilinear requires mipmaps, might be confusing here. Stick to basic interpolation.

## Populates the T2DA Ensure Format OptionButton.
func _populate_ensure_format_options() -> void:
	if not is_instance_valid(ensure_format_option_button):
		printerr(log_prefix + "Error: Ensure Format OptionButton node is missing.")
		return
	ensure_format_option_button.clear()
	# Common, useful formats for TextureArrays
	ensure_format_option_button.add_item("RGBA8 (Default)", Image.FORMAT_RGBA8)
	ensure_format_option_button.add_item("RGB8 (No Alpha)", Image.FORMAT_RGB8)
	ensure_format_option_button.add_item("LA8 (Luminance+Alpha)", Image.FORMAT_LA8)
	ensure_format_option_button.add_item("L8 (Grayscale)", Image.FORMAT_L8)
	ensure_format_option_button.add_item("RGBAF (HDR)", Image.FORMAT_RGBAF)
	# Default internal state matches the first item added
	_t2da_target_format = Image.FORMAT_RGBA8

## Populates the Resizer Output Format OptionButton. Stores extensions as metadata.
func _populate_output_format_options() -> void:
	if not is_instance_valid(output_format_option_button):
		printerr(log_prefix + "Error: Output Format OptionButton node is missing.")
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
	# Default internal state matches the first item added
	_resizer_output_format_ext = "detect"

#endregion

#region T2DA Generation Callbacks & Logic

## Called when the T2DA output name LineEdit text changes.
func _on_output_array_name_changed(new_text: String) -> void:
	default_output_array_name = new_text

## Called when the T2DA output path LineEdit text changes.
func _on_output_path_changed(new_text: String) -> void:
	default_output_path = new_text

## Called when the T2DA 'Save As' button is pressed. Opens file dialog to choose output name/location.
func _on_save_file_name_button_pressed() -> void:
	_configure_file_dialog(
		EditorFileDialog.FILE_MODE_SAVE_FILE,
		"Save Texture2DArray As...",
		default_output_path,
		default_output_array_name + ".tres", # Suggest .tres extension
		PackedStringArray(["*.tres, *.res ; Godot Resource File"]),
		_on_output_array_name_selected # Callback function
	)

## Callback function when a T2DA output file path is selected in the file dialog.
func _on_output_array_name_selected(path: String) -> void:
	# Update internal state and UI fields based on user selection
	default_output_array_name = path.get_file().get_basename()
	default_output_path = path.get_base_dir()
	if is_instance_valid(output_array_name_line_edit):
		output_array_name_line_edit.text = default_output_array_name
	if is_instance_valid(output_path_line_edit):
		output_path_line_edit.text = default_output_path

## Called when the T2DA 'Browse Input Files' button is pressed.
func _on_browse_t2da_input_files_button_pressed() -> void:
	_configure_file_dialog(
		EditorFileDialog.FILE_MODE_OPEN_FILES,
		"Select Input Images for Texture Array",
		"res://", # Start browsing from project root
		"",
		PackedStringArray(["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.tga", "*.exr", "*.hdr; Image Files"]),
		_on_t2da_input_files_selected # Callback function
	)

## Callback function when T2DA input image files are selected in the file dialog.
func _on_t2da_input_files_selected(paths: PackedStringArray) -> void:
	_t2da_input_textures.clear() # Clear previous selections
	var loaded_count: int = 0
	var failed_count: int = 0
	print(log_prefix + "Loading %d selected image(s) for T2DA..." % paths.size())

	for path in paths:
		if not FileAccess.file_exists(path):
			printerr(log_prefix + "Error: Selected file does not exist: %s" % path)
			failed_count += 1
			continue

		var image: Image = Image.load_from_file(path)
		if image != null and not image.is_empty():
			# Create an ImageTexture from the loaded Image
			var texture: ImageTexture = ImageTexture.create_from_image(image)
			if is_instance_valid(texture):
				texture.resource_path = path # Store original path for reference/transfer
				_t2da_input_textures.append(texture)
				loaded_count += 1
			else:
				printerr(log_prefix + "Error: Failed to create ImageTexture for: %s" % path.get_file())
				failed_count += 1
		else:
			printerr(log_prefix + "Error: Failed to load image data from: %s" % path.get_file())
			failed_count += 1

	# Update UI labels
	if is_instance_valid(input_files_count_label):
		input_files_count_label.text = "Images (%d)" % loaded_count
	_update_t2da_input_files_status() # Perform validation and update status label

	if failed_count > 0:
		push_warning(log_prefix + "%d image(s) failed to load for T2DA." % failed_count)
	elif loaded_count > 0:
		print(log_prefix + "Successfully loaded %d image(s) for T2DA." % loaded_count)

## Called when the T2DA 'Browse Output Folder' button is pressed.
func _on_browse_t2da_output_folder_pressed() -> void:
	_configure_file_dialog(
		EditorFileDialog.FILE_MODE_OPEN_DIR,
		"Select Output Folder for Texture Array",
		default_output_path, # Start browsing from current setting
		"",
		PackedStringArray([]), # No specific file filters for directory selection
		_on_t2da_output_folder_selected # Callback function
	)

## Callback function when a T2DA output folder is selected in the file dialog.
func _on_t2da_output_folder_selected(path: String) -> void:
	default_output_path = path
	if is_instance_valid(output_path_line_edit):
		output_path_line_edit.text = path # Update the LineEdit UI

## Called when the T2DA 'Ensure Format' CheckButton is toggled.
func _on_ensure_format_toggled(button_pressed: bool) -> void:
	_t2da_ensure_format = button_pressed
	if is_instance_valid(ensure_format_option_button):
		ensure_format_option_button.disabled = not button_pressed # Enable/disable dropdown

	if not button_pressed:
		print(log_prefix + "T2DA 'Ensure Format' disabled. Original formats will be used.")
		_update_t2da_input_files_status() # Re-validate using original formats
	else:
		print(log_prefix + "T2DA 'Ensure Format' enabled. Target format: %s" % _get_image_format_name(_t2da_target_format))
		# Validation might change if format conversion is now required
		_update_t2da_input_files_status()

## Called when an item is selected in the T2DA 'Ensure Format' OptionButton.
func _on_ensure_format_selected(index: int) -> void:
	if is_instance_valid(ensure_format_option_button):
		var selected_format_id = ensure_format_option_button.get_selected_id()
		if selected_format_id != _t2da_target_format:
			_t2da_target_format = selected_format_id
			print(log_prefix + "T2DA target format set to: %s" % _get_image_format_name(_t2da_target_format))
			# Re-validate if the target format changes while 'Ensure Format' is active
			if _t2da_ensure_format:
				_update_t2da_input_files_status()

## Called when the 'Generate Texture Array' button is pressed. Initiates the T2DA creation process.
func _on_build_texture_array_button_pressed() -> void:
	if _t2da_input_textures.is_empty():
		printerr(log_prefix + "Build cancelled: No input images loaded for T2DA.")
		_set_status_label(input_files_status_label, "No input images selected.", Color.ORANGE)
		return

	# Step 1: Convert image formats if requested
	if _t2da_ensure_format:
		_set_status_label(input_files_status_label, "Converting formats...", Color.BLUE)
		if not _convert_t2da_input_images_to_target_format():
			printerr(log_prefix + "Build cancelled: Format conversion failed.")
			# Status label should be set by the conversion function on failure
			return

	# Step 2: Validate the textures (size and format consistency)
	_set_status_label(input_files_status_label, "Validating images...", Color.BLUE)
	if not _validate_t2da_input_textures():
		printerr(log_prefix + "Build cancelled: Input image validation failed.")
		# Status label should be set by the validation function on failure
		return

	# Step 3: Proceed with building the Texture2DArray resource (deferred for UI responsiveness)
	_set_status_label(input_files_status_label, "Building Texture Array...", Color.BLUE)
	call_deferred("_build_texture_array", _t2da_input_textures)

## Converts the loaded T2DA input images to the specified `_t2da_target_format`.
## Updates the textures in the _t2da_input_textures array in-place.
## Returns true if conversion was successful (or not needed), false otherwise.
func _convert_t2da_input_images_to_target_format() -> bool:
	if not _t2da_ensure_format or _t2da_input_textures.is_empty():
		return true # Nothing to convert

	var target_format_name: String = _get_image_format_name(_t2da_target_format)
	print(log_prefix + "Ensuring all T2DA input images are in format: %s" % target_format_name)
	# Don't set status blue here yet, let the loop provide feedback or final result

	var all_ok: bool = true
	for i in range(_t2da_input_textures.size()):
		var old_texture: Texture2D = _t2da_input_textures[i] # Get the existing texture
		if not is_instance_valid(old_texture):
			printerr(log_prefix + "Conversion Error: Invalid texture instance at index %d." % i)
			all_ok = false
			break # Cannot proceed if texture is invalid

		# Use duplicate() to avoid modifying the image associated with the potentially cached old_texture directly
		var image: Image = old_texture.get_image()
		if not is_instance_valid(image) or image.is_empty():
			printerr(log_prefix + "Conversion Error: Invalid image data for texture %d ('%s')." % [i, old_texture.resource_path]) # Use old path for logging
			all_ok = false
			break

		var image_copy = image.duplicate() # Work on a copy
		if not is_instance_valid(image_copy):
			printerr(log_prefix + "Conversion Error: Failed to duplicate image data for texture %d." % i)
			all_ok = false
			break

		if image_copy.get_format() != _t2da_target_format:
			var original_format_name: String = _get_image_format_name(image_copy.get_format())
			var original_path_for_log = old_texture.resource_path if old_texture.resource_path else "in-memory"
			print(log_prefix + "Converting T2DA img %d ('%s'): %s -> %s" % [i + 1, original_path_for_log.get_file(), original_format_name, target_format_name])

			# --- Perform Conversion on the copied Image object ---
			image_copy.convert(_t2da_target_format)

			# --- Verify conversion on the Image object ---
			if image_copy.get_format() != _t2da_target_format:
				printerr(log_prefix + "Error: Failed converting T2DA image %d ('%s') to %s!" % [i + 1, original_path_for_log.get_file(), target_format_name])
				_set_status_label(input_files_status_label, "Error: Format conversion failed for image %d!" % (i + 1), Color.RED)
				all_ok = false
				break # Stop on first conversion failure
			else:
				# --- SUCCESS: Update the Texture in the array ---
				print(log_prefix + " > Conversion successful. Updating texture in list.")
				# Create a NEW ImageTexture from the *converted* image data
				var new_texture: ImageTexture = ImageTexture.create_from_image(image_copy)
				if is_instance_valid(new_texture):
					# --- FIX: REMOVE resource_path assignment ---
					# Do NOT assign the old path to the new in-memory texture
					# new_texture.resource_path = old_texture.resource_path
					# Keep the original path stored separately if needed for other features,
					# but don't assign it to the new texture object itself here.
					# Maybe store it in the new_texture's metadata?
					new_texture.set_meta("original_path", old_texture.resource_path if old_texture.resource_path else "")


					# Replace the old texture with the new one in the array
					_t2da_input_textures[i] = new_texture
				else:
					printerr(log_prefix + "Error: Failed to create new ImageTexture after conversion for image %d!" % (i + 1))
					_set_status_label(input_files_status_label, "Error: Texture creation failed post-convert for img %d!" % (i + 1), Color.RED)
					all_ok = false
					break
		# else: Format already matches, no conversion needed for this image

	if all_ok:
		print(log_prefix + "Format conversion and texture update step completed successfully.")
		_set_status_label(input_files_status_label, "Format conversion successful.", Color.GREEN) # Okay to set green now
	else:
		print(log_prefix + "Format conversion and texture update step failed.")

	return all_ok

## Validates the loaded T2DA input textures for size and format consistency.
## If _t2da_ensure_format is true, format consistency is NOT checked here,
## as it will be handled later during the build process.
## Updates the status label accordingly. Returns true if validation passes, false otherwise.
func _validate_t2da_input_textures() -> bool:
	if is_instance_valid(ready_to_generate_label):
		ready_to_generate_label.text = "Ready? (Checking...)"

	if _t2da_input_textures.size() < 1:
		_set_status_label(input_files_status_label, "Requires at least 1 image.", Color.ORANGE)
		if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
		return false

	# Check the first texture/image
	var first_texture: Texture2D = _t2da_input_textures[0]
	if not is_instance_valid(first_texture):
		_set_status_label(input_files_status_label, "Error: First texture is invalid!", Color.RED)
		if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
		return false
	var first_image: Image = first_texture.get_image()
	if not is_instance_valid(first_image) or first_image.is_empty():
		_set_status_label(input_files_status_label, "Error: First image data is invalid!", Color.RED)
		if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
		return false

	var first_size: Vector2i = first_image.get_size()
	# Determine the format of the first image for comparison *if* not ensuring format
	var first_format: Image.Format = first_image.get_format()
	var first_format_name: String = _get_image_format_name(first_format)

	# Determine the format name to display in the status message
	var display_format_name = _get_image_format_name(_t2da_target_format) if _t2da_ensure_format else first_format_name

	if _t2da_input_textures.size() == 1:
		# Even with one image, show the format it *will* be if ensure is on.
		_set_status_label(input_files_status_label, "1 image (%s, %s). Minimum 2 recommended." % [str(first_size), display_format_name], Color.YELLOW)
		# Allow generation with one image. Validation passes here.

	# Check subsequent textures/images
	for i in range(1, _t2da_input_textures.size()):
		var current_texture: Texture2D = _t2da_input_textures[i]
		if not is_instance_valid(current_texture):
			_set_status_label(input_files_status_label, "Error: Image %d is invalid!" % (i + 1), Color.RED)
			if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
			return false

		var current_image: Image = current_texture.get_image()
		if not is_instance_valid(current_image) or current_image.is_empty():
			_set_status_label(input_files_status_label, "Error: Image %d data is invalid!" % (i + 1), Color.RED)
			if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
			return false

		# --- Check size ---
		var current_size: Vector2i = current_image.get_size()
		if current_size != first_size:
			_set_status_label(input_files_status_label, "Error: Size mismatch! Img %d (%s) vs Img 1 (%s). Use Resizer?" % [i + 1, str(current_size), str(first_size)], Color.RED)
			if is_instance_valid(transfer_array_input_files_to_resizer_button):
				transfer_array_input_files_to_resizer_button.grab_focus()
			if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
			return false

		# --- Check format ONLY IF _t2da_ensure_format IS FALSE ---
		if not _t2da_ensure_format:
			var current_format: Image.Format = current_image.get_format()
			if current_format != first_format:
				# Format mismatch detected, and we are NOT enforcing a target format later. This is an error now.
				var current_format_name: String = _get_image_format_name(current_format)
				var error_message: String = "Error: Format mismatch! Img %d (%s) vs Img 1 (%s). Use 'Ensure Format'?" % [i + 1, current_format_name, first_format_name]
				_set_status_label(input_files_status_label, error_message, Color.RED)
				if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (No)"
				return false
		# else: If _t2da_ensure_format is true, we *ignore* the format check during this validation phase.
		# We assume the conversion step during the build process will handle it.

	# If all checks passed (or format checks were skipped because _t2da_ensure_format is true)
	if is_instance_valid(ready_to_generate_label): ready_to_generate_label.text = "Ready? (Yes!)"
	_set_status_label(input_files_status_label, "%d images OK (%s, %s)" % [_t2da_input_textures.size(), str(first_size), display_format_name], Color.GREEN)
	return true

## Performs the actual creation and saving of the Texture2DArray resource. Called deferred.
func _build_texture_array(textures: Array[Texture2D]) -> void:
	if textures.is_empty():
		printerr(log_prefix + "Build Error: Texture list is empty.")
		_set_status_label(input_files_status_label, "Error: Build failed - No textures provided.", Color.RED)
		return

	print(log_prefix + "Starting Texture2DArray build with %d textures..." % textures.size())

	# Extract Image data from the input Textures
	var images_array: Array[Image] = []
	for i in range(textures.size()):
		var tex: Texture2D = textures[i]
		if not is_instance_valid(tex):
			printerr(log_prefix + "Build Error: Invalid texture instance at index %d." % i)
			_set_status_label(input_files_status_label, "Error: Build failed - Invalid texture data.", Color.RED)
			return
		var img: Image = tex.get_image()
		if is_instance_valid(img) and not img.is_empty():
			images_array.append(img)
		else:
			printerr(log_prefix + "Build Error: Could not get valid image data from texture %d ('%s')." % [i, tex.resource_path])
			_set_status_label(input_files_status_label, "Error: Build failed - Invalid image data.", Color.RED)
			return

	if images_array.is_empty():
		printerr(log_prefix + "Build Error: No valid images were extracted from the textures.")
		_set_status_label(input_files_status_label, "Error: Build failed - No valid image data found.", Color.RED)
		return

	# Create the Texture2DArray resource and populate it
	var array_texture: Texture2DArray = Texture2DArray.new()
	print(log_prefix + "Texture2DArray resource created. Populating from images...")
	var create_error: Error = array_texture.create_from_images(images_array)

	if create_error != OK:
		printerr(log_prefix + "Creation Error: Texture2DArray.create_from_images() failed with error code: %d (%s)" % [create_error, error_string(create_error)])
		_set_status_label(input_files_status_label, "Error: Array creation failed! Code: %d" % create_error, Color.RED)
		return
	else:
		print(log_prefix + "Texture2DArray data populated successfully.")

	# --- Determine Final Save Path (Handle Subfolder & Overwrite) ---
	var final_save_dir: String = default_output_path
	var final_array_name: String = default_output_array_name
	# Sanitize potential array name for use as folder name
	var subfolder_name_base: String = default_output_array_name.validate_filename().replace(" ", "_").strip_edges()
	if subfolder_name_base == "": subfolder_name_base = "t2da_output" # Fallback if name is empty/invalid

	if _t2da_create_subfolder:
		final_save_dir = default_output_path.path_join(subfolder_name_base)
		print(log_prefix + "Using subfolder for T2DA output: " + final_save_dir)

	# Construct initial save path
	var save_path_str: String = final_save_dir.path_join(final_array_name + ".tres")

	# Handle overwrite prevention by appending counter if needed
	if not _t2da_allow_overwrite:
		var counter: int = 1
		var original_name: String = final_array_name
		while FileAccess.file_exists(save_path_str):
			final_array_name = original_name + "_" + str(counter)
			save_path_str = final_save_dir.path_join(final_array_name + ".tres")
			counter += 1
		if counter > 1:
			print(log_prefix + "Output file exists and overwrite is disabled. Using unique name: " + final_array_name)

	# --- Ensure Output Directory Exists ---
	var dir_access = DirAccess.open("res://") # Get DirAccess for project scope
	if not dir_access:
		printerr(log_prefix + "Save Error: Could not access project directory ('res://').")
		_set_status_label(input_files_status_label, "Save Error: Directory access failed!", Color.RED)
		return

	# Check if target directory needs creation (use absolute path for check)
	var global_save_dir = ProjectSettings.globalize_path(final_save_dir)
	if not DirAccess.dir_exists_absolute(global_save_dir):
		print(log_prefix + "Creating output directory: " + final_save_dir)
		var mk_err: Error = dir_access.make_dir_recursive(final_save_dir)
		if mk_err != OK:
			printerr(log_prefix + "Save Error: Failed to create directory '%s'. Error: %d (%s)" % [final_save_dir, mk_err, error_string(mk_err)])
			_set_status_label(input_files_status_label, "Save Error: Create folder failed!", Color.RED)
			return

	# --- Save the Resource ---
	print(log_prefix + "Saving Texture2DArray resource to: " + save_path_str)
	# Flags for better saving (optional, but good practice)
	var save_flags = ResourceSaver.FLAG_COMPRESS # Use default compression
	var save_err: Error = ResourceSaver.save(array_texture, save_path_str, save_flags)

	if save_err == OK:
		print(log_prefix + "Texture2DArray saved successfully: " + save_path_str)
		_set_status_label(input_files_status_label, "Texture Array saved successfully!", Color.GREEN)
		# Refresh filesystem view in editor
		if is_instance_valid(editor_interface):
			print(log_prefix + "Requesting filesystem scan...")
			editor_interface.get_resource_filesystem().scan()
	else:
		printerr(log_prefix + "Save Error: Failed to save '%s'. Error: %d (%s)" % [save_path_str, save_err, error_string(save_err)])
		_set_status_label(input_files_status_label, "Save Error! Code: %d" % save_err, Color.RED)

## Updates the T2DA input status label based on the current state and runs validation.
func _update_t2da_input_files_status() -> void:
	if not is_instance_valid(input_files_status_label):
		return # Label node not ready or invalid

	if _t2da_input_textures.is_empty():
		_set_status_label(input_files_status_label, "No T2DA input images loaded.", Color.AQUA)
		if is_instance_valid(ready_to_generate_label):
			ready_to_generate_label.text = "Ready? (No)"
		if is_instance_valid(build_t2da_button):
			build_t2da_button.disabled = true
	else:
		# Run validation, which will set the appropriate status message and color
		var is_valid = _validate_t2da_input_textures()
		if is_instance_valid(build_t2da_button):
			build_t2da_button.disabled = not is_valid


#endregion

#region Image Resizing Callbacks & Logic

## Called when the Resizer 'Browse Input Files' button is pressed.
func _on_image_resize_browse_input_files_button_pressed() -> void:
	_configure_file_dialog(
		EditorFileDialog.FILE_MODE_OPEN_FILES,
		"Select Images to Resize",
		"res://",
		"",
		PackedStringArray(["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.tga", "*.exr", "*.hdr; Image Files"]),
		_on_image_resize_input_files_selected # Callback
	)

## Callback function when Resizer input image files are selected.
func _on_image_resize_input_files_selected(paths: PackedStringArray) -> void:
	_resize_input_image_paths = paths.duplicate() # Store selected paths
	_resize_output_image_paths.clear() # Clear any previous output paths
	print(log_prefix + "Resizer received %d input file path(s)." % paths.size())
	# Update UI based on selection
	_update_resize_input_files_status()
	_update_largest_image_size_label(paths)
	_update_quality_slider_visibility() # Visibility might depend on first file type if format is "detect"
	if is_instance_valid(resize_images_button):
		resize_images_button.disabled = paths.is_empty() # Enable button if files selected

## Called when the Resizer 'Browse Output Folder' button is pressed.
func _on_image_resize_browse_output_folder_button_pressed() -> void:
	_configure_file_dialog(
		EditorFileDialog.FILE_MODE_OPEN_DIR,
		"Select Image Resizer Output Folder",
		default_image_resize_output_path, # Start from current setting
		"",
		PackedStringArray([]),
		_on_image_resize_output_folder_selected # Callback
	)

## Callback function when Resizer output folder is selected.
func _on_image_resize_output_folder_selected(path: String) -> void:
	default_image_resize_output_path = path
	if is_instance_valid(image_resize_output_path_line_edit):
		image_resize_output_path_line_edit.text = path # Update UI

## Updates Resizer status labels and attempts to set default mipmap state based on the first image's import settings.
func _update_resize_input_files_status() -> void:
	var count: int = _resize_input_image_paths.size()
	if is_instance_valid(resize_input_files_count_label):
		resize_input_files_count_label.text = "Selected Images (%d)" % count
	if is_instance_valid(ready_to_resize_label):
		ready_to_resize_label.text = "Ready? (%s)" % ("Yes" if count > 0 else "No")
	if is_instance_valid(resize_image_status_label):
		if count == 0:
			_set_status_label(resize_image_status_label, "Select images using 'Browse Input'.", Color.AQUA)
		else:
			_set_status_label(resize_image_status_label, "%d image(s) selected for resizing." % count, Color.MAGENTA) # Use a distinct color

	# Update Mipmap Checkbox Default based on first image's import settings
	if count > 0:
		_set_default_mipmap_state_from_import(_resize_input_image_paths[0])
	else:
		_set_mipmap_checkbox_state(false) # Reset checkbox if no files are selected

## Calculates the maximum width and height from a list of image paths and updates the corresponding label.
func _update_largest_image_size_label(paths: PackedStringArray) -> void:
	# FIX: Reverted to use load_from_file as get_image_size_from_file is not static
	if not is_instance_valid(largest_image_size_label):
		return # Label not ready

	var max_w: int = 0
	var max_h: int = 0
	var ok_count: int = 0
	var fail_count: int = 0

	for p in paths:
		if not FileAccess.file_exists(p):
			fail_count += 1
			continue
		var image: Image = Image.load_from_file(p) # Load the image to get its size
		if image != null and not image.is_empty():
			var img_size: Vector2i = image.get_size()
			max_w = max(max_w, img_size.x)
			max_h = max(max_h, img_size.y)
			ok_count += 1
		else:
			printerr(log_prefix + "Warning: Failed to load image to get size: %s" % p.get_file())
			fail_count += 1

	largest_image_size_label.text = "%dx%d" % [max_w, max_h]

	# Update status label if there were issues reading sizes
	if fail_count > 0 and is_instance_valid(resize_image_status_label):
		# Make sure status update doesn't overwrite a more important previous message if only some failed
		var current_text = resize_image_status_label.text
		if not current_text.begins_with("Error"): # Don't overwrite error messages
			_set_status_label(resize_image_status_label, "Warning: Couldn't read size for %d image(s)." % fail_count, Color.YELLOW)
	elif ok_count > 0 and (max_w == 0 or max_h == 0) and is_instance_valid(resize_image_status_label):
		_set_status_label(resize_image_status_label, "Warning: Could not determine largest size.", Color.YELLOW)


## Reads the .import file associated with an image path to determine its mipmap setting.
func _set_default_mipmap_state_from_import(first_image_path: String) -> void:
	# Look for the specific mipmap parameter in the texture import settings
	var import_mip_value = _read_import_setting(first_image_path, "params/mipmaps", null)

	if import_mip_value != null and import_mip_value is bool:
		_default_mipmap_state = import_mip_value
		print(log_prefix + "Detected mipmap state from '%s': %s" % [first_image_path.get_file(), str(_default_mipmap_state)])
	else:
		# Default to false if setting not found or import file missing/invalid
		_default_mipmap_state = false
		print(log_prefix + "Could not detect mipmap state for '%s'. Defaulting to false." % first_image_path.get_file())

	# Update the UI checkbox to reflect the detected or default state
	_set_mipmap_checkbox_state(_default_mipmap_state)

## Helper function to set the state of the mipmap checkbox and update the internal variable.
func _set_mipmap_checkbox_state(state: bool) -> void:
	if is_instance_valid(use_mipmaps_check_button):
		# Only update if the state is different to avoid triggering toggled signal unnecessarily
		if use_mipmaps_check_button.button_pressed != state:
			use_mipmaps_check_button.button_pressed = state
	# Always update the internal state variable
	_resizer_use_mipmaps = state

## Called when the Resizer 'Use Largest Size' CheckButton is toggled.
func _on_use_largest_size_check_button_toggled(pressed: bool) -> void:
	_use_largest_image_dimensions = pressed
	_update_use_largest_size_ui() # Update related UI elements

## Updates the editability and placeholder text of the custom size input fields based on the 'Use Largest Size' setting.
func _update_use_largest_size_ui() -> void:
	if not (is_instance_valid(custom_image_width_line_edit) and is_instance_valid(custom_image_height_line_edit)):
		return # UI elements not ready

	var allow_custom_edit: bool = not _use_largest_image_dimensions
	custom_image_width_line_edit.editable = allow_custom_edit
	custom_image_height_line_edit.editable = allow_custom_edit

	# Set appropriate placeholder text
	custom_image_width_line_edit.placeholder_text = "Width (px)" if allow_custom_edit else "(Uses Largest Width)"
	custom_image_height_line_edit.placeholder_text = "Height (px)" if allow_custom_edit else "(Uses Largest Height)"

	# Clear text fields if switching back to 'Use Largest Size'
	if not allow_custom_edit:
		custom_image_width_line_edit.clear()
		custom_image_height_line_edit.clear()

## Called when the custom image width or height text changes. (Currently no action needed).
func _on_custom_image_size_changed(new_text: String) -> void:
	# Validation could be added here later if needed (e.g., ensure numeric input)
	pass

## Called when the Resize Mode (aspect ratio) OptionButton selection changes.
func _on_resize_mode_selected(index: int) -> void:
	if not is_instance_valid(resize_mode_option_button): return
	if not is_instance_valid(padding_color_picker):
		printerr(log_prefix + "Warning: Padding Color Picker node is missing or invalid.")
		return

	var selected_id = resize_mode_option_button.get_selected_id()
	print(log_prefix + "Resize aspect mode selected: ID " + str(selected_id))

	# Enable the padding color picker only when the 'Pad' mode is selected
	var enable_padding_picker: bool = (selected_id == ResizeAspectMode.PAD)
	padding_color_picker.disabled = not enable_padding_picker

	if enable_padding_picker:
		print(log_prefix + "Padding color picker enabled for Pad mode.")
	else:
		print(log_prefix + "Padding color picker disabled.")

## Called when the Resizer Output Prefix LineEdit text changes.
func _on_output_prefix_changed(new_text: String) -> void:
	_resizer_output_prefix = new_text.strip_edges() # Trim leading/trailing whitespace

## Called when the Resizer Output Suffix LineEdit text changes.
func _on_output_suffix_changed(new_text: String) -> void:
	_resizer_output_suffix = new_text.strip_edges() # Trim leading/trailing whitespace

## Called when the Resizer Output Format OptionButton selection changes.
func _on_output_format_selected(index: int) -> void:
	if is_instance_valid(output_format_option_button):
		var selected_metadata = output_format_option_button.get_item_metadata(index)
		if selected_metadata != null: # Ensure metadata exists
			_resizer_output_format_ext = selected_metadata
			print(log_prefix + "Resizer output format set to: %s" % _resizer_output_format_ext)
			_update_quality_slider_visibility() # Update slider visibility based on new format

## Updates the visibility and editability of the lossy quality slider based on the selected output format.
func _update_quality_slider_visibility() -> void:
	var show_quality_slider: bool = false
	var current_format_lower: String = str(_resizer_output_format_ext).to_lower() # Use lowercase for comparison

	if current_format_lower == "detect":
		# If detecting, check the format of the *first* input file (if any)
		if not _resize_input_image_paths.is_empty():
			var first_ext: String = _resize_input_image_paths[0].get_extension().to_lower()
			if first_ext == "jpg" or first_ext == "jpeg" or first_ext == "webp":
				show_quality_slider = true
		# else: Keep false if no files or first file is not lossy
	elif current_format_lower == "jpg" or current_format_lower == "webp":
		# Explicitly selected lossy format
		show_quality_slider = true

	# Update UI elements
	if is_instance_valid(format_image_output_quality_h_slider):
		format_image_output_quality_h_slider.visible = show_quality_slider
		format_image_output_quality_h_slider.editable = show_quality_slider
	if is_instance_valid(output_quality_value_label):
		output_quality_value_label.visible = show_quality_slider
	if is_instance_valid(output_quality_label):
		output_quality_label.visible = show_quality_slider

	if show_quality_slider: print(log_prefix + "Output quality slider is now visible.")
	else: print(log_prefix + "Output quality slider is now hidden.")

## Called when the Output Quality HSlider value changes.
func _on_output_quality_slider_changed(value: float) -> void:
	_resizer_output_quality = roundi(value) # Store quality as an integer 0-100
	if is_instance_valid(output_quality_value_label):
		output_quality_value_label.text = "%d%%" % _resizer_output_quality # Update display label

## Called when the Resizer Padding ColorPickerButton color changes.
func _on_padding_color_changed(new_color: Color) -> void:
	_resizer_pad_color = new_color
	print(log_prefix + "Resizer padding color updated to: %s" % str(new_color))

## Called when the Resizer 'Use Mipmaps' CheckButton is toggled by the user.
func _on_use_mipmaps_toggled(button_pressed: bool) -> void:
	# This function is called when the user *manually* clicks the checkbox
	_resizer_use_mipmaps = button_pressed
	print(log_prefix + "Mipmap generation manually set to: %s" % str(_resizer_use_mipmaps))

## Called when the Resizer 'Batch Rename' CheckButton is toggled.
func _on_batch_rename_toggled(button_pressed: bool) -> void:
	_resizer_batch_rename_enabled = button_pressed
	if is_instance_valid(batch_rename_output_images_line_edit):
		batch_rename_output_images_line_edit.editable = button_pressed # Enable/disable text input
	if button_pressed: print(log_prefix + "Batch renaming enabled.")
	else: print(log_prefix + "Batch renaming disabled.")

## Called when the Resizer Batch Rename pattern LineEdit text changes.
func _on_batch_rename_pattern_changed(new_text: String) -> void:
	# Allow spaces here; whitespace removal is a separate option applied later if enabled
	_resizer_batch_rename_pattern = new_text

## Called when the 'Resize Images' button is pressed. Gathers settings and starts the resize process.
func _on_resize_images_button_pressed() -> void:
	if _resize_input_image_paths.is_empty():
		_set_status_label(resize_image_status_label, "Select input images first.", Color.ORANGE)
		return

	# Clear previous output paths before starting a new batch
	_resize_output_image_paths.clear()

	var target_width: int = 0
	var target_height: int = 0

	# Determine Target Size based on UI settings
	if _use_largest_image_dimensions:
		# Parse size from the label displaying largest dimensions
		var size_text: String = largest_image_size_label.text
		var size_parts: PackedStringArray = size_text.split("x")
		if size_parts.size() == 2 and size_parts[0].is_valid_int() and size_parts[1].is_valid_int():
			target_width = int(size_parts[0])
			target_height = int(size_parts[1])
		else:
			_set_status_label(resize_image_status_label, "Error: Cannot parse largest size label!", Color.RED)
			printerr(log_prefix + "Error parsing largest size label text: '%s'" % size_text)
			return
	else:
		# Parse size from custom input fields
		var width_text: String = custom_image_width_line_edit.text
		var height_text: String = custom_image_height_line_edit.text
		if width_text.is_valid_int() and height_text.is_valid_int():
			target_width = int(width_text)
			target_height = int(height_text)
		else:
			_set_status_label(resize_image_status_label, "Error: Custom width/height must be valid numbers.", Color.RED)
			return

	# Validate target size
	if target_width <= 0 or target_height <= 0:
		_set_status_label(resize_image_status_label, "Error: Target width and height must be greater than 0.", Color.RED)
		return

	# Get other settings from UI
	var aspect_mode_id: int = resize_mode_option_button.get_selected_id()
	var interpolation_filter: Image.Interpolation = resize_filter_option_button.get_selected_id() as Image.Interpolation
	var output_dir_base: String = default_image_resize_output_path
	var final_output_dir: String = output_dir_base

	# Handle Resizer Subfolder creation (timestamped)
	if _resizer_create_subfolder:
		var timestamp: int = Time.get_unix_time_from_system()
		var subfolder_name: String = "resized_" + str(timestamp)
		final_output_dir = output_dir_base.path_join(subfolder_name)
		print(log_prefix + "Using timestamped subfolder for resizer output: " + final_output_dir)

	# Ensure Output Directory Exists before processing
	var dir_access = DirAccess.open("res://")
	if not dir_access:
		printerr(log_prefix + "Resize Error: Could not access project directory ('res://').")
		_set_status_label(resize_image_status_label, "Error: Directory access failed!", Color.RED)
		return
	var global_final_output_dir = ProjectSettings.globalize_path(final_output_dir)
	if not DirAccess.dir_exists_absolute(global_final_output_dir):
		print(log_prefix + "Creating output directory: " + final_output_dir)
		var mkdir_err: Error = dir_access.make_dir_recursive(final_output_dir)
		if mkdir_err != OK:
			printerr(log_prefix + "Resize Error: Cannot create folder '%s'. Error: %d (%s)" % [final_output_dir, mkdir_err, error_string(mkdir_err)])
			_set_status_label(resize_image_status_label, "Error: Failed to create output folder!", Color.RED)
			return

	# Defer the actual image processing to avoid freezing the editor UI
	_set_status_label(resize_image_status_label, "Resizing %d image(s)..." % _resize_input_image_paths.size(), Color.BLUE)
	call_deferred("_process_resize_batch", target_width, target_height, aspect_mode_id, interpolation_filter,
					_resizer_output_prefix, _resizer_output_suffix, _resizer_output_format_ext,
					_resizer_output_quality, _resizer_pad_color, _resizer_use_mipmaps,
					_resizer_remove_whitespace, _resizer_batch_rename_enabled, _resizer_batch_rename_pattern,
					final_output_dir) # Pass the potentially modified final output directory


## Processes a batch of images for resizing based on the provided parameters. Called deferred.
func _process_resize_batch(target_width: int, target_height: int,
						   aspect_mode_id: int, interpolation_filter: Image.Interpolation,
						   output_prefix: String, output_suffix: String, output_format_ext: String, output_quality: int,
						   pad_color: Color, generate_mipmaps: bool,
						   remove_whitespace: bool, batch_rename: bool, batch_rename_pattern: String,
						   output_dir: String) -> void:
	var success_count: int = 0
	var fail_count: int = 0
	var batch_rename_counter: int = 1 # Counter for batch renaming, starting at 1
	var temp_output_paths: PackedStringArray = [] # Collect paths of successfully saved files

	print(log_prefix + "Starting resize batch processing...")
	print(log_prefix + " - Target Size: %dx%d" % [target_width, target_height])
	print(log_prefix + " - Aspect Mode: %d, Interpolation: %d" % [aspect_mode_id, interpolation_filter])
	print(log_prefix + " - Naming: Prefix='%s', Suffix='%s', Batch=%s ('%s'), Whitespace=%s" % [output_prefix, output_suffix, str(batch_rename), batch_rename_pattern, str(remove_whitespace)])
	print(log_prefix + " - Output: Format='%s', Quality=%d, Mipmaps=%s, PadColor=%s" % [output_format_ext, output_quality, str(generate_mipmaps), str(pad_color)])
	print(log_prefix + " - Output Directory: %s" % output_dir)

	# --- Process Each Input Image ---
	for input_path in _resize_input_image_paths:
		if not FileAccess.file_exists(input_path):
			printerr(log_prefix + "Resize Error: Input file not found: %s" % input_path)
			fail_count += 1
			continue

		var image: Image = Image.load_from_file(input_path)
		if image == null or image.is_empty():
			printerr(log_prefix + "Resize Error: Failed to load image data from: %s" % input_path.get_file())
			fail_count += 1
			continue # Skip this image

		var original_width: float = image.get_width()
		var original_height: float = image.get_height()
		var processed_image: Image = image.duplicate() # Work on a copy to avoid modifying the original Image resource if it's used elsewhere

		# --- Apply Resizing based on Aspect Mode ---
		match aspect_mode_id:
			ResizeAspectMode.STRETCH:
				processed_image.resize(target_width, target_height, interpolation_filter)
			ResizeAspectMode.PAD:
				var target_ratio: float = float(target_width) / target_height
				var original_ratio: float = original_width / original_height
				var scale: float = 1.0
				if original_ratio > target_ratio: # Image is wider than target aspect ratio
					scale = float(target_width) / original_width
				else: # Image is taller or same aspect ratio
					scale = float(target_height) / original_height

				var scaled_width: int = roundi(original_width * scale)
				var scaled_height: int = roundi(original_height * scale)

				# Create a new blank image with the target size and format
				var padded_image: Image = Image.create(target_width, target_height, false, processed_image.get_format())
				padded_image.fill(pad_color) # Fill with the specified padding color

				# Resize the original (duplicate) image to fit within padding area
				var temp_resized_image = processed_image.duplicate() # Duplicate again for resize operation
				temp_resized_image.resize(scaled_width, scaled_height, interpolation_filter)

				# Calculate top-left position to center the scaled image
				var paste_x: int = (target_width - scaled_width) / 2
				var paste_y: int = (target_height - scaled_height) / 2

				# Blit the resized image onto the padded background
				padded_image.blit_rect(temp_resized_image, Rect2i(0, 0, scaled_width, scaled_height), Vector2i(paste_x, paste_y))
				processed_image = padded_image # Replace processed_image with the new padded one

			ResizeAspectMode.CROP:
				var target_ratio: float = float(target_width) / target_height
				var original_ratio: float = original_width / original_height
				var scale: float = 1.0
				# Scale to cover the target area completely
				if original_ratio < target_ratio: # Image is taller than target aspect ratio (needs scaling based on width)
					scale = float(target_width) / original_width
				else: # Image is wider or same aspect ratio (needs scaling based on height)
					scale = float(target_height) / original_height

				var scaled_width: int = roundi(original_width * scale)
				var scaled_height: int = roundi(original_height * scale)

				# Resize the image first to cover the target area
				processed_image.resize(scaled_width, scaled_height, interpolation_filter)

				# Calculate the top-left corner for cropping (center crop)
				var crop_x: int = (scaled_width - target_width) / 2
				var crop_y: int = (scaled_height - target_height) / 2

				# Get the cropped region
				processed_image = processed_image.get_region(Rect2i(crop_x, crop_y, target_width, target_height))

		# --- Generate Mipmaps (Optional) ---
		if generate_mipmaps:
			if not processed_image.has_mipmaps(): # Only generate if not already present
				print(log_prefix + "Generating mipmaps for %s..." % input_path.get_file())
				var mip_err: Error = processed_image.generate_mipmaps()
				if mip_err != OK:
					printerr(log_prefix + "Mipmap Error for '%s': %d (%s)" % [input_path.get_file(), mip_err, error_string(mip_err)])
					# Continue processing even if mipmap generation fails

		# --- Construct Output Filename ---
		var base_name: String = ""
		var current_extension: String = input_path.get_extension()
		# Determine final extension (handle "detect" case)
		var final_extension: String = output_format_ext
		if final_extension == "detect":
			final_extension = current_extension if current_extension != "" else "png" # Default to png if no extension

		# Determine base name (batch rename or original based)
		if batch_rename:
			# Use pattern + user suffix + counter
			var pattern: String = batch_rename_pattern if batch_rename_pattern.strip_edges() != "" else "image"
			var counter_str: String = "_%03d" % batch_rename_counter # Padded counter e.g., _001
			base_name = pattern + output_suffix + counter_str # Order: Pattern_UserSuffix_Counter
			batch_rename_counter += 1
		else:
			# Use original base name + user suffix
			base_name = input_path.get_file().get_basename()
			# Optionally remove whitespace from the original base name
			if remove_whitespace:
				var regex = RegEx.new()
				# Regex to find one or more whitespace characters (space, tab, newline etc.)
				var compile_error = regex.compile("\\s+")
				if compile_error == OK:
					base_name = regex.sub(base_name, "", true) # Replace all occurrences with empty string
				else:
					printerr(log_prefix + "Regex compile error for whitespace removal!")
					base_name = base_name.replace(" ", "") # Fallback to simple space removal
			base_name = base_name + output_suffix # Add user suffix AFTER potential whitespace removal

		# Combine parts: Prefix + BaseName + Extension
		var new_filename: String = (output_prefix + base_name + "." + final_extension).validate_filename()
		var output_path: String = output_dir.path_join(new_filename)

		# --- Save Processed Image ---
		var save_err: Error = ERR_UNAVAILABLE # Default error code
		# Prepare quality factors for relevant formats
		var quality_float_jpg: float = float(output_quality) / 100.0 # JPG expects 0.0 to 1.0
		var quality_float_webp: float = float(output_quality) # WebP expects 0 to 100 float

		match final_extension.to_lower():
			"png":
				save_err = processed_image.save_png(output_path)
			"jpg", "jpeg":
				save_err = processed_image.save_jpg(output_path, quality_float_jpg)
			"webp":
				# Determine lossy/lossless based on quality. >=100 means lossless attempt.
				var webp_lossless: bool = (quality_float_webp >= 100.0)
				save_err = processed_image.save_webp(output_path, webp_lossless, quality_float_webp)
			"bmp":
				save_err = processed_image.save_bmp(output_path)
			"tga":
				save_err = processed_image.save_tga(output_path)
			_:
				printerr(log_prefix + "Save Error: Unsupported output format '%s' for file '%s'." % [final_extension, new_filename])
				save_err = ERR_INVALID_PARAMETER # Indicate unsupported format

		if save_err == OK:
			success_count += 1
			temp_output_paths.append(output_path) # Add successfully saved path
			print(log_prefix + "Successfully resized and saved '%s' to '%s'" % [input_path.get_file(), output_path])
		else:
			printerr(log_prefix + "Save Error: Failed saving '%s'. Error: %d (%s)" % [new_filename, save_err, error_string(save_err)])
			fail_count += 1

	# --- Final Update & Optional Transfer ---
	_resize_output_image_paths = temp_output_paths # Store the successfully created output paths

	var final_status_text: String = "Resize complete: %d succeeded, %d failed." % [success_count, fail_count]
	var final_color: Color = Color.RED if success_count == 0 and fail_count > 0 else Color.YELLOW if fail_count > 0 else Color.GREEN
	_set_status_label(resize_image_status_label, final_status_text, final_color)
	print(log_prefix + final_status_text)

	# Focus the 'Transfer Output' button as a visual cue that processing finished
	if is_instance_valid(transfer_resizer_output_images_to_array_gen_button):
		transfer_resizer_output_images_to_array_gen_button.grab_focus()

	# Refresh filesystem if files were created/modified
	if success_count > 0 and is_instance_valid(editor_interface):
		editor_interface.get_resource_filesystem().scan()

	# Auto-transfer if enabled and successful files exist
	if _transfer_images_to_array_generator_after_resize and success_count > 0:
		print(log_prefix + "Auto-transferring %d resized images to T2DA Generator..." % success_count)
		# Use the collected output paths for transfer
		call_deferred("_transfer_paths_to_t2da_generator", _resize_output_image_paths)

#endregion

#region Transfer Actions & Logic

## Called when the 'Transfer Resizer Input -> T2DA Gen' button is pressed.
func _on_transfer_resizer_input_files_to_array_gen_pressed() -> void:
	if _resize_input_image_paths.is_empty():
		printerr(log_prefix + "Transfer failed: No Resizer input images selected.")
		_set_status_label(input_files_status_label, "Error: No resizer inputs to transfer.", Color.RED)
		return

	print(log_prefix + "Transferring %d Resizer input paths -> T2DA Generator..." % _resize_input_image_paths.size())
	# Call the common transfer function with the Resizer's input paths
	_transfer_paths_to_t2da_generator(_resize_input_image_paths)
	# Update status labels
	_set_status_label(resize_image_status_label, "Input paths transferred to T2DA Generator.", Color.GREEN)
	_set_status_label(input_files_status_label, "Received paths from Resizer.", Color.GREEN)


## Called when the 'Transfer Resizer Output -> T2DA Gen' button is pressed.
func _on_transfer_resizer_output_images_to_array_gen_pressed() -> void:
	if _resize_output_image_paths.is_empty():
		printerr(log_prefix + "Transfer failed: No Resizer output images available (Run resize first or none succeeded).")
		_set_status_label(input_files_status_label, "Warning: No resizer output paths available.", Color.YELLOW)
		_set_status_label(resize_image_status_label, "No successful resize outputs to transfer.", Color.YELLOW)
		return

	# Verify paths still exist before transferring
	var valid_output_paths: PackedStringArray = []
	for path in _resize_output_image_paths:
		if FileAccess.file_exists(path):
			valid_output_paths.append(path)
		else:
			printerr(log_prefix + "Warning: Resized output file not found during transfer: %s" % path)

	if valid_output_paths.is_empty():
		printerr(log_prefix + "Transfer failed: None of the recorded output paths could be found.")
		_set_status_label(input_files_status_label, "Error: Could not find any output files.", Color.RED)
		_set_status_label(resize_image_status_label, "Error finding output files for transfer.", Color.RED)
		return

	print(log_prefix + "Transferring %d Resizer output paths -> T2DA Generator..." % valid_output_paths.size())
	# Call the common transfer function with the validated Resizer's output paths
	_transfer_paths_to_t2da_generator(valid_output_paths)
	# Update status labels
	_set_status_label(resize_image_status_label, "Output paths transferred to T2DA Generator.", Color.GREEN)
	_set_status_label(input_files_status_label, "Received paths from Resizer outputs.", Color.GREEN)

## Called when the 'Transfer T2DA Input -> Resizer' button is pressed.
func _on_transfer_array_input_files_to_resizer_pressed() -> void:
	if is_instance_valid(transfer_array_input_files_to_resizer_button):
		transfer_array_input_files_to_resizer_button.release_focus() # Defocus button after press

	if _t2da_input_textures.is_empty():
		printerr(log_prefix + "Transfer failed: No T2DA input textures loaded.")
		_set_status_label(resize_image_status_label, "Warning: No T2DA images loaded to transfer.", Color.YELLOW)
		return

	var paths_to_transfer: PackedStringArray = []
	var missing_path_count: int = 0
	var invalid_texture_count: int = 0

	print(log_prefix + "Preparing to transfer T2DA input paths -> Resizer...")
	for texture in _t2da_input_textures:
		if is_instance_valid(texture):
			# --- Retrieve path from metadata ---
			var path: String = ""
			if texture.has_meta("original_path"):
				path = texture.get_meta("original_path")
			# --- Fallback to resource_path if metadata doesn't exist (e.g., if loaded directly without conversion) ---
			elif texture.resource_path != null and texture.resource_path != "":
				path = texture.resource_path
				print(log_prefix + " > Using resource_path as fallback for transfer: %s" % path)

			if path != "" and FileAccess.file_exists(path):
				paths_to_transfer.append(path)
			else:
				printerr(log_prefix + "Warning: T2DA texture missing a valid original path (checked meta['original_path'] and resource_path): '%s'" % path)
				missing_path_count += 1
		else:
			printerr(log_prefix + "Warning: Encountered invalid T2DA texture instance during transfer.")
			invalid_texture_count += 1

	# Update the Resizer's input path list
	_resize_input_image_paths = paths_to_transfer
	var total_issues: int = missing_path_count + invalid_texture_count

	print(log_prefix + "Transferred %d T2DA paths -> Resizer input. (%d issues encountered)." % [paths_to_transfer.size(), total_issues])

	# Update Resizer UI based on the transferred paths
	_update_resize_input_files_status()
	_update_largest_image_size_label(_resize_input_image_paths)
	_update_quality_slider_visibility()
	if is_instance_valid(resize_images_button):
		resize_images_button.disabled = _resize_input_image_paths.is_empty()

	# Set appropriate status message on the Resizer side
	if total_issues > 0:
		_set_status_label(resize_image_status_label, "Transferred %d paths from T2DA (%d issues)." % [paths_to_transfer.size(), total_issues], Color.ORANGE)
	elif paths_to_transfer.is_empty():
		_set_status_label(resize_image_status_label, "Transfer from T2DA complete, but no valid paths found.", Color.ORANGE)
	else:
		_set_status_label(resize_image_status_label, "Transferred %d paths from T2DA successfully!" % paths_to_transfer.size(), Color.GREEN)

## Loads images from a given list of file paths into the T2DA Generator's input list (`_t2da_input_textures`).
func _transfer_paths_to_t2da_generator(paths: PackedStringArray) -> void:
	# Defocus transfer buttons after action
	if is_instance_valid(transfer_resizer_output_images_to_array_gen_button):
		transfer_resizer_output_images_to_array_gen_button.release_focus()
	if is_instance_valid(transfer_resizer_input_files_to_array_gen_button):
		transfer_resizer_input_files_to_array_gen_button.release_focus()

	_t2da_input_textures.clear() # Clear existing T2DA inputs
	var loaded_count: int = 0
	var failed_count: int = 0
	print(log_prefix + "Loading %d transferred paths into T2DA Generator..." % paths.size())

	for path in paths:
		if not FileAccess.file_exists(path):
			printerr(log_prefix + "Transfer Load Error: File not found: %s" % path)
			failed_count += 1
			continue

		var image: Image = Image.load_from_file(path)
		if image != null and not image.is_empty():
			var texture: ImageTexture = ImageTexture.create_from_image(image)
			if is_instance_valid(texture):
				texture.resource_path = path # Store the path it was loaded from
				_t2da_input_textures.append(texture)
				loaded_count += 1
			else:
				printerr(log_prefix + "Transfer Load Error: Failed to create ImageTexture for: " + path.get_file())
				failed_count += 1
		else:
			printerr(log_prefix + "Transfer Load Error: Failed to load image data from: %s" % path.get_file())
			failed_count += 1

	# Update T2DA UI
	if is_instance_valid(input_files_count_label):
		input_files_count_label.text = "Images (%d)" % loaded_count
	_update_t2da_input_files_status() # Validate the newly loaded images

	if failed_count > 0:
		push_warning(log_prefix + "Transfer loading finished with %d failure(s)." % failed_count)
		_set_status_label(input_files_status_label, "Loaded %d images (%d failed)." % [loaded_count, failed_count], Color.YELLOW)
	elif loaded_count > 0:
		print(log_prefix + "Successfully loaded %d transferred images into T2DA Generator." % loaded_count)
		# Status set by _update_t2da_input_files_status
	else:
		print(log_prefix + "Transfer loading finished. No images were loaded.")
		_set_status_label(input_files_status_label, "Loaded 0 images from transfer.", Color.ORANGE)

#endregion

#region Utility Functions

## Sets the text and text color for a given Label node. Resets color if default color is used.
func _set_status_label(label: Label, text: String, color: Color = RESET_COLOR) -> void:
	if not is_instance_valid(label):
		printerr(log_prefix + "Error: Attempted to set status on an invalid Label node.")
		return

	label.text = text
	var color_override_name = "font_color" # Theme property name for font color

	if color == RESET_COLOR:
		# If reset color is requested, remove any existing color override
		if label.has_theme_color_override(color_override_name):
			label.remove_theme_color_override(color_override_name)
	else:
		# Apply the specified color override
		label.add_theme_color_override(color_override_name, color)

## Configures and displays the shared EditorFileDialog.
func _configure_file_dialog(mode: EditorFileDialog.FileMode, title: String, current_dir: String, current_file: String, filters: PackedStringArray, callback_func: Callable) -> void:
	if not is_instance_valid(file_selection_dialog):
		printerr(log_prefix + "Error: EditorFileDialog node is invalid or missing.")
		if is_instance_valid(editor_interface):
			editor_interface.get_base_control().show_warning("Plugin Error: File Dialog is not available.", "Error")
		return

	# Determine the signal name based on the file mode
	var signal_name: String = ""
	match mode:
		EditorFileDialog.FILE_MODE_OPEN_FILE: signal_name = "file_selected"
		EditorFileDialog.FILE_MODE_OPEN_FILES: signal_name = "files_selected"
		EditorFileDialog.FILE_MODE_OPEN_DIR: signal_name = "dir_selected"
		EditorFileDialog.FILE_MODE_SAVE_FILE: signal_name = "file_selected"
		_:
			printerr(log_prefix + "Error: Invalid file dialog mode specified: %d" % mode)
			return

	# Disconnect any previous connections for this *specific* signal from *this* object
	# to prevent multiple callbacks firing from previous configurations.
	for connection in file_selection_dialog.get_signal_connection_list(signal_name):
		var connected_callable: Callable = connection.get("callable")
		# Ensure callable is valid and bound to this object before disconnecting
		if connected_callable != null and connected_callable.is_valid() and connected_callable.get_object() == self:
			# FIX: disconnect() returns void, cannot check return value or assign it
			file_selection_dialog.disconnect(signal_name, connected_callable)
			# Cannot log error here based on return value, rely on engine errors if disconnect fails fundamentally

	# Configure the dialog
	file_selection_dialog.file_mode = mode
	file_selection_dialog.title = title
	# Ensure the starting directory exists, otherwise default to res://
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(current_dir)):
		file_selection_dialog.current_dir = current_dir
	else:
		printerr(log_prefix + "Warning: Provided start directory '%s' not found, defaulting to 'res://'." % current_dir)
		file_selection_dialog.current_dir = "res://"
	file_selection_dialog.current_file = current_file
	file_selection_dialog.clear_filters()
	for f in filters:
		file_selection_dialog.add_filter(f)
	file_selection_dialog.access = EditorFileDialog.ACCESS_RESOURCES # Ensure it uses virtual filesystem

	# Connect the appropriate signal to the callback function (one-shot)
	var connect_error: Error = file_selection_dialog.connect(signal_name, callback_func, CONNECT_ONE_SHOT)
	if connect_error != OK:
		printerr(log_prefix + "Error: Failed to connect file dialog signal '%s'. Code: %d (%s)" % [signal_name, connect_error, error_string(connect_error)])
		return

	# Show the dialog
	file_selection_dialog.popup_centered_ratio(0.75)


## Converts an Image.Format enum value to a human-readable string representation.
func _get_image_format_name(format_enum: int) -> String:
	# FIX: Reverted to explicit match statement for enum-to-string conversion
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
		# FORMAT_ETC removed in Godot 4
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


## Reads a specific setting from a resource's .import file using ConfigFile.
func _read_import_setting(resource_path: String, setting_key: String, default_value = null):
	var import_path: String = resource_path + ".import"
	if not FileAccess.file_exists(import_path):
		# print(log_prefix + "Import file not found: %s" % import_path)
		return default_value # Import file doesn't exist

	var config_file = ConfigFile.new()
	var err: Error = config_file.load(import_path)
	if err != OK:
		printerr(log_prefix + "Error loading import file '%s': %s." % [import_path.get_file(), error_string(err)])
		return default_value # Error loading file

	# Import settings are typically under the [params] section
	var value = config_file.get_value("params", setting_key, default_value)
	return value


## Applies standard editor icons to various buttons in the UI for consistency.
func _apply_button_icons() -> void:
	if not is_instance_valid(editor_interface):
		print(log_prefix + "Cannot apply icons: EditorInterface not available.")
		return
	var base_control: Control = editor_interface.get_base_control()
	if not is_instance_valid(base_control):
		print(log_prefix + "Cannot apply icons: Base editor control not available.")
		return

	print(log_prefix + "Applying standard editor icons to buttons...")
	# Map buttons to EditorIcon names
	var icon_map: Dictionary = {
		browse_input_files_button: "Load",
		browse_output_folder_button: "Folder",
		output_array_name_button: "Save",
		image_resize_browse_input_files_button: "Load",
		image_resize_browse_output_folder_button: "Folder",
		transfer_resizer_input_files_to_array_gen_button: "ArrowUp",
		transfer_resizer_output_images_to_array_gen_button: "ArrowUp",
		transfer_array_input_files_to_resizer_button: "ArrowDown",
		build_t2da_button: "Array",
		resize_images_button: "ImageTexture"
	}

	for button_node in icon_map:
		var icon_name: String = icon_map[button_node]
		if not is_instance_valid(button_node):
			print(log_prefix + "Warning: Node is invalid, cannot apply icon '%s'." % icon_name)
			continue

		var icon_texture: Texture2D = base_control.get_theme_icon(icon_name, "EditorIcons")
		if icon_texture != null:
			# Check if the node is actually a Button before setting icon
			if button_node is Button:
				(button_node as Button).icon = icon_texture
			else:
				printerr(log_prefix + "Error: Node assigned for icon '%s' is not a Button." % icon_name)
		else:
			printerr(log_prefix + "Error: Editor icon '%s' not found in theme." % icon_name)

	print(log_prefix + "Finished applying button icons.")


## Applies specific title styles (bold font, specific sizes) to title Labels using editor theme settings.
func _apply_title_label_styles() -> void:
	if not is_instance_valid(editor_interface):
		print(log_prefix + "Cannot apply styles: EditorInterface not available.")
		return
	var base_control: Control = editor_interface.get_base_control()
	if not is_instance_valid(base_control):
		print(log_prefix + "Cannot apply styles: Base editor control not available.")
		return

	print(log_prefix + "Applying custom styles to title labels...")
	# Get relevant theme fonts and sizes
	var bold_font: Font = base_control.get_theme_font("bold", "EditorFonts")
	var doc_title_font_size: int = base_control.get_theme_font_size("doc_title_size", "EditorFonts")
	var section_title_font_size: int = base_control.get_theme_font_size("title_size", "EditorFonts") # Usually smaller than doc title

	# Helper lambda to apply font and size overrides
	var apply_style = func(label_node: Label, font: Font, size: int):
		if not is_instance_valid(label_node): return
		if is_instance_valid(font):
			label_node.add_theme_font_override("font", font)
		if size > 0:
			label_node.add_theme_font_size_override("font_size", size)

	# Apply styles to specific labels
	apply_style.call(t2da_tools_doc_title_label, bold_font, doc_title_font_size) # Main plugin title
	apply_style.call(t2da_title_label, bold_font, section_title_font_size) # T2DA section title
	apply_style.call(resizer_title_label, bold_font, doc_title_font_size) # Resizer section title (using larger size for emphasis)
	apply_style.call(transfer_to_resizer_section_title_label, bold_font, section_title_font_size) # Transfer section title
	apply_style.call(transfer_to_generator_section_title_label, bold_font, section_title_font_size) # Transfer section title

	print(log_prefix + "Finished applying title styles.")

#endregion