-- =====================================================
-- HUDMANAGER.LUA - Gestor Principal del HUD
-- Autor: MIWELO
-- Versión: 1.0.0
-- Descripción: Gestor principal que coordina todos los elementos del HUD
-- =====================================================

HUDManager = {}
HUDManager.__index = HUDManager

-- =====================================================
-- CONFIGURACIÓN
-- =====================================================
local HUD_MANAGER_CONFIG = {
    enabled = true,
    showInInterior = true,
    hideWithMTA = true,
    fadeInDuration = 500,
    fadeOutDuration = 300,
    updateInterval = 50,
    enableAnimations = true,
    enableAutoHide = true,
    autoHideDelay = 5000
}

-- =====================================================
-- VARIABLES GLOBALES
-- =====================================================
local hudElements = {}
local hudState = {
    visible = true,
    alpha = 255,
    lastActivity = 0,
    isAnimating = false,
    currentAnimation = nil
}

local renderStats = {
    elementsRendered = 0,
    renderTime = 0,
    lastFrameTime = 0
}

local hudTimers = {}
local hudEvents = {}

-- =====================================================
-- CONSTRUCTOR
-- =====================================================
function HUDManager:new(config)
    local instance = {
        config = config or {},
        elements = {},
        state = {
            visible = true,
            alpha = 255,
            animating = false
        },
        timers = {},
        animations = {},
        lastUpdate = 0
    }
    
    -- Aplicar configuración por defecto
    for key, value in pairs(HUD_MANAGER_CONFIG) do
        if instance.config[key] == nil then
            instance.config[key] = value
        end
    end
    
    setmetatable(instance, HUDManager)
    return instance
end

-- =====================================================
-- INICIALIZACIÓN
-- =====================================================

-- Inicializar HUD Manager
function HUDManager:initialize()
    -- Ocultar HUD original de MTA
    if self.config.hideWithMTA then
        showPlayerHudComponent("all", false)
    end
    
    -- Inicializar elementos del HUD
    self:initializeElements()
    
    -- Configurar eventos
    self:setupEvents()
    
    -- Iniciar bucle de renderizado
    self:startRenderLoop()
    
    -- Configurar animación de entrada
    if self.config.enableAnimations then
        self:fadeIn()
    end
    
    outputDebugString("HUD Manager inicializado correctamente", 3)
    return true
end

-- Inicializar elementos del HUD
function HUDManager:initializeElements()
    -- Inicializar HUD del jugador
    self:initializePlayerHUD()
    
    -- Inicializar velocímetro
    self:initializeSpeedometer()
    
    -- Inicializar indicadores
    self:initializeIndicators()
    
    -- Configurar elementos en el estado inicial
    self:resetElementStates()
end

-- Inicializar HUD del jugador
function HUDManager:initializePlayerHUD()
    local config = HUD_CONFIG.PLAYER_HUD
    
    hudElements.playerHUD = {
        type = "player_hud",
        x = config.position.x,
        y = config.position.y,
        width = config.size.width,
        height = config.size.height,
        visible = config.enabled,
        alpha = 255,
        
        -- Elementos específicos
        healthBar = nil,
        armorBar = nil,
        hungerBar = nil,
        thirstBar = nil,
        staminaBar = nil,
        
        -- Estado de animación
        animationState = "idle",
        lastUpdate = 0
    }
    
    -- Crear barras de estadísticas
    self:createStatBars()
end

-- Crear barras de estadísticas
function HUDManager:createStatBars()
    local config = HUD_CONFIG.PLAYER_HUD
    local startY = config.position.y + 20
    local barHeight = config.visual.barHeight
    local barSpacing = config.visual.barSpacing
    
    local statOrder = {"health", "armor", "hunger", "thirst", "stamina"}
    
    for i, statName in ipairs(statOrder) do
        if config.stats[statName].enabled then
            local barY = startY + (i - 1) * (barHeight + barSpacing)
            
            hudElements.playerHUD[statName .. "Bar"] = {
                type = "stat_bar",
                stat = statName,
                x = config.position.x + 10,
                y = barY,
                width = config.size.width - 20,
                height = barHeight,
                color = config.stats[statName].color,
                maxValue = config.stats[statName].max,
                currentValue = 0,
                targetValue = 0,
                visible = true,
                alpha = 255
            }
        end
    end
end

