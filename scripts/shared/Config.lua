--[[
    Config.lua
    Central combat configuration - SIFU FEEL TUNING
]]

local Config = {}

--------------------------------------------------------------------------------
-- STAMINA SETTINGS
--------------------------------------------------------------------------------
Config.Stamina = {
    Max = 100,
    RegenRate = 20,         -- Slightly faster for flow
    RegenDelay = 0.8,       -- Shorter delay
}

--------------------------------------------------------------------------------
-- PLAYER DEFAULTS
--------------------------------------------------------------------------------
Config.Player = {
    WalkSpeed = 16,
    JumpPower = 50,
}

--------------------------------------------------------------------------------
-- POSTURE SYSTEM (Keep your Sekiro system, just tune it)
-- NOTE: Nested inside Combat to match existing code
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- HIT FEEL / GAME JUICE (SIFU = SNAPPY, PUNCHY)
--------------------------------------------------------------------------------
Config.HitFeel = {
    -- Hitstop (SHORTER = snappier, more responsive)
    HitstopLight = 0.025,       -- Was 0.04
    HitstopHeavy = 0.04,        -- Was 0.06
    HitstopFinal = 0.055,       -- Was 0.08
    HitstopDeflect = 0.06,

    -- Camera shake (slightly reduced for cleaner look)
    ShakeLight = 0.3,
    ShakeHeavy = 0.5,
    ShakeFinal = 0.7,
    ShakeDuration = 0.10,       -- Shorter shake

    -- Screen flash
    FlashAlpha = 0.12,
    FlashDuration = 0.05,

    -- Enemy flash
    EnemyFlashColor = Color3.new(1, 1, 1),
    EnemyFlashDuration = 0.05,

    -- Damage numbers
    DamageNumberDuration = 0.5,
    DamageNumberRise = 1.5,

    -- Face attacker
    FaceAttackerDuration = 0.03,
}

--------------------------------------------------------------------------------
-- COMBAT MECHANICS (SIFU FLOW)
--------------------------------------------------------------------------------
Config.Combat = {
    -- Lock-on
    LockOnRange = 50,
    LockOnBreakRange = 60,

    -- Combo (faster flow)
    ComboResetCooldown = 1.0,   -- Was 1.5 - faster reset
    ComboWindow = 0.50,         -- Generous chaining

    -- Input buffering (RESPONSIVE)
    InputBufferWindow = 0.20,   -- Was 0.15 - more forgiving

    -- Canceling
    DashCancelsAttack = true,
    BlockCancelsRecovery = true,
    DashCancelWindow = 0.08,    -- Can cancel earlier

    -- POSTURE SYSTEM (nested here to match existing code)
    Posture = {
        Max = 100,
        RegenRate = 10,
        RegenDelay = 1.8,
        PressureRegenMultiplier = 0.2,
        LowHPMultiplier = 0.5,
    },

    -- DEFLECT SYSTEM
    Deflect = {
        Window = 0.18,
        PostureDamage = 25,
        HitstopDuration = 0.06,
        PushbackDistance = 2,
    },

    -- GUARD BREAK
    GuardBreak = {
        StunDuration = 0.9,
        ExecutionWindow = 1.2,
        ExecutionDamage = 50,
        ExecutionKnockback = 150,
    },

    -- HIT FOLLOW (attacker follows victim)
    HitFollow = {
        AttackerFollowDistance = 4,
        AttackerFollowSpeed = 50,
        VictimKnockbackMultiplier = 0.7,
        VictimLaunchMultiplier = 0.8,
    },
}

--------------------------------------------------------------------------------
-- COMBAT LOCK / FOLLOW (THE KEY TO SIFU FEEL)
--------------------------------------------------------------------------------
Config.CombatLock = {
    -- How close attacker stays to victim
    StandoffDistance = 4,     -- Studs in front of victim

    -- Follow responsiveness (HIGHER = tighter, more glued)
    FollowResponsiveness = 50,  -- Was 40 - tighter follow
    OrientResponsiveness = 45,  -- Was 35 - faster face snap

    -- Physics
    MaxForce = 150000,          -- Strong lock

    -- Duration
    DefaultLockDuration = 0.5,  -- How long lock lasts per hit
    ExtendOnHit = 0.3,          -- Extend lock on subsequent hits

    -- Both players ALWAYS face each other
    ForceMutualFacing = true,
}

--------------------------------------------------------------------------------
-- KNOCKBACK TUNING (SIFU = LESS FLOATY)
--------------------------------------------------------------------------------
Config.Knockback = {
    -- Global multipliers
    DistanceMultiplier = 0.7,   -- Less knockback distance (keep enemies close)
    LiftMultiplier = 0.8,       -- Less vertical pop

    -- Attacker follow
    AttackerFollowDistance = 2.0,   -- Stay 2 studs from victim
    AttackerFollowSpeed = 50,       -- Fast follow

    -- Victim
    VictimHitstunMultiplier = 0.85, -- Slightly shorter hitstun (faster pace)
}

--------------------------------------------------------------------------------
-- DEBUG OPTIONS
--------------------------------------------------------------------------------
Config.Debug = {
    ShowHitboxes = false,
    LogStateChanges = false,
    LogCombatEvents = false,
    LogCombatLock = false,
}

return Config