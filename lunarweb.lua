local lunarweb = {}


lunarweb.ret = ""

-- HiJack all io routines
--[[
function print (...)
   for i,v in ipairs(arg) do
      lunarweb.ret = lunarweb.ret .. tostring(v)
   end
   lunarweb.ret = lunarweb.ret .. "<br>"
end

function io.write (...)
   for i,v in ipairs(arg) do
      lunarweb.ret = lunarweb.ret .. tostring(v)
   end
   lunarweb.ret = lunarweb.ret
end
]]--

lunarweb.APPLET_DIR = "/home/necromant/Dev/software/lunartool/"

lunarweb.load_applet = function(applet)
   dofile(lunarweb.APPLET_DIR..applet..".lua")   
end

lunarweb.hint = function(applet,self)
   if (nil==self) then
      print("nil")
   else
      print(table.tostring(self))
   end
end

lunarweb.run = function(applet,self)
   params = { }
   if (self.GET ~= nil) then
      params = self.GET;
   end
   lunarusb.override_config(params);
   return lunarusb.execute_applet(params);
end

lunarweb.dispatch = function(applet, action, self)
   lunarweb.load_applet(applet);
   return lunarweb.run(applet, self)
end


return lunarweb