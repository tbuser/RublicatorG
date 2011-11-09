#!/usr/bin/env ruby -wKU

require "rublicatorg"

$DEBUG = true

makerbot = RublicatorG.new("/dev/tty.usbserial-A600emXZ")

puts "Motherboard Firmware Version: #{makerbot.motherboard_version} (#{makerbot.motherboard_build_name})"
puts "Toolhead 0 Firmware Version: #{makerbot.toolhead_version(0)} (#{makerbot.toolhead_build_name(0)})"
makerbot.motherboard_init
puts "Machine Name: #{makerbot.name}"
