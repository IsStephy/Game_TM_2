from PIL import Image
import os

def merge_images(folder_path, output_path, images_per_row=20):
    # Get all image files in the folder
    image_files = [f for f in os.listdir(folder_path) if f.lower().endswith(('png', 'jpg', 'jpeg', 'bmp', 'gif'))]
    image_files.sort()  # Ensure consistent order
    
    if not image_files:
        print("No images found in the folder.")
        return
    
    # Open all images
    images = [Image.open(os.path.join(folder_path, img)).convert("RGBA") for img in image_files]
    
    # Determine grid size
    num_images = len(images)
    rows = (num_images + images_per_row - 1) // images_per_row  # Ceiling division
    max_width = max(img.width for img in images)
    max_height = max(img.height for img in images)
    
    merged_width = images_per_row * max_width
    merged_height = rows * max_height
    merged_image = Image.new('RGBA', (merged_width, merged_height), (0, 0, 0, 0))  # Transparent background
    
    # Paste images in grid
    x_offset, y_offset = 0, 0
    for idx, img in enumerate(images):
        merged_image.paste(img, (x_offset, y_offset), img)
        x_offset += max_width
        if (idx + 1) % images_per_row == 0:
            x_offset = 0
            y_offset += max_height
    
    # Save the merged image
    merged_image.save(output_path, format="PNG")  # Ensure PNG format to keep transparency
    print(f"Merged image saved as {output_path}")

# Example usage
merge_images('C:\\Users\\User\\Desktop\\Tiles\\tile_parts\\Final', 'merged_output.png')
