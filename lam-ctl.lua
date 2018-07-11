#!/usr/bin/lua
package.path="./?.lua;"..package.path;
require "math"
require "lunarusb"
local bit = require "bit"

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
   vid = 0x1d50,
   pid = 0x6032,
   vendor = "www.ncrmnt.org",
   product = "OpenEtch",  

   hyst = { 
      {
	 adc = 1, --adc channel
	 relay = 2, --relay to use
	 inverted = 1, -- we use NTC thermistor
      }
   },

   temp_setpoint = 160, -- Temperature setpoint
   -- Configuration
   hyst_spacing = 1,   
   Vin = 5.0, -- Logic level
   R_pu = 4700, -- Pull-up resistor value in voltage div, Ohms
   b_coeff = 3990, -- B coefficient for calculations
   r_at_25c = 100000, -- NTC Thermistor resistance in Ohms at 25C */
   offset = 1,
   actions={}   

};

function string:split(pat)
   pat = pat or '%s+'
   local st, g = 1, self:gmatch("()("..pat..")")
   local function getter(segs, seps, sep, cap1, ...)
      st = sep and seps + #sep
      return self:sub(segs, (seps or 0) - 1), cap1 or sep, ...
   end
   return function() if st then return getter(st, g()) end end
end

function kelvin(celsius)
   return 273.15 + celsius;
end

function celsius(kelvin)
   return kelvin - 273.15;
end


function adc_to_volts(v)
   return tonumber(v)*config.Vin/1024.0;
end

function volts_to_adc(v)
   return v*1024/config.Vin;
end

function volts_to_resistance(V)
   return config.R_pu/(config.Vin/V - 1.0);
end

function resistance_to_volts(R)
   return R / (config.R_pu + R) * config.Vin;
end

function resistance_to_degrees(R)
   r=config.r_at_25c*math.exp(-config.b_coeff/kelvin(25.0))
   return celsius(config.b_coeff/math.log(R/r));
end

function degrees_to_resistance(T)
   return config.r_at_25c*math.exp(config.b_coeff * (1/kelvin(T) - 1/kelvin(25.0)));
end


function sleep(n)
  return os.execute("sleep " .. tonumber(n))
end

RQ_RELAY=0
RQ_SET_HYST=1
RQ_GET_HYST=2
RQ_GET_ADC=3
RQ_SET_LED=4


--      libusb.control_msg(dev.hndl,requesttype,request,value,index,bytes,timeout)

function config.actions.start(i,dev)
   print("Detected: " .. dev.vendor .. "  " .. dev.product .. " " .. dev.serial);
end

function config.actions.relay(i,dev,arg)
   v = string.split(arg, ",");
   returncode = libusb.control_msg(dev.hndl,
			 USB_TYPE_VENDOR,
			 RQ_RELAY,v(1),v(2),0,6000)
end


function config.actions.on(i,dev,arg)
   v = string.split(arg, ",");
   id = v(0);
   id = tonumber(id);
   sp = v(1);
   temp = sp;
   temp = volts_to_adc(resistance_to_volts(degrees_to_resistance(temp)))
   off = math.ceil(temp) - config.hyst_spacing;
   on  = math.floor(temp) + config.hyst_spacing;
   enabled = 1;
   if (off < 0 or on < 0) then
      enabled = 0;
   end

   print("Hyst id: "..id.." Set Point: " .. sp .. " Hysteresis values: on "..on.." off "..off);
   settings = string.format("%u %u %u %u %u %u ", 
			    enabled, config.hyst[id].inverted, on, off, config.hyst[id].adc, config.hyst[id].relay)
   libusb.control_msg(dev.hndl,
			 USB_TYPE_VENDOR,
			 RQ_SET_HYST,id,0,settings,6000)
   returncode= 0
end

function config.actions.off(i,dev,arg)
   id = tonumber(arg);
   settings = string.format("%u %u %u %u %u %u ", 
			    0, config.hyst[id].inverted, 0, 0, config.hyst[id].adc, config.hyst[id].relay)
   libusb.control_msg(dev.hndl,
			 USB_TYPE_VENDOR,
			 RQ_SET_HYST,id,0,settings,6000)
   returncode = 0
end

function config.actions.hystch(i,dev,arg)
      print("ADC channel for hyst: "..arg);
      returncode = libusb.control_msg(dev.hndl,
			 USB_TYPE_VENDOR,
			 RQ_SET_HYST_CHAN,tonumber(arg),0,0,6000)
end


function config.actions.adc(i,dev,arg)
   v = libusb.control_msg(dev.hndl,
			     bit.bor(USB_TYPE_VENDOR, 0x80),
			     RQ_GET_ADC,arg,0,32,6000)
   if lunarusb.from_web() then
      return resistance_to_degrees(volts_to_resistance(adc_to_volts(v))); 
   else
      return "Channel " .. arg .. " raw: " .. v .. " volts: " .. 
	    adc_to_volts(v) .. "v" .. 
	    " resistance: " .. volts_to_resistance(adc_to_volts(v)) ..
	    " temp: ".. 
	    resistance_to_degrees(volts_to_resistance(adc_to_volts(v)));   
   end
end

function config.actions.led(i,dev,arg)
   returncode = libusb.control_msg(dev.hndl,
			     bit.bor(USB_TYPE_VENDOR, 0x80),
			     RQ_SET_LED,arg,0,32,6000)
end



function config.actions.toner(i,dev,arg)
   config.actions.on(i,dev,"1,180")
   config.actions.relay(i,dev,"0,1")
end

function config.actions.off(i,dev,arg)
   print("Turning off the heater...")
   config.actions.on(i,dev,"1,18")   
   config.actions.relay(i,dev,"0,1")
   print("Cooling down...")
   repeat
      v = libusb.control_msg(dev.hndl,
			     bit.bor(USB_TYPE_VENDOR, 0x80),
			     RQ_GET_ADC,config.hyst[1].adc,0,32,6000)
      temp = resistance_to_degrees(volts_to_resistance(adc_to_volts(v))); 
   until temp < 100
   config.actions.relay(i,dev,"0,0")
   print("Done!")
end




function config.actions.adcmon(i,dev,arg)
   a = {}
   print("ADC monitoring enabled");
   while true do
   for i=0,2,1 do
      a[i] = libusb.control_msg(dev.hndl,
			       bit.bor(USB_TYPE_VENDOR, 0x80),
			       RQ_GET_ADC,i,0,32,6000)
      io.write(resistance_to_degrees(volts_to_resistance(adc_to_volts(a[i]))).."  \t");
      --io.write(a[i].."  \t");

   end
      io.write("\n");
      io.flush();
   end
end

function config.actions.plot(i,dev,arg)
   os.execute("lua ./lam-ctl.lua --do_plot="..arg.." | driveGnuPlots.pl 1 1500 adc")
end

function config.actions.do_plot(i,dev,arg)
   while true do
      a = libusb.control_msg(dev.hndl,
			     bit.bor(USB_TYPE_VENDOR, 0x80),
			     RQ_GET_ADC, arg, 0, 32, 6000)
      print("0:"..resistance_to_degrees(volts_to_resistance(adc_to_volts(a))));
      sleep(0.3);
   end
end


lunarusb.run()
