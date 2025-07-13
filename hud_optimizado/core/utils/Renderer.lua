-- =====================================================
-- RENDERER.LUA - Sistema de Renderizado Optimizado
-- Autor: MIWELO
-- Versión: 1.0.0
-- Descripción: Renderizador optimizado con batching y cache
-- =====================================================

Renderer = {}
Renderer.__index = Renderer

-- =====================================================
-- CONFIGURACIÓN DEL RENDERIZADOR
-- =====================================================
local RENDER_CONFIG = {
    maxBatchSize = 100,
    enableBatching = true,
    enableFrustumCulling = true,
    enableCache = true,
    targetFPS = 60,
    maxDrawCalls = 150
}

-- =====================================================
-- VARIABLES GLOBALES
-- =====================================================
local renderQueue = {}
local batchQueue = {}
local renderStats = {
    drawCalls = 0,
    batchedCalls = 0,
    culledObjects = 0,
    frameTime = 0,
    lastFrame = 0
}

local isRendering = false
local lastRenderTime = 0
local frameCount = 0
local fpsCounter = 0
local lastFPSUpdate = 0

-- =====================================================
-- CONSTRUCTOR
-- =====================================================
function Renderer:new(config)
    local instance = {
        config = config or {},
        queue = {},
        batchQueue = {},
        shaders = {},
        fonts = {},
        textures = {},
        renderTargets = {},
        stats = {
            drawCalls = 0,
            batchedCalls = 0,
            frameTime = 0
        }
    }
    
    -- Aplicar configuración por defecto
    for key, value in pairs(RENDER_CONFIG) do
        if instance.config[key] == nil then
            instance.config[key] = value
        end
    end
    
    setmetatable(instance, Renderer)
    return instance
end

-- =====================================================
-- GESTIÓN DE RENDERIZADO
-- =====================================================

-- Inicializar sistema de renderizado
function Renderer:initialize()
    -- Cargar shaders
    self:loadShaders()
    
    -- Cargar fuentes
    self:loadFonts()
    
    -- Configurar eventos de renderizado
    addEventHandler("onClientRender", root, function()
        self:onRender()
    end)
    
    addEventHandler("onClientPreRender", root, function()
        self:onPreRender()
    end)
    
    addEventHandler("onClientHUDRender", root, function()
        self:onHUDRender()
    end)
    
    return true
end

-- Evento principal de renderizado
function Renderer:onRender()
    if not HUD_CONFIG.GENERAL.enabled then
        return
    end
    
    local currentTime = getTickCount()
    local deltaTime = currentTime - (self.lastRenderTime or currentTime)
    
    -- Control de FPS
    if deltaTime < (1000 / self.config.targetFPS) then
        return
    end
    
    self.lastRenderTime = currentTime
    
    -- Inicializar frame
    self:beginFrame()
    
    -- Procesar cola de renderizado
    self:processRenderQueue()
    
    -- Finalizar frame
    self:endFrame()
    
    -- Actualizar estadísticas
    self:updateStats(deltaTime)
end

-- Evento de pre-renderizado
function Renderer:onPreRender()
    -- Limpiar cola anterior
    self:clearQueue()
    
    -- Preparar frustum culling
    self:updateViewport()
end

-- Evento de renderizado de HUD
function Renderer:onHUDRender()
    -- Renderizar elementos específicos del HUD
    self:renderHUDElements()
end

-- =====================================================
-- GESTIÓN DE COLA DE RENDERIZADO
-- =====================================================

