Texture Array Tools Addon - Instructions

Version: 0.1.0 (Beta)

----------------------------------------

CONTENTS
----------------------------------------

1. Introduction
2. Example Files
3. Installation
4. Using the Texture2DArray Generator
5. Using the Image Resizer
6. Using the Transfer Area
7. Important Considerations & Potential Issues
8. Common Use Cases
9. Troubleshooting & Feedback

----------------------------------------

1. INTRODUCTION

----------------------------------------
This document provides detailed instructions for using the Texture Array Tools addon for Godot Engine 4.x (tested with 4.4.1).

The addon offers two primary functionalities within the Godot editor:

- Texture2DArray Generator: Creates Texture2DArray resource files (`.tres`) from a list of source images.
- Image Resizer: Performs batch resizing of images with various options for aspect ratio handling, filtering, naming, and formatting.

Please note this addon is currently in a BETA stage. While functional, stability is not guaranteed, and unexpected behavior or performance issues may occur, especially with very large datasets. Use with caution and backup your project.

----------------------------------------

2. EXAMPLE FILES

----------------------------------------
An `examples` folder is included at the root of the project directory where this addon is installed. It contains subfolders:

- `odd_sized_images`: A set of images with varying dimensions and alphas, useful for testing the Image Resizer or the Generator's "Ensure Format" feature.
- `even_sized_images`: A set of images with identical dimensions. One has an alpha channel, hopefully suitable for direct use with the Texture2DArray Generator.

Feel free to use these images for initial testing and familiarization with the addon's capabilities.

----------------------------------------

3. INSTALLATION

----------------------------------------

1. Obtain the addon files (e.g., download ZIP from release, clone repository).
2. If downloaded as a ZIP, extract it. Locate the `texture_array_tools` folder within the extracted `addons` directory.
3. Copy the `texture_array_tools` folder into your Godot project's `addons` folder. If your project doesn't have an `addons` folder at its root (`res://addons/`), create it first.
    The final structure should be: `res://addons/texture_array_tools/[addon files]`
4. Open your Godot project.
5. Navigate to `Project -> Project Settings`.
6. Go to the `Plugins` tab.
7. Find "Texture Array Tools" in the list.
8. Check the "Enable" box on the right side.
9. If successful, a new dock panel titled "Texture Array Tools" will appear in the editor UI, typically defaulting to the bottom-left dock area (alongside FileSystem, Scene, etc.). You can drag the panel's tab to other dock locations if desired.

----------------------------------------

4. USING THE TEXTURE2DARRAY GENERATOR

----------------------------------------
This section creates Texture2DArray resource files (`.tres`).

1. **Input Images:**
    - Click the `Browse...` button (Load icon) next to "Input Images".
    - Select two or more source image files (`.png`, `.jpg`, etc.) using the file dialog.
    - **Requirement:** By default, all selected images MUST have the exact same dimensions (width & height) and pixel format (e.g., all RGBA8, all L8). Validation checks will report errors if they differ.
    - The label next to the button shows the number of currently loaded images.

2. **Output Path:**
    - Enter the desired output folder path (e.g., `res://my_arrays`) into the `Output Path` LineEdit.
    - Alternatively, click the `Browse...` button (Folder icon) to select the output folder using the file dialog.

3. **Array Name:**
    - Enter the base filename for the output `.tres` file (e.g., `terrain_layers`) into the `Array Name` LineEdit. The `.tres` extension is added automatically.
    - Alternatively, click the `Browse...` button (Save icon) next to the LineEdit to select a save location and filename simultaneously using the file dialog (this will also update the Output Path).

