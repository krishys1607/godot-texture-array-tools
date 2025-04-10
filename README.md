# Texture Array Tools Addon

<p align="left">
<!-- Badges cringelord area -->
  <img src="https://img.shields.io/badge/Godot-4.4%2B-478CBF?logo=godotengine" alt="Godot Version"/>
  <img src="https://img.shields.io/badge/Status-Beta-orange" alt="Status: Beta"/>
 <img src="https://img.shields.io/badge/Made%20in-VS%20Code-007ACC?logo=visualstudiocode" alt="Made in VS Code"/>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-blue" alt="License: MIT"/>
  </a>
</p>

<p align="left">
  <img src="https://github.com/user-attachments/assets/cdd64a19-899d-4a67-be65-f65cc6138267" alt="GIF of the T2DA Tools in Godot 4.4.1" width="400">
</p>

Your one-stop(?) shop for wrangling Texture2DArrays and batch-resizing images directly within the Godot editor.

Less alt-tabbing, more game dev... I hope. (or more time debugging this addon, who knows?)

---

## ⚠️ WARNING ⚠️

**!! PLEASE NOTE:** This addon is in **BETA**. Things might break, your PC might catch fire (unlikely, but hey), memory leaks probably.

* **DON'T:** Use this in production without extensive testing. Don't expect flawless stability.
* **DO:** Backup your project! Use version control (like Git)! Test on a separate branch first! You have been warned.

If cheesy, corny, unprofessional language triggers something primal deep within - then [INSTRUCTIONS.md](INSTRUCTIONS.md) is made for you. (Plus, it has more detailed information)

---

## Description

Ever wanted to make Texture Arrays without leaving the comfy confines of the Godot editor? Without writing scripts to generate them? Me too. This addon provides an in-editor UI for:

1. **Texture2DArray Generation:** Feed it a bunch of compatible images, and it'll spit out a `.tres` file ready to use. Basic file format enforcement.
2. **Image Resizing:** Need to resize a batch of images? Choose dimensions, pick your aspect ratio handling (Stretch, Pad, Crop), select interpolation filters, manage output naming (prefix/suffix/batch rename), choose output formats (PNG/JPG/WebP/Detect), control quality, add padding color, generate mipmaps (maybe!), create subfolders, and clear whitespace!
3. **File Transfer Buttons:** Easily YEET image lists between the Generator and Resizer sections.

---

## Features

Spent way too long on flooding it with possible features.

* **T2DA Generator:**
  * Select multiple input images.
  * Specify output path and filename.
  * **Ensure Format:** Force all input images to a chosen format (RGBA8, RGB8, etc.) before building. Bye-bye, format errors! (I will never need this in my life! Please, someone test these!)
  * **Subfolder Generation:** Automatically create a subfolder based on the array name.
  * **Overwrite Protection:** Choose to overwrite existing files or automatically append `*_1`, `*_2`, etc.

