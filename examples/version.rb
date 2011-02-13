#!/usr/bin/env ruby -wKU

require "rublicatorg"

$DEBUG = true

makerbot = RublicatorG.new("/dev/tty.usbserial-FTE3Q0I3")

puts "Motherboard Firmware Version: #{makerbot.get_motherboard_version}"

