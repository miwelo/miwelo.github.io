-- =====================================================
-- POLYGONMANAGER.LUA - Gestor de Polígonos y Círculos
-- Autor: MIWELO
-- Versión: 1.0.0
-- Descripción: Gestión optimizada de formas geométricas para el HUD
-- =====================================================

PolygonManager = {}
PolygonManager.__index = PolygonManager

-- =====================================================
-- CONFIGURACIÓN
-- =====================================================
local POLYGON_CONFIG = {
    maxPolygons = 100,
    enableCache = true,
    cacheLifetime = 500,
    defaultSegments = 32,
    enableAntialiasing = true,
    optimizeVertices = true
}

-- =====================================================
-- VARIABLES GLOBALES
-- =====================================================
local activePolygons = {}
local polygonCache = {}
local renderQueue = {}
local geometryStats = {
    polygonsRendered = 0,
    verticesGenerated = 0,
    cacheHits = 0,
    cacheMisses = 0
}

-- Cache específico para polígonos
local polygonCacheManager = createCache("polygons", {
    maxSize = 200,
    defaultLifetime = POLYGON_CONFIG.cacheLifetime,
    cleanupInterval = 2000
})

-- =====================================================
-- CONSTRUCTOR
-- =====================================================
function PolygonManager:new(config)
    local instance = {
        config = config or {},
        polygons = {},
        circles = {},
        arcs = {},
        cache = {},
        stats = {
            rendered = 0,
            cached = 0
        }
    }
    
    -- Aplicar configuración por defecto
    for key, value in pairs(POLYGON_CONFIG) do
        if instance.config[key] == nil then
            instance.config[key] = value
        end
    end
    
    setmetatable(instance, PolygonManager)
    return instance
end

-- =====================================================
-- GESTIÓN DE CÍRCULOS
-- =====================================================

-- Crear círculo optimizado
function PolygonManager:createCircle(x, y, radius, segments, filled)
    segments = segments or self.config.defaultSegments
    filled = filled ~= false -- Por defecto true
    
    local cacheKey = string.format("circle_%d_%d_%d_%d_%s", 
        math.floor(x), math.floor(y), math.floor(radius), segments, tostring(filled))
    
    -- Intentar obtener del cache
    local cachedCircle = polygonCacheManager:get(cacheKey)
    if cachedCircle then
        geometryStats.cacheHits = geometryStats.cacheHits + 1
        return cachedCircle
    end
    
    geometryStats.cacheMisses = geometryStats.cacheMisses + 1
    
    -- Generar vértices del círculo
    local vertices = self:generateCircleVertices(x, y, radius, segments)
    
    local circle = {
        type = "circle",
        x = x,
        y = y,
        radius = radius,
        segments = segments,
        filled = filled,
        vertices = vertices,
        boundingBox = self:calculateBoundingBox(vertices),
        id = self:generateId(),
        created = getTickCount()
    }
    
    -- Guardar en cache
    polygonCacheManager:set(cacheKey, circle)
    
    geometryStats.verticesGenerated = geometryStats.verticesGenerated + #vertices
    
    return circle
end

-- Generar vértices de círculo
function PolygonManager:generateCircleVertices(x, y, radius, segments)
    local vertices = {}
    local angleStep = (2 * math.pi) / segments
    
    for i = 0, segments - 1 do
        local angle = i * angleStep
        local vertexX = x + math.cos(angle) * radius
        local vertexY = y + math.sin(angle) * radius
        
        table.insert(vertices, {x = vertexX, y = vertexY, angle = angle})
    end
    
    return vertices
end