4. **Options:**
    - **`Ensure Format?` (Checkbox):** If checked, enables the format dropdown. Before building, the addon will attempt to convert all loaded input images to the selected `Target Format`. This is useful for resolving format mismatch errors. **Recommended:** Check this if your source images might have different formats.
    - **`Target Format` (OptionButton):** (Enabled only if `Ensure Format?` is checked). Select the desired output `Image.Format` for all images in the array (e.g., `RGBA8`, `RGB8`, `LA8`). Defaults to `RGBA8`.
    - **`Generate Subfolder from Array Name?` (Checkbox):** If checked, a subfolder named after the `Array Name` (with spaces replaced by underscores) will be created inside the specified `Output Path`. The `.tres` file will be saved within this subfolder. Example: If path is `res://out` and name is `Cool Array`, output will be `res://out/Cool_Array/Cool Array.tres`.
    - **`Overwrite Existing Array?` (Checkbox):**
        - If checked: Saves the `.tres` file with the exact specified name, overwriting any existing file at that path.
        - If unchecked (Default): Checks if a file with the target name already exists. If it does, it automatically appends `_1`, `_2`, etc., to the filename until an unused name is found (e.g., `MyArray.tres` becomes `MyArray_1.tres`).

5. **Status & Build:**
    - The `Status:` label provides feedback on the loaded images (number, dimensions, format) and reports validation errors (size/format mismatch) or success. Aim for a green "OK" message.
    - The `Ready?` label gives a simple Yes/No indication based on validation.
    - Once the status is OK, click the `Generate Array` button (Array icon) to create and save the `.tres` resource file. The process may take a moment for large images or many layers. Check the Godot Output panel for detailed logs or errors during the build.

----------------------------------------

5. USING THE IMAGE RESIZER

----------------------------------------
This section allows batch resizing and reformatting of images.

1. **Input Images:**
    - Click the `Browse...` button (Load icon) to select source image files.
    - The label shows the number of selected files.

2. **Output Path:**
    - Enter or `Browse...` (Folder icon) for the base directory where resized images will be saved. Note the `Create Timestamped Subfolder?` option below.

3. **Target Size:**
    - **`Use Largest Size` (Checkbox):**
        - Checked (Default): Automatically determines the largest width and height among all selected input images. All images will be resized targeting these maximum dimensions. The detected size is displayed (e.g., "1024x1024").
        - Unchecked: Allows manual input. The `Width` and `Height` LineEdits become editable.
    - **`Width` / `Height` (LineEdits):** Enter the desired numeric output width and height in pixels when `Use Largest Size` is unchecked.

4. **Resize Mode (Aspect Ratio):** (OptionButton)
    - `Stretch`: Ignores the original aspect ratio and forces the image into the exact target dimensions. May cause distortion.
    - `Keep Aspect (Pad)`: Resizes the image to fit *within* the target dimensions while maintaining its original aspect ratio. Any empty space created is filled with the color selected in the `Padding Color` picker.
    - `Keep Aspect (Crop)`: Resizes the image to *cover* the target dimensions while maintaining its original aspect ratio. Any parts of the image extending beyond the target dimensions are cropped away from the center.

5. **Resize Filter (Interpolation):** (OptionButton)
    - Selects the algorithm used for scaling pixels: `Nearest` (pixelated, fast), `Bilinear` (smooth), `Cubic` (smoother), `Lanczos` (sharpest, potentially slower).

6. **Output Naming:**
    - **`Prefix` (LineEdit):** Optional text added *before* the base filename (e.g., `resized_`).
    - **`Suffix` (LineEdit):** Optional text added *after* the base filename but *before* any batch rename counter or the file extension (e.g., `_normal`).
    - **`Remove Whitespace?` (Checkbox):** If checked AND *Batch Rename is DISABLED*, spaces in the *original* filename will be removed. Example: `my file name.png` -> `myfile_suffix.png`.
    - **`Batch Rename?` (Checkbox):** If checked, ignores original filenames entirely. Enables the `Batch Pattern` LineEdit below.
    - **`Batch Pattern` (LineEdit):** (Enabled only if `Batch Rename?` is checked). Enter the base name for all output files (e.g., `terrain_tile`). The final name structure will be `Prefix` + `Pattern` + `Suffix` + `_Counter` + `.Extension` (e.g., `pre_terrain_tile_suf_001.png`). The counter (`_001`, `_002`, etc.) is always added when batch renaming.

