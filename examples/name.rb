#!/usr/bin/env ruby -wKU

require "rublicatorg"

$DEBUG = true

makerbot = RublicatorG.new("/dev/tty.usbserial-FTE3Q0I3")

old_name = makerbot.name
puts "Old Machine Name: #{old_name}"
makerbot.name = "Foo Bar"
puts "New Machine Name: #{makerbot.name}"
makerbot.name = old_name
puts "Reset Old Machine Name: #{makerbot.name}"
