fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'xResuL Albania'
description 'Skining Script by xResuL Albania for qbcore and esx'
version '1.1.0'

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'es_extended',  -- opsionale
    --'qb-core'       -- opsionale
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