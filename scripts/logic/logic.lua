-- put logic functions here using the Lua API: https://github.com/black-sliver/PopTracker/blob/master/doc/PACKS.md#lua-interface
-- don't be afraid to use custom logic functions. it will make many things a lot easier to maintain, for example by adding logging.
-- to see how this function gets called, check: locations/locations.json
-- example:
function has_more_then_n_consumable(n)
    local count = Tracker:ProviderCountForCode('consumable')
    local val = (count > tonumber(n))
    if ENABLE_DEBUG_LOG then
        print(string.format("called has_more_then_n_consumable: count: %s, n: %s, val: %s", count, n, val))
    end
    if val then
        return 1 -- 1 => access is in logic
    end
    return 0 -- 0 => no access
end

function no_scroll(levelCode)
    local scrollMode = Tracker:FindObjectForCode("set-scroll-mode").CurrentStage
    local levelNotScroll = has("cancelautoscroll-"..levelCode)
    if scrollMode == 6 then
        return true
    elseif scrollMode == 3 or scrollMode == 1 then
        return has("cancelautoscroll") or levelNotScroll
    else
        return levelNotScroll
    end
end

function HasScroll(levelCode)
    return not no_scroll(levelCode)
end

function has_pipe_up()
    local pipeMode = Tracker:FindObjectForCode("set-pipe-traversal").CurrentStage

    return pipeMode == 0 or (pipeMode == 1 and has("pipetraversal")) or has("pipetraversal-up")
end

function has_pipe_down()
    local pipeMode = Tracker:FindObjectForCode("set-pipe-traversal").CurrentStage

    return pipeMode == 0 or (pipeMode == 1 and has("pipetraversal")) or has("pipetraversal-down")
end

function has_pipe_left()
    local pipeMode = Tracker:FindObjectForCode("set-pipe-traversal").CurrentStage

    return pipeMode == 0 or (pipeMode == 1 and has("pipetraversal")) or has("pipetraversal-left")
end

function has_pipe_right()
    local pipeMode = Tracker:FindObjectForCode("set-pipe-traversal").CurrentStage

    return pipeMode == 0 or (pipeMode == 1 and has("pipetraversal")) or has("pipetraversal-right")
end

function has_midway(code)
    return has_all(code.."midwaybell", "set-shuffle-midways")
end

function has_castle_midway()
    return has("set-mario-castle-midway") and has_midway("mariocastle")
end

function has_goal()
    if Tracker:FindObjectForCode("set-gc-goal").CurrentStage == 2 then
        return has("mariocoinfragment", Tracker:FindObjectForCode("set-mc-frag-required").AcquiredCount)
    else
        return has("goalcoin", Tracker:FindObjectForCode("set-gc-required").AcquiredCount)
    end
end

function can_take_hit(count)
    if not count then
        return has_any("mushroom", "carrot", "fireflower")
    end
    local powerups = 0
    if has("mushroom") then
        powerups = powerups + 1
    end
    if has_any("carrot", "fireflower") then
        powerups = powerups + 1
    end
    count = tonumber(count)
    return powerups >= count
end

function can_spin()
    return has_any("mushroom", "fireflower")
end

function not_shuffle_midways()
    return not Tracker:FindObjectForCode("set-shuffle-midways").Active
end

function not_blocked_by_sharks()
    local sharks = Tracker:ProviderCountForCode("set-tz1-sharks")
    if sharks == 0 or has("carrot") then
        return true
    else
        return can_take_hit(sharks)
    end
end

