-- game.lua
local Constants = require('constants')
local Card = require('card')
local Piles = require('piles')

local Game = {
    stockPile = nil,
    wastePile = nil,
    foundationPiles = {},
    tableauPiles = {},
    draggedCard = nil,
    sourcePile = nil,
    deck = {},
    backgroundImage = nil,
    isDragging = false
}

function Game:initialize()
    -- Load background
    local success, result = pcall(function()
        self.backgroundImage = love.graphics.newImage("assets/background4.png")
        self.backgroundImage:setWrap("repeat", "repeat")
    end)
    
    if not success then
        Constants.Utils.debug("WARNING: Failed to load background image: " .. tostring(result))
    end
    
    -- Create piles
    self:createPiles()
    
    -- Initialize and shuffle deck
    self:initializeDeck()
    
    -- Deal initial tableau
    self:dealInitialTableau()
    
    Constants.Utils.debug("Game initialized successfully")
end

function Game:createPiles()
    -- Create stock and waste piles
    self.stockPile = Piles.StockPile.new(
        Constants.LAYOUT.STOCKPILE_X, 
        Constants.LAYOUT.STOCKPILE_Y
    )
    
    self.wastePile = Piles.WastePile.new(
        Constants.LAYOUT.STOCKPILE_X + Constants.LAYOUT.CARD_SPACING_X, 
        Constants.LAYOUT.STOCKPILE_Y
    )
    
    -- Create foundation piles
    for i, suit in ipairs(Constants.SUITS) do
        local foundationPile = Piles.FoundationPile.new(
            Constants.LAYOUT.FOUNDATION_START_X + (i-1) * Constants.LAYOUT.CARD_SPACING_X,
            Constants.LAYOUT.FOUNDATION_Y,
            suit
        )
        table.insert(self.foundationPiles, foundationPile)
    end
    
    -- Create tableau piles
    for i = 1, 7 do
        local tableauPile = Piles.TableauPile.new(
            Constants.LAYOUT.TABLEAU_START_X + (i-1) * Constants.LAYOUT.CARD_SPACING_X,
            Constants.LAYOUT.TABLEAU_Y
        )
        table.insert(self.tableauPiles, tableauPile)
    end
    
    Constants.Utils.debug("Piles created successfully")
end

