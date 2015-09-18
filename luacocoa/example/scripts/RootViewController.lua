local RootViewController = oc.class("RootViewController", "UIViewController",
    "UITableViewDataSource", "UITableViewDelegate")

-- dealloc add directly to class, so this way don't need to call super
function RootViewController:dealloc()
    print "RootViewController dealloc!!"
end

RootViewController("viewDidLoad", function (self)
    self:navigationItem():setTitle("Demo")
    self:navigationItem():setRightBarButtonItem(
        oc.UIBarButtonItem:alloc():initWithBarButtonSystemItem_target_action(
            4, self, "clickAddItem:"));

    self:navigationItem():setLeftBarButtonItem(
        oc.UIBarButtonItem:alloc():initWithTitle_style_target_action(
            "退出", 0, self, "exitApp:"));

    self.dataSource = {}

    local bounds = self:view():bounds()
    local tableView = oc.UITableView:alloc():initWithFrame_style(bounds, 0)
    tableView:setAutoresizingMask( 1 <<1 | 1<<4 )
    tableView:setDelegate(self)
    tableView:setDataSource(self)
    tableView:setBackgroundColor( oc.UIColor:clearColor() )
    self.tableView = tableView

    self:view():addSubview(tableView)
    self:view():setBackgroundColor( oc.UIColor:cyanColor() )
end)

RootViewController("exitApp:", function (self, sender)
    print "click exitApp"
    oc.UIView:animateWithDuration_animations_completion(0.35, function ()
        self:view():setAlpha(0)
    end, oc.block( function (finish)
        os.exit(0)
    end, "vB"))
end, "v@:@")

RootViewController("clickAddItem:", function (self, sender)
    print "click add item"
    table.insert(self.dataSource, os.date())
    self.tableView:reloadData()
end, oc.encode('void', 'id', 'SEL', 'id'))

RootViewController("tableView:numberOfRowsInSection:", function (self, tableView, section)
    return #self.dataSource
end)

RootViewController("numberOfSectionsInTableView:", function (self,tableView)
    return 1
end)

RootViewController("tableView:cellForRowAtIndexPath:", function (self,tableView, indexPath)
    local cell = tableView:dequeueReusableCellWithIdentifier("cell")
    if not cell then
        cell = oc.UITableViewCell:new()
    end
    cell:textLabel():setText( self.dataSource[indexPath:row()+1] )
    return cell
end)

RootViewController("- tableView:canEditRowAtIndexPath:", function (self, tableView, indexPath)
    return true
end)

RootViewController("tableView:commitEditingStyle:forRowAtIndexPath:", function (self, tableView, style, indexPath)
    if style == 1 then -- UITableViewCellEditingStyleDelete
        table.remove(self.dataSource, indexPath:row()+1 )
        tableView:deleteRowsAtIndexPaths_withRowAnimation({indexPath}, 0)
    end
end)

print "RootViewController load end"

return RootViewController
