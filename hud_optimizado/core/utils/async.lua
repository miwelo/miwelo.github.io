-- =====================================================
-- ASYNC.LUA - Sistema Asíncrono (Compatibilidad)
-- Autor: MIWELO
-- Versión: 1.0.0
-- Descripción: Sistema para operaciones asíncronas y compatibilidad
-- =====================================================

Async = {}
Async.__index = Async

-- =====================================================
-- CONFIGURACIÓN
-- =====================================================
local ASYNC_CONFIG = {
    maxConcurrentTasks = 50,
    defaultTimeout = 5000,
    enableTimeout = true,
    enableQueue = true,
    maxQueueSize = 100
}

-- =====================================================
-- VARIABLES GLOBALES
-- =====================================================
local taskQueue = {}
local activeTasks = {}
local taskIdCounter = 0
local asyncStats = {
    completedTasks = 0,
    failedTasks = 0,
    timeoutTasks = 0,
    queuedTasks = 0
}

-- =====================================================
-- CONSTRUCTOR
-- =====================================================
function Async:new(config)
    local instance = {
        config = config or {},
        tasks = {},
        timers = {},
        callbacks = {},
        id = taskIdCounter
    }
    
    taskIdCounter = taskIdCounter + 1
    
    -- Aplicar configuración por defecto
    for key, value in pairs(ASYNC_CONFIG) do
        if instance.config[key] == nil then
            instance.config[key] = value
        end
    end
    
    setmetatable(instance, Async)
    return instance
end

-- =====================================================
-- GESTIÓN DE TAREAS
-- =====================================================

-- Ejecutar función de forma asíncrona
function Async:execute(func, callback, timeout)
    if type(func) ~= "function" then
        if callback then
            callback(false, "Invalid function provided")
        end
        return false
    end
    
    local taskId = self:generateTaskId()
    timeout = timeout or self.config.defaultTimeout
    
    local task = {
        id = taskId,
        func = func,
        callback = callback,
        timeout = timeout,
        startTime = getTickCount(),
        status = "pending"
    }
    
    -- Verificar si hay espacio para ejecutar inmediatamente
    if #activeTasks < self.config.maxConcurrentTasks then
        self:executeTask(task)
    else
        -- Agregar a la cola si está habilitada
        if self.config.enableQueue then
            if #taskQueue < self.config.maxQueueSize then
                table.insert(taskQueue, task)
                task.status = "queued"
                asyncStats.queuedTasks = asyncStats.queuedTasks + 1
            else
                if callback then
                    callback(false, "Queue is full")
                end
                return false
            end
        else
            if callback then
                callback(false, "Too many concurrent tasks")
            end
            return false
        end
    end
    
    return taskId
end

-- Ejecutar tarea inmediatamente
function Async:executeTask(task)
    task.status = "running"
    activeTasks[task.id] = task
    
    -- Configurar timeout si está habilitado
    if self.config.enableTimeout and task.timeout > 0 then
        task.timer = setTimer(function()
            self:timeoutTask(task.id)
        end, task.timeout, 1)
    end
    
    -- Ejecutar función en el siguiente frame para no bloquear
    setTimer(function()
        self:runTaskFunction(task)
    end, 1, 1)
    
    return true
end

-- Ejecutar función de la tarea
function Async:runTaskFunction(task)
    if not activeTasks[task.id] or task.status ~= "running" then
        return
    end
    
    local success, result = pcall(task.func)
    
    if success then
        self:completeTask(task.id, true, result)
    else
        self:completeTask(task.id, false, result)
    end
end

-- Completar tarea
function Async:completeTask(taskId, success, result)
    local task = activeTasks[taskId]
    if not task then
        return
    end
    
    -- Limpiar timer si existe
    if task.timer then
        killTimer(task.timer)
        task.timer = nil
    end
    
    -- Actualizar estado
    task.status = success and "completed" or "failed"
    task.endTime = getTickCount()
    task.duration = task.endTime - task.startTime
    
    -- Ejecutar callback
    if task.callback then
        setTimer(function()
            task.callback(success, result, task.duration)
        end, 1, 1)
    end
    
    -- Actualizar estadísticas
    if success then
        asyncStats.completedTasks = asyncStats.completedTasks + 1
    else
        asyncStats.failedTasks = asyncStats.failedTasks + 1
    end
    
    -- Remover de tareas activas
    activeTasks[taskId] = nil
    
    -- Procesar siguiente tarea en cola
    self:processQueue()
end