-- Inicializar velocímetro
function HUDManager:initializeSpeedometer()
    local config = HUD_CONFIG.SPEEDOMETER
    
    hudElements.speedometer = {
        type = "speedometer",
        x = config.position.x,
        y = config.position.y,
        width = config.size.width,
        height = config.size.height,
        visible = false, -- Solo visible en vehículo
        alpha = 255,
        
        -- Elementos del velocímetro
        speedGauge = nil,
        fuelGauge = nil,
        speedText = nil,
        gearText = nil,
        
        -- Estado actual
        currentSpeed = 0,
        targetSpeed = 0,
        currentFuel = 100,
        currentGear = 1,
        
        -- Configuración visual
        needleAngle = 0,
        targetNeedle = 0
    }
    
    -- Crear medidores circulares
    self:createSpeedometerGauges()
end

-- Crear medidores del velocímetro
function HUDManager:createSpeedometerGauges()
    local config = HUD_CONFIG.SPEEDOMETER
    local centerX = config.position.x + config.size.width / 2
    local centerY = config.position.y + config.size.height / 2
    
    -- Medidor de velocidad principal
    hudElements.speedometer.speedGauge = createCircularGauge(
        centerX, centerY, 100, 
        -math.pi * 0.75, math.pi * 0.75, 
        0, config.speed.maxSpeed, 8
    )
    
    -- Medidor de combustible
    hudElements.speedometer.fuelGauge = createCircularGauge(
        centerX - 60, centerY + 40, 30,
        -math.pi, 0,
        100, 100, 4
    )
end

-- Inicializar indicadores
function HUDManager:initializeIndicators()
    local config = HUD_CONFIG.INDICATORS
    
    hudElements.indicators = {
        type = "indicators",
        x = config.position.x,
        y = config.position.y,
        visible = false, -- Solo visible en vehículo
        alpha = 255,
        
        -- Indicadores individuales
        engine = self:createIndicator("engine", 0),
        lights = self:createIndicator("lights", 1),
        locked = self:createIndicator("locked", 2),
        handbrake = self:createIndicator("handbrake", 3),
        seatbelt = self:createIndicator("seatbelt", 4)
    }
end

-- Crear indicador individual
function HUDManager:createIndicator(name, index)
    local config = HUD_CONFIG.INDICATORS
    local iconSize = config.visual.iconSize
    local spacing = config.visual.spacing
    
    return {
        type = "indicator",
        name = name,
        x = config.position.x + index * spacing,
        y = config.position.y,
        width = iconSize,
        height = iconSize,
        icon = config.vehicle[name].icon,
        color = config.vehicle[name].color,
        visible = false,
        alpha = 0,
        pulsing = false,
        pulseTime = 0
    }
end

-- =====================================================
-- BUCLE DE RENDERIZADO
-- =====================================================

-- Iniciar bucle de renderizado
function HUDManager:startRenderLoop()
    addEventHandler("onClientRender", root, function()
        self:onRender()
    end)
    
    -- Timer de actualización de datos
    hudTimers.updateTimer = setTimer(function()
        self:updateData()
    end, self.config.updateInterval, 0)
end

-- Evento principal de renderizado
function HUDManager:onRender()
    if not self.config.enabled or not hudState.visible then
        return
    end
    
    local startTime = getTickCount()
    
    -- Verificar si debe mostrarse
    if not self:shouldRender() then
        return
    end
    
    -- Actualizar animaciones
    if self.config.enableAnimations then
        self:updateAnimations()
    end
    
    -- Renderizar elementos visibles
    local elementsRendered = 0
    
    -- Renderizar HUD del jugador
    if hudElements.playerHUD and hudElements.playerHUD.visible then
        self:renderPlayerHUD()
        elementsRendered = elementsRendered + 1
    end
    
    -- Renderizar velocímetro si está en vehículo
    if isPlayerInVehicle() and hudElements.speedometer and hudElements.speedometer.visible then
        self:renderSpeedometer()
        elementsRendered = elementsRendered + 1
    end
    
    -- Renderizar indicadores si está en vehículo
    if isPlayerInVehicle() and hudElements.indicators and hudElements.indicators.visible then
        self:renderIndicators()
        elementsRendered = elementsRendered + 1
    end
    
    -- Actualizar estadísticas de renderizado
    renderStats.elementsRendered = elementsRendered
    renderStats.renderTime = getTickCount() - startTime
    renderStats.lastFrameTime = getTickCount()
end

