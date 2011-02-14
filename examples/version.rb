#!/usr/bin/env ruby -wKU

require "rublicatorg"

# $DEBUG = true

makerbot = RublicatorG.new("/dev/tty.usbserial-FTE3Q0I3")

puts "Motherboard Firmware Version: #{makerbot.get_motherboard_version} (#{makerbot.get_motherboard_build_name})"
puts "Toolhead Firmware Version: #{makerbot.get_toolhead_version(0)} (#{makerbot.get_toolhead_build_name(0)})"
puts "Machine Name: #{makerbot.machine_name}"
