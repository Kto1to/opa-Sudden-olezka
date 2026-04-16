--[[

Credits (people i stole from)

Neco Arc Jumpscare (GodWladi)
Inspiration + some of the code

Concrete scrape when slow (Ixion)
Mod config menu code

]]

local mod = RegisterMod("Random Foxy Jumpscare", 1)
local game = Game()
local rng = RNG()
local sfxManager = SFXManager()
local json = require("json")

local persistentData = {}
local defaultConfig = {
    chancePerSecond = 10000,
    volume = 10,          -- 10 = 100%
    configVersion = 1
}

--FNAF 2 parity
local jumpscareSpeed = 1.10
local freddySpeed = 1.10
local staticSpeed = 0.50
local frameDelay = 90

local GOLDEN_FREDDY_CHANCE = 100000000

--sprite size
local sizeX = 512
local sizeY = 384

--sounds
local jumpscareSound = Isaac.GetSoundIdByName("OlezhkaJumpscare")
local static = Isaac.GetSoundIdByName("static")

local staticVolume = 4.0

--Sprites
local jumpscareSprite = Sprite()
jumpscareSprite:Load("gfx/jumpscare.anm2", true)
jumpscareSprite.PlaybackSpeed = jumpscareSpeed

local staticSprite = Sprite()
staticSprite:Load("gfx/static.anm2", true)
local staticAnim = staticSprite:GetDefaultAnimation()
staticSprite.PlaybackSpeed = staticSpeed

local freddySprite = Sprite()
freddySprite:Load("gfx/freddy.anm2", true)
freddySprite.PlaybackSpeed = freddySpeed

--variables
local number = 1
local jumpscareDebounce = false
local isSpritePlaying = false
local phase = 1
local color = Color.Default
local opaqueness = 1.0
local currentVolume = staticVolume
local whoGotYou = jumpscareSprite

local f = Font()
f:Load("font/terminus.fnt")

local function crashthefuckinggamelmao()
    f:DrawString(nil, -500, -500, KColor(1,1,1,0), 0, false)
end

local function customRandom(x)
    if x == 0 then return 1 else return rng:RandomInt(x) end
end

function mod:randomScare()
    if persistentData["configVersion"] == nil then
        mod:loadConfiguration()
    end

    if ModConfigMenu then
        chancePerSecond = persistentData["chancePerSecond"] * 100
        staticVolume = persistentData["volume"] / 1.5
    end

    if number >= 30 then
        number = 1
        if customRandom(GOLDEN_FREDDY_CHANCE) == 0 and jumpscareDebounce == false then
            whoGotYou = freddySprite
            jumpscareDebounce = true
        elseif customRandom(chancePerSecond) == 0 and jumpscareDebounce == false then
            whoGotYou = jumpscareSprite
            jumpscareDebounce = true
        end
    else
        number = number + 1
    end
end