-- Verificar si debe renderizarse
function HUDManager:shouldRender()
    -- No renderizar si el jugador está muerto y no está configurado para hacerlo
    if not HUD_CONFIG.GENERAL.showWhenDead and getElementHealth(localPlayer) <= 0 then
        return false
    end
    
    -- No renderizar en interiores si no está configurado
    if not HUD_CONFIG.GENERAL.showInInterior and getElementInterior(localPlayer) > 0 then
        return false
    end
    
    -- Verificar auto-ocultación
    if self.config.enableAutoHide then
        local currentTime = getTickCount()
        if currentTime - hudState.lastActivity > self.config.autoHideDelay then
            return false
        end
    end
    
    return true
end

-- =====================================================
-- RENDERIZADO DE ELEMENTOS
-- =====================================================

-- Renderizar HUD del jugador
function HUDManager:renderPlayerHUD()
    local hud = hudElements.playerHUD
    local config = HUD_CONFIG.PLAYER_HUD
    
    -- Renderizar fondo
    if config.visual.backgroundColor then
        renderRectangle(
            hud.x, hud.y, hud.width, hud.height,
            self:applyAlpha(config.visual.backgroundColor, hud.alpha)
        )
    end
    
    -- Renderizar borde
    if config.visual.borderColor and config.visual.borderWidth > 0 then
        self:renderBorder(hud.x, hud.y, hud.width, hud.height,
                         config.visual.borderWidth, 
                         self:applyAlpha(config.visual.borderColor, hud.alpha))
    end
    
    -- Renderizar barras de estadísticas
    self:renderStatBars()
end

-- Renderizar barras de estadísticas
function HUDManager:renderStatBars()
    local config = HUD_CONFIG.PLAYER_HUD
    local statOrder = {"health", "armor", "hunger", "thirst", "stamina"}
    
    for _, statName in ipairs(statOrder) do
        local barKey = statName .. "Bar"
        local bar = hudElements.playerHUD[barKey]
        
        if bar and bar.visible then
            self:renderStatBar(bar, statName)
        end
    end
end

-- Renderizar barra de estadística individual
function HUDManager:renderStatBar(bar, statName)
    local config = HUD_CONFIG.PLAYER_HUD
    
    -- Calcular porcentaje
    local percentage = bar.currentValue / bar.maxValue
    local fillWidth = (bar.width - 4) * percentage
    
    -- Renderizar fondo de la barra
    renderRectangle(
        bar.x, bar.y, bar.width, bar.height,
        self:applyAlpha({40, 40, 40, 200}, bar.alpha)
    )
    
    -- Renderizar relleno de la barra
    if fillWidth > 0 then
        renderRectangle(
            bar.x + 2, bar.y + 2, fillWidth, bar.height - 4,
            self:applyAlpha(bar.color, bar.alpha)
        )
    end
    
    -- Renderizar texto si está habilitado
    if config.visual.showPercentage then
        local text = math.floor(percentage * 100) .. "%"
        renderText(
            text, bar.x + bar.width + 5, bar.y, 50, bar.height,
            self:applyAlpha(HUD_CONFIG.COLORS.textPrimary, bar.alpha),
            0.8, "default"
        )
    end
end

-- Renderizar velocímetro
function HUDManager:renderSpeedometer()
    local speedometer = hudElements.speedometer
    local config = HUD_CONFIG.SPEEDOMETER
    
    -- Renderizar fondo del velocímetro
    renderRectangle(
        speedometer.x, speedometer.y, speedometer.width, speedometer.height,
        self:applyAlpha(config.visual.backgroundColor, speedometer.alpha)
    )
    
    -- Renderizar medidor de velocidad
    if speedometer.speedGauge then
        -- Actualizar valor del medidor
        speedometer.speedGauge.value = speedometer.currentSpeed
        speedometer.speedGauge.valueArc = createArc(
            speedometer.speedGauge.x, speedometer.speedGauge.y, 
            speedometer.speedGauge.radius,
            speedometer.speedGauge.startAngle,
            speedometer.speedGauge.startAngle + (speedometer.speedGauge.endAngle - speedometer.speedGauge.startAngle) * 
            (speedometer.currentSpeed / config.speed.maxSpeed),
            32, speedometer.speedGauge.thickness
        )
        
        renderCircularGauge(
            speedometer.speedGauge,
            self:applyAlpha({100, 100, 100, 100}, speedometer.alpha),
            self:applyAlpha(config.visual.accentColor, speedometer.alpha)
        )
    end
    
    -- Renderizar medidor de combustible
    if speedometer.fuelGauge then
        renderCircularGauge(
            speedometer.fuelGauge,
            self:applyAlpha({100, 100, 100, 100}, speedometer.alpha),
            self:applyAlpha(config.fuel.warningColor, speedometer.alpha)
        )
    end
    
    -- Renderizar texto de velocidad
    local speedText = math.floor(speedometer.currentSpeed) .. (config.speed.showKMH and " KM/H" or " MPH")
    renderText(
        speedText,
        speedometer.x + speedometer.width / 2 - 30, speedometer.y + speedometer.height / 2 + 20,
        60, 30,
        self:applyAlpha(config.visual.primaryColor, speedometer.alpha),
        1.2, "primary"
    )
    
    -- Renderizar marcha
    if config.visual.showGear then
        renderText(
            "Gear: " .. speedometer.currentGear,
            speedometer.x + 20, speedometer.y + speedometer.height - 40,
            80, 20,
            self:applyAlpha(config.visual.primaryColor, speedometer.alpha),
            1.0, "default"
        )
    end
