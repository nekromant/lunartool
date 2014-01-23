#!/usr/bin/lua

lunarusb = require "lunarusb"

function lunarusb.printusage(applet)
   print("Necromant's Lunartool :: applet " .. arg[0]);
   print(config.description);
   print("--- COMMON STUFF ---\n");
   print("\t--list,-l           -  List matching devices\n")
   print("Use the following to override stuff from applet config file\n")
   print("\t--vid=0x0000        -  Force this VID")
   print("\t--pid=0x0000        -  Force this PID")
   print("\t--vendor=something  -  Force this Vendor Name")
   print("\t--product=something -  Force this Product Name")
   print("\t--serial=something  -  Force this Serial Number")
   print("\nHandling multiple devices\n")
   print("\t--id=N              - Use Nth device (If more than one matches")
   print("\t--broadcast=N       - Do stuff with all detected devices")   
   print("\n--- APPLET OPTIONS ---\n");
   for n,v in pairs(config.usage) do
      print(v);
   end
end

function lunarusb.listdevs(devs)
   print("--- Matching devices ---");
   if nil == devs then
      print("NONE")
   else
      for a,d in pairs(devs) do
	 print("ID: " .. a .. " Manufacturer: " .. d.vendor .. 
	       " Product: " .. d.product .. " Serial: " .. d.serial);
      end
   end
end


-- getopt, POSIX style command line argument parser
-- param arg contains the command line arguments in a standard table.
-- param options is a string with the letters that expect string values.
-- returns a table where associated keys are true, nil, or a string value.
-- The following example styles are supported
--   -a one  ==> opts["a"]=="one"
--   -bone   ==> opts["b"]=="one"
--   -c      ==> opts["c"]==true
--   --c=one ==> opts["c"]=="one"
--   -cdaone ==> opts["c"]==true opts["d"]==true opts["a"]=="one"
-- note POSIX demands the parser ends at the first non option
--      this behavior isn't implemented.

function lunarusb.getopt( arg, options )
   local tab = {}
   for k, v in ipairs(arg) do
      if string.sub( v, 1, 2) == "--" then
	 local x = string.find( v, "=", 1, true )
	 if x then tab[ string.sub( v, 3, x-1 ) ] = string.sub( v, x+1 )
	 else      tab[ string.sub( v, 3 ) ] = true
	 end
      elseif string.sub( v, 1, 1 ) == "-" then
	 local y = 2
	 local l = string.len(v)
	 local jopt
	 while ( y <= l ) do
	    jopt = string.sub( v, y, y )
	    if string.find( options, jopt, 1, true ) then
	       if y < l then
		  tab[ jopt ] = string.sub( v, y+1 )
		  y = l
	       else
		  tab[ jopt ] = arg[ k + 1 ]
	       end
	    else
	       tab[ jopt ] = true
	    end
	    y = y + 1
	 end
      end
   end
   return tab
end

--
-- Pure Lua version of basename.
--
lunarusb.basename = function(path)
   local i = string.len(path)

   while string.sub(path, i, i) == "/" and i > 0 do
      path = string.sub(path, 1, i - 1)
      i = i - 1
   end
   while i > 0 do
      if string.sub(path, i, i) == "/" then
	 break
      end
      i = i - 1
   end
   if i > 0 then
      path = string.sub(path, i + 1, -1)
   end
   if path == "" then
      path = "/"
   end

   return path
end



lunarusb.args = lunarusb.getopt(arg, "d");

tab = lunarusb.args;
if tab['help'] or tab['h'] then
   lunarusb.printusage(arg[0]);
   os.exit(1)
end

--Override config with default params

lunarusb.override_config(tab);

if tab['list'] or tab['l'] then
   lunarusb.listdevs(devs);
   os.exit(1)
end

ret = lunarusb.execute_applet(tab);
if (ret ~= nil) then
   print(ret)
end

os.exit(returncode);

