local QBCore = exports['qb-core']:GetCoreObject()
QBCore.Commands.Add("create:vehshop", "Create a Vehicle Shop",{}, false, function(source)
  TriggerClientEvent("VehicleShops:CreateNew",source)
end, "admin")