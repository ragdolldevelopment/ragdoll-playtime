fx_version 'cerulean'
game 'gta5'
lua54 "yes"
author "valentino"
description "Playtime Script For ESX, QBCore & QBX"
version "1.0.2"

dependencies {
    'ox_lib',
    'oxmysql',
    'ox_inventory'
}

shared_scripts {
    '@ox_lib/init.lua',
	'config.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/*.lua',
}

client_scripts {
	'client/*.lua',
}
