-- piles.lua
local Constants = require('constants')

-- Base Pile class
local Pile = {}
Pile.__index = Pile

function Pile.new(x, y)
    local self = setmetatable({}, Pile)
    self.x = x
    self.y = y
    self.cards = {}
    return self
end

function Pile:draw()
    -- Debug: draw pile boundary
    if Constants.DEBUG.SHOW_PILE_BOUNDS then
        love.graphics.setColor(0, 1, 0, 0.3)
        love.graphics.rectangle('line', self.x, self.y, 
            71 * Constants.LAYOUT.CARD_SCALE,
            96 * Constants.LAYOUT.CARD_SCALE)
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    -- Draw cards
    for _, card in ipairs(self.cards) do
        card:draw()
    end
end

function Pile:addCard(card, faceUp)
    if not card then
        Constants.Utils.debug("ERROR: Attempted to add nil card to pile")
        return
    end
    
    if faceUp ~= nil then
        card.isFaceUp = faceUp
    end
    
    local yOffset = #self.cards * Constants.LAYOUT.STACK_SPACING
    card:updatePosition(self.x, self.y + yOffset, true)
    table.insert(self.cards, card)
    
    Constants.Utils.debug(string.format("Added %s to pile at (%d, %d)", 
        card.name, self.x, self.y + yOffset))
end

function Pile:removeCard(card)
    for i, c in ipairs(self.cards) do
        if c == card then
            local removedCard = table.remove(self.cards, i)
            Constants.Utils.debug(string.format("Removed %s from pile", card.name))
            return removedCard
        end
    end
    Constants.Utils.debug(string.format("WARNING: Attempted to remove card %s not found in pile", 
        card.name))
    return nil
end

