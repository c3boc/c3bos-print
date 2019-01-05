require 'json'
require 'erb'
require 'ostruct'
require 'bunny'


@template = "
====== BOC Order ======
ID: <%= id %>
Location: <%= user[\"username\"] %>
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
  File.open("/dev/ttyUSB0", "w") { |file| file.write(text.encode(Encoding::CP437)) }
end

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
  order["order_items"].reject! { |item| item["amount"].nil? }
  puts "Order ##{order['id']} received"
  print_order(order)
end

sleep
