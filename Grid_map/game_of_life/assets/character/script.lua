local sprite = app.activeSprite
if not sprite then
  app.alert("No active sprite!")
  return
end

local scaleFactor = 2  -- Scale by 2x
local imageWidth = sprite.width * scaleFactor
local imageHeight = sprite.height * scaleFactor
local layers = sprite.layers

-- Create a new blank image with double the size
local tilemap = Image(imageWidth * #layers, imageHeight, sprite.colorMode)

for i, layer in ipairs(layers) do
  local cel = layer:cel(1)
  if cel then
    local tempImage = cel.image:clone()  -- Clone the image to avoid modifying original
    tempImage:resize(tempImage.width * scaleFactor, tempImage.height * scaleFactor) -- Scale it

    local xOffset = (i - 1) * imageWidth  -- Move each layer horizontally
    tilemap:drawImage(tempImage, xOffset + cel.position.x * scaleFactor, cel.position.y * scaleFactor)
  end
end

local filePath = "D:/tilemap2.png"
tilemap:saveAs(filePath)
app.alert("Tilemap saved at: " .. filePath)
