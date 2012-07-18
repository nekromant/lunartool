-- PWM Control Utility
config = {
   description = "Servotool Control Utility",
   usage = {
      "Outlet control: --on=outlet --reboot=outlet --off=outlet",
      "PWM control --timer=a --ch=a|b --pwm=value",
      "Servo: --servo=[a|b] --pwm",
      "Global: --all=<1|0>"
   },
   --short options that need args
   commandline="oa";
   vid = 0x1d50,
   pid = 0x6032,
   vendor = "www.ncrmnt.org",
   product = "serv-o-tool",  
   actions={},
};

--      libusb.control_msg(dev.hndl,requesttype,request,value,index,bytes,timeout)

function pwm_private(i,dev,ch,val)
   returncode = libusb.control_msg(dev.hndl,
				   USB_TYPE_VENDOR,
				   ch,val,1,0,6000)
   return returncode
end

function config.actions.start(i,dev)
   print("Using serv-o-tool with serial: " .. dev.serial);
end


function config.actions.pwm16(i,dev,arg)
   print("Setting 16-bit pwm channel " .. lunartool.args['ch'] .. " to ".. arg);
   pwm_private(i,dev,lunartool.args['ch'],arg);
   duty = arg*100/40000;
   dutyms = duty*20/100;
   print("Duty cycle: "..duty.."% "..dutyms.."/20 ms");
end

function config.actions.pwm8(i,dev,arg)
   print("Setting 8-bit pwm channel " .. lunartool.args['ch'] .. " to ".. arg);
   print("TODO: Timing calculation");
   pwm_private(i,dev,lunartool.args['ch'],arg);
end


function config.actions.pwm(i,dev,arg)
   print("Setting pwm channel " .. lunartool.args['ch'] .. " to ".. arg);
      returncode = libusb.control_msg(dev.hndl,
			 USB_TYPE_VENDOR,
			 lunartool.args['ch'],arg,1,0,6000)
end

function config.actions.angle(i,dev,arg)
   m = config.hacks[dev.serial].map[tonumber(lunartool.args['ch'])];
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