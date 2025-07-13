-- =====================================================
-- DATAMANAGER.LUA - Gestor de Datos del Jugador/Vehículo
-- Autor: MIWELO
-- Versión: 1.0.0
-- Descripción: Gestión optimizada de datos con cache inteligente
-- =====================================================

DataManager = {}
DataManager.__index = DataManager

-- =====================================================
-- CONFIGURACIÓN
-- =====================================================
local DATA_CONFIG = {
    updateInterval = 50,     -- ms
    cacheLifetime = 200,     -- ms
    smoothingFactor = 0.1,   -- Para transiciones suaves
    enableSmoothing = true,
    enablePrediction = false,
    maxHistorySize = 10
}

-- =====================================================
-- VARIABLES GLOBALES
-- =====================================================
local playerData = {
    health = 100,
    armor = 0,
    hunger = 100,
    thirst = 100,
    stamina = 100,
    money = 0
}

local vehicleData = {
    speed = 0,
    fuel = 100,
    engine = false,
    lights = false,
    locked = false,
    handbrake = false,
    seatbelt = false,
    gear = 0,
    rpm = 0,
    damage = 0,
    temperature = 80
}

local smoothedData = {}
local dataHistory = {}
local lastUpdate = 0
local updateTimer = nil

-- Cache específico para datos
local dataCache = createCache("dataManager", {
    maxSize = 200,
    defaultLifetime = DATA_CONFIG.cacheLifetime,
    cleanupInterval = 1000
})

-- =====================================================
-- CONSTRUCTOR
-- =====================================================
function DataManager:new(config)
    local instance = {
        config = config or {},
        playerData = {},
        vehicleData = {},
        smoothedData = {},
        history = {},
        lastUpdate = 0,
        isActive = false
    }
    
    -- Aplicar configuración por defecto
    for key, value in pairs(DATA_CONFIG) do
        if instance.config[key] == nil then
            instance.config[key] = value
        end
    end
    
    setmetatable(instance, DataManager)
    return instance
end

-- =====================================================
-- INICIALIZACIÓN
-- =====================================================

-- Inicializar el gestor de datos
function DataManager:initialize()
    self.isActive = true
    
    -- Inicializar datos suavizados
    self:initializeSmoothData()
    
    -- Inicializar historial
    self:initializeHistory()
    
    -- Configurar timer de actualización
    self:startUpdateTimer()
    
    -- Configurar eventos
    self:setupEvents()
    
    outputDebugString("DataManager inicializado correctamente", 3)
    return true
end

-- Inicializar datos suavizados
function DataManager:initializeSmoothData()
    for key, value in pairs(playerData) do
        smoothedData["player_" .. key] = value
    end
    
    for key, value in pairs(vehicleData) do
        smoothedData["vehicle_" .. key] = value
    end
end

-- Inicializar historial
function DataManager:initializeHistory()
    dataHistory = {
        player = {},
        vehicle = {}
    }
end

-- Configurar eventos
function DataManager:setupEvents()
    -- Eventos de jugador
    addEventHandler("onClientPlayerWasted", localPlayer, function()
        self:updatePlayerData("health", 0)
    end)
    
    addEventHandler("onClientPlayerSpawn", localPlayer, function()
        self:updatePlayerData("health", 100)
    end)
    
    -- Eventos de vehículo
    addEventHandler("onClientVehicleEnter", root, function(player, seat)
        if player == localPlayer and seat == 0 then
            self:onVehicleEnter(source)
        end
    end)
    
    addEventHandler("onClientVehicleExit", root, function(player, seat)
        if player == localPlayer and seat == 0 then
            self:onVehicleExit(source)
        end
    end)
end

-- =====================================================
-- ACTUALIZACIÓN DE DATOS
-- =====================================================

-- Iniciar timer de actualización
function DataManager:startUpdateTimer()
    if updateTimer then
        killTimer(updateTimer)
    end
    
    updateTimer = setTimer(function()
        self:update()
    end, self.config.updateInterval, 0)
end

