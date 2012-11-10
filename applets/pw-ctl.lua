-- Power Control Utility
config = {
   description = "Outlet Control Utility",
   usage = {
      "Outlet control: --on=outlet --reboot=outlet",
      "List avaliable outlets and their numbers: --outlets",
      "Global: --all=<1|0>"
   },
   --short options that need args
   commandline="oa";
   vid = 0x16c0,
   pid = 0x05dc,
   vendor = "www.ncrmnt.org",
   product = "tiny-pwr",  
   actions={},
   hacks = { 
      TransformaticMkI = {
	 group = {0,1,2,3,4,5,6,7,8,14,12,13},
	 rickroll = { 14, 12, 13, 0, 1, 2 },
	 inverted = { 2, 1, 0, 14, 13},
	 prohibit = { 9, 10, 11 },
	 outlets = " 12-14 - LEDS\n 0-2 - power control\n 3-8 - spare"
	 },
      alpha = {
	 group = {0,1,2,3,4,5},
	 rickroll = { 0, 1, 2, 3, 4, 5 },
	 inverted = { 0, 1, 2, 3, 4, 5 },
	 prohibit = { 9, 10, 11 },
	 outlets = " 12-14 - LEDS\n 0-2 - power control\n 3-8 - spare"
	 }

   }
};


--      libusb.control_msg(dev.hndl,requesttype,request,value,index,bytes,timeout)

-- Checks if the channel needs to be inverted, returns the state
function check_inversion(dev, arg, state)
   if nil ~= config.hacks[dev.serial] and nil ~= config.hacks[dev.serial].inverted then
      if (table.contains(config.hacks[dev.serial].inverted, tonumber(arg))) then
	 if state==1 then state=0 else state=1 end
      end
   end
   return state;
end

function config.actions.start(i,dev)
   print("Detected: " .. dev.serial);
end

function config.actions.outlets(i,dev,arg)
   print("--- OUTLET INFO ---")
   if nil ~= config.hacks[dev.serial] and nil ~= config.hacks[dev.serial].outlets then
      print( config.hacks[dev.serial].outlets);
   end

end

function config.actions.on(i,dev,arg)
      print("Turning outlet " .. arg .. " on");
      state = check_inversion(dev,arg,1);
      returncode = libusb.control_msg(dev.hndl,
			 USB_TYPE_VENDOR,
			 tonumber(arg),state,0,0,6000)
end

function config.actions.off(i,dev,arg)
      print("Turning outlet " .. arg .. " off");
      state = check_inversion(dev,arg,0);
      returncode = libusb.control_msg(dev.hndl,
			 USB_TYPE_VENDOR,
			 tonumber(arg),state,0,0,6000)
end

function config.actions.reboot(i,dev,arg)
      print("Rebooting outlet " .. arg);
      config.actions.off(i,dev,arg)
      os.execute("sleep 2");
      config.actions.on(i,dev,arg)
      
end

function config.actions.rickroll(i,dev,arg)
   config.actions.all(i,dev,0)
   os.execute("sleep 1")
   if nil ~= config.hacks[dev.serial] and nil ~= config.hacks[dev.serial].rickroll then
      for _,outlet in pairs(config.hacks[dev.serial].rickroll) do
	 config.actions.on(i,dev,outlet)
	 os.execute("sleep 1")
      end
   end

end

function config.actions.all(i,dev,arg)
   print("Setting all outlets to state: " .. arg);
   if nil ~= config.hacks[dev.serial] and nil ~= config.hacks[dev.serial].group then
      for _,n in pairs(config.hacks[dev.serial].group) do
	 if 1==tonumber(arg) then
	    config.actions.on(i,dev,n);
	 else
	    config.actions.off(i,dev,n);
	 end
      end
   end
end

-- called after all the callbacks, if any
function config.actions.finish(i,dev)
    --  print("All done, have fun");
end