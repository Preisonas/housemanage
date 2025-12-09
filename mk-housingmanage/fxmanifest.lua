fx_version 'cerulean'
game 'gta5'

name 'mk-housingmanage'
author 'Preisonas'
description 'Housing Management System with React UI'
version '1.0.0'

lua54 'yes'

ui_page 'html/index.html'

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

files {
    'html/index.html',
    'html/assets/*.js',
    'html/assets/*.css',
    'html/assets/*.png',
    'html/assets/*.jpg',
    'html/assets/*.svg',
    'html/assets/*.woff',
    'html/assets/*.woff2'
}

dependencies {
    'es_extended',
    'oxmysql',
    'mk-housing'
}