* **Image Resizer:**
For when you need to resize a batch of images, without having to manually resize them, leave the editor or use ImageMagick.
  * Select multiple input images.
  * Specify output path.
  * Choose target dimensions (use largest found or specify custom WxH).
  * **Aspect Ratio Modes:** Stretch, Keep Aspect (Pad), Keep Aspect (Crop).
  * **Interpolation Filters:** Nearest, Bilinear, Cubic, Lanczos.
  * **Padding Color:** Choose the color used when padding (only for Pad mode).
  * **Output Naming:** Add optional Prefix and/or Suffix to filenames.
  * **Output Format:** Save as PNG, JPG, WebP, or auto-detect from input.
  * **Quality Control:** Slider (0-100%) for JPG/WebP output quality.
  * **Use Mipmaps:** Option to generate mipmaps for resized images (defaults based on first input's `.import` setting, but you can override it).
  * **Subfolder Generation:** Automatically create a timestamped subfolder for resize batches.
  * **Whitespace Removal:** Option to strip spaces from original filenames (ignored if batch renaming).
  * **Batch Rename:** Option to rename all output files sequentially using a custom pattern (e.g., `myImage_suffix_001.png`).
* **Transfer Buttons:** Buttons to quickly move input file lists between the Generator and Resizer.

### Other Stuff

* **Editor Theming:** Uses a separate resource (`PluginSystemThemeUIApplier`) to (mostly) match your current editor theme. (AN ABSOLUTELY CONVOLUTED WIP)
* **Tooltips:** Hover over UI elements for hopefully helpful explanations!

---

## Installation (The Ritual)

1. **Get the Goods:** Clone this repository or download the latest release ZIP.
2. **Unzip (if needed):** If you downloaded a ZIP, extract it. You should find an `addons` folder inside.
3. **Copy/Paste:** Copy the `texture_array_tools` folder (the one *inside* the `addons` folder you downloaded/cloned) into your *project's* `addons` folder. Create an `addons` folder in your project root if it doesn't exist. (Your project structure should look like `res://addons/texture_array_tools/...`)
4. **Enable in Godot:**
    * Open your Godot project.
    * Go to `Project -> Project Settings`.
    * Navigate to the `Plugins` tab.
    * Find "Texture Array Tools" in the list.
    * Check the **Enable** box on the right.
5. **Witness the Magic (or Errors):** A new dock panel titled "Texture Array Tools" should appear, likely docked in the **upper left** area by default (alongside Scene, Import etc.). You can drag this tab to other dock areas if you prefer! If you see errors in the Output panel instead... well, good luck.

---

## How to Use (sparknotes version)

After enabling the plugin, find the "Texture Array Tools" dock panel.

Both the T2DA Generator and Image Resizer are all crammed into the same dockable tab, for better or for worse.

<p align="left">
  <table>
      <tr>
        <td><img src="https://github.com/user-attachments/assets/3acc626b-aebc-4f52-bf42-461454715935" alt="T2DA Generator UI" width="400"></td>
        <td><img src="https://github.com/user-attachments/assets/fd7be7ad-5c10-436c-8bbc-78aa8f31b5b6" alt="Image Resizer UI" width="400"></td>
      </tr>
  </table>
</p>

### 📜 Texture2DArray Generator

1. **Input Images:** Click `Browse...` (Load icon) to select two or more images.
    * **IMPORTANT:** By default, all selected images *must* have the same dimensions and pixel format (e.g., all RGBA8, all RGB8).
    * **TIP:** Use the **`Ensure Format?`** checkbox and dropdown below to force all images into a compatible format (like RGBA8) *before* building. This is highly recommended if something is amiss!
2. **Output File:** Click `Browse...` (Folder icon) or type the path to the output folder (`res://...`).
3. **Array Name:** Click `Browse...` (Save icon) or type the desired base filename for your `.tres` file.
4. **Options:**
    * `Ensure Format?`: Check this and select a target format (e.g., RGBA8) to avoid format mismatch errors.
    * `Generate Subfolder?`: Creates `res://YourOutputPath/YourArrayName/YourArrayName.tres`.
    * `Overwrite Existing?`: If unchecked, prevents overwriting by adding `_1`, `_2`, etc. to the filename if it already exists.
5. **Build:** Check the status label. If it looks good (green "OK" message), hit `Generate Array` (Array icon)!

### ✂️ Image Resizer 😮‍💨

1. **Input Images:** Click `Browse...` (Load icon) to select images you want to resize.
2. **Output Path:** Click `Browse...` (Folder icon) or type the path where resized images will be saved.
3. **Target Size:**
    * Check `Use Largest Size` to automatically resize all images to the largest dimensions found in the input set.
    * Uncheck it and enter your desired `Width` and `Height` manually.
4. **Resize Mode:** Choose how to handle aspect ratios:
    * `Stretch`: Ignores aspect ratio, fits exactly to target dimensions.
    * `Keep Aspect (Pad)`: Fits image within target dimensions, keeps aspect ratio, fills empty space with the **Padding Color**. (Color picker enabled only in this mode).
    * `Keep Aspect (Crop)`: Scales image to *cover* target dimensions, keeps aspect ratio, crops off edges that extend beyond the target.
5. **Resize Filter:** Select the image scaling quality (Nearest = pixelated, Lanczos = sharpest).
6. **Output Naming:**
    * `Prefix`/`Suffix`: Add optional text before/after the base filename.
    * `Remove Whitespace?`: If NOT batch renaming, removes spaces from original filenames.
    * `Batch Rename?`: Check this and provide a `Batch Pattern` (e.g., `terrain`) to rename all outputs like `Prefix_Pattern_Suffix_001.ext`. Ignores original filenames and whitespace removal if checked. (over-stretching it by calling it a 'batch pattern' lmao.)
7. **Output Format:** Choose `PNG`, `JPG`, `WebP`, or `Detect from Input`.
    * If JPG or WebP (or Detect finds one), the **Quality** slider (and percentage label) will appear. 0=Awful, 100=Best.
8. **Use Mipmaps?:** Check to generate mipmaps for the resized images. The initial state is guessed from the first input image's `.import` file, but you can override it.
9. **Create Subfolder?:** Check to save this batch into a unique timestamped subfolder inside the main Resizer output path.
10. **Resize:** Check the status label. When ready, hit `Resize Images` (ImageTexture icon)!

### 🔄 Transfer Area

* **Gen -> Resizer:** Sends the paths currently loaded in the T2DA Generator *to* the Image Resizer's input list. Useful if T2DA validation fails due to size/format.
* **Resizer Input -> Gen:** Sends the paths currently loaded in the Image Resizer's input list *to* the T2DA Generator.
* **Resizer Output -> Gen:** Transfers the list of image paths that were successfully created during the last resize operation to the T2DA Generator. (Uses the stored list, doesn't re-scan the directory).
* **Auto Transfer:** If checked, automatically performs the 'Resizer Output -> Gen' transfer (transferring the paths from the last successful resize) after the resize operation completes!

### ✨ Tooltips & Further Information

Hover over *most* buttons, checkboxes, and input fields for a quick explanation!

I've kept them as annoying as humanly possible.

Please see [INSTRUCTIONS.md](INSTRUCTIONS.md) for more detailed instructions and usage examples, as well as any bugs or unusual behaviors that have been reported thus far.

---

## Feedback / Contributing

Found a bug? Got a suggestion? Did it actually *not* crash?

* Please open an issue on the GitHub repository for bugs or feature requests.
* Pull requests are welcome if you want to fix something or add features (but maybe open an issue first to discuss).

---

## Credits

This addon draws heavy inspiration from these Unity scripts:

* [XJINEUnity_Texture2DArrayGenerator](https://github.com/XJINE/Unity_Texture2DArrayGenerator)
* [vr-voyage/TextureArrayGenerator.cs](https://gist.github.com/vr-voyage/faf7d655285655020dd8343ad7847c25)
* [MephestoKhaan/TextureArrayCreator.cs](https://gist.github.com/MephestoKhaan/8953d2f38195c9c15ced7ff4e9c632ef)

---

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
