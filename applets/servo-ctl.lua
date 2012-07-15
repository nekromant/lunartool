-- PWM Control Utility
config = {
   description = "Servo/PWM Control Utility",
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
   product = "servomatic",  
   actions={},
   hacks = { 
      ServoMaticMKI = {
	 servocount = 15,
	 -- maxangle ; pwm_mix; pwm_max
	 defmap = { 180, 900, 4600 },
	 map = { 
	    [1]  = { 180, 900, 4600 };
	    [2] = { 180, 900, 4600 };
	    [3]  = { 180, 900, 4600 };
	    [4]  = { 180, 900, 4600 };
	    [5] = { 180, 900, 4600 };
	    [13] = { 180, 900, 4600 };
	 },
	 prohibit = { 9, 10, 11 },
	 outlets = " 12-14 - LEDS\n 0-2 - power control\n 3-8 - spare"
      }
   }
};


--      libusb.control_msg(dev.hndl,requesttype,request,value,index,bytes,timeout)

function config.actions.start(i,dev)
   print("Detected: " .. dev.serial);
end

function config.actions.pwm(i,dev,arg)
   print("Setting pwm channel " .. lunartool.args['ch'] .. " to ".. arg);
      -- state = check_inversion(dev,arg,1);
      returncode = libusb.control_msg(dev.hndl,
			 USB_TYPE_VENDOR,
			 lunartool.args['ch'],arg,1,0,6000)
end

function config.actions.angle(i,dev,arg)
   m = config.hacks[dev.serial].map[tonumber(lunartool.args['ch'])];
   if (m == nil) then
      m = config.hacks[dev.serial].defmap;
   end
   print(m);
   print(table.tostring(m));
   local k = (m[3]-m[2])/m[1];
   local pwm = k*arg+m[2];
   config.actions.pwm(i, dev, pwm);
   
   
end

function config.actions.interactive(i,dev,arg)
   print("Interactive mode for channel: " .. lunartool.args['ch']);
   print("Step: " .. lunartool.args['step']);
   print("Start: " .. lunartool.args['start']);
   print("Use q & w to increment &decrment");
   os.execute("stty raw opost -echo")
   local pwm = tonumber(lunartool.args['start']);
   local step = lunartool.args['step'];
   while true do
      local k = io.read(1);
      if k == 'w' then
	 pwm=pwm+step
      else if k == 's' then
	    pwm = pwm - step
	   else if k == 'q' then
		 break
		end
	   end
      end
      print("PWM: " .. pwm);
      config.actions.pwm(i, dev, pwm);
   end
   os.execute("stty sane")
end

function config.actions.off(i,dev,arg)
   print("Turning pwm channel " .. lunartool.args['ch'] .. " off" );
      -- state = check_inversion(dev,arg,1);
      returncode = libusb.control_msg(dev.hndl,
			 USB_TYPE_VENDOR,
			 lunartool.args['ch'],arg,0,0,6000)
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