-- card.lua
local Constants = require('constants')

local Card = {}
Card.__index = Card

function Card.new(suit, value, image)
    local self = setmetatable({}, Card)
    self.suit = suit
    self.value = value
    self.name = value .. " of " .. suit
    self.image = image
    self.backImage = love.graphics.newImage("/assets/card_back.png")
    self.scale = Constants.LAYOUT.CARD_SCALE
    self.isFaceUp = false
    self.x = 0
    self.y = 0
    self.targetX = 0
    self.targetY = 0
    self.isDragging = false
    self.dragOffsetX = 0
    self.dragOffsetY = 0
    self.attachedCards = {}
    self.attachedTo = nil  -- Reference to the card this is attached to
    return self
end

function Card:draw(skipAttached)
    -- Draw attached cards first (if not skipped)
    if not skipAttached and #self.attachedCards > 0 then
        for _, card in ipairs(self.attachedCards) do
            card:draw(true)
        end
    end
    
    -- Draw this card
    if self.isFaceUp then
        love.graphics.draw(self.image, self.x, self.y, 0, self.scale, self.scale)
    else
        love.graphics.draw(self.backImage, self.x, self.y, 0, self.scale, self.scale)
    end

    -- Debug visualization
    if Constants.DEBUG.SHOW_PILE_BOUNDS then
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.rectangle('line', 
            self.x, self.y, 
            self.image:getWidth() * self.scale,
            self.image:getHeight() * self.scale)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Card:containsPoint(x, y)
    local extend = Constants.LAYOUT.HIT_AREA_EXTEND
    local cardWidth = self.image:getWidth() * self.scale
    local cardHeight = self.image:getHeight() * self.scale
    
    return x >= self.x - extend and 
           x <= self.x + cardWidth + extend and
           y >= self.y - extend and 
           y <= self.y + cardHeight + extend
end

function Card:startDragging(x, y)
    self.isDragging = true
    self.dragOffsetX = x - self.x
    self.dragOffsetY = y - self.y
    Constants.Utils.debug("Started dragging " .. self.name)
end

function Card:stopDragging()
    self.isDragging = false
    self.dragOffsetX = 0
    self.dragOffsetY = 0
    Constants.Utils.debug("Stopped dragging " .. self.name)
end

function Card:updatePosition(x, y, skipAttached)
    -- Store old position for debugging
    local oldX, oldY = self.x, self.y
    
    self.x = x
    self.y = y
    
    if not skipAttached and #self.attachedCards > 0 then
        local stackOffset = Constants.LAYOUT.TABLEAU_OVERLAP
        for i, card in ipairs(self.attachedCards) do
            card:updatePosition(x, y + (stackOffset * i), true)
        end
    end
    
    --[[if Constants.DEBUG.VERBOSE then
        Constants.Utils.debug(string.format("%s moved from (%.0f, %.0f) to (%.0f, %.0f)",
            self.name, oldX, oldY, x, y))
    end--]]
end

function Card:clearAllAttachments()
    -- Debug log before clearing
    if Constants.DEBUG.VERBOSE then
        Constants.Utils.debug(string.format("Clearing attachments for %s (had %d attached cards)",
            self.name, #self.attachedCards))
    end
    
    -- Clear this card's attachments
    for _, card in ipairs(self.attachedCards) do
        card.attachedTo = nil
    end
    self.attachedCards = {}
    
    -- Clear reference to parent card
    if self.attachedTo then
        self.attachedTo = nil
    end
end

function Card:attachCard(card)
    -- Prevent attaching to self or circular references
    if card == self then
        Constants.Utils.debug("ERROR: Attempted to attach card to itself")
        return
    end
    
    -- Clear any previous attachments from the card being attached
    card:clearAllAttachments()
    
    -- Add to attachments
    table.insert(self.attachedCards, card)
    card.attachedTo = self
    
    -- Update position
    card:updatePosition(self.x, self.y + Constants.LAYOUT.TABLEAU_OVERLAP, true)
    
    Constants.Utils.debug(string.format("Attached %s to %s", card.name, self.name))
end

function Card:getAllCardsBelow()
    local cards = {self}
    local currentCard = self
    
    -- Follow the chain of attachments
    while #currentCard.attachedCards > 0 do
        local nextCard = currentCard.attachedCards[1]  -- Get the first (and should be only) attached card
        table.insert(cards, nextCard)
        currentCard = nextCard
    end
    
    return cards
end

function Card:detachCard(card)
    for i, attachedCard in ipairs(self.attachedCards) do
        if attachedCard == card then
            table.remove(self.attachedCards, i)
            card.attachedTo = nil
            Constants.Utils.debug(string.format("Detached %s from %s", card.name, self.name))
            break
        end
    end
end

function Card:detachFromParent()
    if self.attachedTo then
        self.attachedTo:detachCard(self)
    end
end

function Card:getAllCardsBelow()
    local cards = {self}
    for _, card in ipairs(self.attachedCards) do
        local belowCards = card:getAllCardsBelow()
        for _, belowCard in ipairs(belowCards) do
            table.insert(cards, belowCard)
        end
    end
    return cards
end

function Card:getAttachedCards()
    return self.attachedCards or {}
end

-- Game rule checks
function Card:canStackOnFoundation(topCard)
    if not topCard then
        return self.value == "Ace"
    end
    
    return self.suit == topCard.suit and 
           Constants.Utils.getCardRank(self.value) == 
           Constants.Utils.getCardRank(topCard.value) + 1
end

function Card:canStackOnTableau(topCard)
    if not topCard then
        return self.value == "King"
    end
    
    return Constants.Utils.areOppositeColors(self.suit, topCard.suit) and
           Constants.Utils.getCardRank(self.value) == 
           Constants.Utils.getCardRank(topCard.value) - 1
end

return Card