function AreCoinsAvailable(reachableCoins, location)
    if Archipelago.PlayerNumber == -1 then
        local coinLoc = Tracker:FindObjectForCode(location)
        if coinLoc ~= nil then
            if coinLoc.AvailableChestCount == 0 then
                UpdateAvailableCoins(0, location)
            else
                UpdateAvailableCoins(reachableCoins, location)
            end
            return (coinLoc.ChestCount - coinLoc.AvailableChestCount) < reachableCoins
        end
        return false
    end
    local coinLoc = COIN_LOCATIONS[location]
    if coinLoc == nil then
        UpdateAvailableCoins(0, location)
        return true
    end
    local count = 0
    for _, v in ipairs(coinLoc) do
        if v <= reachableCoins then
            count = v
        elseif count ~= 0 then
            UpdateAvailableCoins(count, location)
            return true
        else
            UpdateAvailableCoins(0, location)
            return false
        end
    end
    UpdateAvailableCoins(count, location)
    return true
end

function UpdateAvailableCoins(coins, location)
    local availableLoc = nil
    for _, mapping in ipairs(COIN_MAPPING_LOCATIONS) do
        if mapping[1] == location then
            availableLoc = Tracker:FindObjectForCode(mapping[2])
        end
    end
    if availableLoc == nil then
        return
    end
    availableLoc.AvailableChestCount = coins
end

