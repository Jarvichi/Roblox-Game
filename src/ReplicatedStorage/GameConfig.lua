-- GameConfig: Shared configuration for the Tag Game
-- Loaded by both server (GameManager) and client (TagClient)
return {
    ROUND_COUNT         = 5,   -- total rounds per game
    ROUND_DURATION      = 60,  -- seconds each round lasts
    INTERMISSION_DELAY  = 10,  -- seconds between rounds
    RESULTS_DISPLAY     = 6,   -- seconds to show round/game results
    MIN_PLAYERS         = 2,   -- minimum players to start

    IT_WALK_SPEED       = 22,  -- "It" player walk speed (default is 16)
    NORMAL_WALK_SPEED   = 16,

    TAG_IMMUNITY        = 2,   -- seconds of immunity after being tagged
    POINTS_PER_SECOND   = 1,   -- points awarded to non-It players each second
    ROUND_SURVIVAL_BONUS = 10, -- extra points for surviving an entire round without being It
}