-- Actualización principal
function DataManager:update()
    if not self.isActive then
        return
    end
    
    local currentTime = getTickCount()
    
    -- Actualizar datos del jugador
    self:updatePlayerStats()
    
    -- Actualizar datos del vehículo si está en uno
    if isPedInVehicle(localPlayer) then
        self:updateVehicleStats()
    end
    
    -- Aplicar suavizado si está habilitado
    if self.config.enableSmoothing then
        self:applySmoothTransitions(currentTime - lastUpdate)
    end
    
    -- Guardar en historial
    self:saveToHistory()
    
    lastUpdate = currentTime
end

-- Actualizar estadísticas del jugador
function DataManager:updatePlayerStats()
    local cacheKey = "player_stats_" .. getTickCount()
    
    local stats = dataCache:getOrSet(cacheKey, function()
        return {
            health = getElementHealth(localPlayer),
            armor = getPedArmor(localPlayer),
            hunger = self:getCustomStat("hunger", 100),
            thirst = self:getCustomStat("thirst", 100),
            stamina = self:getCustomStat("stamina", 100),
            money = getPlayerMoney(localPlayer) or 0
        }
    end, 100)
    
    for key, value in pairs(stats) do
        self:updatePlayerData(key, value)
    end
end

-- Actualizar estadísticas del vehículo
function DataManager:updateVehicleStats()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if not vehicle then
        return
    end
    
    local cacheKey = "vehicle_stats_" .. getElementModel(vehicle) .. "_" .. math.floor(getTickCount() / 100)
    
    local stats = dataCache:getOrSet(cacheKey, function()
        local vx, vy, vz = getElementVelocity(vehicle)
        local speed = math.sqrt(vx^2 + vy^2 + vz^2) * 180 -- Convertir a km/h
        
        return {
            speed = speed,
            fuel = self:getVehicleFuel(vehicle),
            engine = getVehicleEngineState(vehicle),
            lights = getVehicleOverrideLights(vehicle) == 2,
            locked = isVehicleLocked(vehicle),
            handbrake = getVehicleHandbrake(vehicle),
            seatbelt = self:getCustomVehicleStat("seatbelt", false),
            gear = self:calculateGear(speed),
            rpm = self:calculateRPM(speed, vehicle),
            damage = self:getVehicleDamage(vehicle),
            temperature = self:getEngineTemperature(vehicle)
        }
    end, 50)
    
    for key, value in pairs(stats) do
        self:updateVehicleData(key, value)
    end
end

-- =====================================================
-- MÉTODOS DE DATOS ESPECÍFICOS
-- =====================================================

-- Actualizar dato del jugador
function DataManager:updatePlayerData(key, value)
    if playerData[key] ~= value then
        playerData[key] = value
        
        -- Trigger evento para notificar cambio
        triggerEvent("onPlayerDataUpdate", localPlayer, key, value)
    end
end

-- Actualizar dato del vehículo
function DataManager:updateVehicleData(key, value)
    if vehicleData[key] ~= value then
        vehicleData[key] = value
        
        -- Trigger evento para notificar cambio
        triggerEvent("onVehicleDataUpdate", localPlayer, key, value)
    end
end

-- Obtener estadística personalizada
function DataManager:getCustomStat(statName, defaultValue)
    -- En un servidor real, esto se obtendría del servidor
    -- Por ahora, simulamos algunos valores
    if statName == "hunger" then
        return math.random(80, 100)
    elseif statName == "thirst" then
        return math.random(75, 100)
    elseif statName == "stamina" then
        return math.random(85, 100)
    end
    
    return defaultValue
end

-- Obtener estadística personalizada del vehículo
function DataManager:getCustomVehicleStat(statName, defaultValue)
    -- Simulación de stats personalizadas
    if statName == "seatbelt" then
        return math.random() > 0.5
    end
    
    return defaultValue
end

-- Obtener combustible del vehículo
function DataManager:getVehicleFuel(vehicle)
    -- En un servidor real, esto se obtendría del servidor
    -- Simulamos un valor basado en el tiempo
    local baseTime = getTickCount() / 1000
    return math.max(0, 100 - (baseTime % 100))
end

-- Calcular marcha
function DataManager:calculateGear(speed)
    if speed < 10 then return 1
    elseif speed < 30 then return 2
    elseif speed < 60 then return 3
    elseif speed < 90 then return 4
    elseif speed < 120 then return 5
    else return 6
    end