-- Crear arco
function PolygonManager:createArc(x, y, radius, startAngle, endAngle, segments, thickness)
    segments = segments or math.max(8, math.floor(self.config.defaultSegments * (endAngle - startAngle) / (2 * math.pi)))
    thickness = thickness or 2
    
    local cacheKey = string.format("arc_%d_%d_%d_%.2f_%.2f_%d_%d", 
        math.floor(x), math.floor(y), math.floor(radius), startAngle, endAngle, segments, thickness)
    
    local cachedArc = polygonCacheManager:get(cacheKey)
    if cachedArc then
        return cachedArc
    end
    
    local vertices = self:generateArcVertices(x, y, radius, startAngle, endAngle, segments, thickness)
    
    local arc = {
        type = "arc",
        x = x,
        y = y,
        radius = radius,
        startAngle = startAngle,
        endAngle = endAngle,
        segments = segments,
        thickness = thickness,
        vertices = vertices,
        boundingBox = self:calculateBoundingBox(vertices),
        id = self:generateId(),
        created = getTickCount()
    }
    
    polygonCacheManager:set(cacheKey, arc)
    return arc
end

-- Generar vértices de arco
function PolygonManager:generateArcVertices(x, y, radius, startAngle, endAngle, segments, thickness)
    local vertices = {}
    local angleStep = (endAngle - startAngle) / segments
    local innerRadius = radius - thickness / 2
    local outerRadius = radius + thickness / 2
    
    -- Generar vértices del arco (quad strip)
    for i = 0, segments do
        local angle = startAngle + i * angleStep
        
        -- Vértice interior
        local innerX = x + math.cos(angle) * innerRadius
        local innerY = y + math.sin(angle) * innerRadius
        table.insert(vertices, {x = innerX, y = innerY, type = "inner"})
        
        -- Vértice exterior
        local outerX = x + math.cos(angle) * outerRadius
        local outerY = y + math.sin(angle) * outerRadius
        table.insert(vertices, {x = outerX, y = outerY, type = "outer"})
    end
    
    return vertices
end

-- =====================================================
-- GESTIÓN DE POLÍGONOS
-- =====================================================

-- Crear polígono regular
function PolygonManager:createRegularPolygon(x, y, radius, sides, rotation)
    sides = sides or 6
    rotation = rotation or 0
    
    local cacheKey = string.format("polygon_%d_%d_%d_%d_%.2f", 
        math.floor(x), math.floor(y), math.floor(radius), sides, rotation)
    
    local cachedPolygon = polygonCacheManager:get(cacheKey)
    if cachedPolygon then
        return cachedPolygon
    end
    
    local vertices = self:generateRegularPolygonVertices(x, y, radius, sides, rotation)
    
    local polygon = {
        type = "polygon",
        x = x,
        y = y,
        radius = radius,
        sides = sides,
        rotation = rotation,
        vertices = vertices,
        boundingBox = self:calculateBoundingBox(vertices),
        id = self:generateId(),
        created = getTickCount()
    }
    
    polygonCacheManager:set(cacheKey, polygon)
    return polygon
end

-- Generar vértices de polígono regular
function PolygonManager:generateRegularPolygonVertices(x, y, radius, sides, rotation)
    local vertices = {}
    local angleStep = (2 * math.pi) / sides
    
    for i = 0, sides - 1 do
        local angle = rotation + i * angleStep
        local vertexX = x + math.cos(angle) * radius
        local vertexY = y + math.sin(angle) * radius
        
        table.insert(vertices, {x = vertexX, y = vertexY})
    end
    
    return vertices
end

-- Crear polígono personalizado
function PolygonManager:createCustomPolygon(vertices, filled)
    filled = filled ~= false
    
    if not vertices or #vertices < 3 then
        return nil
    end
    
    local polygon = {
        type = "custom_polygon",
        vertices = vertices,
        filled = filled,
        boundingBox = self:calculateBoundingBox(vertices),
        id = self:generateId(),
        created = getTickCount()
    }
    
    return polygon
end

-- =====================================================
-- RENDERIZADO DE FORMAS
-- =====================================================

-- Renderizar círculo
function PolygonManager:renderCircle(circle, color, postGUI)
    if not circle or circle.type ~= "circle" then
        return false
    end
    
    color = color or {255, 255, 255, 255}
    postGUI = postGUI or false
    
    if circle.filled then
        return self:renderFilledCircle(circle, color, postGUI)
    else
        return self:renderCircleOutline(circle, color, postGUI)
    end
end

