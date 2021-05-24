local Plater = _G.Plater
local DF = DetailsFramework
local COMM_PLATER_PREFIX = "PLT"
local COMM_SCRIPT_GROUP_EXPORTED = "GE"

local LibAceSerializer = LibStub:GetLibrary ("AceSerializer-3.0")


function Plater.CreateCommHeader(prefix, encodedString)
    return LibAceSerializer:Serialize(prefix, UnitName("player"), GetRealmName(), UnitGUID("player"), encodedString)
end

function Plater.SendComm(uniqueId, ...)
    --create the payload, the first index is always the hook id
    local arguments = {uniqueId, ...}

    --compress the msg
    local msgEncoded = Plater.CompressData(arguments, "comm")
    if (not msgEncoded) then
        return
    end

    --create the comm header
    local header = Plater.CreateCommHeader(Plater.COMM_SCRIPT_MSG, msgEncoded)

    --send the message
    if (IsInRaid()) then
        Plater:SendCommMessage(COMM_PLATER_PREFIX, header, "RAID")

    elseif (IsInGroup()) then
        Plater:SendCommMessage(COMM_PLATER_PREFIX, header, "PARTY")
    end

    return true
end

--when received a message from a script
function Plater.MessageReceivedFromScript(prefix, playerName, playerRealm, playerGUID, message)
    --localize the script

    --trigger the event 'Comm Message'
end


--> Plater comm handler
    Plater.CommHandler = {
        [COMM_SCRIPT_GROUP_EXPORTED] = Plater.ScriptReceivedFromGroup,
        [Plater.COMM_SCRIPT_MSG] = Plater.ScriptReceivedMessage,
    }

    function Plater:CommReceived(commPrefix, dataReceived, channel, source)
        local dataDeserialized = {LibAceSerializer:Deserialize(dataReceived)}

        local successfulDeserialize = dataDeserialized[1]

        if (not successfulDeserialize) then
            Plater:Msg("failed to deserialize a comm received.")
            return
        end

        local prefix =  dataDeserialized[2]
        local unitName = source
        local realmName = dataDeserialized[4]
        local unitGUID = dataDeserialized[5]
        local encodedData = dataDeserialized[6]

        local func = Plater.CommHandler[prefix]

        if (func) then
            local runOkay, errorMsg = pcall(func, prefix, unitName, realmName, unitGUID, encodedData)
            if (not runOkay) then
                Plater:Msg("error on something")
            end
        end
    end

    --register the comm
    Plater:RegisterComm(COMM_PLATER_PREFIX, "CommReceived")




-- ~compress ~zip ~export ~import ~deflate ~serialize
function Plater.CompressData (data, dataType)
    local LibDeflate = LibStub:GetLibrary ("LibDeflate")
    
    if (LibDeflate and LibAceSerializer) then
        local dataSerialized = LibAceSerializer:Serialize (data)
        if (dataSerialized) then
            local dataCompressed = LibDeflate:CompressDeflate (dataSerialized, {level = 9})
            if (dataCompressed) then
                if (dataType == "print") then
                    local dataEncoded = LibDeflate:EncodeForPrint (dataCompressed)
                    return dataEncoded
                    
                elseif (dataType == "comm") then
                    local dataEncoded = LibDeflate:EncodeForWoWAddonChannel (dataCompressed)
                    return dataEncoded
                end
            end
        end
    end
end


function Plater.DecompressData (data, dataType)
    local LibDeflate = LibStub:GetLibrary ("LibDeflate")
    
    if (LibDeflate and LibAceSerializer) then
        
        local dataCompressed
        
        if (dataType == "print") then
            dataCompressed = LibDeflate:DecodeForPrint (data)
            if (not dataCompressed) then
                Plater:Msg ("couldn't decode the data.")
                return false
            end

        elseif (dataType == "comm") then
            dataCompressed = LibDeflate:DecodeForWoWAddonChannel (data)
            if (not dataCompressed) then
                Plater:Msg ("couldn't decode the data.")
                return false
            end
        end
        
        local dataSerialized = LibDeflate:DecompressDeflate (dataCompressed)
        if (not dataSerialized) then
            Plater:Msg ("couldn't uncompress the data.")
            return false
        end
        
        local okay, data = LibAceSerializer:Deserialize (dataSerialized)
        if (not okay) then
            Plater:Msg ("couldn't unserialize the data.")
            return false
        end
        
        return data
    end
end