end

-- Calcular RPM
function DataManager:calculateRPM(speed, vehicle)
    local gear = self:calculateGear(speed)
    local baseRPM = 800 -- RPM en ralentí
    local maxRPM = 6000
    
    -- Cálculo simplificado de RPM
    local gearRatio = {0.1, 0.2, 0.35, 0.5, 0.7, 0.9}
    local ratio = gearRatio[gear] or 0.9
    
    return baseRPM + (speed * ratio * 50)
end

-- Obtener daño del vehículo
function DataManager:getVehicleDamage(vehicle)
    local panels = {}
    local doors = {}
    local lights = {}
    local tires = {}
    
    for i = 0, 6 do
        panels[i] = getVehiclePanelState(vehicle, i)
        if i < 6 then
            doors[i] = getVehicleDoorState(vehicle, i)
        end
        if i < 4 then
            lights[i] = getVehicleLightState(vehicle, i)
            tires[i] = getVehicleWheelStates(vehicle)
        end
    end
    
    -- Calcular porcentaje de daño general
    local totalDamage = 0
    local components = 0
    
    for _, state in pairs(panels) do
        totalDamage = totalDamage + state
        components = components + 1
    end
    
    return math.min(100, (totalDamage / components) * 25)
end

-- Obtener temperatura del motor
function DataManager:getEngineTemperature(vehicle)
    local engineHealth = getElementHealth(vehicle)
    local baseTemp = 80
    
    -- La temperatura aumenta cuando el motor está dañado
    local tempIncrease = (1000 - engineHealth) / 10
    
    return math.min(120, baseTemp + tempIncrease)
end

-- =====================================================
-- SUAVIZADO Y TRANSICIONES
-- =====================================================

-- Aplicar transiciones suaves
function DataManager:applySmoothTransitions(deltaTime)
    local factor = self.config.smoothingFactor
    
    -- Suavizar datos del jugador
    for key, targetValue in pairs(playerData) do
        local smoothKey = "player_" .. key
        local currentValue = smoothedData[smoothKey] or targetValue
        
        smoothedData[smoothKey] = self:lerp(currentValue, targetValue, factor)
    end
    
    -- Suavizar datos del vehículo
    for key, targetValue in pairs(vehicleData) do
        local smoothKey = "vehicle_" .. key
        local currentValue = smoothedData[smoothKey] or targetValue
        
        -- Algunos valores no deben suavizarse (booleanos)
        if type(targetValue) == "boolean" then
            smoothedData[smoothKey] = targetValue
        else
            smoothedData[smoothKey] = self:lerp(currentValue, targetValue, factor)
        end
    end
end

-- Interpolación lineal
function DataManager:lerp(a, b, t)
    return a + (b - a) * t
end

-- =====================================================
-- HISTORIAL
-- =====================================================

-- Guardar en historial
function DataManager:saveToHistory()
    local currentTime = getTickCount()
    
    -- Guardar datos del jugador
    table.insert(dataHistory.player, {
        time = currentTime,
        data = table.copy(playerData)
    })
    
    -- Guardar datos del vehículo
    table.insert(dataHistory.vehicle, {
        time = currentTime,
        data = table.copy(vehicleData)
    })
    
    -- Limitar tamaño del historial
    while #dataHistory.player > self.config.maxHistorySize do
        table.remove(dataHistory.player, 1)
    end
    
    while #dataHistory.vehicle > self.config.maxHistorySize do
        table.remove(dataHistory.vehicle, 1)
    end
end

