-- =====================================================
-- CONFIG.LUA - Configuración Centralizada del HUD Optimizado
-- Autor: MIWELO
-- Versión: 1.0.0
-- =====================================================

HUD_CONFIG = {}

-- =====================================================
-- CONFIGURACIÓN GENERAL
-- =====================================================
HUD_CONFIG.GENERAL = {
    enabled = true,
    showInInterior = true,
    showWhenDead = false,
    hideWithOriginalHUD = true,
    useCustomCursor = false,
    debugMode = false
}

-- =====================================================
-- CONFIGURACIÓN DE RENDIMIENTO
-- =====================================================
HUD_CONFIG.PERFORMANCE = {
    fpsLimit = 60,
    maxFPS = 120,
    enableCache = true,
    cacheLifetime = 1000, -- milisegundos
    updateInterval = 50, -- milisegundos
    enableBatching = true,
    maxDrawCalls = 100,
    enableConditionalRender = true
}

-- =====================================================
-- CONFIGURACIÓN DEL HUD DEL JUGADOR
-- =====================================================
HUD_CONFIG.PLAYER_HUD = {
    enabled = true,
    position = {x = 43, y = 320},
    size = {width = 300, height = 200},
    
    -- Configuración de stats
    stats = {
        health = {enabled = true, color = {255, 82, 82, 255}, max = 100},
        armor = {enabled = true, color = {158, 158, 158, 255}, max = 100},
        hunger = {enabled = true, color = {255, 193, 7, 255}, max = 100},
        thirst = {enabled = true, color = {33, 150, 243, 255}, max = 100},
        stamina = {enabled = true, color = {76, 175, 80, 255}, max = 100}
    },
    
    -- Configuración visual
    visual = {
        backgroundColor = {0, 0, 0, 180},
        borderColor = {255, 255, 255, 100},
        borderWidth = 2,
        cornerRadius = 8,
        barHeight = 20,
        barSpacing = 5,
        showPercentage = true,
        showIcons = true
    }
}

-- =====================================================
-- CONFIGURACIÓN DEL VELOCÍMETRO
-- =====================================================
HUD_CONFIG.SPEEDOMETER = {
    enabled = true,
    position = {x = 1140, y = 500},
    size = {width = 350, height = 250},
    
    -- Configuración de velocidad
    speed = {
        showKMH = true,
        showMPH = false,
        maxSpeed = 300,
        speedMultiplier = 1.5,
        smoothTransition = true,
        updateRate = 20
    },
    
    -- Configuración de combustible
    fuel = {
        enabled = true,
        maxFuel = 100,
        warningLevel = 20,
        criticalLevel = 10,
        warningColor = {255, 193, 7, 255},
        criticalColor = {244, 67, 54, 255}
    },
    
    -- Configuración visual
    visual = {
        backgroundColor = {0, 0, 0, 180},
        primaryColor = {255, 255, 255, 255},
        accentColor = {33, 150, 243, 255},
        needleColor = {244, 67, 54, 255},
        textSize = 1.2,
        showGear = true,
        showEngineState = true,
        showLights = true,
        showBelt = true,
        showHandbrake = true,
        showDamage = true
    }
}

-- =====================================================
-- CONFIGURACIÓN DE INDICADORES
-- =====================================================
HUD_CONFIG.INDICATORS = {
    enabled = true,
    position = {x = 1000, y = 400},
    
    -- Estados de vehículo
    vehicle = {
        engine = {enabled = true, icon = "repair.png", color = {76, 175, 80, 255}},
        lights = {enabled = true, icon = "light.png", color = {255, 193, 7, 255}},
        locked = {enabled = true, icon = "locked.png", color = {244, 67, 54, 255}},
        handbrake = {enabled = true, icon = "brake.png", color = {244, 67, 54, 255}},
        seatbelt = {enabled = true, icon = "belt.png", color = {33, 150, 243, 255}}
    },
    
    -- Configuración visual
    visual = {
        iconSize = 32,
        spacing = 40,
        animationDuration = 500,
        pulseEffect = true,
        showTooltips = true
    }
}

-- =====================================================
-- CONFIGURACIÓN DE ANIMACIONES
-- =====================================================
HUD_CONFIG.ANIMATIONS = {
    enabled = true,
    
    -- Tipos de animaciones
    types = {
        fade = {duration = 300, easing = "InOutQuad"},
        slide = {duration = 500, easing = "OutBack"},
        scale = {duration = 200, easing = "OutElastic"},
        pulse = {duration = 1000, easing = "InOutSine"}
    },
    
    -- Configuración específica
    fadeIn = {duration = 500, delay = 0},
    fadeOut = {duration = 300, delay = 0},
    valueChange = {duration = 200, smoothness = 0.1},
    statusChange = {duration = 400, bounceEffect = true}
}

