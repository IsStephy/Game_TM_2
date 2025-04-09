import os
from PIL import Image
from itertools import product

def is_valid_combination(combo):
    starts = [part[:2] for part in combo]
    if len(set(starts)) > 2:
        return False
    for i in range(2, len(starts)):
        if starts[i] == starts[i - 2] and starts[i] != starts[i - 1]:
            return False
    return True

def generate_biome_sorted_tiles(parts_folder, output_folder):
    os.makedirs(output_folder, exist_ok=True)

    parts = [f for f in os.listdir(parts_folder) if f.endswith(".png")]
    parts.sort()

    # Group by part number (1-6) and biome prefix (GR, SN, etc.)
    grouped_parts = {n: [] for n in range(1, 7)}
    for part in parts:
        try:
            part_num = int(part[2])  # E.g., GR1.png → 1
            grouped_parts[part_num].append(part)
        except:
            continue

    # All biome prefixes available
    all_biomes = sorted(set(p[:2] for p in parts))

    # Create all valid 6-part combinations
    all_combos = product(
        grouped_parts[1],
        grouped_parts[2],
        grouped_parts[3],
        grouped_parts[4],
        grouped_parts[5],
        grouped_parts[6]
    )

    # Filter only valid ones
    valid_combos = [combo for combo in all_combos if is_valid_combination(combo)]

    # Sort combinations into biome buckets
    biome_to_combos = {biome: [] for biome in all_biomes}
    for combo in valid_combos:
        involved_biomes = set(p[:2] for p in combo)
        for biome in involved_biomes:
            biome_to_combos[biome].append(combo)

    file_index = 0
    prefix_map = {prefix: i+1 for i, prefix in enumerate(all_biomes)}  # For filename numbering

    for biome in all_biomes:
        combos = biome_to_combos[biome]
        for combo in combos:
            images = [Image.open(os.path.join(parts_folder, part)) for part in combo]
            width, height = images[0].size
            combined = Image.new("RGBA", (width, height), (255, 255, 255, 0))
            for img in images:
                combined.paste(img, (0, 0), img if img.mode == "RGBA" else None)

            # Filename: 0000_GR_1_2_1_2_1_1.png (includes index + biome + part IDs)
            biome_codes = "_".join(str(prefix_map[p[:2]]) for p in combo)
            filename = f"{file_index:04d}_{biome}_{biome_codes}.png"
            combined.save(os.path.join(output_folder, filename))
            file_index += 1

    return file_index

# Example usage
parts_folder = "D:\lectures\TM\Game_TM_2\\tile_parts\Initial"
output_folder = "D:\lectures\TM\Game_TM_2\\tile_parts\Final"
generated_count = generate_biome_sorted_tiles(parts_folder, output_folder)
print(f"Generated {generated_count} full tile combinations, sorted by biome.")