7. **Output Format:** (OptionButton)
    - `Detect from Input`: Attempts to save the output image using the same format as its corresponding input file (defaults to PNG if detection fails).
    - `PNG`: Saves as PNG (lossless, supports transparency).
    - `JPG`: Saves as JPG (lossy, no transparency, good for photos). The `Quality` slider affects compression.
    - `WebP`: Saves as WebP (can be lossy or lossless, supports transparency). The `Quality` slider affects compression (heuristic determines lossy/lossless based on 100% value).

8. **Quality:** (Slider and Label)
    - This slider and percentage label (`0%` to `100%`) **only appear and are active** if the selected `Output Format` is `JPG`, `WebP`, or `Detect from Input` (and the detected input format is JPG or WebP).
    - Controls the compression quality for lossy formats. Higher values mean better quality but larger file sizes. Defaults to 90.

9. **Padding Color:** (ColorPickerButton)
    - This button is **only enabled** if the `Resize Mode` is set to `Keep Aspect (Pad)`.
    - Click it to select the color used to fill the empty border areas when padding. Defaults to transparent black.

10. **Use Mipmaps?:** (Checkbox)
    - If checked, attempts to generate mipmap levels for the resized output images before saving. This can improve texture performance at a distance but increases file size.
    - **Default State:** When input images are selected, the checkbox's *initial* state is determined by reading the `mipmaps` setting from the `.import` file of the *first* selected image (if the `.import` file exists and is readable).
    - **User Override:** You can always manually check or uncheck the box to override the detected default for the current resize operation.

11. **Create Timestamped Subfolder?:** (Checkbox)
    - If checked, all images processed in the current batch will be saved into a new subfolder within the main `Output Path`. The subfolder name is generated using the current Unix timestamp (e.g., `resized_1678886400`) to ensure uniqueness for each batch run.

12. **Status & Resize:**
    - The `Status:` label provides feedback on readiness and the outcome of the resize operation.
    - The `Ready?` label gives a simple Yes/No indication.
    - Once input images are selected and settings configured, click the `Resize Images` button (ImageTexture icon). Check the Godot Output panel for detailed logs.

----------------------------------------

6. USING THE TRANSFER AREA

----------------------------------------
These buttons facilitate moving file lists between the Generator and Resizer sections:

- **`Gen -> Resizer` (ArrowDown icon):** Copies the list of image paths currently loaded in the T2DA Generator section *into* the Image Resizer's input list. Useful if T2DA validation failed and you need to resize/reformat the images first.
- **`Resizer Input -> Gen` (ArrowUp icon):** Copies the list of image paths currently selected as input for the Image Resizer *into* the T2DA Generator's input list.
- **`Resizer Output -> Gen` (ArrowUp icon):** Scans the directory specified in the Image Resizer's `Output Path` for image files and loads their paths *into* the T2DA Generator's input list. Useful after a resize operation if Auto Transfer was off.
- **`Auto Transfer Resized -> T2DA Gen?` (Checkbox):** If checked, automatically performs the "Resizer Output -> Gen" action *after* the Image Resizer finishes processing a batch successfully.

----------------------------------------

7. IMPORTANT CONSIDERATIONS & POTENTIAL ISSUES

----------------------------------------

- **Memory Usage:**
  - This addon operates primarily by loading full, uncompressed image data into RAM using `Image.load_from_file()`. This **bypasses** Godot's optimized import system and VRAM compression.
  - Loading or processing a large number of very high-resolution images simultaneously can consume significant RAM and may lead to performance degradation or instability in the editor, especially during:
    - Loading many files into either section.
    - The T2DA format conversion step (`_convert_t2da_input_images_to_target_format`).
    - The Image Resizer batch processing (`_process_resize_batch`), which may create temporary image copies for padding/cropping.
    - The final T2DA build step (`create_from_images`).
  - **Mitigation:** Process large batches of images in smaller chunks if you experience slowdowns. Be mindful of the source image dimensions and file counts. Consider closing and reopening the Godot editor occasionally if it becomes sluggish after heavy use.

