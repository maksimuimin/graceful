package = 'graceful'
version = 'scm-1'
source  = {
    url    = 'git+https://github.com/maksimuimin/graceful.git';
    branch = 'main';
}
description = {
    summary = "Graceful initialization/finalization/code reload for tarantool modules",
    homepage = "https://github.com/maksimuimin/graceful.git",
    license = "BSD2",
    maintainer = "Maksim Uimin <uimin1maksim@yandex.ru>"
}
dependencies = {
    "lua >= 5.1", -- actually tarantool > 1.6
    "checks >= 3.1.0-1",
}
build = {
    type = 'builtin';
    modules = {
        ['graceful'] = 'graceful/init.lua';
    }
}
-- vim: syntax=lua ts=4 sts=4 sw=4 et