end

-- Renderizar indicadores
function HUDManager:renderIndicators()
    local indicators = hudElements.indicators
    
    for name, indicator in pairs(indicators) do
        if type(indicator) == "table" and indicator.type == "indicator" and indicator.visible then
            self:renderIndicator(indicator)
        end
    end
end

-- Renderizar indicador individual
function HUDManager:renderIndicator(indicator)
    local config = HUD_CONFIG.INDICATORS
    local alpha = indicator.alpha
    
    -- Aplicar efecto de pulso si está habilitado
    if indicator.pulsing and config.visual.pulseEffect then
        local pulseAlpha = math.abs(math.sin(getTickCount() / 500)) * 255
        alpha = math.min(alpha, pulseAlpha)
    end
    
    -- Renderizar icono (simulado con rectángulo coloreado)
    renderRectangle(
        indicator.x, indicator.y, indicator.width, indicator.height,
        self:applyAlpha(indicator.color, alpha)
    )
    
    -- Renderizar borde del indicador
    self:renderBorder(indicator.x, indicator.y, indicator.width, indicator.height,
                     2, self:applyAlpha({255, 255, 255, 100}, alpha))
end

-- =====================================================
-- ACTUALIZACIÓN DE DATOS
-- =====================================================

-- Actualizar datos del HUD
function HUDManager:updateData()
    -- Actualizar datos del jugador
    self:updatePlayerData()
    
    -- Actualizar datos del vehículo si está en uno
    if isPlayerInVehicle() then
        self:updateVehicleData()
        self:showVehicleElements()
    else
        self:hideVehicleElements()
    end
end

-- Actualizar datos del jugador
function HUDManager:updatePlayerData()
    local playerData = getPlayerData(nil, true) -- Datos suavizados
    
    -- Actualizar barras de estadísticas
    local statOrder = {"health", "armor", "hunger", "thirst", "stamina"}
    
    for _, statName in ipairs(statOrder) do
        local barKey = statName .. "Bar"
        local bar = hudElements.playerHUD[barKey]
        
        if bar and playerData[statName] then
            bar.targetValue = playerData[statName]
            
            -- Suavizar transición
            local diff = bar.targetValue - bar.currentValue
            bar.currentValue = bar.currentValue + diff * 0.1
        end
    end
end

-- Actualizar datos del vehículo
function HUDManager:updateVehicleData()
    local vehicleData = getVehicleData(nil, true) -- Datos suavizados
    local speedometer = hudElements.speedometer
    local indicators = hudElements.indicators
    
    -- Actualizar velocímetro
    if speedometer then
        speedometer.targetSpeed = vehicleData.speed or 0
        speedometer.currentFuel = vehicleData.fuel or 100
        speedometer.currentGear = vehicleData.gear or 1
        
        -- Suavizar velocidad
        local diff = speedometer.targetSpeed - speedometer.currentSpeed
        speedometer.currentSpeed = speedometer.currentSpeed + diff * 0.15
    end
    
    -- Actualizar indicadores
    if indicators then
        self:updateIndicator(indicators.engine, vehicleData.engine)
        self:updateIndicator(indicators.lights, vehicleData.lights)
        self:updateIndicator(indicators.locked, vehicleData.locked)
        self:updateIndicator(indicators.handbrake, vehicleData.handbrake)
        self:updateIndicator(indicators.seatbelt, vehicleData.seatbelt)
    end
end

