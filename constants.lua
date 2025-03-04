-- constants.lua
local Constants = {
    LAYOUT = {
        CARD_SCALE = 0.6,
        CARD_SPACING_X = 100,
        CARD_SPACING_Y = 20,
        STACK_SPACING = 0,  -- Vertical spacing for stacked cards // ONLY WORKS FOR FOUNDATION PILE
        STOCKPILE_X = 20,
        STOCKPILE_Y = 20,
        WINDOW_WIDTH = 800,   -- Updated to match main.lua window size
        WINDOW_HEIGHT = 600,  -- Updated to match main.lua window size
        FOUNDATION_START_X = 340,
        FOUNDATION_Y = 20,
        TABLEAU_START_X = 20,
        TABLEAU_Y = 200,
        TABLEAU_OVERLAP = 20, -- Vertical spacing for stacked cards on tableau piles
        HIT_AREA_EXTEND = 5  -- Extra pixels for hit detection
    },
    
    SUITS = {"Hearts", "Diamonds", "Clubs", "Spades"},
    VALUES = {"Ace", "2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King"},
    
    COLORS = {
        Hearts = "red",
        Diamonds = "red",
        Clubs = "black",
        Spades = "black"
    },
    
    -- Card Rankings (1-13)
    VALUE_RANKS = {
        Ace = 1,
        ["2"] = 2,
        ["3"] = 3,
        ["4"] = 4,
        ["5"] = 5,
        ["6"] = 6,
        ["7"] = 7,
        ["8"] = 8,
        ["9"] = 9,
        ["10"] = 10,
        Jack = 11,
        Queen = 12,
        King = 13
    },

    -- Debug flags
    DEBUG = {
        SHOW_PILE_BOUNDS = false,  -- Set to true to see pile boundaries
        LOG_MOVES = false,          -- Set to true to log card movements
        VERBOSE = false            -- Set to true for detailed logging
    }
}

-- Utility functions
Constants.Utils = {
    getCardColor = function(suit)
        return Constants.COLORS[suit]
    end,
    
    getCardRank = function(value)
        return Constants.VALUE_RANKS[value]
    end,
    
    areOppositeColors = function(suit1, suit2)
        return Constants.COLORS[suit1] ~= Constants.COLORS[suit2]
    end,
    
    getNextValue = function(value)
        local rank = Constants.VALUE_RANKS[value]
        for v, r in pairs(Constants.VALUE_RANKS) do
            if r == rank + 1 then
                return v
            end
        end
        return nil
    end,
    
    getPrevValue = function(value)
        local rank = Constants.VALUE_RANKS[value]
        for v, r in pairs(Constants.VALUE_RANKS) do
            if r == rank - 1 then
                return v
            end
        end
        return nil
    end,
    
    -- Debug helper functions
    debug = function(msg)
        if Constants.DEBUG.VERBOSE then
            print("[DEBUG] " .. tostring(msg))
        end
    end,
    
    logMove = function(card, fromPile, toPile)
        if Constants.DEBUG.LOG_MOVES then
            print(string.format("[MOVE] %s: %s -> %s", 
                card.name,
                fromPile and "source" or "unknown",
                toPile and "target" or "unknown"))
        end
    end
}

return Constants