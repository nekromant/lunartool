#!/usr/bin/lua
require('libusb');

lunarusb = {}

USB_TYPE_VENDOR=64
USB_ENDPOINT_IN=0x80

lunarusb.DISPATCH_CMDLINE=1
lunarusb.DISPATCH_WEB=2


function table.val_to_str ( v )
   if "string" == type( v ) then
      v = string.gsub( v, "\n", "\\n" )
      if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
	 return "'" .. v .. "'"
      end
      return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
   else
      return "table" == type( v ) and table.tostring( v ) or
	 tostring( v )
   end
end

function table.key_to_str ( k )
   if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
      return k
   else
      return "[" .. table.val_to_str( k ) .. "]"
   end
end

function table.tostring( tbl )
   local result, done = {}, {}
   for k, v in ipairs( tbl ) do
      table.insert( result, table.val_to_str( v ) )
      done[ k ] = true
   end
   for k, v in pairs( tbl ) do
      if not done[ k ] then
	 table.insert( result,
		       table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
      end
   end
   return "{" .. table.concat( result, "," ) .. "}<br>"
end


-- Simply dumps a table, and is pretty much only a wrapper
-- for a loop. It is useful however, because you can specify
-- a specific type, and only values of that type will be listed
local function dump(x,y)
   if type(x) ~= "table" then
      error("expected table and string, but got " .. type(x) .. " and " ..type(y), 2);
   end
   
   for k,v in pairs(x) do
      -- if a type is specified, check to see
      -- if current value is of right type.
      if y ~= nil then
	 if type(v) == y then
	    print(k, "\t", v);
	 end
      else
	 print(k, "\t", v)
      end
   end
end

-- Once again, just another wrapper. Still useful.
function globaldump(type)
   print("Current Lua Memory Usage: "..collectgarbage("count").." Kilobytes\n");
   dump(_G, type);
end


function lunarusb.find_devices(vid, pid)
   ret = {};
   local buses=libusb.get_busses()
   local last_device
   for busname, bus in pairs(buses) do
      local devices=libusb.get_devices(bus)
      for devname, device in pairs(devices) do
	 local descriptor=libusb.device_descriptor(device)
	 if ((vid == 0) or (descriptor.idVendor == vid) ) then
	    if ((pid == 0) or (descriptor.idProduct == pid)) then
	       table.insert(ret, {
			       descriptor = descriptor,
			       dev = device,
			       bus = bus
				 })
	    end
	 end
	 --table.insert(ret, { 
	 --	      , "desc:", descriptor.iProduct, s or err)
	 last_device=device		
      end     
   end
   return ret
end


function lunarusb.string_filter(devs, v, p, s)
   local matches = {};
   for num,device in pairs(devs) do
      --print(table.tostring(device));
      hndl = libusb.open(device.dev);
      if (nil == hndl) then
	 print("Couldn't open dev, skipping")
      else
	 -- print(device.descriptor.iVendor);
	 local vendor,err = libusb.get_string_simple(hndl,device.descriptor.iManufacturer);
	 if (err) then vendor = "?" end
	 local product,err = libusb.get_string_simple(hndl,device.descriptor.iProduct);
	 if (err) then product = "?" end
	 local serial,err = libusb.get_string_simple(hndl,device.descriptor.iSerialNumber);
	 if (err) then serial = "?" end
	 if ((nil == v) or (v == vendor)) then
	    if ((nil == p) or (p == product)) then
	       if ((nil == s) or (s == serial)) then
		  table.insert(matches, {
				  device = device,
				  vendor = vendor,
				  product = product,
				  serial = serial,
				  hndl = hndl
					})
	       else
		  libusb.close(hndl); -- clean up
	       end
	    end
	 end
      end
   end
   return matches;
end


function table.contains(table, element)
   for _, value in pairs(table) do
      if value == element then
	 return true
      end
   end
   return false
end


function lunarusb.run(applet, action, self)
   if (nil ~= lunarusb.dispatch_source) then
      return; 
   end

   if (nil == applet) then
      lunarusb.dispatch_source = lunarusb.DISPATCH_CMDLINE;
      require "lunartool"
   else
      lunarusb.dispatch_source = lunarusb.DISPATCH_WEB;
      local w = require "lunarweb"
      return w.dispatch(applet, action, self)
   end
end


lunarusb.from_web = function()
   return (lunarusb.dispatch_source == lunarusb.DISPATCH_WEB)
end

lunarusb.override_config = function(tab)
   local i, device
   if nil ~= tab['vid'] then
      config.vid = tonumber(tab['vid']);
      print("Forced vid from commandline: " .. config.vid);
   end
   
   if nil ~= tab['pid'] then
      config.pid = tonumber(tab['pid']);
      print("Forced pid from commandline: " .. config.pid);
   end
   
   if nil ~= tab['vendor'] then
      config.vendor = tab['vendor'];
      print("Forced vendor from commandline: " .. config.vendor);
   end
   
   if nil ~= tab['product'] then
      config.product = tab['product'];
      print("Forced product from commandline: " .. config.product);
   end

   if nil ~= tab['serial'] then
      config.serial = tab['serial'];
      print("Forced serial from commandline: " .. config.serial);
   end
   
   if (config.offset == nil) then
      config.offset = 1;
   end

   -- Handle offsets and broadcasts
   if nil ~= tab['id'] then
      config.offset = tonumber(tab['id'])
   end

   if (tab['broadcast'] or tab['b']) then
      config.broadcast = true;
   end

end

lunarusb.execute_applet = function(tab)
   returncode = 0
   local devs = lunarusb.find_devices(config.vid, config.pid);
   local devs = lunarusb.string_filter(devs, config.vendor, config.product, config.serial)
   local r;
   local ret=""
   for i,device in pairs(devs) do
      if (config.broadcast or (i == config.offset)) then  
	 if nil ~= config.actions.start then
	    r = config.actions.start(i,device)
	    if (r~=nil) then
	       ret=ret..r;
	    end
	 end
	 if not config.broadcast then
	    break;	
	 end
      end
   end
   
   -- Callbacks
   for j,t in pairs(tab) do
      for i,device in pairs(devs) do
	 if (config.broadcast or (i == config.offset)) then  
	    if nil ~= config.actions[j] then
	       r=config.actions[j](i,device,t)
	       if (r~=nil) then
		  ret=ret..r;
	       end
	    end
	    if not config.broadcast then
	       break;	
	    end
	 end
      end
   end

   for i,device in pairs(devs) do
      if (config.broadcast or (i == config.offset)) then  
	 if nil ~= config.actions.finish then
	    r=config.actions.finish(i,device)
	    if (r~=nil) then
	       ret=ret..r;
	    end
	 end
      end
      if not config.broadcast then
	 break;	
      end
   end

   for i,device in pairs(devs) do
      libusb.close(device.hndl);
   end

   return ret;
end




return lunarusb