-- =====================================================
-- CONFIGURACIÓN DE COLORES
-- =====================================================
HUD_CONFIG.COLORS = {
    -- Colores principales
    primary = {33, 150, 243, 255},
    secondary = {156, 39, 176, 255},
    success = {76, 175, 80, 255},
    warning = {255, 193, 7, 255},
    error = {244, 67, 54, 255},
    info = {33, 150, 243, 255},
    
    -- Colores de fondo
    background = {0, 0, 0, 180},
    backgroundLight = {255, 255, 255, 20},
    backgroundDark = {0, 0, 0, 220},
    
    -- Colores de texto
    textPrimary = {255, 255, 255, 255},
    textSecondary = {255, 255, 255, 180},
    textDisabled = {255, 255, 255, 100},
    
    -- Colores de stats
    health = {244, 67, 54, 255},
    armor = {158, 158, 158, 255},
    hunger = {255, 193, 7, 255},
    thirst = {33, 150, 243, 255},
    stamina = {76, 175, 80, 255},
    fuel = {255, 152, 0, 255}
}

-- =====================================================
-- CONFIGURACIÓN DE RECURSOS
-- =====================================================
HUD_CONFIG.ASSETS = {
    -- Imágenes
    images = {
        logo = "core/assets/images/logo.png",
        speedometer = "core/assets/images/velo.png",
        fuel = "core/assets/images/fuel.png",
        light = "core/assets/images/light.png",
        repair = "core/assets/images/repair.png",
        locked = "core/assets/images/locked.png",
        brake = "core/assets/images/brake.png",
        belt = "core/assets/images/belt.png",
        button = "core/assets/images/button.png"
    },
    
    -- Fuentes
    fonts = {
        primary = "core/assets/fonts/sfbold.ttf",
        secondary = "core/assets/fonts/bold.ttf",
        defaultSize = 12,
        titleSize = 16,
        smallSize = 10
    },
    
    -- Shaders
    shaders = {
        circle = "core/assets/shader/shader.fx"
    }
}

-- =====================================================
-- CONFIGURACIÓN DE COMPATIBILIDAD
-- =====================================================
HUD_CONFIG.COMPATIBILITY = {
    -- Funciones exportadas para compatibilidad
    exports = {
        "toggleHUD",
        "isHUDEnabled", 
        "setHUDVisible",
        "updatePlayerStats",
        "updateVehicleData"
    },
    
    -- Eventos compatibles
    events = {
        "onHUDToggle",
        "onStatsUpdate",
        "onVehicleDataUpdate"
    },
    
    -- Configuración de retrocompatibilidad
    legacy = {
        supportOldFunctions = true,
        deprecationWarnings = false,
        oldEventNames = true
    }
}

-- =====================================================
-- CONFIGURACIÓN DE DEPURACIÓN
-- =====================================================
HUD_CONFIG.DEBUG = {
    enabled = false,
    showFPS = false,
    showMemoryUsage = false,
    showRenderTime = false,
    showCacheStats = false,
    logLevel = "INFO", -- ERROR, WARN, INFO, DEBUG
    outputToConsole = true,
    outputToFile = false
}

-- =====================================================
-- FUNCIONES DE CONFIGURACIÓN
-- =====================================================

-- Obtener configuración con valores por defecto
function getConfig(path, default)
    local keys = split(path, ".")
    local current = HUD_CONFIG
    
    for _, key in ipairs(keys) do
        if current[key] then
            current = current[key]
        else
            return default
        end
    end
    
    return current
end

-- Establecer configuración
function setConfig(path, value)
    local keys = split(path, ".")
    local current = HUD_CONFIG
    
    for i = 1, #keys - 1 do
        local key = keys[i]
        if not current[key] then
            current[key] = {}
        end
        current = current[key]
    end
    
    current[keys[#keys]] = value
end

-- Función auxiliar para dividir strings
function split(str, delimiter)
    local result = {}
    local pattern = "(.-)" .. delimiter
    local lastEnd = 1
    local s, e, cap = str:find(pattern, 1)
    
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(result, cap)
        end
        lastEnd = e + 1
        s, e, cap = str:find(pattern, lastEnd)
    end
    
    if lastEnd <= #str then
        cap = str:sub(lastEnd)
        table.insert(result, cap)
    end
    
    return result
end

-- Validar configuración al iniciar
function validateConfig()
    -- Validaciones básicas de la configuración
    if type(HUD_CONFIG.PERFORMANCE.fpsLimit) ~= "number" or HUD_CONFIG.PERFORMANCE.fpsLimit <= 0 then
        HUD_CONFIG.PERFORMANCE.fpsLimit = 60
    end
    
    if type(HUD_CONFIG.PERFORMANCE.updateInterval) ~= "number" or HUD_CONFIG.PERFORMANCE.updateInterval <= 0 then
        HUD_CONFIG.PERFORMANCE.updateInterval = 50
    end
    
    -- Más validaciones según necesidad
end

-- Inicializar configuración
validateConfig()