function UpdateAvailableCoinsToMax(location)
    local availableLoc = nil
    for _, mapping in ipairs(COIN_MAPPING_LOCATIONS) do
        if mapping[1] == location then
            availableLoc = Tracker:FindObjectForCode(mapping[2])
        end
    end
    if availableLoc == nil then
        return
    end
    if Archipelago.PlayerNumber == -1 then
        local coinLoc = Tracker:FindObjectForCode(location)
        if coinLoc ~= nil and coinLoc.AvailableChestCount == 0 then
            availableLoc.AvailableChestCount = 0
        else
            availableLoc.AvailableChestCount = availableLoc.ChestCount
        end
        return
    end
    local coinLoc = COIN_LOCATIONS[location]
    if coinLoc == nil or #coinLoc == 0 then
        availableLoc.AvailableChestCount = 0
        return
    end

    availableLoc.AvailableChestCount = coinLoc[#coinLoc]
end

function sceniccourse_coins()
    UpdateAvailableCoinsToMax("@Scenic Course/Coinsanity/Coins")
    return true
end

function mushroomzone_coins()
    local reachableCoins = 38
    local noScroll = no_scroll("mushroomzone")
    if has_any("mushroom", "fireflower") or noScroll then
        reachableCoins = reachableCoins + 2
    end
    if has_pipe_down() then
        reachableCoins = reachableCoins + 19
        if has_pipe_up() or noScroll then
            reachableCoins = reachableCoins + 5
        end
        if has_pipe_up() then
            reachableCoins = reachableCoins + 20
            if noScroll then
                reachableCoins = reachableCoins + 4
            end
        end
    end
    return AreCoinsAvailable(reachableCoins, "@Mushroom Zone/Coinsanity/Coins")
end

function treezone1_coins()
    local reachableCoins = 87
    if no_scroll("treezone1") then
        UpdateAvailableCoinsToMax("@Tree Zone 1/Coinsanity/Coins")
        return true
    end

    return AreCoinsAvailable(reachableCoins, "@Tree Zone 1/Coinsanity/Coins")
end

function treezone2_coins()
    local reachableCoins = 18
    local autoScroll = HasScroll("treezone2")

    if has_pipe_right() then
        reachableCoins = reachableCoins + 38
        if has("carrot") then
            reachableCoins = reachableCoins + 12
            if not autoScroll then
                reachableCoins = reachableCoins + 30
            end
        end
    elseif has_midway("treezone2") then
        reachableCoins = reachableCoins + 30
        if not autoScroll then
            reachableCoins = reachableCoins + 8
        end
    end

    return AreCoinsAvailable(reachableCoins, "@Tree Zone 2/Coinsanity/Coins")
end

function treezone3_coins()
    local location = "@Tree Zone 3/Coinsanity/Coins"
    if HasScroll("treezone3") then
        return AreCoinsAvailable(4, location)
    end
    if has("carrot") then
        UpdateAvailableCoinsToMax(location)
        return true
    elseif has_any("mushroom", "fireflower") then
        return AreCoinsAvailable(21, location)
    end
    return AreCoinsAvailable(19, location)
end

function treezone4_coins()
    local autoScroll = HasScroll("treezone4")
    local entryway = 14
    local hall = 4
    local firstTripDownstairs = 31
    local secondTripDownstairs = 15
    local downstairsWithAutoScroll = 12
    local finalRoom = 10

    local reachableCoinsFromStart = 0
    local reachableCoinsFromBell = 0

    if has_pipe_up() then
        reachableCoinsFromStart = reachableCoinsFromStart + entryway
        if has_pipe_right() then
            reachableCoinsFromStart = reachableCoinsFromStart + hall
            if has_pipe_down() then
                if autoScroll then
                    reachableCoinsFromStart = reachableCoinsFromStart + downstairsWithAutoScroll
                else
                    reachableCoinsFromStart = reachableCoinsFromStart + finalRoom + firstTripDownstairs + secondTripDownstairs
                end
            end
        end
    end
    if has_midway("treezone4") then
        if has_pipe_down() and (autoScroll or not has_pipe_left()) then
            reachableCoinsFromBell = reachableCoinsFromBell + finalRoom
        elseif has_pipe_left() and not autoScroll then
            if has_pipe_down() then
                reachableCoinsFromBell = reachableCoinsFromBell + firstTripDownstairs
                if has_pipe_right() then
                    reachableCoinsFromBell = reachableCoinsFromBell + entryway + hall
                    if has_pipe_up() then
                        reachableCoinsFromBell = reachableCoinsFromBell + secondTripDownstairs + finalRoom
                    end
                end
            else
                reachableCoinsFromBell = reachableCoinsFromBell + entryway + hall
            end
        end
    end

    return AreCoinsAvailable(math.max(reachableCoinsFromBell, reachableCoinsFromStart), "@Tree Zone 4/Coinsanity/Coins")
end

function treezone5_coins()
    local autoScroll = HasScroll("treezone5")
    local reachableCoins = 0

    if has_any("mushroom", "fireflower") then
        reachableCoins = reachableCoins + 2
    end
    if has("carrot") then
        reachableCoins = reachableCoins + 18
        if has_pipe_up() and not autoScroll then
            reachableCoins = reachableCoins + 13
        end
    elseif has_pipe_up() then
        reachableCoins = reachableCoins + 13
    end

    return AreCoinsAvailable(reachableCoins, "@Tree Zone 5/Coinsanity/Coins")
end

function treezonesecret_coins()
    UpdateAvailableCoinsToMax("@Tree Zone Secret Course/Coinsanity/Coins")
    return true
end

function pumpkinzone1_coins()
    local autoScroll = HasScroll("pumpkinzone1")
    if autoScroll then
        return has_midway("pumpkinzone1") and AreCoinsAvailable(12, "@Pumpkin Zone 1/Coinsanity/Coins")
    end
    local reachableCoins = 0
    if has_midway("pumpkinzone1") or has_pipe_down() then
        reachableCoins = reachableCoins + 38
        if has_pipe_up() then
            reachableCoins = reachableCoins + 2
        end
    end

    return AreCoinsAvailable(reachableCoins, "@Pumpkin Zone 1/Coinsanity/Coins")
end

function pumpkinzone2_coins()
    local autoScroll = HasScroll("pumpkinzone2")
    local reachableCoins =  17
    if has_pipe_down() then
        if not autoScroll then
            reachableCoins = reachableCoins + 7
        end
        if (has_pipe_up() or autoScroll) and has("waterphysics") then
            reachableCoins = reachableCoins + 6
            if has_pipe_right() and not autoScroll then
                reachableCoins = reachableCoins + 1
                if has_any("mushroom", "fireflower") then
                    reachableCoins = reachableCoins + 5
                end
            end
        end
    end

    return AreCoinsAvailable(reachableCoins, "@Pumpkin Zone 2/Coinsanity/Coins")
end

function pumpkinzone3_coins()
    local autoScroll = HasScroll("pumpkinzone3")
    local reachableCoins = 38
    if has_pipe_up() and ((not autoScroll) or has_pipe_down()) then
        reachableCoins = reachableCoins + 12
    end
    if has_pipe_down() and not autoScroll then
        reachableCoins = reachableCoins + 11
    end

    return AreCoinsAvailable(reachableCoins, "@Pumpkin Zone 3/Coinsanity/Coins")
end

function pumpkinzone4_coins()
    local reachableCoins = 29
    if has_pipe_down() then
        if HasScroll("pumpkinzone4") then
            if has_pipe_up() then
                reachableCoins = reachableCoins + 16
            else
                reachableCoins = reachableCoins + 4
            end
        else
            reachableCoins = reachableCoins + 28
            if has_pipe_up() then
                reachableCoins = reachableCoins + 16
            end
        end
    end

    return AreCoinsAvailable(reachableCoins, "@Pumpkin Zone 4/Coinsanity/Coins")
end

function pumpkinzonesecret1_coins()
    if has("carrot") then
        if HasScroll("pumpkinzonesecret1") then
            return AreCoinsAvailable(172, "@Pumpkin Zone Secret Course 1/Coinsanity/Coins")
        end
        UpdateAvailableCoinsToMax("@Pumpkin Zone Secret Course 1/Coinsanity/Coins")
        return true
    end
    return AreCoinsAvailable(40, "@Pumpkin Zone Secret Course 1/Coinsanity/Coins")
end

function pumpkinzonesecret2_coins()
    UpdateAvailableCoinsToMax("@Pumpkin Zone Secret Course 2/Coinsanity/Coins")
    return true
end

function mariozone1_coins()
    local autoScroll = HasScroll("mariozone1")
    local reachableCoins = 0
    if has_pipe_right() or (has_pipe_left() and has_midway("mariozone1") and not autoScroll) then
        reachableCoins = reachableCoins + 32
    end
    if has_pipe_right() and (has_any("mushroom", "fireflower", "carrot") or not autoScroll) then
        reachableCoins = reachableCoins + 8
        if has("carrot") then
            reachableCoins = reachableCoins + 28
        else
            reachableCoins = reachableCoins + 12
        end
        if has("fireflower") and not autoScroll then
            reachableCoins = reachableCoins + 46
        end
    end

    return AreCoinsAvailable(reachableCoins, "@Mario Zone 1/Coinsanity/Coins")
end

function mariozone2_coins()
    UpdateAvailableCoinsToMax("@Mario Zone 2/Coinsanity/Coins")
    return true
end

function mariozone3_coins()
    local autoScroll = HasScroll("mariozone3")
    local reachableCoins = 10
    local reachableSpikeCoins = 0
    if has("carrot") then
        reachableSpikeCoins = 15
    else
        local items = Tracker:ProviderCountForCode("set-mz3-claws")
        if has("mushroom") then
            items = items + 1
        end
        if has("fireflower") then
            items = items + 1
        end
        reachableSpikeCoins = math.min(3, items) * 5
    end
    reachableCoins = reachableCoins + reachableSpikeCoins
    if not autoScroll then
        reachableCoins = reachableCoins + 10
    end
    if has("fireflower") then
        reachableCoins = reachableCoins + 22
        if autoScroll then
            reachableCoins = reachableCoins - (3 + reachableSpikeCoins)
        end
    end
    return AreCoinsAvailable(reachableCoins, "@Mario Zone 3/Coinsanity/Coins")
end

function mariozone4_coins()
    if no_scroll("mariozone4") then
        UpdateAvailableCoinsToMax("@Mario Zone 4/Coinsanity/Coins")
        return true
    end
    return AreCoinsAvailable(60, "@Mario Zone 4/Coinsanity/Coins")
end

function turtlezone1_coins()
    local autoScroll = HasScroll("turtlezone1")
    local reachableCoins = 30
    if not_blocked_by_sharks() then
        reachableCoins = reachableCoins + 13
        if autoScroll then
            reachableCoins = reachableCoins - 1
        end
    end
    if has_any("waterphysics", "carrot") then
        reachableCoins = reachableCoins + 10
    end
    if has("carrot") then
        reachableCoins = reachableCoins + 24
        if autoScroll then
            reachableCoins = reachableCoins - 10
        end
    end

    return AreCoinsAvailable(reachableCoins, "@Turtle Zone 1/Coinsanity/Coins")
end

function turtlezone2_coins()
    local autoScroll = HasScroll("turtlezone2")
    local reachableCoins = 2
    if autoScroll then
        if has("waterphysics") then
            reachableCoins = reachableCoins + 6
        end
    else
        reachableCoins = reachableCoins + 2
        if has("waterphysics") then
            reachableCoins = reachableCoins + 20
        elseif has_midway("turtlezone2") then
            reachableCoins = reachableCoins + 4
        end
        if has_pipe_right() and has_pipe_down() and (has("waterphysics") or has_midway("turtlezone2")) then
            reachableCoins = reachableCoins + 1
            if has_pipe_left() and has_pipe_up() then
                reachableCoins = reachableCoins + 1
                if has("waterphysics") then
                    reachableCoins = reachableCoins + 1
                end
            end
        end
    end
    return AreCoinsAvailable(reachableCoins, "@Turtle Zone 2/Coinsanity/Coins")
end

function turtlezone3_coins()
    if has_any("waterphysics", "mushroom", "fireflower", "carrot") then
        UpdateAvailableCoinsToMax("@Turtle Zone 3/Coinsanity/Coins")
        return true
    end
    return AreCoinsAvailable(51, "@Turtle Zone 3/Coinsanity/Coins")
end

function turtlezonesecret_coins()
    local reachableCoins = 53
    if has("carrot") then
        reachableCoins = reachableCoins + 44
    elseif has("fireflower") then
        reachableCoins = reachableCoins + 36
    end

    return AreCoinsAvailable(reachableCoins, "@Turtle Zone Secret Course/Coinsanity/Coins")
end

function hippozone_coins()
    local reachableCoins = 4
    if HasScroll("hippozone") then
        if has("hippobubble") then
            reachableCoins = 160
        elseif has("carrot") then
            reachableCoins = 90
        elseif has("waterphysics") then
            reachableCoins = 28
        end
    else
        if has_any("waterphysics", "hippobubble", "carrot") then
            reachableCoins = reachableCoins + 108
            if has_any("mushroom", "fireflower", "hippobubble") then
                reachableCoins = reachableCoins + 6
            end
        end
        if has_all("fireflower", "waterphysics") then
            reachableCoins = reachableCoins + 1
        end
        if has("hippobubble") then
            reachableCoins = reachableCoins + 52
        end
    end

    return AreCoinsAvailable(reachableCoins, "@Hippo Zone/Coinsanity/Coins")
end

function spacezone1_coins()
    local autoScroll = HasScroll("spacezone1")
    local levelCode = "@Space Zone 1/Coinsanity/Coins"
    if autoScroll then
        local reachableCoins = 0
        reachableCoins = reachableCoins + 12
        if has_any("carrot", "spacephysics") then
            reachableCoins = reachableCoins + 20
        end
        if has("spacephysics") then
            reachableCoins = reachableCoins + 40
        end
        return AreCoinsAvailable(reachableCoins, levelCode)
    end
    if has_any("carrot", "spacephysics") then
        UpdateAvailableCoinsToMax(levelCode)
        return true
    end
    if has_any("mushroom", "fireflower") and AreCoinsAvailable(50, levelCode) then
        return true
    end
    return AreCoinsAvailable(21, levelCode)
end

function spacezone2_coins()
    local autoScroll = HasScroll("spacezone2")
    local reachableCoins = 12
    if has_any("mushroom", "fireflower", "carrot", "spacephysics") then
        reachableCoins = reachableCoins + 15
        if has("spacephysics") or not autoScroll then
            reachableCoins = reachableCoins + 4
        end
    end
    if has("spacephysics") or (has("mushroom") and has_any("fireflower", "carrot")) then
        reachableCoins = reachableCoins + 3
    end
    if has("spacephysics") then
        reachableCoins = reachableCoins + 79
        if not autoScroll then
            reachableCoins = reachableCoins + 21
        end
    end
    return AreCoinsAvailable(reachableCoins, "@Space Zone 2/Coinsanity/Coins")
end

function spacezonesecret_coins()
    if no_scroll("spacezonesecret") then
        UpdateAvailableCoinsToMax("@Space Zone Secret Course/Coinsanity/Coins")
        return true
    end
    return AreCoinsAvailable(96, "@Space Zone Secret Course/Coinsanity/Coins")
end

function macrozone1_coins()
    local autoScroll = HasScroll("macrozone1")
    local reachableCoins = 0
    if has_pipe_down() then
        reachableCoins = reachableCoins + 69
        if autoScroll then
            if has_any("mushroom", "fireflower") then
                reachableCoins = reachableCoins + 5
            end
        else
            reachableCoins = reachableCoins + 9
            if has("fireflower") then
                reachableCoins = reachableCoins + 19
            end
        end
    elseif has_midway("macrozone1") then
        if autoScroll then
            reachableCoins = reachableCoins + 16
            if has_any("mushroom", "fireflower") then
                reachableCoins = reachableCoins + 5
            end
        else
            reachableCoins = reachableCoins + 67
        end
    end

    return AreCoinsAvailable(reachableCoins, "@Macro Zone 1/Coinsanity/Coins")
end

function macrozone2_coins()
    local levelCode = "@Macro Zone 2/Coinsanity/Coins"
    local autoScroll = no_scroll("macrozone2")

    if has_pipe_up() and has("waterphysics") and not autoScroll then
        if has_pipe_down() then
            UpdateAvailableCoinsToMax(levelCode)
            return true
        end
        if has_midway("macrozone2") then
            return AreCoinsAvailable(42, levelCode)
        end
    end
    return AreCoinsAvailable(27, levelCode)
end

function macrozone3_coins()
    local autoScroll = HasScroll("macrozone3")
    local reachableCoins = 7

    if not autoScroll then
        reachableCoins = reachableCoins + 17
    end
    if has_pipe_up() and has_pipe_down() then
        if autoScroll then
            reachableCoins = reachableCoins + 56
        else
            UpdateAvailableCoinsToMax("@Macro Zone 3/Coinsanity/Coins")
            return true
        end
    elseif has_pipe_up() then
        if autoScroll then
            reachableCoins = reachableCoins + 12
        else
            reachableCoins = reachableCoins + 36
        end
    elseif has_pipe_down() then
        reachableCoins = reachableCoins + 18
    end
    if has_midway("macrozone3") then
        reachableCoins = math.max(reachableCoins, 30)
    end
    return AreCoinsAvailable(reachableCoins, "@Macro Zone 3/Coinsanity/Coins")
end

function macrozone4_coins()
    local reachableCoins = 61
    if HasScroll("macrozone4") then
        reachableCoins = reachableCoins - 8
        if has("carrot") then
            reachableCoins = reachableCoins + 6
        end
    end

    return AreCoinsAvailable(reachableCoins, "@Macro Zone 4/Coinsanity/Coins")
end

function macrozonesecret_coins()
    if has_any("mushroom", "fireflower") then
        UpdateAvailableCoinsToMax("@Macro Zone Secret Course/Coinsanity/Coins")
        return true
    end
    return false
end