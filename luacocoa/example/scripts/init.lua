-- global init script
print "lua init begin!"

appDelegate = oc.class.UIApplication:sharedApplication():delegate()

local rootVC = require("RootViewController"):new()
appDelegate.navigation = oc.UINavigationController:alloc():initWithRootViewController(rootVC)
appDelegate.navigation.root = rootVC
appDelegate:window():setRootViewController(appDelegate.navigation)

print "lua init end!"
