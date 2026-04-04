fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'xResuL Albania'
description 'xrb-Hunting Script with talent tree'
version '2.0.0'

ui_page 'web/index.html'

dependencies {
    'xrb-lib',
    'ox_lib',
    'ox_target',
    'ox_inventory',
}

shared_scripts {
    '@ox_lib/init.lua',
    '@xrb-lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/icons/*.svg'
}