-- Obtener historial
function DataManager:getHistory(type, count)
    count = count or self.config.maxHistorySize
    local history = dataHistory[type] or {}
    
    local result = {}
    local startIndex = math.max(1, #history - count + 1)
    
    for i = startIndex, #history do
        table.insert(result, history[i])
    end
    
    return result
end

-- =====================================================
-- EVENTOS DE VEHÍCULO
-- =====================================================

-- Al entrar en vehículo
function DataManager:onVehicleEnter(vehicle)
    -- Resetear datos del vehículo
    self:resetVehicleData()
    
    -- Forzar actualización inmediata
    self:updateVehicleStats()
    
    triggerEvent("onVehicleEnterHUD", localPlayer, vehicle)
end

-- Al salir del vehículo
function DataManager:onVehicleExit(vehicle)
    -- Limpiar datos del vehículo
    self:resetVehicleData()
    
    triggerEvent("onVehicleExitHUD", localPlayer, vehicle)
end

-- Resetear datos del vehículo
function DataManager:resetVehicleData()
    for key, _ in pairs(vehicleData) do
        vehicleData[key] = 0
        smoothedData["vehicle_" .. key] = 0
    end
    
    vehicleData.engine = false
    vehicleData.lights = false
    vehicleData.locked = false
    vehicleData.handbrake = false
    vehicleData.seatbelt = false
end

-- =====================================================
-- MÉTODOS PÚBLICOS
-- =====================================================

-- Obtener datos del jugador
function DataManager:getPlayerData(key, smooth)
    if key then
        if smooth and self.config.enableSmoothing then
            return smoothedData["player_" .. key] or playerData[key]
        else
            return playerData[key]
        end
    else
        if smooth and self.config.enableSmoothing then
            local result = {}
            for k, _ in pairs(playerData) do
                result[k] = smoothedData["player_" .. k] or playerData[k]
            end
            return result
        else
            return table.copy(playerData)
        end
    end
end

-- Obtener datos del vehículo
function DataManager:getVehicleData(key, smooth)
    if key then
        if smooth and self.config.enableSmoothing then
            return smoothedData["vehicle_" .. key] or vehicleData[key]
        else
            return vehicleData[key]
        end
    else
        if smooth and self.config.enableSmoothing then
            local result = {}
            for k, _ in pairs(vehicleData) do
                result[k] = smoothedData["vehicle_" .. k] or vehicleData[k]
            end
            return result
        else
            return table.copy(vehicleData)
        end
    end
end

-- Verificar si está en vehículo
function DataManager:isInVehicle()
    return isPedInVehicle(localPlayer)
end

-- Obtener vehículo actual
function DataManager:getCurrentVehicle()
    return getPedOccupiedVehicle(localPlayer)
end

-- =====================================================
-- CONTROL
-- =====================================================

-- Pausar actualizaciones
function DataManager:pause()
    self.isActive = false
end

-- Reanudar actualizaciones
function DataManager:resume()
    self.isActive = true
end

-- Destruir gestor
function DataManager:destroy()
    self.isActive = false
    
    if updateTimer then
        killTimer(updateTimer)
        updateTimer = nil
    end
    
    -- Limpiar eventos
    removeEventHandler("onClientPlayerWasted", localPlayer, function() end)
    removeEventHandler("onClientPlayerSpawn", localPlayer, function() end)
end

-- =====================================================
-- INSTANCIA GLOBAL
-- =====================================================
local globalDataManager = DataManager:new(DATA_CONFIG)

-- =====================================================
-- FUNCIONES GLOBALES
-- =====================================================

-- Inicializar gestor global
function initializeDataManager()
    return globalDataManager:initialize()
end

-- Obtener datos del jugador
function getPlayerData(key, smooth)
    return globalDataManager:getPlayerData(key, smooth)
end

-- Obtener datos del vehículo
function getVehicleData(key, smooth)
    return globalDataManager:getVehicleData(key, smooth)
end

-- Verificar si está en vehículo
function isPlayerInVehicle()
    return globalDataManager:isInVehicle()
end

-- Obtener vehículo actual
function getPlayerVehicle()
    return globalDataManager:getCurrentVehicle()
end

-- Obtener historial
function getDataHistory(type, count)
    return globalDataManager:getHistory(type, count)
end

-- =====================================================
-- UTILIDADES
-- =====================================================

-- Copia profunda de tabla
function table.copy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        if type(v) == "table" then
            copy[k] = table.copy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- =====================================================
-- INICIALIZACIÓN AUTOMÁTICA
-- =====================================================
addEventHandler("onClientResourceStart", resourceRoot, function()
    initializeDataManager()
end)

-- Exportar para uso global
_G.DataManager = DataManager
_G.getPlayerData = getPlayerData
_G.getVehicleData = getVehicleData