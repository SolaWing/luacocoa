local RootViewController = oc.class("RootViewController", "UIViewController",
    "UITableViewDataSource", "UITableViewDelegate")

RootViewController("viewDidLoad", function (self)
    self:navigationItem():setTitle("Demo")
    self:navigationItem():setRightBarButtonItem(
        oc.UIBarButtonItem:alloc():initWithBarButtonSystemItem_target_action(
            4, self, "clickAddItem:"))

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
