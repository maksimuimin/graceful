# graceful
Graceful initialization/finalization/code reload for tarantool modules

## Rationale
A very common way to deliver lua packages updates to production among
Tarantool System Administrators is to call `dofile` on the top-level
lua app in the admin console.

It is expected that all lua code would be reloaded from the hard drive
without stopping the Tarantool instance.

Unfortunately, that is not always the case. If the top-level app has
some dependencies, it is responsible for reloading all of those but
this functionality is often not implemented.

This module helps writing reloadable lua packeges in order not to
bother top-level application developers with reloading them by hands.

## How to use
### Inside of a library
The library must register itself as a reloadable package. By calling the
`register_module(name, opts)` function.

The library must specify the name of the package (must be the the same
string that is passed to `require()` function to load the library).

It also may specify the following options:
- `version` - a table or string representation of the library version.
May be useful to determine if module state needs some migrations for
version compatibility or not. Consider using `semver(maj, min, patch)`
function for this option.
- `init(mod)` - function to initialize the use library. May accept the
module object as the argument. Is called only on the first time during
the tarantool instance runtime (unlike `box.once` will be called again
after instance restart, but not after `dofile`)
- `finalize(mod)` - function to finilize the use library. May accept the
module object as the argument. May be used for graceful shutdown (it
is called on `unregister_module` or `box.ctl.on_shutdown`.
- `before_reload(mod)` - function to be called before reloading the module
from the hard drive. May be useful to pass some extra info to the
`on_reload` handler through the module state.
- `after_reload(mod)` - function to be called after the module is reloaded.
May be useful to upgrade the state for the compatibility with the new
version of the module.

Please keep in mind that during the reload the old version (from the memory)
of the `before_reload` function and the new version (from the hard drive)
of the `on_reload` function are called.

The `register_module(name, opts)` returns the module object, which besides
the parameters above contains also an empty `state` table. That table may
be used by the library to store any library-scope global variables.

The `init(mod)` and `finalize(mod)` function may be used to migrate the
library state between the library versions.

```lua
require('strict').on()

local checks = require('checks')
local fiber = require('fiber')
local graceful = require('graceful')

local function fiber_func()
    fiber.sleep(10)
end

local STATE = graceful.register_module('my_dependency', {
    version = graceful.semver(1, 0, 0),
    init = function (mod)
        mod.state.fib = fiber.new(fiber_func)
    end,
    finilize = function (mod)
        mod.state.fib:cancel()
        mod.state.fib = nil
    end,
    before_reload = function (mod)
        mod.state.old_version = mod.version,
    end,
    on_reload = function (mod)
        if mod.version:string() ~= mod.state.old_version:string() then
            -- There is possibly a diff in fiber_func, restart the fiber
            mod.state.fib:cancel()
            mod.state.fib = fiber.new(fiber_func)
        end
        mod.state.old_version = nil
    end,
}).state

local function get_fiber()
    return STATE.fib
end
```

### Inside of an app
The app should just call the `reload()` function in order to upgrade all
the reloadable packages to their state on the hard drive.

```lua
require('strict').on()
require('graceful').reload()

local my_dependency = require('my_dependency')
```

## Feature ideas
- Module reloading in the order of initial `require` calls
- tarantool/metrics support (it could be handy to see all the module
reloads in a dashboard)