-- Renderizar círculo relleno
function PolygonManager:renderFilledCircle(circle, color, postGUI)
    local vertices = circle.vertices
    local centerX, centerY = circle.x, circle.y
    
    -- Usar triangulación para renderizar el círculo relleno
    for i = 1, #vertices do
        local current = vertices[i]
        local next = vertices[i % #vertices + 1]
        
        -- Crear triángulo desde el centro a dos vértices consecutivos
        self:renderTriangle(
            {x = centerX, y = centerY},
            current,
            next,
            color,
            postGUI
        )
    end
    
    geometryStats.polygonsRendered = geometryStats.polygonsRendered + 1
    return true
end

-- Renderizar contorno de círculo
function PolygonManager:renderCircleOutline(circle, color, postGUI)
    local vertices = circle.vertices
    
    -- Conectar vértices consecutivos con líneas
    for i = 1, #vertices do
        local current = vertices[i]
        local next = vertices[i % #vertices + 1]
        
        dxDrawLine(current.x, current.y, next.x, next.y, tocolor(unpack(color)), 1, postGUI)
    end
    
    geometryStats.polygonsRendered = geometryStats.polygonsRendered + 1
    return true
end

-- Renderizar arco
function PolygonManager:renderArc(arc, color, postGUI)
    if not arc or arc.type ~= "arc" then
        return false
    end
    
    color = color or {255, 255, 255, 255}
    postGUI = postGUI or false
    
    local vertices = arc.vertices
    
    -- Renderizar como quad strip
    for i = 1, #vertices - 2, 2 do
        local v1 = vertices[i]     -- Inner current
        local v2 = vertices[i + 1] -- Outer current
        local v3 = vertices[i + 2] -- Inner next
        local v4 = vertices[i + 3] -- Outer next
        
        -- Renderizar quad como dos triángulos
        if v1 and v2 and v3 and v4 then
            self:renderTriangle(v1, v2, v3, color, postGUI)
            self:renderTriangle(v2, v3, v4, color, postGUI)
        end
    end
    
    geometryStats.polygonsRendered = geometryStats.polygonsRendered + 1
    return true
end

-- Renderizar polígono
function PolygonManager:renderPolygon(polygon, color, postGUI)
    if not polygon or not polygon.vertices then
        return false
    end
    
    color = color or {255, 255, 255, 255}
    postGUI = postGUI or false
    
    if polygon.filled then
        return self:renderFilledPolygon(polygon, color, postGUI)
    else
        return self:renderPolygonOutline(polygon, color, postGUI)
    end
end

-- Renderizar polígono relleno
function PolygonManager:renderFilledPolygon(polygon, color, postGUI)
    local vertices = polygon.vertices
    
    if #vertices < 3 then
        return false
    end
    
    -- Triangulación fan desde el primer vértice
    local center = vertices[1]
    for i = 2, #vertices - 1 do
        local current = vertices[i]
        local next = vertices[i + 1]
        
        self:renderTriangle(center, current, next, color, postGUI)
    end
    
    geometryStats.polygonsRendered = geometryStats.polygonsRendered + 1
    return true
end

-- Renderizar contorno de polígono
function PolygonManager:renderPolygonOutline(polygon, color, postGUI)
    local vertices = polygon.vertices
    
    for i = 1, #vertices do
        local current = vertices[i]
        local next = vertices[i % #vertices + 1]
        
        dxDrawLine(current.x, current.y, next.x, next.y, tocolor(unpack(color)), 1, postGUI)
    end
    
    geometryStats.polygonsRendered = geometryStats.polygonsRendered + 1
    return true
end

-- =====================================================
-- UTILIDADES DE RENDERIZADO
-- =====================================================

-- Renderizar triángulo
function PolygonManager:renderTriangle(v1, v2, v3, color, postGUI)
    -- Crear triángulo usando tres líneas
    dxDrawLine(v1.x, v1.y, v2.x, v2.y, tocolor(unpack(color)), 1, postGUI)
    dxDrawLine(v2.x, v2.y, v3.x, v3.y, tocolor(unpack(color)), 1, postGUI)
    dxDrawLine(v3.x, v3.y, v1.x, v1.y, tocolor(unpack(color)), 1, postGUI)
    
    -- Para relleno, podrías usar una textura o múltiples líneas
    if self.config.enableAntialiasing then
        self:fillTriangle(v1, v2, v3, color, postGUI)
    end
    
    return true
end

-- Rellenar triángulo (simplificado)
function PolygonManager:fillTriangle(v1, v2, v3, color, postGUI)
    -- Implementación simplificada de relleno
    -- En una implementación real, usarías scanline o barycentric coordinates
    
    local minY = math.min(v1.y, v2.y, v3.y)
    local maxY = math.max(v1.y, v2.y, v3.y)
    
    for y = minY, maxY, 2 do -- Paso de 2 para optimización
        local intersections = self:getLineIntersections(y, v1, v2, v3)
        
        if #intersections >= 2 then
            table.sort(intersections)
            dxDrawLine(intersections[1], y, intersections[#intersections], y, tocolor(unpack(color)), 1, postGUI)
        end
    end
end

-- Obtener intersecciones de línea horizontal con triángulo
function PolygonManager:getLineIntersections(y, v1, v2, v3)
    local intersections = {}
    
    -- Verificar intersección con cada lado del triángulo
    local sides = {{v1, v2}, {v2, v3}, {v3, v1}}
    
    for _, side in ipairs(sides) do
        local p1, p2 = side[1], side[2]
        
        if (p1.y <= y and p2.y >= y) or (p1.y >= y and p2.y <= y) then
            if p1.y ~= p2.y then
                local x = p1.x + (y - p1.y) * (p2.x - p1.x) / (p2.y - p1.y)
                table.insert(intersections, x)
            end
        end
    end
    
    return intersections
end

-- =====================================================
-- FORMAS ESPECIALES PARA HUD
-- =====================================================

-- Crear medidor circular (como velocímetro)
function PolygonManager:createCircularGauge(x, y, radius, startAngle, endAngle, value, maxValue, thickness)
    startAngle = startAngle or -math.pi * 0.75  -- -135°
    endAngle = endAngle or math.pi * 0.75       -- 135°
    value = value or 0
    maxValue = maxValue or 100
    thickness = thickness or 10
    
    -- Calcular ángulo actual basado en el valor
    local valueAngle = startAngle + (endAngle - startAngle) * (value / maxValue)
    
    -- Crear arco de fondo
    local backgroundArc = self:createArc(x, y, radius, startAngle, endAngle, 64, thickness)
    
    -- Crear arco de valor
    local valueArc = self:createArc(x, y, radius, startAngle, valueAngle, 32, thickness)
    
    return {
        type = "circular_gauge",
        x = x,
        y = y,
        radius = radius,
        startAngle = startAngle,
        endAngle = endAngle,
        value = value,
        maxValue = maxValue,
        thickness = thickness,
        backgroundArc = backgroundArc,
        valueArc = valueArc,
        id = self:generateId()
    }
end

-- Renderizar medidor circular
function PolygonManager:renderCircularGauge(gauge, backgroundColor, valueColor, postGUI)
    backgroundColor = backgroundColor or {100, 100, 100, 100}
    valueColor = valueColor or {255, 255, 255, 255}
    
    -- Renderizar fondo
    self:renderArc(gauge.backgroundArc, backgroundColor, postGUI)
    
    -- Renderizar valor
    self:renderArc(gauge.valueArc, valueColor, postGUI)
    
    return true
end

-- Crear barra de progreso circular
function PolygonManager:createCircularProgressBar(x, y, radius, value, maxValue, thickness, segments)
    value = math.max(0, math.min(value or 0, maxValue or 100))
    maxValue = maxValue or 100
    thickness = thickness or 8
    segments = segments or 64
    
    local progress = value / maxValue
    local endAngle = -math.pi / 2 + (2 * math.pi * progress) -- Comenzar desde arriba
    
    local progressArc = self:createArc(x, y, radius, -math.pi / 2, endAngle, 
                                     math.floor(segments * progress), thickness)
    
    return {
        type = "circular_progress",
        x = x,
        y = y,
        radius = radius,
        value = value,
        maxValue = maxValue,
        progress = progress,
        thickness = thickness,
        arc = progressArc,
        id = self:generateId()
    }
end

-- =====================================================
-- UTILIDADES
-- =====================================================

-- Calcular bounding box
function PolygonManager:calculateBoundingBox(vertices)
    if not vertices or #vertices == 0 then
        return {minX = 0, minY = 0, maxX = 0, maxY = 0}
    end
    
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    
    for _, vertex in ipairs(vertices) do
        minX = math.min(minX, vertex.x)
        maxX = math.max(maxX, vertex.x)
        minY = math.min(minY, vertex.y)
        maxY = math.max(maxY, vertex.y)
    end
    
    return {
        minX = minX,
        minY = minY,
        maxX = maxX,
        maxY = maxY,
        width = maxX - minX,
        height = maxY - minY
    }
end

-- Generar ID único
function PolygonManager:generateId()
    return "poly_" .. math.random(100000, 999999) .. "_" .. getTickCount()
end

-- Verificar si un punto está dentro de un polígono
function PolygonManager:pointInPolygon(x, y, vertices)
    local inside = false
    local j = #vertices
    
    for i = 1, #vertices do
        local xi, yi = vertices[i].x, vertices[i].y
        local xj, yj = vertices[j].x, vertices[j].y
        
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    
    return inside
end

-- Obtener estadísticas
function PolygonManager:getStats()
    return {
        polygonsRendered = geometryStats.polygonsRendered,
        verticesGenerated = geometryStats.verticesGenerated,
        cacheHits = geometryStats.cacheHits,
        cacheMisses = geometryStats.cacheMisses,
        cacheHitRate = geometryStats.cacheHits / math.max(1, geometryStats.cacheHits + geometryStats.cacheMisses) * 100
    }
end

-- Limpiar estadísticas
function PolygonManager:clearStats()
    geometryStats = {
        polygonsRendered = 0,
        verticesGenerated = 0,
        cacheHits = 0,
        cacheMisses = 0
    }
end

-- =====================================================
-- INSTANCIA GLOBAL
-- =====================================================
local globalPolygonManager = PolygonManager:new(POLYGON_CONFIG)

-- =====================================================
-- FUNCIONES GLOBALES
-- =====================================================

-- Crear círculo
function createCircle(x, y, radius, segments, filled)
    return globalPolygonManager:createCircle(x, y, radius, segments, filled)
end

-- Renderizar círculo
function renderCircle(circle, color, postGUI)
    return globalPolygonManager:renderCircle(circle, color, postGUI)
end

-- Crear arco
function createArc(x, y, radius, startAngle, endAngle, segments, thickness)
    return globalPolygonManager:createArc(x, y, radius, startAngle, endAngle, segments, thickness)
end

-- Renderizar arco
function renderArc(arc, color, postGUI)
    return globalPolygonManager:renderArc(arc, color, postGUI)
end

-- Crear medidor circular
function createCircularGauge(x, y, radius, startAngle, endAngle, value, maxValue, thickness)
    return globalPolygonManager:createCircularGauge(x, y, radius, startAngle, endAngle, value, maxValue, thickness)
end

-- Renderizar medidor circular
function renderCircularGauge(gauge, backgroundColor, valueColor, postGUI)
    return globalPolygonManager:renderCircularGauge(gauge, backgroundColor, valueColor, postGUI)
end

-- Crear barra de progreso circular
function createCircularProgressBar(x, y, radius, value, maxValue, thickness, segments)
    return globalPolygonManager:createCircularProgressBar(x, y, radius, value, maxValue, thickness, segments)
end

-- Obtener estadísticas de polígonos
function getPolygonStats()
    return globalPolygonManager:getStats()
end

-- Exportar para uso global
_G.PolygonManager = PolygonManager
_G.createCircle = createCircle
_G.renderCircle = renderCircle
_G.createCircularGauge = createCircularGauge