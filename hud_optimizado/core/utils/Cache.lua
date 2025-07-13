-- =====================================================
-- CACHE.LUA - Sistema de Cache Inteligente
-- Autor: MIWELO
-- Versión: 1.0.0
-- Descripción: Sistema de cache optimizado para reducir cálculos repetitivos
-- =====================================================

Cache = {}
Cache.__index = Cache

-- =====================================================
-- CONFIGURACIÓN DEL CACHE
-- =====================================================
local CACHE_CONFIG = {
    maxSize = 1000,           -- Máximo número de entradas
    defaultLifetime = 1000,   -- Tiempo de vida por defecto (ms)
    cleanupInterval = 5000,   -- Intervalo de limpieza (ms)
    enableStats = true        -- Estadísticas habilitadas
}

-- =====================================================
-- VARIABLES GLOBALES
-- =====================================================
local cacheInstances = {}
local globalStats = {
    hits = 0,
    misses = 0,
    evictions = 0,
    totalRequests = 0
}

-- =====================================================
-- CONSTRUCTOR
-- =====================================================
function Cache:new(name, config)
    local instance = {
        name = name or "default",
        config = config or {},
        data = {},
        metadata = {},
        size = 0,
        stats = {
            hits = 0,
            misses = 0,
            evictions = 0,
            lastCleanup = getTickCount()
        }
    }
    
    -- Aplicar configuración por defecto
    for key, value in pairs(CACHE_CONFIG) do
        if instance.config[key] == nil then
            instance.config[key] = value
        end
    end
    
    setmetatable(instance, Cache)
    
    -- Registrar instancia
    cacheInstances[name] = instance
    
    -- Iniciar limpieza automática
    if instance.config.cleanupInterval > 0 then
        instance:startCleanupTimer()
    end
    
    return instance
end

-- =====================================================
-- MÉTODOS PRINCIPALES
-- =====================================================

-- Obtener valor del cache
function Cache:get(key)
    self.stats.totalRequests = (self.stats.totalRequests or 0) + 1
    globalStats.totalRequests = globalStats.totalRequests + 1
    
    local entry = self.data[key]
    
    if not entry then
        self.stats.misses = self.stats.misses + 1
        globalStats.misses = globalStats.misses + 1
        return nil
    end
    
    local metadata = self.metadata[key]
    local currentTime = getTickCount()
    
    -- Verificar si ha expirado
    if metadata.expires and currentTime > metadata.expires then
        self:remove(key)
        self.stats.misses = self.stats.misses + 1
        globalStats.misses = globalStats.misses + 1
        return nil
    end
    
    -- Actualizar último acceso
    metadata.lastAccessed = currentTime
    metadata.accessCount = (metadata.accessCount or 0) + 1
    
    self.stats.hits = self.stats.hits + 1
    globalStats.hits = globalStats.hits + 1
    
    return entry
end

-- Establecer valor en el cache
function Cache:set(key, value, lifetime)
    local currentTime = getTickCount()
    lifetime = lifetime or self.config.defaultLifetime
    
    -- Si la clave ya existe, actualizarla
    if self.data[key] then
        self.data[key] = value
        local metadata = self.metadata[key]
        metadata.created = currentTime
        metadata.lastAccessed = currentTime
        metadata.expires = lifetime > 0 and (currentTime + lifetime) or nil
        return true
    end
    
    -- Verificar espacio disponible
    if self.size >= self.config.maxSize then
        self:evictLRU()
    end
    
    -- Agregar nueva entrada
    self.data[key] = value
    self.metadata[key] = {
        created = currentTime,
        lastAccessed = currentTime,
        expires = lifetime > 0 and (currentTime + lifetime) or nil,
        accessCount = 0,
        size = self:calculateSize(value)
    }
    
    self.size = self.size + 1
    return true
end

-- Remover entrada del cache
function Cache:remove(key)
    if self.data[key] then
        self.data[key] = nil
        self.metadata[key] = nil
        self.size = self.size - 1
        return true
    end
    return false
end

-- Verificar si existe una clave
function Cache:has(key)
    if not self.data[key] then
        return false
    end
    
    local metadata = self.metadata[key]
    local currentTime = getTickCount()
    
    -- Verificar expiración
    if metadata.expires and currentTime > metadata.expires then
        self:remove(key)
        return false
    end
    
    return true
end

-- Obtener o establecer (con función generadora)
function Cache:getOrSet(key, generator, lifetime)
    local value = self:get(key)
    
    if value ~= nil then
        return value
    end
    
    -- Generar nuevo valor
    if type(generator) == "function" then
        value = generator()
    else
        value = generator
    end
    
    if value ~= nil then
        self:set(key, value, lifetime)
    end
    
    return value
end

-- =====================================================
-- MÉTODOS DE LIMPIEZA
-- =====================================================

-- Limpiar entradas expiradas
function Cache:cleanup()
    local currentTime = getTickCount()
    local removed = 0
    
    for key, metadata in pairs(self.metadata) do
        if metadata.expires and currentTime > metadata.expires then
            self:remove(key)
            removed = removed + 1
        end
    end
    
    self.stats.lastCleanup = currentTime
    return removed
end

-- Evacuar entrada LRU (Least Recently Used)
function Cache:evictLRU()
    local oldestKey = nil
    local oldestTime = math.huge
    
    for key, metadata in pairs(self.metadata) do
        if metadata.lastAccessed < oldestTime then
            oldestTime = metadata.lastAccessed
            oldestKey = key
        end
    end
    
    if oldestKey then
        self:remove(oldestKey)
        self.stats.evictions = self.stats.evictions + 1
        globalStats.evictions = globalStats.evictions + 1
    end
