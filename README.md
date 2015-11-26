# What's this?

this is a Library of full Objective-C Runtime Binding For Lua.

the goal is to write native iOS or MAC App in lua. Or use lua to patch Online-Code for
bug fixs, add features, etc.

# Features

* Full bridge between Objc and lua types
* Full support for struct type
* Support All Objective-C method.
* Support All blocks with different signature
* Support create new Class.
* Support add or replace a method in Class
* Autoconvert lua types to method declare types when needed

# Examples

How would I create a UIView and color it red?

```lua
local v = oc.UIView:alloc():initWithFrame( oc.CGRect({0,0}, {320, 100}) )
v:setBackgroundColor(oc.UIColor:redColor())
```

How about multiple arguments methods?

```lua
-- Just replace : to _ for SEL. If the SEL indeed contains a _, use __
oc.UIBarButtonItem:alloc():initWithTitle_style_target_action(
        "edit", 0, self, "edit:")
```

How do I send an array/dictionary/string ?

```lua
-- lib autoconvert table, string, number to method param type when needed
oc.NSMutableArray:arrayWithArray{"red", "white", "black"}
```

How can I create a custom ViewController?

```lua
-- just call oc.class function and it will return the created class.
-- first param is class name, second is super class.
-- and after are conform protocols
--
-- if class already exists, it simplely add protocols
local RootViewController = oc.class("RootViewController", "UIViewController",
        "UITableViewDataSource", "UITableViewDelegate")

-- dealloc add directly to class, so this way don't need to call super
function RootViewController:dealloc()
    print "RootViewController dealloc!!"
end

-- add or override method by call on class object
-- first is method SEL name, second is function.
RootViewController("viewDidLoad", function (self)
    -- call super method with self and self class
    oc.super(self, "RootViewController"):viewDidLoad()

    -- do your staff here
    self:navigationItem():setLeftBarButtonItem(
        oc.UIBarButtonItem:alloc():initWithTitle_style_target_action(
            "exit", 0, self, "exitApp:"));
end)

-- class method can be added or overrided by prefixing '+'
RootViewController("+ description", function(self)
    return "test RootViewController"
end)
```

How can I create blocks?

```lua
RootViewController("exitApp:", function (self, sender)
    -- lib autoconvert lua function to block when needed
    -- if all block param type is id, and return type is id or void.
    oc.UIView:animateWithDuration_animations_completion(0.35, function ()
        self:view():setAlpha(0)
    end, oc.block( function (finish)
        os.exit(0)
    end, {"void", "BOOL"}))
    -- for blocks has different sign, need to use oc.block function to
    -- create a block object and specifiy encoding obviously.

    -- you can use encoding string directly,
    -- or pass a array of type names to help create encoding string
end, "v@:@")
-- for custom add method, need to specifiy encoding.
--
-- can omit when override super method, protocol method,
-- or if all param is id, and return type is id or void.
```

How to call blocks?

```lua
-- you can direct call for blocks which all param type is @, and don't need return value
aBlock()
aBlockWithIDParam(obj)

-- for other signature, need to specify encoding obviously
-- the encoding is second param of oc.invoke().
-- followed by block params
local ret = oc.invoke(aBlock, {"NSInteger", "NSInteger"}, 1);
local ret = oc.invoke(aBlock, {"CGRect", "CGPoint", "CGSize"}, {0,0}, {100,100});
```

How to use struct types?

```lua
-- to create empty struct
local rect = oc.CGRect()
-- to create struct with values. notice CGRect contains CGPoint and CGSize
local rect = oc.CGRect({0,0}, {100,100})

-- index struct by name
local x = rect.x
local size = rect.size
-- index struct by offset, offset begin at 1
local x = rect[1][1]
local size = rect[2]

-- set value on struct by index name
rect.x = 10;
-- set value on struct by offset
rect[1] = {0, 50}       -- set new origin
-- NOTE: avoid indirect assign pattern, because first index return a copy struct
-- rect.size.width = 50

-- create struct or index struct by name only work for register struct.
-- the default register structs can be found in luaoc_struct.m: reg_default_struct
-- you can reg new struct in lua by:
oc.struct.reg('structName',
              {'attrName', oc.encode.CGFloat},
              {'attrName2', oc.encode.CGFloat})
```

What if I need to pass a out param or in-out param?

```lua
-- var type is used as a container for a block memory
-- you can pass it to the param.
-- for example, If need to get the out error:

-- first create a var type and specify the memory data type
local error_var = oc.var(oc.encode.id)

-- then call method need a NSError** out param
local data = oc.NSData:dataWithContentsOfFile_options_error("path_to_file", 0, error_var)

-- get error object
local error = oc.getvar(error_var)
```

How to call C Functions?

to call C Functions, you first need to register it in C.
you can register it use `luaoc_reg_cfunc`

```c
// register a func with sign @@
luaoc_reg_cfunc(L, "funcName", funcPtr, "@@")
```

What do I need to notice when develop?

lua manage id object just like ARC. so you need to care about retain cycles.
you can break retain cycle by use weak var.

```lua
-- create a weak ref
local weakObj = oc.weakvar(obj)
local weakObj2 = oc.weakvar(obj2)

-- get obj from weak ref, getvar can accept multiple var object
local obj, obj2 = oc.getvar(weakObj, weakObj2)
if obj and obj2 then
    -- do staff
end
```

# Setup

You can build the project and import the static lib and include headers.
for ios, here is a *build_release_ios.sh* script to build universe library.

Or you can add libffi and luaoc project to your project directly

# More
If you find any bugs, please post a issue to me.

PR is also welcome.
