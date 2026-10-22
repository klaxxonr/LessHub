local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local remotesExist = pcall(function()
    return ReplicatedStorage.Remotes.Ball.Tackle ~= nil
end)

StarterGui:SetCore("SendNotification", {
    Title = "Test Sonucu",
    Text = remotesExist and "Remotelar Bulundu!" or "Remotelar Yolu Degismis!",
    Duration = 5
})
