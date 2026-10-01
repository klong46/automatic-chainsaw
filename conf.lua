function love.conf(t)
    t.identity = "gangs"
    t.version = "11.5"
    t.console = false

    t.window.title = "Gangs - Turn-Based City Warfare"
    t.window.icon = nil
    t.window.width = 960
    t.window.height = 720
    t.window.borderless = false
    t.window.resizable = false
    t.window.minwidth = 960
    t.window.minheight = 720
    t.window.vsync = 1

    t.modules.audio = true
    t.modules.sound = true
    t.modules.graphics = true
    t.modules.timer = true
    t.modules.keyboard = true
    t.modules.mouse = true
    t.modules.event = true
end