end

-- Limpiar todo el cache
function Cache:clear()
    self.data = {}
    self.metadata = {}
    self.size = 0
end

-- =====================================================
-- MÉTODOS DE UTILIDAD
-- =====================================================

-- Calcular tamaño aproximado de un valor
function Cache:calculateSize(value)
    local valueType = type(value)
    
    if valueType == "string" then
        return #value
    elseif valueType == "table" then
        return self:calculateTableSize(value)
    elseif valueType == "number" then
        return 8
    elseif valueType == "boolean" then
        return 1
    else
        return 16 -- Tamaño estimado para otros tipos
    end
end

-- Calcular tamaño de tabla (recursivo con protección)
function Cache:calculateTableSize(tbl, visited)
    if type(tbl) ~= "table" then
        return 0
    end
    
    visited = visited or {}
    if visited[tbl] then
        return 0 -- Evitar referencias circulares
    end
    visited[tbl] = true
    
    local size = 0
    for key, value in pairs(tbl) do
        size = size + self:calculateSize(key) + self:calculateSize(value)
        if type(value) == "table" then
            size = size + self:calculateTableSize(value, visited)
        end
    end
    
    return size
end

-- Iniciar timer de limpieza automática
function Cache:startCleanupTimer()
    if self.cleanupTimer then
        killTimer(self.cleanupTimer)
    end
    
    self.cleanupTimer = setTimer(function()
        self:cleanup()
    end, self.config.cleanupInterval, 0)
end

-- Detener timer de limpieza
function Cache:stopCleanupTimer()
    if self.cleanupTimer then
        killTimer(self.cleanupTimer)
        self.cleanupTimer = nil
    end
end

-- =====================================================
-- MÉTODOS DE ESTADÍSTICAS
-- =====================================================

-- Obtener estadísticas del cache
function Cache:getStats()
    local totalRequests = self.stats.hits + self.stats.misses
    local hitRate = totalRequests > 0 and (self.stats.hits / totalRequests * 100) or 0
    
    return {
        name = self.name,
        size = self.size,
        maxSize = self.config.maxSize,
        hits = self.stats.hits,
        misses = self.stats.misses,
        evictions = self.stats.evictions,
        hitRate = hitRate,
        totalRequests = totalRequests,
        lastCleanup = self.stats.lastCleanup,
        memoryUsage = self:getMemoryUsage()
    }
end

-- Obtener uso de memoria estimado
function Cache:getMemoryUsage()
    local total = 0
    for key, metadata in pairs(self.metadata) do
        total = total + (metadata.size or 0)
    end
    return total
end

-- =====================================================
-- FUNCIONES GLOBALES
-- =====================================================

-- Obtener instancia de cache
function getCache(name)
    return cacheInstances[name]
end

-- Crear o obtener cache
function createCache(name, config)
    if cacheInstances[name] then
        return cacheInstances[name]
    end
    return Cache:new(name, config)
end

-- Obtener estadísticas globales
function getCacheGlobalStats()
    local totalRequests = globalStats.hits + globalStats.misses
    local globalHitRate = totalRequests > 0 and (globalStats.hits / totalRequests * 100) or 0
    
    return {
        instances = table.size(cacheInstances),
        totalHits = globalStats.hits,
        totalMisses = globalStats.misses,
        totalEvictions = globalStats.evictions,
        totalRequests = globalStats.totalRequests,
        globalHitRate = globalHitRate
    }
end

-- Limpiar todos los caches
function cleanupAllCaches()
    local totalRemoved = 0
    for name, cache in pairs(cacheInstances) do
        totalRemoved = totalRemoved + cache:cleanup()
    end
    return totalRemoved
end

-- Destruir cache
function destroyCache(name)
    local cache = cacheInstances[name]
    if cache then
        cache:stopCleanupTimer()
        cache:clear()
        cacheInstances[name] = nil
        return true
    end
    return false
end

-- =====================================================
-- CACHE PREDEFINIDOS
-- =====================================================

-- Cache para datos de jugador
local playerDataCache = Cache:new("playerData", {
    maxSize = 100,
    defaultLifetime = 500,
    cleanupInterval = 2000
})

-- Cache para datos de vehículo
local vehicleDataCache = Cache:new("vehicleData", {
    maxSize = 50,
    defaultLifetime = 100,
    cleanupInterval = 1000
})

-- Cache para renderizado
local renderCache = Cache:new("render", {
    maxSize = 200,
    defaultLifetime = 1000,
    cleanupInterval = 3000
})

-- =====================================================
-- FUNCIONES DE CONVENIENCIA
-- =====================================================

-- Cache específico para datos de jugador
function cachePlayerData(key, value, lifetime)
    return playerDataCache:set(key, value, lifetime)
end

function getCachedPlayerData(key)
    return playerDataCache:get(key)
end

-- Cache específico para datos de vehículo
function cacheVehicleData(key, value, lifetime)
    return vehicleDataCache:set(key, value, lifetime)
end

function getCachedVehicleData(key)
    return vehicleDataCache:get(key)
end

-- Cache específico para renderizado
function cacheRenderData(key, value, lifetime)
    return renderCache:set(key, value, lifetime)
end

function getCachedRenderData(key)
    return renderCache:get(key)
end

-- =====================================================
-- INICIALIZACIÓN
-- =====================================================

-- Limpiar caches automáticamente cada 10 segundos
setTimer(cleanupAllCaches, 10000, 0)

-- Exportar para uso global
_G.Cache = Cache
_G.createCache = createCache
_G.getCache = getCache