-- Agregar elemento a la cola de renderizado
function Renderer:addToQueue(element)
    if not element or not element.type then
        return false
    end
    
    -- Aplicar frustum culling si está habilitado
    if self.config.enableFrustumCulling and not self:isInViewport(element) then
        renderStats.culledObjects = renderStats.culledObjects + 1
        return false
    end
    
    -- Agregar prioridad si no existe
    element.priority = element.priority or 0
    element.id = element.id or (#self.queue + 1)
    
    table.insert(self.queue, element)
    
    return true
end

-- Procesar cola de renderizado
function Renderer:processRenderQueue()
    if #self.queue == 0 then
        return
    end
    
    -- Ordenar por prioridad y tipo para optimizar batching
    table.sort(self.queue, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return a.type < b.type
    end)
    
    -- Procesar elementos
    if self.config.enableBatching then
        self:processBatched()
    else
        self:processIndividual()
    end
end

-- Procesar elementos individualmente
function Renderer:processIndividual()
    for _, element in ipairs(self.queue) do
        self:renderElement(element)
        renderStats.drawCalls = renderStats.drawCalls + 1
    end
end

-- Procesar elementos con batching
function Renderer:processBatched()
    local batches = self:createBatches()
    
    for _, batch in ipairs(batches) do
        self:renderBatch(batch)
        renderStats.batchedCalls = renderStats.batchedCalls + 1
    end
end

-- Crear batches de elementos similares
function Renderer:createBatches()
    local batches = {}
    local currentBatch = nil
    
    for _, element in ipairs(self.queue) do
        if not currentBatch or 
           currentBatch.type ~= element.type or 
           #currentBatch.elements >= self.config.maxBatchSize then
            
            currentBatch = {
                type = element.type,
                elements = {},
                shader = element.shader,
                texture = element.texture
            }
            table.insert(batches, currentBatch)
        end
        
        table.insert(currentBatch.elements, element)
    end
    
    return batches
end

-- =====================================================
-- RENDERIZADO DE ELEMENTOS
-- =====================================================

-- Renderizar elemento individual
function Renderer:renderElement(element)
    local success = false
    
    -- Configurar shader si existe
    if element.shader and self.shaders[element.shader] then
        dxSetShaderValue(self.shaders[element.shader], "gTime", getTickCount() / 1000)
    end
    
    -- Renderizar según el tipo
    if element.type == "rectangle" then
        success = self:renderRectangle(element)
    elseif element.type == "text" then
        success = self:renderText(element)
    elseif element.type == "image" then
        success = self:renderImage(element)
    elseif element.type == "line" then
        success = self:renderLine(element)
    elseif element.type == "circle" then
        success = self:renderCircle(element)
    elseif element.type == "polygon" then
        success = self:renderPolygon(element)
    end
    
    return success
end

-- Renderizar batch de elementos
function Renderer:renderBatch(batch)
    if #batch.elements == 0 then
        return false
    end
    
    -- Configurar estado del batch
    if batch.shader and self.shaders[batch.shader] then
        dxSetShaderValue(self.shaders[batch.shader], "gTime", getTickCount() / 1000)
    end
    
    -- Renderizar elementos del batch
    for _, element in ipairs(batch.elements) do
        self:renderElement(element)
    end
    
    return true
end

-- =====================================================
-- MÉTODOS DE RENDERIZADO ESPECÍFICOS
-- =====================================================

-- Renderizar rectángulo
function Renderer:renderRectangle(element)
    local x = element.x or 0
    local y = element.y or 0
    local w = element.width or 100
    local h = element.height or 100
    local color = element.color or {255, 255, 255, 255}
    local postGUI = element.postGUI or false
    
    return dxDrawRectangle(x, y, w, h, tocolor(unpack(color)), postGUI)
end

-- Renderizar texto
function Renderer:renderText(element)
    local text = element.text or ""
    local x = element.x or 0
    local y = element.y or 0
    local w = element.width or 0
    local h = element.height or 0
    local color = element.color or {255, 255, 255, 255}
    local scale = element.scale or 1
    local font = element.font or "default"
    local alignX = element.alignX or "left"
    local alignY = element.alignY or "top"
    local clip = element.clip or false
    local wordBreak = element.wordBreak or false
    local postGUI = element.postGUI or false
    
    -- Usar fuente personalizada si está disponible
    local fontElement = self.fonts[font] or font
    
    return dxDrawText(text, x, y, x + w, y + h, tocolor(unpack(color)), 
                     scale, fontElement, alignX, alignY, clip, wordBreak, postGUI)
end

-- Renderizar imagen
function Renderer:renderImage(element)
    local texture = element.texture or ""
    local x = element.x or 0
    local y = element.y or 0
    local w = element.width or 100
    local h = element.height or 100
    local rotation = element.rotation or 0
    local rotationCenterX = element.rotationCenterX or 0
    local rotationCenterY = element.rotationCenterY or 0
    local color = element.color or {255, 255, 255, 255}
    local postGUI = element.postGUI or false
    
    -- Usar textura cacheada si está disponible
    local textureElement = self.textures[texture] or texture
    
    return dxDrawImage(x, y, w, h, textureElement, rotation, 
                      rotationCenterX, rotationCenterY, tocolor(unpack(color)), postGUI)
end

-- Renderizar línea
function Renderer:renderLine(element)
    local startX = element.startX or 0
    local startY = element.startY or 0
    local endX = element.endX or 100
    local endY = element.endY or 100
    local color = element.color or {255, 255, 255, 255}
    local width = element.width or 1
    local postGUI = element.postGUI or false
    
    return dxDrawLine(startX, startY, endX, endY, tocolor(unpack(color)), width, postGUI)
end

-- Renderizar círculo
function Renderer:renderCircle(element)
    local x = element.x or 0
    local y = element.y or 0
    local radius = element.radius or 50
    local color = element.color or {255, 255, 255, 255}
    local segments = element.segments or 32
    local filled = element.filled or true
    local postGUI = element.postGUI or false
    
    if filled then
        return self:renderFilledCircle(x, y, radius, color, segments, postGUI)
    else
        return self:renderCircleOutline(x, y, radius, color, segments, postGUI)
    end
end

-- Renderizar círculo relleno
function Renderer:renderFilledCircle(x, y, radius, color, segments, postGUI)
    local angleStep = (2 * math.pi) / segments
    
    for i = 0, segments - 1 do
        local angle1 = i * angleStep
        local angle2 = (i + 1) * angleStep
        
        local x1 = x + math.cos(angle1) * radius
        local y1 = y + math.sin(angle1) * radius
        local x2 = x + math.cos(angle2) * radius
        local y2 = y + math.sin(angle2) * radius
        
        -- Dibujar triángulo del centro a los puntos del perímetro
        dxDrawLine(x, y, x1, y1, tocolor(unpack(color)), 1, postGUI)
        dxDrawLine(x1, y1, x2, y2, tocolor(unpack(color)), 1, postGUI)
        dxDrawLine(x2, y2, x, y, tocolor(unpack(color)), 1, postGUI)
    end
    
    return true
end

-- Renderizar contorno de círculo
function Renderer:renderCircleOutline(x, y, radius, color, segments, postGUI)
    local angleStep = (2 * math.pi) / segments
    local prevX, prevY = x + radius, y
    
    for i = 1, segments do
        local angle = i * angleStep
        local newX = x + math.cos(angle) * radius
        local newY = y + math.sin(angle) * radius
        
        dxDrawLine(prevX, prevY, newX, newY, tocolor(unpack(color)), 1, postGUI)
        
        prevX, prevY = newX, newY
    end
    
    return true
end

-- =====================================================
-- GESTIÓN DE RECURSOS
-- =====================================================

-- Cargar shaders
function Renderer:loadShaders()
    local shaderPath = HUD_CONFIG.ASSETS.shaders.circle
    if fileExists(shaderPath) then
        self.shaders.circle = dxCreateShader(shaderPath)
        if self.shaders.circle then
            outputDebugString("Shader de círculo cargado correctamente", 3)
        end
    end
end

-- Cargar fuentes
function Renderer:loadFonts()
    for name, path in pairs(HUD_CONFIG.ASSETS.fonts) do
        if type(path) == "string" and fileExists(path) then
            self.fonts[name] = dxCreateFont(path, HUD_CONFIG.ASSETS.fonts.defaultSize or 12)
            if self.fonts[name] then
                outputDebugString("Fuente '" .. name .. "' cargada correctamente", 3)
            end
        end
    end
end

-- Cargar textura
function Renderer:loadTexture(name, path)
    if fileExists(path) then
        self.textures[name] = dxCreateTexture(path)
        return self.textures[name] ~= nil
    end
    return false
end

-- =====================================================
-- UTILIDADES
-- =====================================================

-- Verificar si un elemento está en el viewport
function Renderer:isInViewport(element)
    if not element.x or not element.y then
        return true -- Asumir que está visible si no tiene posición
    end
    
    local screenW, screenH = guiGetScreenSize()
    local x, y = element.x, element.y
    local w, h = element.width or 0, element.height or 0
    
    return not (x + w < 0 or x > screenW or y + h < 0 or y > screenH)
end

-- Actualizar viewport
function Renderer:updateViewport()
    local screenW, screenH = guiGetScreenSize()
    self.viewport = {
        x = 0,
        y = 0,
        width = screenW,
        height = screenH
    }
end

-- Limpiar cola de renderizado
function Renderer:clearQueue()
    self.queue = {}
end

-- Inicializar frame
function Renderer:beginFrame()
    renderStats.drawCalls = 0
    renderStats.batchedCalls = 0
    renderStats.culledObjects = 0
    isRendering = true
end

-- Finalizar frame
function Renderer:endFrame()
    isRendering = false
    frameCount = frameCount + 1
end

-- Actualizar estadísticas
function Renderer:updateStats(deltaTime)
    renderStats.frameTime = deltaTime
    renderStats.lastFrame = getTickCount()
    
    -- Calcular FPS
    local currentTime = getTickCount()
    if currentTime - lastFPSUpdate >= 1000 then
        fpsCounter = frameCount
        frameCount = 0
        lastFPSUpdate = currentTime
    end
end

-- Obtener estadísticas
function Renderer:getStats()
    return {
        drawCalls = renderStats.drawCalls,
        batchedCalls = renderStats.batchedCalls,
        culledObjects = renderStats.culledObjects,
        frameTime = renderStats.frameTime,
        fps = fpsCounter,
        queueSize = #self.queue
    }
end

-- =====================================================
-- INSTANCIA GLOBAL
-- =====================================================
local globalRenderer = Renderer:new(RENDER_CONFIG)

-- =====================================================
-- FUNCIONES GLOBALES
-- =====================================================

-- Inicializar renderizador global
function initializeRenderer()
    return globalRenderer:initialize()
end

-- Agregar elemento al renderizador global
function addRenderElement(element)
    return globalRenderer:addToQueue(element)
end

-- Obtener estadísticas del renderizador
function getRenderStats()
    return globalRenderer:getStats()
end

-- Limpiar cola de renderizado global
function clearRenderQueue()
    globalRenderer:clearQueue()
end

-- =====================================================
-- FUNCIONES DE CONVENIENCIA
-- =====================================================

-- Renderizar rectángulo simple
function renderRectangle(x, y, width, height, color, priority)
    return addRenderElement({
        type = "rectangle",
        x = x,
        y = y,
        width = width,
        height = height,
        color = color or {255, 255, 255, 255},
        priority = priority or 0
    })
end

-- Renderizar texto simple
function renderText(text, x, y, width, height, color, scale, font, priority)
    return addRenderElement({
        type = "text",
        text = text,
        x = x,
        y = y,
        width = width or 0,
        height = height or 0,
        color = color or {255, 255, 255, 255},
        scale = scale or 1,
        font = font or "default",
        priority = priority or 0
    })
end

-- Renderizar imagen simple
function renderImage(texture, x, y, width, height, color, priority)
    return addRenderElement({
        type = "image",
        texture = texture,
        x = x,
        y = y,
        width = width,
        height = height,
        color = color or {255, 255, 255, 255},
        priority = priority or 0
    })
end

-- =====================================================
-- INICIALIZACIÓN AUTOMÁTICA
-- =====================================================
addEventHandler("onClientResourceStart", resourceRoot, function()
    initializeRenderer()
end)

-- Exportar para uso global
_G.Renderer = Renderer
_G.addRenderElement = addRenderElement
_G.getRenderStats = getRenderStats