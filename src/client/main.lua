local QBCore = exports['qb-core']:GetCoreObject()
local data = {}
Citizen.CreateThread(function()
  while QBCore == nil do
    TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)
    Citizen.Wait(0)
  end
end)

VehicleShops = {}
VehicleShops.SpawnedVehicles = {}
local veshare = nil
local mods = nil
VehicleShops.Init = function()
  local start = GetGameTimer()
  while (GetGameTimer() - start) < 2000 do Wait(0); end
  QBCore.Functions.TriggerCallback("VehicleShops:GetVehicleShops",function(shopData,kashId)
    VehicleShops.KashId = (kashId or false)
    VehicleShops.Shops  = (shopData.shops or {})
    VehicleShops.WarehouseVehicles = (shopData.vehicles or {})
    VehicleShops.RefreshBlips()
    VehicleShops.Update()
  end)
end



VehicleShops.WarehouseRefresh = function(data)
  VehicleShops.WarehouseVehicles = data
  if InsideWarehouse then
    QBCore.Functions.Notify("Warehouse stock refreshsed. You must re-enter the building.")
    VehicleShops.LeaveWarehouse()
  end
end

VehicleShops.Update = function()
  while true do
    local wait_time = 0
    local plyPos = GetEntityCoords(PlayerPedId())
    if InsideWarehouse then
      local closest,closestDist
      for k,v in pairs(ShopVehicles) do
        local dist = Vdist(plyPos.x,plyPos.y,plyPos.z,v.pos.x,v.pos.y,v.pos.z)
        if not closestDist or dist < closestDist then
          closest = v
          closestDist = dist
        end
      end
      if closest and closestDist and closestDist < 5.0 then
        local min,max = GetModelDimensions(GetHashKey(closest.model))
        local up = vector3(0.0,0.0,0.2)
        local posA = closest.pos.xyz + up
        DrawText3D(posA.x,posA.y,posA.z + max.z, closest.name.." [$~g~"..closest.price.."~s~]\n[~g~G~s~] To buy",15.0)
        if IsControlJustPressed(0,47) then
          VehicleShops.PurchaseStock(closest)
        end
      end
    else
      local closest,closestDist = VehicleShops.GetClosestShop()
      if closestDist < 100.0 then
        local closestVeh,vehDist
        for k,v in pairs(VehicleShops.Shops[closest].displays) do
          local dist = Vdist(plyPos.x,plyPos.y,plyPos.z,v.location.x,v.location.y,v.location.z)
          if not vehDist or dist < vehDist then
            closestVeh = k
            vehDist = dist
          end
          if not VehicleShops.SpawnedVehicles[v.vehicle.plate] then
            RequestModel(v.vehicle.model)
            while not HasModelLoaded(v.vehicle.model) do Wait(0); end
            local veh = CreateVehicle(v.vehicle.model, v.location.x,v.location.y,v.location.z,v.location.heading, false,false)
            FreezeEntityPosition(veh,true)
            SetEntityAsMissionEntity(veh,true,true)
            SetVehicleUndriveable(veh,true)
            SetVehicleDoorsLocked(veh,2)
            SetEntityProofs(veh,true,true,true,true,true,true,true,true)
            SetVehicleTyresCanBurst(veh,false)
            SetModelAsNoLongerNeeded(v.vehicle.model)
            QBCore.Functions.SetVehicleProperties(veh,v.vehicle)
            TriggerEvent('vehiclekeys:client:SetOwner', v.vehicle.plate)
            TriggerEvent('vehiclekeys:client:ToggleEngine')
            v.entity = veh
            VehicleShops.SpawnedVehicles[v.vehicle.plate] = veh
          else
            if not last_spawn_message then
              last_spawn_message = GetGameTimer()
            else
              if GetGameTimer() - last_spawn_message > 1000 then
                last_spawn_message = GetGameTimer()
              end
            end
          end
        end
        if not VehicleShops.Moving and vehDist and vehDist < 10.0 then
          local pos = VehicleShops.Shops[closest].displays[closestVeh].location
          local label = GetLabelText(GetDisplayNameFromVehicleModel(VehicleShops.Shops[closest].displays[closestVeh].vehicle.model))
          if VehicleShop.UseCustomFile then
            veshare = Customs.VehicleModels[VehicleShops.Shops[closest].displays[closestVeh].vehicle.model].name
            mods = Customs.VehicleModels[VehicleShops.Shops[closest].displays[closestVeh].vehicle.model].brand
          else
            veshare = Customs.VehicleModels[VehicleShops.Shops[closest].displays[closestVeh].vehicle.model].name
            mods = Customs.VehicleModels[VehicleShops.Shops[closest].displays[closestVeh].vehicle.model].brand
          end
          local price = (VehicleShops.Shops[closest].displays[closestVeh].price or false)
          local min,max = GetModelDimensions( VehicleShops.Shops[closest].displays[closestVeh].vehicle.model )
          if mods ~= nil then
            DrawText3D(pos.x,pos.y,pos.z + max.z, mods .." | "..veshare.. (price and " [$~g~"..price.."~s~]\n[~g~G~s~] To Buy" or ''),15.0)
          else
            DrawText3D(pos.x,pos.y,pos.z + max.z, veshare.. (price and " [$~g~"..price.."~s~]\n[~g~G~s~] To Buy" or ''),15.0)
          end
          if price then
            if IsControlJustReleased(0,47) then
              local doCont = true
              while doCont do
                local dist = Vdist(GetEntityCoords(PlayerPedId()),vector3(pos.x,pos.y,pos.z))
                if dist > 10.0 then
                  doCont = false
                end 
                DrawText3D(pos.x,pos.y,pos.z + max.z, veshare .. (price and " [$~g~"..price.."~s~]\n[~g~G~s~] Confirm" or ''),15.0)
                if IsControlJustPressed(0,47) then
                  Wait(100)
                  local ent = VehicleShops.SpawnedVehicles[VehicleShops.Shops[closest].displays[closestVeh].vehicle.plate]
                  VehicleShops.PurchaseDisplay(closest,closestVeh,ent)
                  doCont = false
                end
                Wait(0)
              end
            end
          end
        end
      else
        wait_time = 1000
      end
    end
    Wait(wait_time)
  end
