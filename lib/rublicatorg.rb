#!/usr/bin/env ruby -wKU

# RublicatorG - Ruby Makerbot/RepRap Control
# Copyright (C) 2011 Tony Buser <tbuser@gmail.com> - http://tonybuser.com
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

# Protocol Definitions:
# https://docs.google.com/Doc?docid=0AcWKwJ2SAxDzZGd6amZyY2NfMmdtODRnZ2Ri&hl=en&pli=1
# http://replicat.org/sanguino3g#responsecode

require "rubygems"
require "serialport"

class Array
  def hex_to_str
    str = ""
    self.collect{|b| str << "%c" % b}
    str
  end
  
  def to_hex_str
    self.collect{|e| "0x%02x" % e}.join(" ")
  end
end

class String
  def to_hex_str
    str = ""
    self.each_byte {|b| str << '0x%02x ' % b}
    str.strip
  end

  def to_hex_array
    arr = []
    self.each_byte {|b| arr << '0x%02x' % b}
    arr
  end
  
  def from_hex_str
    data = self.split(' ')
    str = ""
    data.each{|h| eval "str += '%c' % #{h}"}
    str
  end
end

# class Bignum
#   # This is needed because String#unpack() can't handle little-endian signed longs...
#   # instead we unpack() as a little-endian unsigned long (i.e. 'V') and then use this
#   # method to convert to signed long.
#   def as_signed
#     -1*(self^0xffffffff) if self > 0xfffffff
#   end
# end

$DEV ||= nil

