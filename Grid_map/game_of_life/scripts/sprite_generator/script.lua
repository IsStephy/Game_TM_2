local sprite = app.activeSprite
if not sprite then
  app.alert("No active sprite!")
  return
end

local tileSize = sprite.width  -- Assuming tiles are the full width of the canvas
local layers = sprite.layers
local columns = math.ceil(math.sqrt(#layers)) -- Arrange tiles in a square grid

-- Create a new image for the tilemap
local tilemapWidth = columns * tileSize
local tilemapHeight = math.ceil(#layers / columns) * tileSize
local tilemap = Image(tilemapWidth, tilemapHeight, sprite.colorMode)

for i, layer in ipairs(layers) do
  -- Hide all layers first
  for _, l in ipairs(layers) do
    l.isVisible = false
  end

  -- Show only the current layer
  layer.isVisible = true
  app.refresh()  -- Ensure changes take effect

  -- Get the active cel (the actual image data)
  local cel = layer:cel(1)
  if cel then
    local tempImage = cel.image  -- Extract cel's image
    local row = math.floor((i - 1) / columns)
    local col = (i - 1) % columns
    tilemap:drawImage(tempImage, col * tileSize, row * tileSize, cel.position)
  end

  -- Restore original state
  layer.isVisible = false
end

-- Re-enable all layers
for _, l in ipairs(layers) do
  l.isVisible = true
end
local filePath = "D:/tilemap2.png"
tilemap:saveAs(filePath)
app.alert("Tilemap saved at: " .. filePath)
