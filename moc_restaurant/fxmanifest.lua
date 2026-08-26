fx_version 'cerulean'
game 'gta5'

author 'MOC Development'
description 'MOC Restaurant Framework'
version '3.3.6'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'bridge/framework.lua',
    'bridge/target.lua',
    'client/main.lua',
    'client/commands.lua',
    'client/builder.lua',
    'client/orders.lua',
    'client/kitchen.lua',
    'client/storage.lua',
    'client/nui.lua',
    'client/animations.lua',
    'client/business.lua',
    'client/deliveries.lua',
    'client/restaurant_menus.lua',
    'client/production.lua',
    'client/blips.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'server/permissions.lua',
    'server/database.lua',
    'server/main.lua',
    'server/kitchen.lua',
    'server/storage.lua',
    'server/pos_diagnostics.lua',
    'server/business.lua',
    'server/diagnostics.lua',
    'server/restaurant_menus.lua',
    'server/production.lua'
}

dependencies {
    'oxmysql'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}