class RublicatorG
  START_BYTE = 0xd5
  
  @@motherboard_codes = {
    # query
    "version"                 => 0x00,
    "init"                    => 0x01,
    "get_buffer_size"         => 0x02,
    "clear_buffer"            => 0x03,
    "get_position"            => 0x04,
    "get_range"               => 0x05,
    "set_range"               => 0x06,
    "abort"                   => 0x07,
    "pause"                   => 0x08,
    "probe"                   => 0x09,
    "tool_query"              => 0x0a,
    "is_finished"             => 0x0b,
    "read_eeprom"             => 0x0c,
    "write_eeprom"            => 0x0d,
    "capture_to_file"         => 0x0e,
    "end_capture"             => 0x0f,
    "playback_file"           => 0x10,
    "reset"                   => 0x11,
    "next_filename"           => 0x12,
    "read_debug_registers"    => 0x13,
    "get_build_name"          => 0x14,
    # buffered
    "queue_point_absolute"    => 0x81,
    "set_position_registers"  => 0x82,
    "find_axes_min"           => 0x83,
    "find_axes_max"           => 0x84,
    "delay"                   => 0x85,
    "change_tool"             => 0x86,
    "wait_for_tool"           => 0x87,
    "tool_command"            => 0x88,
    "enable_axes"             => 0x89
  }
  
  @@toolhead_codes = {
    "version"                 => 0x00,
    "init"                    => 0x01,
    "get_temperature"         => 0x02,
    "set_motor1_pwm"          => 0x04,
    "set_motor2_pwm"          => 0x05,
    "set_motor1_rpm"          => 0x06,
    "set_motor2_rpm"          => 0x07,
    "set_motor1_direction"    => 0x08,
    "set_motor2_direction"    => 0x09,
    "toggle_motor1"           => 0x0a,
    "toggle_motor2"           => 0x0b,
    "toggle_fan"              => 0x0c,
    "toggle_valve"            => 0x0d,
    "set_servo1_position"     => 0x0e,
    "set_servo2_position"     => 0x0f,
    "filament_status"         => 0x10,
    "get_motor1_rpm"          => 0x11,
    "get_motor2_rpm"          => 0x12,
    "get_motor1_pwm"          => 0x13,
    "get_motor2_pwm"          => 0x14,
    "select_tool"             => 0x15,
    "is_tool_ready"           => 0x16,
    
    "get_build_name"          => 0x22
  }
  
  @@response_codes = {
    0x00 => "Generic error, packet discarded.",
    0x01 => "Success.",
    0x02 => "Action buffer overflow, entire packet discarded.",
    0x03 => "CRC mismatch, packet discarded.",
    0x04 => "Query packet too big, packet discarded.",
    0x05 => "Command not supported/recognized.",
    0x06 => "Success; expect more packets.  Used when a single reponse packet cannot contain the entire message to be retrieved.",
    0x07 => "Downstream timeout (for example, a toolhead timed out)."
  }
  
  @@sd_response_codes = {
    0x00 => "operation was successful",
    0x01 => "no SD card was present",
    0x02 => "SD card init failed",
    0x03 => "partition table could not be read",
    0x04 => "filesystem could not be opened",
    0x05 => "root directory could not be opened",
    0x06 => "SD card is locked",
    0x07 => "no such file"
  }
  
  @@mutex = Mutex.new
  
  def initialize(dev = nil)
    dev ||= $DEV

    @@mutex.synchronize do
      begin
        @sp = SerialPort.new(dev, 115200, 8, 1, SerialPort::NONE)

        # @sp.flow_control = SerialPort::HARD
        @sp.read_timeout = 5000
        $stderr.puts "Cannot connect to #{dev}" if @sp.nil?
      # rescue Errno::EBUSY
      rescue
        raise "Cannot connect. The serial port device is busy or unavailable."
      end
    end

    puts "Connected to: serial port #{dev}" if $DEBUG
  end

  # Close the connection
  def close
    @@mutex.synchronize do
      @sp.close if @sp and not @sp.closed?
    end
  end

  # Returns true if the connection to the machine is open; false otherwise
  def connected?
    not @sp.closed?
  end
  
  def send_and_receive(payload, request_reply=true)
    msg = [START_BYTE] + [payload.size] + payload + [crc8(payload.hex_to_str)]

    send_cmd(msg)

    # FIXME: ugly hackish timing, there are much more intelligent ways to handle the delay
    sleep(1)

    if request_reply
      ok,response = recv_reply

      if ok #and response[1] == op[1]
        # data = response[3..response.size]
        data = response
        # TODO ? if data contains a \n character, ruby seems to pass the parts before and after the \n
        # as two different parameters... we need to encode the data into a format that doesn't
        # contain any \n's and then decode it in the receiving method
        # data = data.to_hex_str
      elsif !ok
        $stderr.puts response
        data = false
      else
        $stderr.puts "ERROR: Unexpected response #{response}"
        data = false
      end
    else
      data = true
    end
    data
  end

  def send_cmd(payload)
    @@mutex.synchronize do
      puts "Sending message: #{payload.to_hex_str}" if $DEBUG
      payload.each do |b|
        @sp.putc b
      end
    end
  end

  def recv_reply
    @@mutex.synchronize do
      begin
        header        = @sp.sysread(2)
        start_byte    = header[0..0].to_hex_str
        length        = header[1..1].unpack("C")[0]

        payload       = @sp.sysread(length)
        response_code = payload[0..0].to_hex_str
        msg           = payload[1..-1]

        crc           = @sp.sysread(1).to_hex_str

      # rescue EOFError
      rescue
      	raise "Cannot read from the machine.  Make sure the device is on and connected."
      end

      puts "Received Message: start_byte: #{start_byte} length: #{length} response_code: #{response_code} payload: #{msg.to_hex_str} crc: #{crc}" if $DEBUG

      if response_code != '0x81'
        error = "ERROR: #{@@response_codes[response_code]}"
        return [false,error]
      end

      return [true,msg]
    end
  end

  def crc8(str, crc=0)
    str.each_byte do |byte|
      # * This is a Java implementation of the IButton/Maxim 8-bit CRC. Code ported
      # * from the AVR-libc implementation, which is used on the RR3G end.    
      # crc = (crc ^ data) & 0xff; // i loathe java's promotion rules
      # for (int i = 0; i < 8; i++) {
      #         if ((crc & 0x01) != 0) {
      #                 crc = ((crc >>> 1) ^ 0x8c) & 0xff;
      #         } else {
      #                 crc = (crc >>> 1) & 0xff;
      #         }
      # }

      crc = (crc ^ byte) & 0xff

      8.times do |i|
        unless crc & 0x01 == 0
          crc = ((crc >> 1) ^ 0x8c) & 0xff
        else
          crc = (crc >> 1) & 0xff
        end
      end
    end

    crc
  end

  def motherboard_version
    if result = send_and_receive([@@motherboard_codes["version"]])
      result = result.unpack("v")[0]
      "#{result/100}.#{result % 100}"
    else
      false
    end
  end

  def motherboard_build_name
    if result = send_and_receive([@@motherboard_codes["get_build_name"]])
      result
    else
      false
    end
  end

  def motherboard_init
    if result = send_and_receive([@@motherboard_codes["init"]])
      result
    else
      false
    end
  end

  def name
    payload = []
    payload << @@motherboard_codes["read_eeprom"]
    # at position: 32, integer uint16 to 2 bytes
    payload << (32 & 0xff)
    payload << ((32 >> 8) & 0xff)
    # length to read: 16
    payload << 16
    
    if result = send_and_receive(payload)
      result
    else
      false
    end
  end
  
  def name=(str)
    raise "Name too long.  Name must be <= 16 characters." if str.size > 16
    
    payload = []
    payload << @@motherboard_codes["write_eeprom"]
    # at position: 32, integer uint16 to 2 bytes
    payload << (32 & 0xff)
    payload << ((32 >> 8) & 0xff)
    # length to write
    payload << 16
    # send the name
    str.ljust(16).each_byte do |byte|
      payload << byte
    end
    
    if result = send_and_receive(payload)
      result
    else
      false
    end
  end

  def toolhead_version(tool_id=0)
    payload = [@@motherboard_codes["tool_query"], tool_id, @@toolhead_codes["version"]]
    
    if result = send_and_receive(payload)
      result = result.unpack("v")[0]
      "#{result/100}.#{result % 100}"
    else
      false
    end
  end

  def toolhead_build_name(tool_id=0)
    payload = [@@motherboard_codes["tool_query"], tool_id, @@toolhead_codes["get_build_name"]]
    
    if result = send_and_receive(payload)
      result
    else
      false
    end
  end

  def filenames
    filenames = []

    # keep reading until result is blank? or a max of 100
    100.times do |x|
      filename = send_and_receive([@@motherboard_codes["next_filename"], x == 0 ? 1 : 0]).gsub(/\000/, '')
      if filename == ""
        break
      else
        filenames << filename
      end
    end      

    filenames
  end
  
  def run(filename)
    raise "Filename too long.  Name must be <= 12 characters." if filename.size > 12
    
    payload = []
    payload << @@motherboard_codes["playback_file"]
    filename.each_byte do |byte|
      payload << byte
    end
    
    if result = send_and_receive(payload)
      result
    else
      false
    end
  end
  
end