end

VehicleShops.GetClosestShop = function()
  local pos = GetEntityCoords(PlayerPedId())
  local closest,closestDist
  for k,v in pairs(VehicleShops.Shops) do
    local dist = Vdist(pos.x,pos.y,pos.z,v.locations.entry.x,v.locations.entry.y,v.locations.entry.z)
    if not closestDist or dist < closestDist then
      closestDist = dist
      closest = k
    end
  end
  return (closest or false),(closestDist or 9999)
end

VehicleShops.PurchasedShop = function(shop)
  local closest,dist = VehicleShops.GetClosestShop()
  QBCore.Functions.TriggerCallback("VehicleShops:PurchaseShop",function(can_buy)
    if can_buy then
      QBCore.Functions.Notify(string.format("You purchased a Vehicle Shop for $%i.",VehicleShops.Shops[closest].price))
    else
      QBCore.Functions.Notify("No puedo pagar eso.")
    end
  end,closest)
end

VehicleShops.PurchaseStockVehicle = function(vehicle_data,shop_key)
  if VehicleShops.Shops[shop_key].funds >= vehicle_data.price then
    local label = GetLabelText(GetDisplayNameFromVehicleModel(vehicle_data.model))
    QBCore.Functions.Notify("You bought "..label.." for $"..vehicle_data.price," successfully")
    local plyPed = PlayerPedId()
    local plyPos = GetEntityCoords(plyPed)
    DoScreenFadeOut(500)
    Wait(500)
    local props = QBCore.Functions.GetVehicleProperties(vehicle_data.ent)
    QBCore.Functions.TriggerCallback("VehicleShops:GenerateNewPlate",function(newPlate)
      props.plate = newPlate
      RequestModel(props.model)
      while not HasModelLoaded(props.model) do Wait(0); end
      local newVeh = CreateVehicle(props.model,plyPos.x,plyPos.y,plyPos.z + 50.,0.0,true,true)
      props.mileage = 0
      props.serviced_at = 0
      props.class = GetVehicleClass(newVeh)
      TriggerServerEvent("VehicleShops:VehiclePurchased",shop_key,vehicle_data.key,props)
      QBCore.Functions.SetVehicleProperties(newVeh,props)
      TaskWarpPedIntoVehicle(plyPed,newVeh,-1)
      Wait(500)
      local targetPos = Warehouse.purchasedSpawns[math.random(#Warehouse.purchasedSpawns)]
      SetEntityCoordsNoOffset(newVeh,targetPos.x,targetPos.y,targetPos.z)
      SetEntityHeading(newVeh,targetPos.w)
      SetVehicleOnGroundProperly(newVeh)
      SetEntityAsMissionEntity(newVeh,true,true)
      DoScreenFadeIn(500)
      TriggerEvent("vehiclekeys:client:SetOwner", props.plate)
      TriggerEvent("vehiclekeys:client:ToggleEngine")
      InsideWarehouse = false
      VehicleShops.DespawnShop()
    end)
  else
    QBCore.Functions.Notify("Insufficient funds.","error")
  end
end

VehicleShops.PurchaseStock = function(vehicle)
  local elements = {}
  local PlayerData = QBCore.Functions.GetPlayerData()
  for key,val in pairs(VehicleShops.Shops) do
    if PlayerData.license == val.owner then
      table.insert(elements,{
        label = "[$"..val.funds.."] "..val.name,
        value = key
      })
    else
      for k,v in pairs(val.employees) do
        if v.identifier == PlayerData.license then
          table.insert(elements,{
            label = "[$"..val.funds.."] "..val.name,
            value = key
          })
        end
      end
    end
  end
  if #elements <= 0 then
    table.insert(elements,{
      label = "No shops to display."
    })
  end
  local assert = assert
  local MenuV = assert(MenuV)
  local AccountMain = MenuV:CreateMenu("Administration", '', 'topleft', 255, 0, 0, 'size-125')
  MenuV:OpenMenu(AccountMain, function()
  end)
  for k,v in ipairs(elements) do
    local button = AccountMain:AddButton({ icon = "💰 	", label = v.label, value = v ,select = function(btn)
    local current = btn.Value.value
    --print(current)
    if current then
      VehicleShops.PurchaseStockVehicle(vehicle,current)
    end
  end})
  end
end

VehicleShops.EnterWarehouse = function(...)
  local plyPed = PlayerPedId()
  QBCore.Functions.Notify("Waiting for the models to load")
  Wait(1000)
  DoScreenFadeOut(500)
  Wait(500)
  SetEntityCoordsNoOffset(plyPed, Warehouse.exit.x,Warehouse.exit.y,Warehouse.exit.z)
  SetEntityHeading(plyPed, Warehouse.exit.w)
  VehicleShops.SpawnShop()
  DoScreenFadeIn(500)
  InsideWarehouse = true
  local marker = {
    display  = false,
    location = Warehouse.exit,
    maintext = "Warehouse",
    scale    = vector3(1.5,1.5,1.5),
    distance = 1.0,
    control  = 38,
    callback = VehicleShops.LeaveWarehouse,
    args     = {"buy",k}
  }
  TriggerEvent("Markers:Add",marker,function(m)
    WarehouseMarker = m
  end)
end

VehicleShops.ManageDisplays = function(shop_key)
  local shop = VehicleShops.Shops[shop_key]
  local elements = {}
  local veshare = "" -- تعريف المتغير هنا
  for _,vehicle_data in pairs(shop.stock) do
    if vehicle_data and vehicle_data.vehicle and vehicle_data.vehicle.plate then
      if VehicleShop.UseCustomFile then
        veshare = Customs.VehicleModels[vehicle_data.vehicle.model].name
      end     
      table.insert(elements,{
        label = "["..(vehicle_data.vehicle.plate or '').."] "..veshare,
        value = vehicle_data,
        key   = _
      })
    end
  end
  if #elements == 0 then
    table.insert(elements,{
      label = "No vehicles to display."
    })
  end

  local assert = assert
  local MenuV = assert(MenuV)
  local AccountMain = MenuV:CreateMenu("To Show", '', 'topleft', 255, 0, 0, 'size-125')
  MenuV:OpenMenu(AccountMain, function()
  end)
  for k,v in ipairs(elements) do
  local button = AccountMain:AddButton({ icon = "🚗 	", label = v.label, value = v ,select = function(btn)
    local current = btn.Value
    VehicleShops.DoDisplayVehicle(shop_key,current.key,current.value)
  AccountMain:Close()
  end})
  end
end

VehicleShops.ManageDisplayed = function(shop_key)
  local shop = VehicleShops.Shops[shop_key]
  local elements = {}
  if TableCount(shop.displays) > 0 then
    for _,vehicle_data in pairs(shop.displays) do
      if vehicle_data and vehicle_data.vehicle and vehicle_data.vehicle.plate then
        if VehicleShop.UseCustomFile then
          veshare = Customs.VehicleModels[vehicle_data.vehicle.model].name
          mods = Customs.VehicleModels[vehicle_data.vehicle.model].brand
        else
          veshare = Customs.VehicleModels[vehicle_data.vehicle.model].name
        mods = Customs.VehicleModels[vehicle_data.vehicle.model].brand
        end
        table.insert(elements,{
          label = "["..vehicle_data.vehicle.plate.."] "..mods.." | "..veshare,
          value = vehicle_data,
          key   = _
        })
      end
    end
  else
    table.insert(elements,{
      label = "No vehicles to show."
    })
  end
  local assert = assert
  local MenuV = assert(MenuV)
  local AccountMain = MenuV:CreateMenu("Display", '', 'topleft', 255, 0, 0, 'size-125')
  MenuV:OpenMenu(AccountMain, function()
  end)
  for k,v in ipairs(elements) do
  local button = AccountMain:AddButton({ icon = "🚗 	", label = v.label, value = v ,select = function(btn)
    local current = btn.Value
    if current then
      VehicleShops.ManageVehicles(shop_key)
      TriggerServerEvent("VehicleShops:RemoveDisplay",shop.name,current.key)
    else
      VehicleShops.ManageVehicles(shop_key)
    end
  end})
  end
end

VehicleShops.DoSetPrice = function(shop,vehicle)
  TriggerEvent("Input:Open","Set Price","QBCore",function(p)
    local price = (p and tonumber(p) and tonumber(p) > 0 and tonumber(p) or false)
    if not price then
      QBCore.Functions.Notify("Set a valid price.")
      Wait(200)
      VehicleShops.DoSetPrice(shop,vehicle)
    else      
      
      local vehData = VehicleShops.Shops[shop].displays[vehicle]
      if VehicleShop.UseCustomFile then
        veshare = Customs.VehicleModels[vehData.vehicle.model].name
        mods = Customs.VehicleModels[vehData.vehicle.model].brand
      else
        veshare = Customs.VehicleModels[vehData.vehicle.model].name
        mods = Customs.VehicleModels[vehData.vehicle.model].brand
      end
      TriggerServerEvent("VehicleShops:SetPrice",vehicle,shop,price)
      VehicleShops.ManagementMenu(shop)
    end
  end)
end

VehicleShops.ManageShop = function(shop_key)
  local elements = {
    {label = "Add Funds",value="Add"},
    {label = "Take Funds",value="Take"},
    {label = "Check Funds",value="Check"},
  }
  local input_open = false
  local assert = assert
  local MenuV = assert(MenuV)
  local AccountMain = MenuV:CreateMenu("Store", '', 'topleft', 255, 0, 0, 'size-125')
  MenuV:OpenMenu(AccountMain, function()
  end)
  for k,v in ipairs(elements) do
  local button = AccountMain:AddButton({ icon = "💼 	", label = v.label, value = v ,select = function(btn)
    local current = btn.Value.value
    if current == "Add" then
      input_open = true
      TriggerEvent("Input:Open","Add Funds","QBCore",function(res)
        res = (res and tonumber(res) and tonumber(res) > 0 and tonumber(res) or false)
        input_open = false
        if res then
          TriggerServerEvent("VehicleShops:AddFunds",shop_key,res)
        end
        VehicleShops.ManagementMenu(shop_key)
      end)
    elseif current == "Take" then
      input_open = true
      TriggerEvent("Input:Open","Take Funds","QBCore",function(res)
        res = (res and tonumber(res) and tonumber(res) > 0 and tonumber(res) or false)
        input_open = false
        if res then
          TriggerServerEvent("VehicleShops:TakeFunds",shop_key,res)
        end
        VehicleShops.ManagementMenu(shop_key)
      end)
    elseif current == "Check" then
      QBCore.Functions.Notify("Funds: $"..VehicleShops.Shops[shop_key].funds,1)
      VehicleShops.ManageShop(shop_key)
    end
  end})
  end
end

VehicleShops.ManagePrices = function(shop_key)
  local shop = VehicleShops.Shops[shop_key]
  local elements = {}
  if TableCount(shop.displays) > 0 then
    for _,vehicle_data in pairs(shop.displays) do
      if vehicle_data and vehicle_data.vehicle and vehicle_data.vehicle.plate then
        table.insert(elements,{
          label = "["..vehicle_data.vehicle.plate.."] "..GetLabelText(GetDisplayNameFromVehicleModel(vehicle_data.vehicle.model)),
          value = vehicle_data,
          key   = _
        })
      end
    end
  else
    table.insert(elements,{
      label = "No vehicles to display."
    })
  end
  local assert = assert
  local MenuV = assert(MenuV)
  local AccountMain = MenuV:CreateMenu("Prices", '', 'topleft', 255, 0, 0, 'size-125')
  MenuV:OpenMenu(AccountMain, function()
  end)
  for k,v in ipairs(elements) do
  local button = AccountMain:AddButton({ icon = "💲 	", label = v.label, value = v ,select = function(btn)
    local current = btn.Value
    if current then
      VehicleShops.DoSetPrice(shop_key,current.key)
    else
      VehicleShops.ManageVehicles(shop_key)
    end
  
  end})
  end
end

VehicleShops.DriveVehicle = function(shop_key)
  local shop = VehicleShops.Shops[shop_key]
  local elements = {}
  if #shop.stock > 0 then
    for _,vehicle_data in pairs(shop.stock) do      
      if vehicle_data and vehicle_data.vehicle and vehicle_data.vehicle.plate then
        if VehicleShop.UseCustomFile then
          veshare = Customs.VehicleModels[vehicle_data.vehicle.model].name
          mods = Customs.VehicleModels[vehicle_data.vehicle.model].brand
        else
          veshare = Customs.VehicleModels[vehicle_data.vehicle.model].name
          mods = Customs.VehicleModels[vehicle_data.vehicle.model].brand
        end
        table.insert(elements,{
          label = "["..vehicle_data.vehicle.plate.."] "..mods.." | "..veshare,
          value = vehicle_data,
          key   = _
        })
      end
    end
  else
    table.insert(elements,{
      label = "No vehicles to display."
    })
  end
  local clicked = false
  local assert = assert
  local MenuV = assert(MenuV)
  local AccountMain = MenuV:CreateMenu("Manager", '', 'topleft', 255, 0, 0, 'size-125')
  MenuV:OpenMenu(AccountMain, function()
  end)
  for k,v in ipairs(elements) do
  local button = AccountMain:AddButton({ icon = "🚗 	", label = v.label, value = v ,select = function(btn)
    local current = btn.Value
    if current then
    QBCore.Functions.TriggerCallback("VehicleShops:DriveVehicle",function(can_drive)
    if can_drive then
        local props = current.value.vehicle
        local pos = VehicleShops.Shops[shop_key].locations.purchased
        --print(props,props.model)
        RequestModel(props.model)
        while not HasModelLoaded(props.model) do Wait(0); end
        local veh = CreateVehicle(props.model,pos.x,pos.y,pos.z,pos.heading,true,true)
        SetEntityAsMissionEntity(veh,true,true)
        QBCore.Functions.SetVehicleProperties(veh,props)
        TaskWarpPedIntoVehicle(PlayerPedId(),veh,-1)
        TriggerEvent('vehiclekeys:client:SetOwner', props.plate )
        TriggerEvent('vehiclekeys:client:ToggleEngine')
      else
        QBCore.Functions.Notify(msg)
      end
    end,shop_key,current.key)
  else
    VehicleShops.ManageVehicles(shop_key)
  end
  end})
  end
end

VehicleShops.ManageVehicles = function(shop_key)
  local clicked = false
  local elements = {
    {label = "Display Vehicles",value = "Display"},
    {label = "Save Vehicles",value = "Store"},
    {label = "Set Vehicle Prices",value = "Price"},
    {label = "Drive Stock Vehicle",value = "Drive"},
  }
  local assert = assert
  local MenuV = assert(MenuV)
  local AccountMain = MenuV:CreateMenu("Vehicles", '', 'topleft', 255, 0, 0, 'size-125')
  MenuV:OpenMenu(AccountMain, function()
  end)
  for k,v in ipairs(elements) do
  local button = AccountMain:AddButton({ icon = "🚗 	", label = v.label, value = v ,select = function(btn)
    local current = btn.Value.value
    clicked = true
    if current == "Display" then
      VehicleShops.ManageDisplays(shop_key)
    elseif current == "Store" then
      VehicleShops.ManageDisplayed(shop_key)
    elseif current == "Price" then
      VehicleShops.ManagePrices(shop_key)
    elseif current == "Drive" then
      VehicleShops.DriveVehicle(shop_key)
    end
  end})
  end
end

VehicleShops.HireMenu = function(shop_key)
  local elements = {}
  local ply = PlayerId()
  local coordinates = QBCore.Functions.GetClosestPlayer()
  if coordinates ~= nil then
    --print("-----------------")
    --print("got " ..coordinates)
    --print("-----------------")
    --print(GetPlayerName(coordinates))
    --print(GetPlayerServerId(coordinates))
  for k,v in pairs(elements) do
    if v ~= coordinates then
      table.insert(elements,{
        label = GetPlayerName(coordinates),
        value = GetPlayerServerId(coordinates)
      })
    end
  end
  --print("----elements----")
  --print("got " ..#elements)
end
  if #elements <= 0 then
    table.insert(elements,{
      label = "No players nearby."
    })
  end
  local assert = assert
  local MenuV = assert(MenuV)
  local AccountMain = MenuV:CreateMenu("Hire", '', 'topleft', 255, 0, 0, 'size-125')
  MenuV:OpenMenu(AccountMain, function()
  end)
  for k,v in ipairs(elements) do
  local button = AccountMain:AddButton({ icon = "🧑🏻‍🤝‍🧑🏿 	", label = v.label, value = v ,select = function(btn)
    local current = btn.Value.value
    clicked = true
    if current then
      TriggerServerEvent("VehicleShops:HirePlayer",shop_key,current)
      VehicleShops.ManageEmployees(shop_key)
    else
      VehicleShops.ManageEmployees(shop_key)
    end
  end})
  end
end

VehicleShops.FireMenu = function(shop_key)
  local elements = {}
  for k,v in pairs(VehicleShops.Shops[shop_key].employees) do
    if v ~= PlayerId() then
      table.insert(elements,{
        label = v.identity.firstname .. " " .. v.identity.lastname,
        value = v.identifier  
      })
    end
  end
  if #elements <= 0 then
    table.insert(elements,{
      label = "No employees to display."
    })
  end
  local assert = assert
  local MenuV = assert(MenuV)
  local AccountMain = MenuV:CreateMenu("Fire", '', 'topleft', 255, 0, 0, 'size-125')
  MenuV:OpenMenu(AccountMain, function()
  end)
  for k,v in ipairs(elements) do
  local button = AccountMain:AddButton({ icon = "🧑🏻‍🤝‍🧑🏿 	", label = v.label, value = v ,select = function(btn)
    local current = btn.Value
    if current.value then
      TriggerServerEvent("VehicleShops:FirePlayer",shop_key,current.value)
      VehicleShops.ManageEmployees(shop_key)
    else
      VehicleShops.ManageEmployees(shop_key)
    end
  end})
  end
end

VehicleShops.PayMenu = function(shop_key)
  local elements = {}
  for k,v in pairs(VehicleShops.Shops[shop_key].employees) do
    if v ~= PlayerId() then
      table.insert(elements,{
        label = v.identity.firstname .. " " .. v.identity.lastname,
        value = v.identifier  
      })
    end
  end
  if #elements <= 0 then
    table.insert(elements,{
      label = "No employees to display."
    })
  end
  local assert = assert
  local MenuV = assert(MenuV)
  local AccountMain = MenuV:CreateMenu("Pay", '', 'topleft', 255, 0, 0, 'size-125')
  MenuV:OpenMenu(AccountMain, function()
  end)
  for k,v in ipairs(elements) do
  local button = AccountMain:AddButton({ icon = "💲 	", label = v.label, value = v ,select = function(btn)
    local current = btn.Value
    if current.value then
      TriggerEvent("Input:Open","Pay Amount","QBCore",function(amount)
        amount = (tonumber(amount) ~= nil and tonumber(amount) >= 1 and tonumber(amount) or false)
        if not amount then
          QBCore.Functions.Notify("Invalid amount entered.")
        else
          if VehicleShops.Shops[shop_key].funds < amount then
            QBCore.Functions.Notify("Shop doesn't have this much funds.")
          else
            TriggerServerEvent("VehicleShops:PayPlayer",shop_key,current.value,amount)
          end
        end
        VehicleShops.ManageEmployees(shop_key)
      end)
    else
      VehicleShops.ManageEmployees(shop_key)
    end
  end})
  end
end

VehicleShops.ManageEmployees = function(shop_key)
  local elements = {
    {label = "Hire Employee",value = "Hire"},
    {label = "Fire Employee",value = "Fire"},
    {label = "Pay Employee",value = "Pay"},
  }
  local assert = assert
  local MenuV = assert(MenuV)
  local AccountMain = MenuV:CreateMenu("Employees", '', 'topleft', 255, 0, 0, 'size-125')
  MenuV:OpenMenu(AccountMain, function()
  end)
  for k,v in ipairs(elements) do
  local button = AccountMain:AddButton({ icon = "🧑🏻‍🤝‍🧑🏿 	", label = v.label, value = v ,select = function(btn)
    local current = btn.Value
    if current.value == "Fire" then
      VehicleShops.FireMenu(shop_key)
    elseif current.value == "Hire" then
      VehicleShops.HireMenu(shop_key)
    elseif current.value == "Pay" then
      VehicleShops.PayMenu(shop_key)
    end
  end})
  end
end

VehicleShops.ManagementMenu = function(shop_key)
  local elements = {}
  local PlayerData = QBCore.Functions.GetPlayerData()
  if VehicleShops.Shops[shop_key].owner == PlayerData.license then
    elements = {
      {label = "Vehicle management",  value="Vehicle"},
      {label = "Store management",     value="Shop"},
      {label = "Employee management", value="Employee"},
    }
  else
    elements = {
      {label = "Vehicle management",  value="Vehicle"},
    }
  end
  local assert = assert
  local MenuV = assert(MenuV)
  local AccountMain = MenuV:CreateMenu("Management", '', 'topleft', 255, 0, 0, 'size-125')
  MenuV:OpenMenu(AccountMain, function()
  end)
  for k,v in ipairs(elements) do
  local button = AccountMain:AddButton({ icon = "🧑🏻‍🤝‍🧑🏿 	", label = v.label, value = v ,select = function(btn)
    local current = btn.Value
    if current.value == "Vehicle" then
      VehicleShops.ManageVehicles(shop_key)
    elseif current.value == "Shop" then
      VehicleShops.ManageShop(shop_key)
    elseif current.value == "Employee" then
      VehicleShops.ManageEmployees(shop_key)
    end
  end})
  end
end

VehicleShops.DepositVehicle = function(shop_key)
  local ply_ped = PlayerPedId()
  if IsPedInAnyVehicle(ply_ped,false) then
    local ply_veh = GetVehiclePedIsUsing(ply_ped,false)
    local driver = GetPedInVehicleSeat(ply_veh,-1)
    if driver == ply_ped then
      VehicleShops.CanStockVehicle(shop_key,ply_veh,function(can_store,do_delete)
        if can_store then
          local props = QBCore.Functions.GetVehicleProperties(ply_veh)
          TriggerServerEvent("VehicleShops:StockedVehicle",props,shop_key,do_delete)
          TaskLeaveVehicle(ply_ped,ply_veh,0)
          TaskEveryoneLeaveVehicle(ply_veh)
          SetEntityAsMissionEntity(ply_veh,true,true)
          DeleteVehicle(ply_veh)
        end
      end)
    end
  end
end

VehicleShops.CanStockVehicle = function(shop_key,vehicle,callback)
  local plyPed = PlayerPedId()
  local isEmployed = false
  local PlayerData = QBCore.Functions.GetPlayerData()
  if VehicleShops.Shops[shop_key].owner == PlayerData.license then 
    isEmployed = true
  else
    for k,v in pairs(VehicleShops.Shops[shop_key].employees) do
      if v.identifier == PlayerData.license then
        isEmployed = true
        break
      end
    end
  end
  if not isEmployed then return false; end
  local props = QBCore.Functions.GetVehicleProperties(vehicle) 
  QBCore.Functions.TriggerCallback("VehicleShops:GetVehicleOwner",function(owner)
    --print(tostring(props.plate))
    --print(tostring(VehicleShops.Shops[shop_key].owner))
    if owner and VehicleShops.Shops[shop_key].owner:match(owner)  then   
      callback(true,true)
    else
      if not owner then
        if Config.StockStolenPedVehicles then
          callback(true,false)
        else
          QBCore.Functions.Notify("You cannot store stolen vehicles.")
          callback(false)
        end
        return
      else
        if Config.StockStolenPlayerVehicles then
          callback(true,true)
        else
          QBCore.Functions.Notify("You cannot store other players' vehicles...")
          callback(false)
        end
        return
      end
      callback(false)
    end
  end,props.plate)
end

VehicleShops.Interact = function(a,b)
  if (a == "buy") then
    VehicleShops.PurchasedShop()
  elseif (a == "deposit") then
    VehicleShops.DepositVehicle(b)
  elseif (a == "management") then
    VehicleShops.ManagementMenu(b)
  end
end

VehicleShops.LeaveWarehouse = function()
  local plyPed = PlayerPedId()
  SetEntityCoordsNoOffset(plyPed, Warehouse.entry.x,Warehouse.entry.y,Warehouse.entry.z)
  SetEntityHeading(plyPed, Warehouse.entry.w)
  VehicleShops.DespawnShop()
  InsideWarehouse = false
  TriggerEvent("Markers:Remove",WarehouseMarker)
end

VehicleShops.RefreshBlips = function()  
  local dictStreamed = false
  local startTime = GetGameTimer()
  local PlayerData = QBCore.Functions.GetPlayerData()
  local is_dealer = false
  for k,v in pairs(VehicleShops.Shops) do
    if v.owner == PlayerData.license then
      is_dealer = true
    end
    if not is_dealer then
      for k,v in pairs(v.employees) do
        if v.identifier == PlayerData.license then
          is_dealer = true
        end
      end
    end
  end
  if DealerMarker and not is_dealer then
    RemoveBlip(DealerBlip)
    TriggerEvent("Markers:Remove",DealerMarker)
  elseif not DealerMarker and is_dealer then
    local pos = (Warehouse.entry)
    local blip = AddBlipForCoord(pos.x,pos.y,pos.z)
    SetBlipSprite(blip, 225)
    SetBlipColour(blip, 3)  
    SetBlipAsShortRange(blip,true)
    BeginTextCommandSetBlipName ("STRING")
    AddTextComponentString      ("Vehicle Warehouse")
    EndTextCommandSetBlipName   (blip)
    DealerBlip = blip
    local marker = {
      display  = false,
      location = pos,
      maintext = "Warehouse",
      scale    = vector3(1.5,1.5,1.5),
      distance = 1.0,
      control  = 38,
      callback = VehicleShops.EnterWarehouse,
      args     = {"buy",k}
    }
    TriggerEvent("Markers:Add",marker,function(m)
      DealerMarker = m
    end)
  end
  for k,v in pairs(VehicleShops.Shops) do
    if not v.blip then
      SetAllVehicleGeneratorsActiveInArea(v.locations.entry.x - 50.0, v.locations.entry.y - 50.0, v.locations.entry.z - 50.0, v.locations.entry.x + 50.0, v.locations.entry.y + 50.0, v.locations.entry.z  + 50.0, false, false);
      local pos = (v.locations.entry)
      local blip = AddBlipForCoord(pos.x,pos.y,pos.z)
      SetBlipSprite(blip, 225)
      SetBlipColour(blip, (v.owner == "none" and 0 or 5))  
      BeginTextCommandSetBlipName ("STRING")
      AddTextComponentString      ("Vehicle Shop")
      SetBlipAsShortRange(blip,true)
      EndTextCommandSetBlipName   (blip)
      
      VehicleShops.Shops[k].blip = blip
      VehicleShops.Shops[k].markers = {}

      if not v.owner then
        local marker = {
          display  = false,
          location = pos,
          maintext = "To Buy",
          subtext  = "~s~$~g~"..v.price,
          scale    = vector3(1.5,1.5,1.5),
          distance = 1.0,
          control  = 38,
          callback = VehicleShops.Interact,
          args     = {"buy",k}
        }
        TriggerEvent("Markers:Add",marker,function(m)
          VehicleShops.Shops[k].markers["buy"] = m
        end)
      else
        local render_menus = false
        for k,v in pairs(VehicleShops.Shops[k].employees) do
          if v.identifier == PlayerData.license then
            render_menus = true
          end
        end
        if not render_menus and PlayerData.license == v.owner then
          render_menus = true
        end
        if render_menus then
          local marker = {
            display  = false,
            location = (v.locations.management),
            maintext = "Management",
            scale    = vector3(1.5,1.5,1.5),
            distance = 1.0,
            control  = 38,
            callback = VehicleShops.Interact,
            args     = {"management",k}
          }
          TriggerEvent("Markers:Add",marker,function(m)
            VehicleShops.Shops[k].markers["management"] = m
          end)
          local marker = {
            display  = false,
            location = (v.locations.deposit),
            maintext = "Deposit",
            scale    = vector3(1.5,1.5,1.5),
            distance = 1.0,
            control  = 38,
            callback = VehicleShops.Interact,
            args     = {"deposit",k}
          }
          TriggerEvent("Markers:Add",marker,function(m)
            VehicleShops.Shops[k].markers["deposit"] = m
          end)
        end
      end
    end
  end
end

VehicleShops.Sync = function(data)
  if VehicleShops.Shops then
    for k,v in pairs(VehicleShops.Shops) do
      RemoveBlip(v.blip)
      if v.markers then
        for k,v in pairs(v.markers) do
          TriggerEvent("Markers:Remove",v)
        end
        v.markers = false
      end
      v.blip = false
    end

    VehicleShops.Shops = data
    VehicleShops.RefreshBlips()
  end
end

VehicleShops.SpawnShop = function()
  ShopVehicles = {}
  ShopLookup = {}
  local startTime = GetGameTimer()
  while not IsInteriorReady(GetInteriorAtCoords(GetEntityCoords(PlayerPedId()))) and GetGameTimer() - startTime < 5000 do Wait(0); end
  for k,v in pairs(VehicleShops.WarehouseVehicles) do
    local hash = GetHashKey(v.model)
    local started = GetGameTimer()
    RequestModel(hash)
    while not HasModelLoaded(hash) and (GetGameTimer() - started) < 10000 do Wait(0); end
    if HasModelLoaded(hash) then
      local veh = CreateVehicle(hash, v.pos.x,v.pos.y,v.pos.z, v.pos.w, false,false)

      ShopVehicles[k] = {ent = veh,pos = v.pos,price = v.price,name = v.name,model = v.model,key = k}
      ShopLookup[veh] = k

      FreezeEntityPosition(veh,true)
      SetEntityAsMissionEntity(veh,true,true)
      SetVehicleUndriveable(veh,true)
      SetVehicleDoorsLocked(veh,2)
      SetVehicleEngineOn(veh,true)
    end
    SetModelAsNoLongerNeeded(hash)
  end  
end

VehicleShops.DespawnShop = function()
  if ShopVehicles then
    for k,v in pairs(ShopVehicles) do
      SetEntityAsMissionEntity(v.ent,true,true)
      DeleteEntity(v.ent)
    end
    ShopVehicles = {}
  end
end

VehicleShops.RemoveDisplay = function(shop,veh,data)
  if VehicleShops.SpawnedVehicles[veh] then
    DeleteVehicle(VehicleShops.SpawnedVehicles[veh])  
    VehicleShops.SpawnedVehicles[veh] = false
  end
  VehicleShops.Sync(data)
end  

VehicleShops.PurchaseDisplay = function(shop_key,veh_key,veh_ent)
  local price = VehicleShops.Shops[shop_key].displays[veh_key].price
  if not price then return; end
  local props = QBCore.Functions.GetVehicleProperties(veh_ent)
  QBCore.Functions.TriggerCallback("VehicleShops:TryBuy",function(canBuy,msg)
    if canBuy then
      RequestModel(props.model)
      while not HasModelLoaded(props.model) do Wait(0); end
      local pos = VehicleShops.Shops[shop_key].locations.purchased
      local veh = CreateVehicle(props.model,pos.x,pos.y,pos.z,pos.heading,true,true)
      SetEntityAsMissionEntity(veh,true,true)
      QBCore.Functions.SetVehicleProperties(veh,props)
      TaskWarpPedIntoVehicle(PlayerPedId(),veh,-1)
      SetVehicleEngineOn(veh,true)
    else
      QBCore.Functions.Notify(msg)
    end
  end,shop_key,veh_key,props,GetVehicleClass(veh_ent))
end

VehicleShops.DoDisplayVehicle = function(shopKey,vehKey,vehData)
  local shop = VehicleShops.Shops[shopKey]
  local props = vehData.vehicle
  local pos = shop.locations.spawn

  Wait(500)

  RequestModel(props.model)
  while not HasModelLoaded(props.model) do Wait(0); end

  local displayVehicle = CreateVehicle(props.model, pos.x,pos.y,pos.z, pos.heading, false,false)
  SetEntityCollision(displayVehicle,true,true)
  while not DoesEntityExist(displayVehicle) do Wait(0); end 

  QBCore.Functions.SetVehicleProperties(displayVehicle,props)
  Wait(500)

  local scaleform = GetMoveScaleform()
  local controls = Controls["Moving_Vehicle"]

  targetPos = vector4(pos.x,pos.y,pos.z,pos.heading)

  SetEntityCoordsNoOffset(displayVehicle,pos.x,pos.y,pos.z)
  SetEntityCollision(displayVehicle,true,true)
  SetVehicleUndriveable(displayVehicle,true)
  FreezeEntityPosition(displayVehicle,true)

  VehicleShops.Moving = true

  while true do
    local didMove,didRot = false,false

    DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)

    if IsControlJustPressed(0,controls.cancel) then
      VehicleShops.Moving = false
      SetEntityAsMissionEntity(displayVehicle,true,true)
      DeleteVehicle(displayVehicle)

      VehicleShops.ManagementMenu(shop.name)
      return
    end

    if IsControlPressed(0,controls.place) then
      VehicleShops.Moving = false
      SetEntityAsMissionEntity(displayVehicle,true,true)
      DeleteVehicle(displayVehicle)
      TriggerServerEvent("VehicleShops:SetDisplayed",shopKey,vehKey,Vec2Tab(targetPos))

      VehicleShops.ManagementMenu(shop.name)
      return
    end

    local right,forward,up,pos = GetEntityMatrix(displayVehicle)

    if IsControlJustPressed(0,controls.ground) then
      SetVehicleOnGroundProperly(displayVehicle)
      local x,y,z = table.unpack(GetEntityCoords(displayVehicle))
      local heading = GetEntityHeading(displayVehicle)
      targetPos = vector4(x,y,z,heading)
    end

    local modA = 50
    local modB = 25
    local modC = 0.5

    if IsControlJustPressed(0,controls.zUp) or IsControlPressed(0,controls.zUp) then
      local target = targetPos.xyz + (up/modA)
      targetPos = vector4(target.x,target.y,target.z,targetPos.w)
      didMove = true
    end

    if IsControlJustPressed(0,controls.zDown) or IsControlPressed(0,controls.zDown) then
      local target = targetPos.xyz - (up/modA)
      targetPos = vector4(target.x,target.y,target.z,targetPos.w)
      didMove = true
    end

    if IsControlJustPressed(0,controls.xUp) or IsControlPressed(0,controls.xUp) then
      local target = targetPos.xyz + (forward/modB)
      targetPos = vector4(target.x,target.y,target.z,targetPos.w)
      didMove = true
    end

    if IsControlJustPressed(0,controls.xDown) or IsControlPressed(0,controls.xDown) then
      local target = targetPos.xyz - (forward/modB)
      targetPos = vector4(target.x,target.y,target.z,targetPos.w)
      didMove = true
    end

    if IsControlJustPressed(0,controls.yUp) or IsControlPressed(0,controls.yUp) then
      local target = targetPos.xyz + (right/modB)
      targetPos = vector4(target.x,target.y,target.z,targetPos.w)
      didMove = true
    end

    if IsControlJustPressed(0,controls.yDown) or IsControlPressed(0,controls.yDown) then
      local target = targetPos.xyz - (right/modB)
      targetPos = vector4(target.x,target.y,target.z,targetPos.w)
      didMove = true
    end

    if IsControlJustPressed(0,controls.rotRight) or IsControlPressed(0,controls.rotRight) then
      targetPos = vector4(targetPos.x,targetPos.y,targetPos.z,targetPos.w-modC)
      didRot = true
    end

    if IsControlJustPressed(0,controls.rotLeft) or IsControlPressed(0,controls.rotLeft) then
      targetPos = vector4(targetPos.x,targetPos.y,targetPos.z,targetPos.w+modC)
      didRot = true
    end

    if didMove then 
      FreezeEntityPosition(displayVehicle,false)
      SetEntityRotation(displayVehicle,0.0,0.0,targetPos.w,2)
      SetEntityCoordsNoOffset(displayVehicle,targetPos.xyz); 
      FreezeEntityPosition(displayVehicle,true)
    end
    if didRot then 
      FreezeEntityPosition(displayVehicle,false)
      SetEntityHeading(displayVehicle,targetPos.w); 
      FreezeEntityPosition(displayVehicle,true)
    end
    Wait(0)
  end
end

VehicleShops.CreateNew = function(...)
  local warnEntry,warnManage,warnSpawn,warnDeposit
  local locations = {}
    
  local closest,dist = VehicleShops.GetClosestShop()

  if closest and dist and dist < 20.0 then
    QBCore.Functions.Notify("You're too close to another vehicle shop.")
    return
  end

  TriggerEvent("Input:Open","Set Shop Name","QBCore",function(n)
    local name = (n and tostring(n) and tostring(n):len() and tostring(n):len() > 0 and tostring(n) or false)
    if not name then QBCore.Functions.Notify("Enter a valid name next time."); return; end
    Wait(200)
    TriggerEvent("Input:Open","Set Shop Price","QBCore",function(p)
      local price = (p and tonumber(p) and tonumber(p) > 0 and tonumber(p) or false)
      if not price then QBCore.Functions.Notify("Enter a valid price next time."); return; end
      while true do
        if not locations.blip then
          if not warnBlip then
            QBCore.Functions.Notify("Press G to set the blip location.")
            warnBlip = true
          end
          if IsControlJustReleased(0,47) then
            locations.blip = Vec2Tab(GetEntityCoords(PlayerPedId()))
            Wait(0)
          end
        elseif not locations.entry then
          if not warnEntry then
            QBCore.Functions.Notify("Press G to set the entry/purchase shop location.")
            warnEntry = true
          end
          if IsControlJustReleased(0,47) then
            locations.entry = Vec2Tab(GetEntityCoords(PlayerPedId()))
            Wait(0)
          end
        elseif not locations.management then
          if not warnManage then
            QBCore.Functions.Notify("Press G to set the management menu location.")
            warnManage = true
          end
          if IsControlJustReleased(0,47) then
            locations.management = Vec2Tab(GetEntityCoords(PlayerPedId()))
            Wait(0)
          end
        elseif not locations.spawn then
          if not warnSpawn then
            QBCore.Functions.Notify("Press G to set the vehicle spawn location (inside).")
            warnSpawn = true
          end
          if IsControlJustReleased(0,47) then
            local plyPed = PlayerPedId()
            local pos = GetEntityCoords(plyPed)
            local heading = GetEntityHeading(plyPed)
            locations.spawn = Vec2Tab(vector4(pos.x,pos.y,pos.z,heading))
            Wait(0)
          end
        elseif not locations.purchased then
          if not warnPurchased then
            QBCore.Functions.Notify("Press G to set the vehicle spawn location (outside).")
            warnPurchased = true
          end
          if IsControlJustReleased(0,47) then
            local plyPed = PlayerPedId()
            local pos = GetEntityCoords(plyPed)
            local heading = GetEntityHeading(plyPed)
            locations.purchased = Vec2Tab(vector4(pos.x,pos.y,pos.z,heading))
            Wait(0)
          end
        elseif not locations.deposit then
          if not warnDeposit then        
            QBCore.Functions.Notify("Press G to set the vehicle deposit location.")
            warnDeposit = true
          end
          if IsControlJustReleased(0,47) then
            locations.deposit = Vec2Tab(GetEntityCoords(PlayerPedId()))
            Wait(0)
          end
        else 
          QBCore.Functions.Notify("Shop created, name: "..name..", price: "..price)
          TriggerServerEvent("VehicleShops:Create", name, locations, price)
          return
        end
        Wait(0)
      end
    end)
  end)
end

RegisterNetEvent("VehicleShops:Sync")
AddEventHandler("VehicleShops:Sync", VehicleShops.Sync)

RegisterNetEvent("VehicleShops:RemoveDisplay")
AddEventHandler("VehicleShops:RemoveDisplay", VehicleShops.RemoveDisplay)

RegisterNetEvent("VehicleShops:CreateNew")
AddEventHandler("VehicleShops:CreateNew",VehicleShops.CreateNew)

RegisterNetEvent("VehicleShops:WarehouseRefresh")
AddEventHandler("VehicleShops:WarehouseRefresh",VehicleShops.WarehouseRefresh)

RegisterNetEvent("VehicleShops:init")
AddEventHandler("VehicleShops:init",VehicleShops.Init)

Citizen.CreateThread(VehicleShops.Init)