function mod:render()
    -- Тестовые клавиши (1 = обычный Олежка, 2 = золотой)
    if Input.IsButtonTriggered(Keyboard.KEY_1, 0) then
        whoGotYou = jumpscareSprite
        jumpscareDebounce = true
    elseif Input.IsButtonTriggered(Keyboard.KEY_2, 0) then
        whoGotYou = freddySprite
        jumpscareDebounce = true
    end

    if jumpscareDebounce then
        local screenWidth, screenHeight = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
        local screenCenter = Vector(screenWidth / 2, screenHeight / 2)

        whoGotYou.Scale = Vector(screenWidth / sizeX, screenHeight / sizeY)
        staticSprite.Scale = Vector(screenWidth / sizeX, screenHeight / sizeY)

        if phase == 1 then
            local anim = whoGotYou:GetDefaultAnimation()

            if isSpritePlaying == false then
                isSpritePlaying = true
                
                -- Громкость: 10 = 100%
                local realVolume = (persistentData["volume"] / 10) * 20
                sfxManager:Play(jumpscareSound, realVolume, 0, false, 1.0, 0.0)
                
                whoGotYou:Play(anim, true)
            else
                whoGotYou:Update()
            end

            whoGotYou:RenderLayer(0, screenCenter)

            if sfxManager:IsPlaying(jumpscareSound) == false and whoGotYou:IsFinished(anim) then
                if whoGotYou == freddySprite then
                    crashthefuckinggamelmao()
                end
                frameDelay = 30
                phase = 2
                opaqueness = 1
                currentVolume = staticVolume
                sfxManager:Play(static, staticVolume, 0, false, 1, 0)
                staticSprite:Play(staticAnim, true)
            end

        elseif phase == 2 then
            if staticSprite:IsFinished(staticAnim) then
                staticSprite:Play(staticAnim, true)
            end

            currentVolume = currentVolume - (staticVolume / 100)
            opaqueness = opaqueness - 0.01

            sfxManager:AdjustVolume(static, currentVolume)
            color:SetTint(1, 1, 1, opaqueness)
            staticSprite.Color = color

            staticSprite:Update()
            staticSprite:RenderLayer(0, screenCenter)

            if opaqueness <= 0 then
                sfxManager:Stop(static)
                jumpscareDebounce = false
                isSpritePlaying = false
                phase = 1
            end
        end
    end
end

-- ==================== Mod Config Menu ====================
if ModConfigMenu then
    local modSettings = "Olezka Libo"

    ModConfigMenu.RemoveCategory(modSettings)
    ModConfigMenu.UpdateCategory(modSettings, { Info = {"Random Jumpscare"} })

    ModConfigMenu.AddText(modSettings, "Settings", function() return "Олежка Либо" end)
    ModConfigMenu.AddSpace(modSettings, "Settings")

    ModConfigMenu.AddSetting(modSettings, "Settings", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function() return persistentData["chancePerSecond"] end,
        Minimum = 0, Maximum = 500,
        Display = function() return "Chance per second: " .. persistentData["chancePerSecond"] * 100 end,
        OnChange = function(currentNum)
            persistentData["chancePerSecond"] = currentNum
            mod:SaveData(json.encode(persistentData))
        end,
        Info = {"Higher number = lower chance"}
    })

    ModConfigMenu.AddSetting(modSettings, "Settings", {
        Type = ModConfigMenu.OptionType.NUMBER,
        CurrentSetting = function() return persistentData["volume"] end,
        Minimum = 0,
        Maximum = 30,
        Display = function()
            return "Volume: " .. (persistentData["volume"] * 10) .. "%"
        end,
        OnChange = function(currentNum)
            persistentData["volume"] = currentNum
            mod:SaveData(json.encode(persistentData))
        end,
        Info = {
            "Jumpscare volume in percent",
            "10 = 100% (default)",
            "Recommended: 80% - 100%"
        }
    })
end

function mod:loadConfiguration()
    if mod:HasData() then
        persistentData = json.decode(mod:LoadData())
    else
        persistentData = defaultConfig
    end

    if persistentData["configVersion"] == nil or persistentData["configVersion"] ~= defaultConfig["configVersion"] then
        print("[Olezka Libo] Upgrading config to v" .. defaultConfig["configVersion"])
        persistentData["configVersion"] = defaultConfig["configVersion"]
        for key, value in pairs(defaultConfig) do
            if persistentData[key] == nil then
                persistentData[key] = value
            end
        end
    end
    mod:SaveData(json.encode(persistentData))
end

function mod:GetSeed()
    local seeds = game:GetSeeds()
    local startSeed = seeds:GetStartSeed()
    rng:SetSeed(startSeed, 35)
end

function mod:onGameEnd()
    sfxManager:Stop(jumpscareSound)
    sfxManager:Stop(static)
    jumpscareDebounce = false
    isSpritePlaying = false
    phase = 1
end

mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.loadConfiguration)
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.GetSeed)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.randomScare)
mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.render)