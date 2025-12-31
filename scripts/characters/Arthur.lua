--[[
    Arthur.lua
    Character data for Arthur
    GOAL: SIFU-style fast, grounded, punishable combat

    IMPORTANT:
    - This file is DATA ONLY
    - No logic here
    - Handlers read these values directly
]]

local Arthur = {

    --================================================
    -- BASIC INFO (UI / IDENTIFICATION)
    --================================================
    Name = "Arthur",
    DisplayName = "Arthur Leywin",
    Description = "A young swordsman channeling ether and asuran will.",
    ModelName = "Arthur",

    --================================================
    -- BASE STATS (GLOBAL CHARACTER FEEL)
    --================================================
    Stats = {
        Damage = 1.0,            -- global damage multiplier
        Knockback = 1.0,         -- global knockback multiplier
        Speed = 1.0,             -- movement speed multiplier
        Stamina = 1.0,           -- stamina pool multiplier
        StaminaRegen = 1.0,      -- stamina regen rate
        Health = 100,

        WalkSpeed = 16,          -- Roblox humanoid walkspeed
        JumpPower = 50,

        -- Posture (Sekiro-style guard system)
        PostureMax = 100,
        PostureRegenMultiplier = 1.0,
    },

    --================================================
    -- PASSIVE (STACKING BUFF SYSTEM)
    --================================================
    Passive = {
        Name = "Ether Resonance",

        -- Each hit gives stacks
        MaxStacks = 8,
        StacksPerHit = 1,

        -- Stack behavior
        StackDuration = 8,       -- how long stacks stay before decay
        DecayDuration = 8,       -- how long until stacks fully decay

        -- Buff trigger
        BuffDuration = 5,        -- duration once max stacks reached
        Cooldown = 30,           -- time before passive can trigger again

        -- Buff effects
        BuffDamage = 1.2,        -- damage multiplier during buff
        BuffSpeed = 1.1,         -- speed multiplier during buff

        -- Per-stack bonuses
        DamagePerStack = 0.03,
        AttackSpeedPerStack = 0.03,

        -- Awakening interaction
        AwakeningStackRate = 2,
    },

    --================================================
    -- M1 COMBO (BASIC ATTACKS)
    --================================================
    M1 = {

        -- Combo rules
        MaxCombo = 4,            -- number of hits in chain
        ComboWindow = 0.50,      -- how late you can press to continue
        Hitstun = 0.35,          -- how long enemy is frozen on hit

        -- Hitbox shape
        HitboxSize = Vector3.new(4, 4, 5),
        HitboxOffset = Vector3.new(0, 0, -3),

        -- Movement restrictions during attack
        AttackWalkSpeed = 3,
        AttackJumpPower = 0,

        -- Individual hit data
        Hits = {

            -- HIT 1: fast opener
            {
                startup = 0.10,  -- delay before hitbox appears
                active = 0.12,   -- how long hitbox is active
                recovery = 0.15, -- how long you’re stuck after

                damage = 8,
                knockback = 65,
                postureDamage = 12,
            },

            -- HIT 2: follow-up
            {
                startup = 0.08,
                active = 0.06,
                recovery = 0.08,

                damage = 8,
                knockback = 65,
                postureDamage = 12,
            },

            -- HIT 3: heavier swing
            {
                startup = 0.08,
                active = 0.08,
                recovery = 0.10,

                damage = 10,
                knockback = 65,
                postureDamage = 15,
            },

            -- HIT 4: finisher (punishable)
            {
                startup = 0.08,
                active = 0.10,
                recovery = 0.14,

                damage = 14,
                knockback = 200,
                lift = 3,        -- vertical pop
                postureDamage = 20,
            },
        },
    },

    --================================================
    -- UPTILT (LAUNCHER / COMBO STARTER)
    --================================================
    Uptilt = {

        -- Timing
        Startup = 0.05,
        Active = 0.10,
        Recovery = 0.14,
        RecoveryOnHit = 0.06,    -- faster recovery if it connects

        -- Launch behavior
        Damage = 12,
        LaunchVelocity = 22,     -- how high enemy goes
        ForwardPush = 4,
        Hitstun = 0.28,          -- airtime before enemy can act

        -- Posture
        PostureDamage = 18,

        -- Stamina
        StaminaCost = 10,

        -- Hitbox
        HitboxSize = Vector3.new(4, 6, 4),
        HitboxOffset = Vector3.new(0, 2, -3),

        -- Restrictions
        MaxComboToUse = 2,       -- can't uptilt after hit 3/4

        -- Cooldown
        Cooldown = 0.5,
    },

    --================================================
    -- AERIAL (DOWN SLAM / PLUNGE ATTACK)
    --================================================
    Aerial = {

        -- Timing
        Recovery = 0.30,         -- recovery after landing

        -- Slam behavior (TAP spacebar)
        Damage = 18,             -- base impact damage
        SlamForce = 150,         -- downward force applied
        Knockback = 80,          -- radial knockback from impact
        Hitstun = 0.40,          -- stun duration on hit

        -- Knockback behavior (HOLD spacebar)
        KnockbackDamage = 15,    -- damage when using knockback version
        KnockbackForce = 120,    -- horizontal knockback force
        KnockbackLift = 10,      -- vertical launch force
        KnockbackHitstun = 0.35,

        -- Posture
        PostureDamage = 25,

        -- Stamina
        StaminaCost = 15,

        -- AOE
        Radius = 8,              -- damage radius from impact point

        -- Cooldown
        Cooldown = 1.0,
    },

    --================================================
    -- AERIAL M1 (AIR COMBOS)
    --================================================
    AerialM1 = {

        -- Combo rules
        ComboWindow = 0.60,      -- time window for air combo
        Hitstun = 0.30,          -- how long enemy is frozen

        -- Hitbox
        HitboxSize = Vector3.new(5, 5, 6),
        HitboxOffset = Vector3.new(0, 0, -3),

        -- Air combo hits (inherit from ground combo)
        -- If uptilt at M1-1: get 3 air hits
        -- If uptilt at M1-2: get 2 air hits
        -- If uptilt at M1-3: get 1 air hit
        -- Each hit counts toward total combo

        Hits = {
            -- AIR HIT 1
            {
                startup = 0.08,
                active = 0.10,
                recovery = 0.12,

                damage = 9,
                knockback = 50,      -- Keep them in air
                lift = 2,            -- Slight upward push
                postureDamage = 10,
            },

            -- AIR HIT 2
            {
                startup = 0.07,
                active = 0.08,
                recovery = 0.10,

                damage = 10,
                knockback = 55,
                lift = 1,
                postureDamage = 12,
            },

            -- AIR HIT 3 (Finisher)
            {
                startup = 0.08,
                active = 0.10,
                recovery = 0.14,

                damage = 14,
                knockback = 100,     -- Send them flying
                lift = 5,            -- Big launch
                postureDamage = 18,
            },
        },
    },

    --================================================
    -- DASH (MOVEMENT + I-FRAMES)
    --================================================
    Dash = {
        Distance = 16,           -- how far dash moves
        Duration = 0.12,         -- how fast dash happens
        Cooldown = 0.30,         -- delay before next dash
        IFrames = 0.07,          -- invulnerability window
        StaminaCost = 15,
    },

    --================================================
    -- BLOCK / DEFLECT SYSTEM
    --================================================
    Block = {

        DamageReduction = 0.75,  -- % damage blocked
        KnockbackReduction = 0.3,

        -- Stamina & posture
        StaminaDrain = 12,
        Pushback = 5,

        -- Perfect block
        PerfectWindow = 0.18,    -- timing window
        PerfectStun = 0.35,      -- enemy freeze duration

        -- Guard break
        BreakStun = 1.0,         -- stun when posture breaks
        PostureDamageMultiplier = 0.6,
    },

    --================================================
    -- AWAKENING (POWER MODE)
    --================================================
    Awakening = {
        Name = "Asura Ascension",
        Duration = 25,
        Cooldown = 90,

        SpeedMultiplier = 1.20,
        DamageMultiplier = 1.20,
        M1RangeMultiplier = 1.25,
    },

    --================================================
    -- ANIMATIONS (IDS ONLY)
    --================================================
    Animations = {
        -- Ground M1
        M1_1 = "rbxassetid://12845340632",
        M1_2 = "rbxassetid://12845369253",
        M1_3 = "rbxassetid://12845398367",
        M1_4 = "rbxassetid://12845456406",

        -- Air M1
        AirM1_1 = "rbxassetid://0",  -- TODO: Add aerial M1 animations
        AirM1_2 = "rbxassetid://0",
        AirM1_3 = "rbxassetid://0",

        -- Special attacks
        Uptilt = "rbxassetid://126734284253680",
        Aerial = "rbxassetid://0",         -- Down slam
        AerialKnockback = "rbxassetid://0", -- Hold version

        BlockIdle = "rbxassetid://12927194871",
        BlockHit = "rbxassetid://0",

        DashForward = "rbxassetid://11989948466",
        DashRight   = "rbxassetid://11997368950",
        DashLeft    = "rbxassetid://11997366704",
        DashBack    = "rbxassetid://11997364353",

        HitLight = "rbxassetid://0",
        HitHeavy = "rbxassetid://0",
        HitLaunch = "rbxassetid://0",
        Stunned = "rbxassetid://0",
    },

    --================================================
    -- ANIMATION SPEED MULTIPLIERS
    --================================================
    AnimationSpeeds = {

        -- M1 speed (lower = slower)
        M1_1 = 1.35,
        M1_2 = 1.35,
        M1_3 = 1.35,
        M1_4 = 1.35,

        DashForward = 1.5,
        DashLeft = 1.5,
        DashRight = 1.5,
        DashBack = 1.5,

        Uptilt = 1.20,
        Aerial = 1.25,

        BlockIdle = 1.0,

        HitLight = 0.3,
        HitHeavy = 1.10,
    },

    --================================================
    -- ABILITIES (SLOTS)
    --================================================
    Abilities = {
        "DragonStep",
        "EtherSlash",
        "BurstNova",
        "StaticEdge",
    },

    AwakeningAbilities = {
        "AsuraStep",
        "EthericDivide",
        "DragonNova",
        "Realmbreaker",
    },

    --================================================
    -- ABILITY DATA
    --================================================
    AbilityData = {

        DragonStep = {
            Cooldown = 4,
            StaminaCost = 15,
            Distance = 20,
            Duration = 0.10,
            IFrameWindow = 0.06,

            Damage = 6,
            Knockback = 6,
            Stagger = 0.2,

            HitboxSize = Vector3.new(3, 4, 6),

            CancelFromM1 = true,
            CancelWindow = 0.15,
        },

        EtherSlash = {
            Cooldown = 6,
            StaminaCost = 20,

            Startup = 0.10,
            Active = 0.12,
            Recovery = 0.16,

            Damage = 12,
            Knockback = 8,

            HitboxSize = Vector3.new(8, 4, 6),
            HitboxOffset = Vector3.new(0, 0, -4),

            BlockDrain = 30,
        },

        BurstNova = {
            Cooldown = 8,
            StaminaCost = 25,

            Startup = 0.10,
            Active = 0.08,
            Recovery = 0.18,

            Damage = 8,
            PushDistance = 8,
            Radius = 8,
        },

        StaticEdge = {
            Cooldown = 5,
            StaminaCost = 10,

            CounterWindow = 0.35,
            CounterDamage = 16,
            CounterKnockback = 10,
        },
    },
}

return Arthur