-- Actualizar indicador individual
function HUDManager:updateIndicator(indicator, active)
    if not indicator then return end
    
    indicator.visible = active
    
    if active then
        indicator.alpha = math.min(255, indicator.alpha + 15)
        indicator.pulsing = true
    else
        indicator.alpha = math.max(0, indicator.alpha - 10)
        indicator.pulsing = false
    end
end

-- =====================================================
-- GESTIÓN DE VISIBILIDAD
-- =====================================================

-- Mostrar elementos del vehículo
function HUDManager:showVehicleElements()
    if hudElements.speedometer then
        hudElements.speedometer.visible = true
    end
    
    if hudElements.indicators then
        hudElements.indicators.visible = true
    end
end

-- Ocultar elementos del vehículo
function HUDManager:hideVehicleElements()
    if hudElements.speedometer then
        hudElements.speedometer.visible = false
    end
    
    if hudElements.indicators then
        hudElements.indicators.visible = false
        
        -- Ocultar todos los indicadores
        for name, indicator in pairs(hudElements.indicators) do
            if type(indicator) == "table" and indicator.type == "indicator" then
                indicator.visible = false
                indicator.alpha = 0
            end
        end
    end
end

-- =====================================================
-- ANIMACIONES
-- =====================================================

-- Fade in
function HUDManager:fadeIn(duration, callback)
    duration = duration or self.config.fadeInDuration
    
    self:animateAlpha(0, 255, duration, "InOutQuad", function()
        hudState.visible = true
        if callback then callback() end
    end)
end

-- Fade out
function HUDManager:fadeOut(duration, callback)
    duration = duration or self.config.fadeOutDuration
    
    self:animateAlpha(255, 0, duration, "InOutQuad", function()
        hudState.visible = false
        if callback then callback() end
    end)
end

-- Animar alpha
function HUDManager:animateAlpha(fromAlpha, toAlpha, duration, easing, callback)
    hudState.isAnimating = true
    
    local startTime = getTickCount()
    
    hudTimers.alphaAnimation = setTimer(function()
        local elapsed = getTickCount() - startTime
        local progress = elapsed / duration
        
        if progress >= 1 then
            hudState.alpha = toAlpha
            hudState.isAnimating = false
            
            if hudTimers.alphaAnimation then
                killTimer(hudTimers.alphaAnimation)
                hudTimers.alphaAnimation = nil
            end
            
            if callback then
                callback()
            end
        else
            -- Aplicar easing
            local easedProgress = self:applyEasing(progress, easing or "linear")
            hudState.alpha = fromAlpha + (toAlpha - fromAlpha) * easedProgress
        end
    end, 16, 0) -- ~60 FPS
end

-- Aplicar función de easing
function HUDManager:applyEasing(t, easing)
    if easing == "InOutQuad" then
        return t < 0.5 and 2 * t * t or -1 + (4 - 2 * t) * t
    elseif easing == "OutElastic" then
        return t == 0 and 0 or t == 1 and 1 or (2 ^ (-10 * t)) * math.sin((t * 10 - 0.75) * (2 * math.pi) / 3) + 1
    else
        return t -- Linear
    end
end

-- Actualizar animaciones
function HUDManager:updateAnimations()
    -- Aquí se pueden agregar más animaciones específicas
    -- como animaciones de barras, pulsos, etc.
end

-- =====================================================
-- UTILIDADES
-- =====================================================

-- Aplicar alpha a color
function HUDManager:applyAlpha(color, alpha)
    if not color or #color < 3 then
        return {255, 255, 255, alpha or 255}
    end
    
    return {
        color[1] or 255,
        color[2] or 255,
        color[3] or 255,
        math.floor((color[4] or 255) * (alpha / 255))
    }
end

-- Renderizar borde
function HUDManager:renderBorder(x, y, width, height, borderWidth, color)
    -- Arriba
    renderRectangle(x, y, width, borderWidth, color)
    -- Abajo
    renderRectangle(x, y + height - borderWidth, width, borderWidth, color)
    -- Izquierda
    renderRectangle(x, y, borderWidth, height, color)
    -- Derecha
    renderRectangle(x + width - borderWidth, y, borderWidth, height, color)
end

-- Resetear estados de elementos
function HUDManager:resetElementStates()
    for _, element in pairs(hudElements) do
        if type(element) == "table" then
            element.alpha = 255
            if element.type == "player_hud" then
                element.visible = true
            else
                element.visible = false
            end
        end
    end
end

