from itertools import product
import os
from PIL import Image

def is_valid_combination(combo):
    """Check if a combination is valid based on the given rules."""
    starts = [part[:2] for part in combo]  # Extract start names (e.g., "GR", "MN")
    
    # Ensure there are exactly 2 unique start names (not more)
    if len(set(starts)) > 2:
        return False
    
    # Ensure it does NOT alternate (MN, GR, MN, GR, MN, GR is not allowed)
    for i in range(2, len(starts)):
        if starts[i] == starts[i-2] and starts[i] != starts[i-1]:
            return False

    return True

def generate_valid_combinations(parts_folder, output_folder):
    """Generate valid combinations and save them as layered images."""
    # Get all image file names from the folder
    parts = [f for f in os.listdir(parts_folder) if f.endswith(".png")]
    
    # Assign unique numbers to each prefix
    unique_prefixes = sorted(set(part[:2] for part in parts))
    prefix_map = {prefix: i+1 for i, prefix in enumerate(unique_prefixes)}  # e.g., {'MN': 1, 'GR': 2, 'SN': 3}
    
    # Group parts by numbers (1,2,3,4,5,6)
    grouped_parts = {n: [] for n in range(1, 7)}
    for part in parts:
        num = int(part[2])  # Extract number (e.g., "GR1" -> 1)
        grouped_parts[num].append(part)
    
    # Generate all valid combinations by picking exactly one image per number (1-6)
    all_combos = product(grouped_parts[1], grouped_parts[2], grouped_parts[3],
                         grouped_parts[4], grouped_parts[5], grouped_parts[6])

    valid_combos = [combo for combo in all_combos if is_valid_combination(combo)]
    
    # Ensure output folder exists
    os.makedirs(output_folder, exist_ok=True)
    
    # Save each valid combination as a layered image
    for i, combo in enumerate(valid_combos):
        images = [Image.open(os.path.join(parts_folder, part)) for part in combo]
        
        # Assume all images are the same size
        width, height = images[0].size
        
        # Create a new blank image with the same width and height
        combined_image = Image.new("RGBA", (width, height), (255, 255, 255, 0))
        
        # Layer images on top of each other (each one in a separate layer)
        for img in images:
            combined_image.paste(img, (0, 0), img if img.mode == "RGBA" else None)
        
        # Generate filename based on the assigned numbers
        file_name_parts = [str(prefix_map[part[:2]]) for part in combo]  # Convert types to numbers
        file_name = "_".join(file_name_parts) + ".png"
        
        # Save the combined image
        combined_image.save(os.path.join(output_folder, file_name))
    
    return valid_combos

# Example usage
parts_folder = "C:\\Users\\User\\Desktop\\Tiles\\tile_parts\\Initial"  # Change this to the actual path
output_folder = "C:\\Users\\User\\Desktop\\Tiles\\tile_parts\\Final"  # Change this to the desired output folder
valid_combinations = generate_valid_combinations(parts_folder, output_folder)