-- Timeout de tarea
function Async:timeoutTask(taskId)
    local task = activeTasks[taskId]
    if not task then
        return
    end
    
    task.status = "timeout"
    task.endTime = getTickCount()
    task.duration = task.endTime - task.startTime
    
    -- Ejecutar callback con error de timeout
    if task.callback then
        setTimer(function()
            task.callback(false, "Task timeout", task.duration)
        end, 1, 1)
    end
    
    -- Actualizar estadísticas
    asyncStats.timeoutTasks = asyncStats.timeoutTasks + 1
    
    -- Remover de tareas activas
    activeTasks[taskId] = nil
    
    -- Procesar siguiente tarea en cola
    self:processQueue()
end

-- Procesar cola de tareas
function Async:processQueue()
    if #taskQueue == 0 or #activeTasks >= self.config.maxConcurrentTasks then
        return
    end
    
    local nextTask = table.remove(taskQueue, 1)
    if nextTask then
        self:executeTask(nextTask)
    end
end

-- =====================================================
-- UTILIDADES ASÍNCRONAS
-- =====================================================

-- Delay asíncrono
function Async:delay(ms, callback)
    return self:execute(function()
        -- Esta función se completará cuando el timer expire
        return true
    end, callback, ms + 100) -- Agregar buffer para timeout
end

-- Retry con backoff exponencial
function Async:retry(func, maxAttempts, baseDelay, callback)
    maxAttempts = maxAttempts or 3
    baseDelay = baseDelay or 1000
    
    local attempt = 0
    
    local function tryExecute()
        attempt = attempt + 1
        
        self:execute(func, function(success, result)
            if success or attempt >= maxAttempts then
                if callback then
                    callback(success, result, attempt)
                end
            else
                -- Calcular delay con backoff exponencial
                local delay = baseDelay * (2 ^ (attempt - 1))
                
                setTimer(tryExecute, delay, 1)
            end
        end)
    end
    
    tryExecute()
end

-- Ejecutar múltiples tareas en paralelo
function Async:parallel(tasks, callback)
    if type(tasks) ~= "table" or #tasks == 0 then
        if callback then
            callback(false, "Invalid tasks array")
        end
        return false
    end
    
    local results = {}
    local completed = 0
    local hasError = false
    
    for i, task in ipairs(tasks) do
        self:execute(task, function(success, result)
            results[i] = {success = success, result = result}
            completed = completed + 1
            
            if not success then
                hasError = true
            end
            
            -- Verificar si todas las tareas están completas
            if completed >= #tasks then
                if callback then
                    callback(not hasError, results)
                end
            end
        end)
    end
    
    return true
end

-- Ejecutar tareas en serie
function Async:series(tasks, callback)
    if type(tasks) ~= "table" or #tasks == 0 then
        if callback then
            callback(false, "Invalid tasks array")
        end
        return false
    end
    
    local results = {}
    local currentIndex = 1
    
    local function executeNext()
        if currentIndex > #tasks then
            if callback then
                callback(true, results)
            end
            return
        end
        
        local task = tasks[currentIndex]
        self:execute(task, function(success, result)
            results[currentIndex] = {success = success, result = result}
            
            if not success then
                if callback then
                    callback(false, results)
                end
                return
            end
            
            currentIndex = currentIndex + 1
            setTimer(executeNext, 1, 1)
        end)
    end
    
    executeNext()
    return true
end

-- =====================================================
-- MÉTODOS DE CONTROL
-- =====================================================

-- Cancelar tarea
function Async:cancelTask(taskId)
    local task = activeTasks[taskId]
    if task then
        if task.timer then
            killTimer(task.timer)
        end
        
        task.status = "cancelled"
        activeTasks[taskId] = nil
        
        if task.callback then
            task.callback(false, "Task cancelled")
        end
        
        return true
    end
    
    -- Buscar en cola
    for i, queuedTask in ipairs(taskQueue) do
        if queuedTask.id == taskId then
            table.remove(taskQueue, i)
            queuedTask.status = "cancelled"
            
            if queuedTask.callback then
                queuedTask.callback(false, "Task cancelled")
            end
            
            return true
        end
    end
    
    return false
end

-- Cancelar todas las tareas
function Async:cancelAllTasks()
    -- Cancelar tareas activas
    for taskId, task in pairs(activeTasks) do
        if task.timer then
            killTimer(task.timer)
        end
        
        if task.callback then
            task.callback(false, "All tasks cancelled")
        end
    end
    
    -- Cancelar tareas en cola
    for _, task in ipairs(taskQueue) do
        if task.callback then
            task.callback(false, "All tasks cancelled")
        end
    end
    
    activeTasks = {}
    taskQueue = {}
end

-- Obtener estado de tarea
function Async:getTaskStatus(taskId)
    local task = activeTasks[taskId]
    if task then
        return task.status, getTickCount() - task.startTime
    end
    
    for _, queuedTask in ipairs(taskQueue) do
        if queuedTask.id == taskId then
            return queuedTask.status, getTickCount() - queuedTask.startTime
        end
    end
    
    return nil
end

-- =====================================================
-- UTILIDADES
-- =====================================================

