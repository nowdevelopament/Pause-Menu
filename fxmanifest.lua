server_script '@ElectronAC/src/include/server.lua'
client_script '@ElectronAC/src/include/client.lua'

fx_version 'cerulean'
game 'gta5'

name 'now_Pause'
version '1.0.0'
author 'Now Dev'
lua54 'yes'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js'
}

shared_scripts {
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
}

client_scripts {
    'client/main.lua'
}

dependency '/assetpacks'