-- =====================================================
-- CONFIGURAR EVENTOS
-- =====================================================

-- Configurar eventos del HUD
function HUDManager:setupEvents()
    -- Eventos de jugador
    addEventHandler("onPlayerDataUpdate", localPlayer, function(key, value)
        hudState.lastActivity = getTickCount()
    end)
    
    addEventHandler("onVehicleDataUpdate", localPlayer, function(key, value)
        hudState.lastActivity = getTickCount()
    end)
    
    -- Eventos de vehículo
    addEventHandler("onVehicleEnterHUD", localPlayer, function(vehicle)
        self:showVehicleElements()
    end)
    
    addEventHandler("onVehicleExitHUD", localPlayer, function(vehicle)
        self:hideVehicleElements()
    end)
    
    -- Eventos de teclado/mouse para actividad
    addEventHandler("onClientKey", root, function()
        hudState.lastActivity = getTickCount()
    end)
    
    addEventHandler("onClientClick", root, function()
        hudState.lastActivity = getTickCount()
    end)
end

-- =====================================================
-- MÉTODOS PÚBLICOS
-- =====================================================

-- Toggle HUD
function HUDManager:toggle()
    if hudState.visible then
        self:hide()
    else
        self:show()
    end
end

-- Mostrar HUD
function HUDManager:show()
    if self.config.enableAnimations then
        self:fadeIn()
    else
        hudState.visible = true
        hudState.alpha = 255
    end
end

-- Ocultar HUD
function HUDManager:hide()
    if self.config.enableAnimations then
        self:fadeOut()
    else
        hudState.visible = false
        hudState.alpha = 0
    end
end

-- Verificar si está visible
function HUDManager:isVisible()
    return hudState.visible
end

-- Obtener estadísticas
function HUDManager:getStats()
    return {
        visible = hudState.visible,
        alpha = hudState.alpha,
        elementsRendered = renderStats.elementsRendered,
        renderTime = renderStats.renderTime,
        lastActivity = hudState.lastActivity,
        isAnimating = hudState.isAnimating
    }
end

-- Destruir HUD Manager
function HUDManager:destroy()
    -- Limpiar timers
    for name, timer in pairs(hudTimers) do
        if timer then
            killTimer(timer)
        end
    end
    
    -- Remover eventos
    removeEventHandler("onClientRender", root, function() end)
    
    -- Restaurar HUD original
    showPlayerHudComponent("all", true)
end

-- =====================================================
-- INSTANCIA GLOBAL
-- =====================================================
local globalHUDManager = HUDManager:new(HUD_MANAGER_CONFIG)

-- =====================================================
-- FUNCIONES GLOBALES EXPORTADAS
-- =====================================================

-- Inicializar HUD
function initializeHUD()
    return globalHUDManager:initialize()
end

-- Toggle HUD (función exportada)
function toggleHUD()
    globalHUDManager:toggle()
    return globalHUDManager:isVisible()
end

-- Verificar si HUD está habilitado (función exportada)
function isHUDEnabled()
    return globalHUDManager:isVisible()
end

-- Establecer visibilidad del HUD (función exportada)
function setHUDVisible(visible)
    if visible then
        globalHUDManager:show()
    else
        globalHUDManager:hide()
    end
    return globalHUDManager:isVisible()
end

-- Actualizar stats del jugador (función exportada)
function updatePlayerStats(stats)
    if type(stats) == "table" then
        for key, value in pairs(stats) do
            triggerEvent("onPlayerDataUpdate", localPlayer, key, value)
        end
    end
    return true
end

-- Actualizar datos del vehículo (función exportada)
function updateVehicleData(data)
    if type(data) == "table" then
        for key, value in pairs(data) do
            triggerEvent("onVehicleDataUpdate", localPlayer, key, value)
        end
    end
    return true
end

-- Obtener estadísticas del HUD
function getHUDStats()
    return globalHUDManager:getStats()
end

-- =====================================================
-- INICIALIZACIÓN AUTOMÁTICA
-- =====================================================
addEventHandler("onClientResourceStart", resourceRoot, function()
    initializeHUD()
    outputDebugString("HUD Optimizado iniciado correctamente", 3)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    globalHUDManager:destroy()
    outputDebugString("HUD Optimizado detenido", 3)
end)

-- Exportar para uso global
_G.HUDManager = HUDManager
_G.toggleHUD = toggleHUD
_G.isHUDEnabled = isHUDEnabled
_G.setHUDVisible = setHUDVisible