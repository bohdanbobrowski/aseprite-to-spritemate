----------------------------------------------------------------------
--
-- Aseprite script for export c64 sprite to spritemate json format
-- Autor: Bohdan Bobrowski
-- Url: https://github.com/bohdanbobrowski/aseprite-to-spritemate
--
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Funcions
----------------------------------------------------------------------

local function script_path()
  local str = debug.getinfo(2, "S").source:sub(2)
  return str:match("(.*[/\\])")
end

local function get_file_name(file)
  return file:match("[^/]*.aseprite$")
end

local function get_used_color(tab, val)
  for index, value in ipairs(tab) do
      if value == val then
          return index-1
      end
  end  
  return false
end

----------------------------------------------------------------------
-- START
----------------------------------------------------------------------

local spr = app.activeSprite
if not spr then
  app.alert("There is no sprite to export")
  return
end

if (spr.width~=12 and spr.width~=24) or spr.height~=21  then
  app.alert("Sprite should be 12*21px for multicolor or 24*21px for hi-res!")
  return false
end

if spr.colorMode~= ColorMode.INDEXED then
  app.alert("The sprite should use indexed color mode!")
  return false
end

local spritename = string.gsub(get_file_name(spr.filename), ".aseprite", "")
local newfilename = string.gsub(spr.filename, ".aseprite", "")

-- Build export dialog
local d =
  Dialog("Export to SpriteMate json format")
  :entry {id = "fname", label = "Save as:", text = newfilename, focus = true}
  :button {id = "ok", text = "&OK", focus = true}
  :button {text = "&Cancel"}:show()

local data = d.data
if not data.ok then
  return
end

-- Turn off debug layers before grabbing the current image
for _, layer in ipairs(spr.layers) do
  if layer.name == "Errormap" or layer.name == "Oppmap" then
    layer.isVisible=false
  end
end
app.refresh()

-- Get image from the active frame of the active sprite
local img = Image(spr.spec)
local bitmap = {}
local colors = {}
local json_output = {}

-- List of used colors -- transparency color goes first
local used_colors = {}
table.insert(used_colors, spr.transparentColor)
-- Prepare output json
local json = ""
json = json .. '{"version":1.3'
-- #USED_COLORS# will be replaced later
json = json .. ',"colors":{#USED_COLORS#}'
json = json .. ',"sprites":['
for i=1,#spr.frames do
  img:drawSprite(spr, i)
  if i>1 then
    json = json .. ','
  end
  -- #INDIVIDUAL_COLOR# will be replaced later
  json = json .. '{"name":"' .. spritename .. "_" .. i .. '","color":#INDIVIDUAL_COLOR#,"multicolor":true,"double_x":false,"double_y":false,"overlay":false,"pixels":['
  for h=0, (spr.height-1) do
    if h>0 then
      json = json .. ','
    end
    json = json .. '['
    for w=0, (spr.width-1) do
        if w>0 then
          json = json .. ','
        end
        local realPixelValue = img:getPixel(w,h)
        local pixelValue = 0
        if get_used_color(used_colors, realPixelValue) == false then
          table.insert(used_colors, realPixelValue)
        end
        local pixelValue = get_used_color(used_colors, realPixelValue)
        json = json .. tostring(pixelValue)
        -- Duplicate pixel for multicolor sprites
        if spr.width==12 then          
          json = json .. "," .. tostring(pixelValue)
        end
    end
    json = json .. ']'
  end
  json = json .. ']}'
end
json = json .. '],"current_sprite":0,"pen":1}'

-- Writing colors based on used colors list
local colors_json = ""
for index, value in ipairs(used_colors) do
  if index>1 then
    colors_json = colors_json .. ','
  end
  colors_json = colors_json .. '"' .. (index-1) .. '":' .. value
end
json = string.gsub(json, "#INDIVIDUAL_COLOR#", used_colors[2])
json = string.gsub(json, "#USED_COLORS#", colors_json)

-- Output json filename with Sprite Mate *.spm extension
local out = io.open(data.fname .. ".spm", "w")
out:write(json)
out:close()