function Game:initializeDeck()
    -- Create all cards
    for _, suit in ipairs(Constants.SUITS) do
        for _, value in ipairs(Constants.VALUES) do
            local imagePath = "/assets/" .. string.lower(suit:sub(1,1)) .. 
                            string.lower(value) .. ".png"
            local success, image = pcall(love.graphics.newImage, imagePath)
            if success then
                local card = Card.new(suit, value, image)
                table.insert(self.deck, card)
            else
                Constants.Utils.debug("ERROR: Failed to load card image: " .. imagePath)
            end
        end
    end
    
    -- Shuffle deck
    for i = #self.deck, 2, -1 do
        local j = love.math.random(i)
        self.deck[i], self.deck[j] = self.deck[j], self.deck[i]
    end
    
    -- Move all cards to stock pile
    for _, card in ipairs(self.deck) do
        self.stockPile:addCard(card)
    end
    
    Constants.Utils.debug("Deck initialized with " .. #self.deck .. " cards")
end

function Game:dealInitialTableau()
    for i = 1, 7 do
        for j = i, 7 do
            local card = table.remove(self.stockPile.cards)
            if card then
                self.tableauPiles[j]:addCard(card, i == j)
            else
                Constants.Utils.debug("ERROR: Ran out of cards while dealing tableau")
                return
            end
        end
    end
    Constants.Utils.debug("Initial tableau dealt successfully")
end

function Game:findPileForCard(x, y)
    -- Check foundation piles first
    for _, pile in ipairs(self.foundationPiles) do
        local extend = Constants.LAYOUT.HIT_AREA_EXTEND
        if x >= pile.x - extend and 
           x <= pile.x + (71 * Constants.LAYOUT.CARD_SCALE) + extend and
           y >= pile.y - extend and 
           y <= pile.y + (96 * Constants.LAYOUT.CARD_SCALE) + extend then
            return pile
        end
    end
    
    -- Then check tableau piles
    for _, pile in ipairs(self.tableauPiles) do
        local extend = Constants.LAYOUT.HIT_AREA_EXTEND
        if x >= pile.x - extend and 
           x <= pile.x + (71 * Constants.LAYOUT.CARD_SCALE) + extend then
            local pileHeight = 96 * Constants.LAYOUT.CARD_SCALE
            if #pile.cards > 0 then
                pileHeight = pileHeight + (#pile.cards * Constants.LAYOUT.TABLEAU_OVERLAP)
            end
            if y >= pile.y - extend and y <= pile.y + pileHeight + extend then
                return pile
            end
        end
    end
    
    return nil
end

function Game:handleStockPileClick()
    if self.stockPile:isEmpty() then
        self.wastePile:resetToStock(self.stockPile)
        Constants.Utils.debug("Reset waste pile to stock")
    else
        self.stockPile:drawToWaste(self.wastePile)
        Constants.Utils.debug("Drew card from stock to waste")
    end
end

function Game:update(dt)
    if self.draggedCard then
        local mouseX, mouseY = love.mouse.getPosition()
        self.draggedCard:updatePosition(
            mouseX - self.draggedCard.dragOffsetX,
            mouseY - self.draggedCard.dragOffsetY
        )
    end
end

function Game:draw()
    -- Draw background
    if self.backgroundImage then
        love.graphics.draw(
            self.backgroundImage, 
            0, 0, 0, 
            love.graphics.getWidth() / self.backgroundImage:getWidth(),
            love.graphics.getHeight() / self.backgroundImage:getHeight()
        )
    end
    
    -- Draw all piles except source pile
    if self.draggedCard and self.sourcePile then
        -- Draw non-source piles
        for _, pile in ipairs(self.tableauPiles) do
            if pile ~= self.sourcePile then
                pile:draw()
            end
        end
        
        -- Draw source pile without dragged cards
        local cardsToShow = {}
        for _, card in ipairs(self.sourcePile.cards) do
            if card ~= self.draggedCard and not self:isCardAttachedToDragged(card) then
                table.insert(cardsToShow, card)
            end
        end
        
        -- Temporarily swap cards and draw
        local originalCards = self.sourcePile.cards
        self.sourcePile.cards = cardsToShow
        self.sourcePile:draw()
        self.sourcePile.cards = originalCards
    else
        -- Normal drawing of all piles
        for _, pile in ipairs(self.tableauPiles) do
            pile:draw()
        end
    end
    
    -- Draw stock and waste piles
    self.stockPile:draw()
    self.wastePile:draw()
    
    -- Draw foundation piles
    for _, pile in ipairs(self.foundationPiles) do
        pile:draw()
    end
    
    -- Draw dragged card last
    if self.draggedCard then
        self.draggedCard:draw()
    end
end

function Game:isCardAttachedToDragged(card)
    if not self.draggedCard then return false end
    
    local attachedCards = self.draggedCard:getAttachedCards()
    for _, attachedCard in ipairs(attachedCards) do
        if card == attachedCard then
            return true
        end
    end
    return false
end

function Game:mousepressed(x, y, button)
    if button == 1 then
        -- Prevent multiple drag operations
        if self.isDragging then return end
        
        -- Check stock pile
        if x >= self.stockPile.x and 
           x <= self.stockPile.x + 71 * Constants.LAYOUT.CARD_SCALE and
           y >= self.stockPile.y and 
           y <= self.stockPile.y + 96 * Constants.LAYOUT.CARD_SCALE then
            self:handleStockPileClick()
            return
        end
        
        -- Check waste pile
        if self.wastePile:getTopCard() then
            local topCard = self.wastePile:getTopCard()
            if topCard:containsPoint(x, y) then
                self.draggedCard = topCard
                self.sourcePile = self.wastePile
                topCard:startDragging(x, y)
                self.isDragging = true
                Constants.Utils.debug("Started dragging from waste: " .. topCard.name)
                return
            end
        end
        
        -- Check tableau piles
        for _, pile in ipairs(self.tableauPiles) do
            local card = pile:findCardAt(x, y)
            if card and card.isFaceUp then
                self.draggedCard = card
                self.sourcePile = pile
                card:startDragging(x, y)
                self.isDragging = true
                Constants.Utils.debug("Started dragging from tableau: " .. card.name)
                return
            end
        end
    end
end

function Game:mousereleased(x, y, button)
    if button == 1 and self.draggedCard then
        local targetPile = self:findPileForCard(x, y)
        local validMove = false
        
        Constants.Utils.debug("Attempting to release " .. self.draggedCard.name)
        
        if targetPile then
            if targetPile ~= self.sourcePile then
                if targetPile:canAcceptCard(self.draggedCard) then
                    -- Get all cards being moved as a sequence
                    local cardsToMove = self.draggedCard:getAllCardsBelow()
                    
                    -- Remove all cards from source pile
                    for _, card in ipairs(cardsToMove) do
                        self.sourcePile:removeCard(card)
                    end
                    
                    -- Add all cards to target pile
                    for _, card in ipairs(cardsToMove) do
                        targetPile:addCard(card, true)
                    end
                    
                    validMove = true
                    Constants.Utils.debug("Successfully moved " .. #cardsToMove .. " cards to new pile")
                end
            end
        end
        
        if not validMove then
            Constants.Utils.debug("Invalid move, returning to source pile")
            -- Return card and its attachments to source pile
            self.sourcePile:addCard(self.draggedCard, true)
            
            -- Rebuild attachments if needed
            if self.sourcePile.reattachCards then
                self.sourcePile:reattachCards()
            end
        end
        
        self.draggedCard:stopDragging()
        self.draggedCard = nil
        self.sourcePile = nil
        self.isDragging = false
    end
end

function Game:checkWinCondition()
    for _, pile in ipairs(self.foundationPiles) do
        if #pile.cards ~= 13 then
            return false
        end
    end
    return true
end

return Game