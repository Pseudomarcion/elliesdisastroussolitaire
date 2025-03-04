-- main.lua
local Constants = require('constants')
local Game = require('game')

-- Store window dimensions for consistency
local windowConfig = {
    width = Constants.LAYOUT.WINDOW_WIDTH,
    height = Constants.LAYOUT.WINDOW_HEIGHT
}

local function initializeWindow()
    local success, err = pcall(function()
        love.window.setMode(windowConfig.width, windowConfig.height, {
            resizable = false,
            vsync = true,
            minwidth = windowConfig.width,
            minheight = windowConfig.height
        })
        
        love.window.setTitle("Ellie's Klondike Solitaire v0.05")
    end)
    
    if not success then
        Constants.Utils.debug("ERROR: Failed to initialize window: " .. tostring(err))
        return false
    end
    return true
end

local function initializeGame()
    local success, err = pcall(function()
        Game:initialize()
    end)
    
    if not success then
        Constants.Utils.debug("ERROR: Failed to initialize game: " .. tostring(err))
        return false
    end
    return true
end

function love.load()
    -- Set random seed based on current time
    love.math.setRandomSeed(os.time())
    
    -- Initialize systems
    if not initializeWindow() then
        error("Failed to initialize window system")
    end
    
    if not initializeGame() then
        error("Failed to initialize game system")
    end
    
    Constants.Utils.debug("Game loaded successfully")
end

function love.update(dt)
    if dt > 0.1 then
        -- Skip updates if frame time is too high (prevents large jumps)
        Constants.Utils.debug("WARNING: Large frame time detected: " .. dt)
        return
    end
    
    local success, err = pcall(function()
        Game:update(dt)
    end)
    
    if not success then
        Constants.Utils.debug("ERROR: Update failed: " .. tostring(err))
    end
end

function love.draw()
    local success, err = pcall(function()
        Game:draw()
        
        -- Draw win message if game is won
        if Game:checkWinCondition() then
            -- Dim background
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle('fill', 0, 0, 
                love.graphics.getWidth(), 
                love.graphics.getHeight())
            
            -- Draw win message
            love.graphics.setColor(1, 1, 1, 1)
            local font = love.graphics.getFont()
            local message = "Congratulations! You've won!"
            local messageWidth = font:getWidth(message)
            local messageHeight = font:getHeight()
            
            love.graphics.print(
                message,
                love.graphics.getWidth() / 2 - messageWidth / 2,
                love.graphics.getHeight() / 2 - messageHeight / 2
            )
            
            -- Reset color
            love.graphics.setColor(1, 1, 1, 1)
        end
        
        -- Draw debug info if enabled
        if Constants.DEBUG.VERBOSE then
            love.graphics.setColor(1, 1, 1, 1)
            local debugInfo = {
                "FPS: " .. love.timer.getFPS(),
                "Memory (KB): " .. math.floor(collectgarbage("count")),
                "Dragging: " .. tostring(Game.isDragging)
            }
            
            for i, text in ipairs(debugInfo) do
                love.graphics.print(text, 10, love.graphics.getHeight() - 60 + (i * 20))
            end
        end
    end)
    
    if not success then
        Constants.Utils.debug("ERROR: Draw failed: " .. tostring(err))
        -- Draw error message
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.print("Error: " .. tostring(err), 10, 10)
    end
end

function love.mousepressed(x, y, button, istouch, presses)
    local success, err = pcall(function()
        Game:mousepressed(x, y, button)
    end)
    
    if not success then
        Constants.Utils.debug("ERROR: Mouse press handling failed: " .. tostring(err))
    end
end

function love.mousereleased(x, y, button, istouch, presses)
    local success, err = pcall(function()
        Game:mousereleased(x, y, button)
    end)
    
    if not success then
        Constants.Utils.debug("ERROR: Mouse release handling failed: " .. tostring(err))
    end
end

function love.keypressed(key)
    if key == 'escape' then
        love.event.quit()
    elseif key == 'r' then
        -- Restart game
        local success, err = pcall(function()
            love.event.push("quit", "restart")
        end)
        
        if not success then
            Constants.Utils.debug("ERROR: Game restart failed: " .. tostring(err))
        else
            Constants.Utils.debug("Game restarted successfully")
        end
    elseif key == 'd' then
        -- Toggle debug mode
        Constants.DEBUG.VERBOSE = not Constants.DEBUG.VERBOSE
        Constants.DEBUG.SHOW_PILE_BOUNDS = Constants.DEBUG.VERBOSE
        Constants.Utils.debug("Debug mode: " .. tostring(Constants.DEBUG.VERBOSE))
    end
end

-- Error handler
function love.errorhandler(msg)
    Constants.Utils.debug("FATAL ERROR: " .. tostring(msg))
    
    -- Log the stack trace
    if debug and debug.traceback then
        Constants.Utils.debug("Stack trace: " .. debug.traceback())
    end
    
    -- Display error screen
    return function()
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle('fill', 0, 0, 
            love.graphics.getWidth(), 
            love.graphics.getHeight())
        
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.print("Error: " .. tostring(msg), 10, 10)
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Press escape to quit", 10, 30)
    end
end



--[[
	
	N O T E S :   
				when dragging 2+ attached cards, only the first few get transferred to the new pile, 
				and the other cards get apparently eliminated. For example: dragging [9,8,7,6], to a pile of
				[J,10] will result in [J,10,9,8], the last two cards being lost in limbo, we can no longer move
				any other cards to that pile, because the 7 and 6 exist and don't exist at the same time at that
				location (or something like that...)

				after placing and ace to its foundation pile and drawing any new card, the ace looks like
				it returns to the wastepile, permanently obstructing the 2 cards of the wastepile from view
				and we can't pick it up from the foundation pile. the gray debug perimeter lines are green,
				as if there was an ace there. This doesn't always happen. When it does, the console shows that it
				moved from its original position at the foundation pile to its new position. 

				each suit has a specific pile on the foundation piles; the first pile is reserved to hearts,
				diamonds gets the second, clubs gets the third and spades gets the last, rightmost pile. This
				is obviously incorrect. 

				thw system should be like this: the entire foundation pile area should have a single detection field
				and the card being dragged there should automatically sit on the right place. There is no real
				reason to make the foundation pile work like the other piles (ie tableaus). 

				the game seems to keep eating more and more memory every second. It stabilizes after 1200 and then
				begins to fall, and then starts increasing again all the way to 1200 (KB) and the cycle repeats at 600 KB
				
				
	
]]