-- Generar ID único para tarea
function Async:generateTaskId()
    taskIdCounter = taskIdCounter + 1
    return "task_" .. taskIdCounter .. "_" .. getTickCount()
end

-- Obtener estadísticas
function Async:getStats()
    return {
        activeTasks = table.size(activeTasks),
        queuedTasks = #taskQueue,
        completedTasks = asyncStats.completedTasks,
        failedTasks = asyncStats.failedTasks,
        timeoutTasks = asyncStats.timeoutTasks,
        totalProcessed = asyncStats.completedTasks + asyncStats.failedTasks + asyncStats.timeoutTasks
    }
end

-- Limpiar estadísticas
function Async:clearStats()
    asyncStats = {
        completedTasks = 0,
        failedTasks = 0,
        timeoutTasks = 0,
        queuedTasks = 0
    }
end

-- =====================================================
-- INSTANCIA GLOBAL
-- =====================================================
local globalAsync = Async:new(ASYNC_CONFIG)

-- =====================================================
-- FUNCIONES GLOBALES DE COMPATIBILIDAD
-- =====================================================

-- Ejecutar función asíncrona global
function asyncExecute(func, callback, timeout)
    return globalAsync:execute(func, callback, timeout)
end

-- Delay asíncrono global
function asyncDelay(ms, callback)
    return globalAsync:delay(ms, callback)
end

-- Retry global
function asyncRetry(func, maxAttempts, baseDelay, callback)
    return globalAsync:retry(func, maxAttempts, baseDelay, callback)
end

-- Paralelo global
function asyncParallel(tasks, callback)
    return globalAsync:parallel(tasks, callback)
end

-- Serie global
function asyncSeries(tasks, callback)
    return globalAsync:series(tasks, callback)
end

-- Cancelar tarea global
function asyncCancel(taskId)
    return globalAsync:cancelTask(taskId)
end

-- Obtener estadísticas globales
function getAsyncStats()
    return globalAsync:getStats()
end

-- =====================================================
-- FUNCIONES DE CONVENIENCIA
-- =====================================================

-- Promise-like interface
function createPromise(executor)
    local promise = {
        status = "pending",
        value = nil,
        reason = nil,
        onResolve = {},
        onReject = {}
    }
    
    local function resolve(value)
        if promise.status ~= "pending" then return end
        promise.status = "resolved"
        promise.value = value
        
        for _, callback in ipairs(promise.onResolve) do
            setTimer(function() callback(value) end, 1, 1)
        end
    end
    
    local function reject(reason)
        if promise.status ~= "pending" then return end
        promise.status = "rejected"
        promise.reason = reason
        
        for _, callback in ipairs(promise.onReject) do
            setTimer(function() callback(reason) end, 1, 1)
        end
    end
    
    function promise:then(onResolve, onReject)
        if onResolve then
            if self.status == "resolved" then
                setTimer(function() onResolve(self.value) end, 1, 1)
            else
                table.insert(self.onResolve, onResolve)
            end
        end
        
        if onReject then
            if self.status == "rejected" then
                setTimer(function() onReject(self.reason) end, 1, 1)
            else
                table.insert(self.onReject, onReject)
            end
        end
        
        return self
    end
    
    function promise:catch(onReject)
        return self:then(nil, onReject)
    end
    
    -- Ejecutar el executor
    if executor then
        setTimer(function()
            local success, result = pcall(executor, resolve, reject)
            if not success then
                reject(result)
            end
        end, 1, 1)
    end
    
    return promise
end

-- =====================================================
-- MANEJO DE EVENTOS ASÍNCRONOS
-- =====================================================

-- Wrapper para eventos asíncronos
function onAsyncEvent(eventName, element, callback, timeout)
    return asyncExecute(function()
        local eventReceived = false
        local eventData = nil
        
        local function eventHandler(...)
            eventReceived = true
            eventData = {...}
        end
        
        addEventHandler(eventName, element, eventHandler)
        
        -- Esperar hasta que se reciba el evento o timeout
        local startTime = getTickCount()
        while not eventReceived do
            if timeout and (getTickCount() - startTime) > timeout then
                removeEventHandler(eventName, element, eventHandler)
                error("Event timeout")
            end
            -- En un entorno real, esto sería una espera no bloqueante
        end
        
        removeEventHandler(eventName, element, eventHandler)
        return eventData
    end, callback, timeout)
end

-- =====================================================
-- INICIALIZACIÓN
-- =====================================================

-- Limpiar tareas periódicamente
setTimer(function()
    -- Implementar limpieza de tareas completadas/fallidas antiguas
end, 30000, 0)

-- Exportar para uso global
_G.Async = Async
_G.asyncExecute = asyncExecute
_G.asyncDelay = asyncDelay
_G.createPromise = createPromise