- **.import File Interaction:**
  - The addon primarily works with the *original* source image files (`.png`, `.jpg`, etc.).
  - It **does not** read most settings from existing `.import` files, except for attempting to detect the default `mipmaps` setting for the Resizer's "Use Mipmaps?" checkbox based on the *first* input image.
  - Resized images saved by the addon will trigger Godot to create *new* `.import` files for them when the editor regains focus or rescans the filesystem. You may need to adjust the import settings for these newly generated resized images afterward if needed (e.g., setting Texture type, VRAM compression).

- **File Overwriting / Naming:**
  - Pay close attention to the `Overwrite Existing Array?` checkbox for the T2DA generator. If unchecked, files will be suffixed (`_1`, `_2`, etc.) to avoid data loss.
  - The Resizer's output naming (Prefix, Suffix, Batch Rename, Whitespace Removal) provides flexibility but can lead to unexpected names if options are combined without care. Test with a small batch first. Using subfolders (timestamped or named) is highly recommended to avoid accidental overwrites or cluttered directories.

- **Error Handling:** The addon attempts to report errors via status labels and the Godot Output panel. If an operation fails, check the output panel for more detailed error messages (e.g., file not found, permission errors, format conversion failures).

----------------------------------------

8. COMMON USE CASES

----------------------------------------

- **Texture2DArray Generator:**
  - Creating splatmaps for terrain shaders (albedo, normal, roughness layers).
  - Combining tile variations or sprite sheet frames into a single texture for efficient rendering.
  - Packing different material properties (e.g., masks, heightmaps) into array layers.
  - **Tip:** Use "Ensure Format" to easily combine source images saved with different pixel formats (e.g., mixing RGB and RGBA images by converting them all to RGBA8).

- **Image Resizer:**
  - Batch resizing a collection of downloaded assets to fit project requirements (e.g., power-of-two dimensions).
  - Creating lower-resolution versions of textures for LODs or different quality settings.
  - Resizing UI elements to specific pixel dimensions.
  - Using "Keep Aspect (Pad)" to fit various icons onto square backgrounds without distortion.
  - Using "Keep Aspect (Crop)" to create consistently framed character portraits from larger images.
  - Quickly converting a batch of images between PNG, JPG, and WebP formats.

- **Combined Workflow:**
    1. Select a set of differently sized/formatted images using the Image Resizer's input browser.
    2. Configure the Resizer to output the desired final dimensions, format (e.g., PNG), and enable "Use Mipmaps?".
    3. Enable the "Auto Transfer Resized -> T2DA Gen?" checkbox.
    4. Run the Resizer.
    5. Switch focus to the T2DA Generator; the successfully resized images should now be loaded.
    6. Configure the T2DA output name/path.
    7. Build the Texture2DArray.

----------------------------------------

9. TROUBLESHOOTING & FEEDBACK

----------------------------------------

- **Check Output Panel:** Always monitor the Godot 'Output' panel (bottom of the editor) for detailed log messages and error reports from the addon.
- **Restart Godot:** If the UI behaves strangely or seems stuck, try closing and reopening the Godot editor.
- **Plugin Enable:** Ensure the plugin is still enabled under `Project -> Project Settings -> Plugins`.
- **Dependencies:** This addon primarily relies on core Godot `Image` and `Texture2DArray` functionalities. No external libraries are required.
- **Feedback:** If you encounter bugs, have suggestions, or experience crashes, please open an issue on the addon's GitHub repository (if available). Provide steps to reproduce the problem and check the Output panel for relevant error messages.
