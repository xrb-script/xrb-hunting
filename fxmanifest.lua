fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'xResuL Albania'
description 'Skining Script by xResuL Albania for qbcore and esx'
version '1.2.0'

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}
