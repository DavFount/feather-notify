fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-notify'
description 'Default notification presentation provider for the Feather Framework'
author 'Feather Framework'
version '0.1.0'

shared_scripts {
    'config.lua',
    'shared/results.lua'
}

server_script 'server/main.lua'

client_script 'client/main.lua'