function Pile:getTopCard()
    return self.cards[#self.cards]
end

function Pile:isEmpty()
    return #self.cards == 0
end

-- StockPile class
local StockPile = setmetatable({}, {__index = Pile})
StockPile.__index = StockPile

function StockPile.new(x, y)
    local self = setmetatable(Pile.new(x, y), StockPile)
    self.backImage = love.graphics.newImage("/assets/card_back.png")
    return self
end

function StockPile:draw()
    if not self:isEmpty() then
        love.graphics.draw(self.backImage, self.x, self.y, 0, 
            Constants.LAYOUT.CARD_SCALE, Constants.LAYOUT.CARD_SCALE)
    else
        love.graphics.setColor(0.2, 0.2, 0.2, 0.3)
        love.graphics.rectangle('line', self.x, self.y, 
            self.backImage:getWidth() * Constants.LAYOUT.CARD_SCALE,
            self.backImage:getHeight() * Constants.LAYOUT.CARD_SCALE)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function StockPile:drawToWaste(wastePile)
    if not self:isEmpty() then
        local card = table.remove(self.cards)
        card.isFaceUp = true
        wastePile:addCard(card)
        Constants.Utils.debug(string.format("Drew %s from stock to waste", card.name))
        return true
    end
    return false
end

-- WastePile class
local WastePile = setmetatable({}, {__index = Pile})
WastePile.__index = WastePile

function WastePile.new(x, y)
    local self = setmetatable(Pile.new(x, y), WastePile)
    return self
end

function WastePile:addCard(card, faceUp)
    if faceUp ~= nil then
        card.isFaceUp = faceUp
    else
        card.isFaceUp = true
    end
    
    -- Position cards with offset
    local cardIndex = #self.cards
    local xOffset = 0
    
    if cardIndex >= 2 then
        xOffset = Constants.LAYOUT.CARD_SPACING_X / 2
    elseif cardIndex == 1 then
        xOffset = Constants.LAYOUT.CARD_SPACING_X / 4
    end
    
    card:updatePosition(self.x + xOffset, self.y, true)
    table.insert(self.cards, card)
    
    self:refreshPositions()
    Constants.Utils.debug(string.format("Added %s to waste pile", card.name))
end

function WastePile:refreshPositions()
    local numCards = #self.cards
    local startIndex = math.max(1, numCards - 2)
    
    for i = 1, numCards do
        local card = self.cards[i]
        local xOffset = 0
        
        if i >= startIndex then
            local visiblePosition = i - startIndex
            xOffset = (Constants.LAYOUT.CARD_SPACING_X / 4) * visiblePosition
        end
        
        card:updatePosition(self.x + xOffset, self.y, true)
    end
end

function WastePile:removeCard(card)
    for i = #self.cards, 1, -1 do
        if self.cards[i] == card then
            local removedCard = table.remove(self.cards, i)
            self:refreshPositions()
            Constants.Utils.debug(string.format("Removed %s from waste pile", card.name))
            return removedCard
        end
    end
    return nil
end

function WastePile:findCardAt(x, y)
    if #self.cards > 0 then
        local topCard = self.cards[#self.cards]
        if topCard:containsPoint(x, y) then
            return topCard
        end
    end
    return nil
end

function WastePile:resetToStock(stockPile)
    while not self:isEmpty() do
        local card = table.remove(self.cards)
        card.isFaceUp = false
        stockPile:addCard(card)
        Constants.Utils.debug(string.format("Returned %s to stock pile", card.name))
    end
end

-- FoundationPile class
local FoundationPile = setmetatable({}, {__index = Pile})
FoundationPile.__index = FoundationPile

function FoundationPile.new(x, y, suit)
    local self = setmetatable(Pile.new(x, y), FoundationPile)
    self.suit = suit
    return self
end

function FoundationPile:canAcceptCard(card)
    if not card.isFaceUp then return false end
    
    -- Remove suit restriction, let game logic handle placement
    if self:isEmpty() then
        return card.value == "Ace"
    end
    
    local topCard = self:getTopCard()
    return card.suit == topCard.suit and 
           Constants.Utils.getCardRank(card.value) == 
           Constants.Utils.getCardRank(topCard.value) + 1
end

function FoundationPile:draw()
    if self:isEmpty() then
        love.graphics.setColor(0.2, 0.2, 0.2, 0.3)
        love.graphics.rectangle('line', self.x, self.y, 
            71 * Constants.LAYOUT.CARD_SCALE,
            96 * Constants.LAYOUT.CARD_SCALE)
        love.graphics.setColor(1, 1, 1, 1)
    else
        Pile.draw(self)
    end
end

-- TableauPile class
local TableauPile = setmetatable({}, {__index = Pile})
TableauPile.__index = TableauPile

function TableauPile.new(x, y)
    local self = setmetatable(Pile.new(x, y), TableauPile)
    return self
end

function TableauPile:addCard(card, faceUp)
    if not card then
        Constants.Utils.debug("ERROR: Attempted to add nil card to tableau")
        return
    end
    
    if faceUp ~= nil then
        card.isFaceUp = faceUp
    end
    
    -- Clear any existing attachments
    card:clearAllAttachments()
    
    -- Calculate position
    local yOffset = #self.cards * Constants.LAYOUT.TABLEAU_OVERLAP
    
    -- Update card position
    card:updatePosition(self.x, self.y + yOffset, true)
    
    -- Add to pile
    table.insert(self.cards, card)
    
    -- Update attachments
    self:reattachCards()
    
    Constants.Utils.debug(string.format("Added %s to tableau at position %d", 
        card.name, #self.cards))
end

function TableauPile:reattachCards()
    -- Clear all attachments first
    for _, card in ipairs(self.cards) do
        card:clearAllAttachments()
    end
    
    -- Find the first face-up card
    local firstFaceUpIndex = 1
    for i = #self.cards, 1, -1 do
        if not self.cards[i].isFaceUp then
            firstFaceUpIndex = i + 1
            break
        end
    end
    
    -- Create a chain of attachments for all face-up cards
    if firstFaceUpIndex <= #self.cards then
        local parentCard = self.cards[firstFaceUpIndex]
        for i = firstFaceUpIndex + 1, #self.cards do
            parentCard:attachCard(self.cards[i])
            parentCard = self.cards[i]
        end
    end
end

function TableauPile:canAcceptCard(card)
    if self:isEmpty() then
        return card.value == "King"
    end
    
    local topCard = self:getTopCard()
    if not card:canStackOnTableau(topCard) then
        return false
    end
    
    -- If this card is valid, all cards attached to it must also form a valid sequence
    local currentCard = card
    while #currentCard.attachedCards > 0 do
        local nextCard = currentCard.attachedCards[1]
        if not nextCard:canStackOnTableau(currentCard) then
            return false
        end
        currentCard = nextCard
    end
    
    return true
end

function TableauPile:findCardAt(x, y)
    for i = #self.cards, 1, -1 do
        local card = self.cards[i]
        if card.isFaceUp and card:containsPoint(x, y) then
            return card, i
        end
    end
    return nil
end

function TableauPile:removeCard(card)
    local cardIndex
    for i, c in ipairs(self.cards) do
        if c == card then
            cardIndex = i
            break
        end
    end
    
    if cardIndex then
        -- Get all attached cards before modifying attachments
        local cardsToMove = card:getAllCardsBelow()
        
        -- Remove all cards from pile
        for i = #self.cards, cardIndex, -1 do
            table.remove(self.cards, i)
        end
        
        -- Update remaining cards
        if #self.cards > 0 then
            self.cards[#self.cards].isFaceUp = true
        end
        
        return cardsToMove
    end
    return nil
end

return {
    Pile = Pile,
    StockPile = StockPile,
    WastePile = WastePile,
    FoundationPile = FoundationPile,
    TableauPile = TableauPile
}