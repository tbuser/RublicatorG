#!/usr/bin/env ruby -wKU

require "rublicatorg"

$DEBUG = true

makerbot = RublicatorG.new("/dev/tty.usbserial-A600emXZ")

makerbot.run("home.s3g")

