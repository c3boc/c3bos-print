require 'escper'
require 'json'
require 'erb'
require 'ostruct'
require 'bunny'


@template = "
====== BOC Order ======
ID: <%= order_id %>
Location: <%= location %>
Date: <%= created_at %>

==== Order Details ====
<% for item in order_items %>
* <%= item[\"amount\"] %>x <%= item[\"beverage\"][\"name\"] %>
<% end %>
=======================



"

def print_order(order)
  orderstruct = OpenStruct.new(order)
  text = ERB.new(@template).result(orderstruct.instance_eval { binding })
  print_engine.open
  print_engine.print 1, text
  print_engine.close
end

puts "connect to printer"
printer = Escper::VendorPrinter.new :id => 1, :name => 'Drucker', :path => '/dev/ttyUSB0', :copies => 1
print_engine = Escper::Printer.new 'local', printer

puts "declare connection"
connection = Bunny.new(:host => "rabbitmq",
                       :port => "5672",
                       :vhost => "c3boc.c3bos",
                       :user => "c3bos",
                       :password => "c3bos")

puts "start connection"
connection.start

puts "create channel"
channel = connection.create_channel

puts "connec to queue"
queue  = channel.queue("c3bos.orders", :auto_delete => false)

puts "subscribe to queue"
queue.subscribe do |delivery_info, metadata, payload|
  order = JSON.parse(payload)
  puts "Order ##{order['id']} received"
  print_order(order)
end

sleep
