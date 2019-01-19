require 'json'
require 'erb'
require 'ostruct'
require 'bunny'
require 'libusb'
require 'rubyserial'

@printer = { serial: false, handle: nil, ep: nil }
@queue = nil
@template = <<EOT
====== BOC Order ======
ID: <%= id %>
Location: <%= user['username'] %>
Date: <%= created_at %>

==== Order Details ====
<% for item in order_items %>
* <%= item['amount'] %>x <%= item['beverage']['name'] %>
<% end %>
=======================
EOT

# 38400 is the default baud rate for some Epson printers
def connect_serial(dev, rate = 38400)
  @printer[:serial] = true
  Serial.new(dev, rate.to_i)
end

# finds the first USB device with a printer interface
def find_printer
  unless ARGV.empty?
    connect_serial($1, $2.to_i)
  else
    device = LIBUSB::Context.new.devices.find do |dev|
      dev.settings.find do |s|
        # baseclass printer, subclass printer
        s.bInterfaceClass == 7 && s.bInterfaceSubClass == 1
      end
    end
    if device
      return device
    else
      # try finding serial devices
      serialdevs = Dir.glob ['/dev/cu.*serial*', '/dev/ttyUSB*']
      if serialdevs.any?
        puts 'Found these serial devices:'
        puts serialdevs
        if serialdevs.one?
          dev = serialdevs.first
          puts "Using #{dev}..."
          connect_serial dev
        end
      end
    end
  end
end

def usb_setup(dev)
  product = [dev.manufacturer, dev.product, dev.serial_number].join(' ')
  puts "Using printer '#{product}'"

  ep = dev.endpoints.find { |e| e.direction == :out }
  handle = ep.device.open
  if handle.kernel_driver_active?(ep.interface)
    handle.auto_detach_kernel_driver = true
  end
  handle.claim_interface ep.interface

  @printer[:ep] = ep
  @printer[:handle] = handle
end

def dev_setup
  unless dev = find_printer
    puts 'No printer found!'
    puts 'Printer connected via serial? Specify device and baud rate:'
    puts "#{$0} <device> [rate]"
    exit 1
  end

  if @printer[:serial]
    @printer[:handle] = dev
  else
    usb_setup dev
  end
end

def printer_setup
  dev_setup
  set_encoding 0
end

def queue_setup
  connection = Bunny.new(
    host: ENV['RABBITMQ_HOST'] || 'rabbitmq',
    port: ENV['RABBITMQ_PORT'] || 5672,
    vhost: ENV['RABBITMQ_VHOST'] || 'c3boc.c3bos',
    user: ENV['RABBITMQ_USER'] || 'c3bos',
    password: ENV['RABBITMQ_PASS'] || 'c3bos'
  )

  connection.start
  channel = connection.create_channel
  queue = ENV['RABBITMQ_QUEUE'] || 'c3bos.orders'
  @queue = channel.queue(queue, auto_delete: false)
end

def write(msg)
  if @printer[:serial]
    @printer[:handle].write(msg)
  else
    @printer[:handle].bulk_transfer(endpoint: @printer[:ep], dataOut: msg)
  end
end

# for PC437, use charset 0
def set_encoding(charset)
  write("\x1Bt" + charset.chr)
end

def feed(lines)
  # feed command exists, but this is a failsafe method
  write("\n" * lines)
end

def cut
  write("\x1DV\x00")
end

def prnt(msg)
  write(msg.encode(Encoding::CP437, invalid: :replace, undef: :replace) + "\n")
end

def print_order(order)
  orderstruct = OpenStruct.new(order)
  text = ERB.new(@template).result(orderstruct.instance_eval { binding })
  prnt(text)
  feed(5)
  cut
end

printer_setup
queue_setup

@queue.subscribe do |_delivery_info, _metadata, payload|
  order = JSON.parse(payload)
  puts "Order ##{order['id']} received"
  order['order_items'].reject! { |item| item['amount'].to_i.zero? }
  print_order(order)
end

puts "\nPrinting 'test'"
prnt 'test'
feed 10
cut
puts "done!\n\n---\n\n"
puts 'Ready to take orders'
sleep